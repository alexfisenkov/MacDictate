import dotenv from 'dotenv';
import express from 'express';
import cors from 'cors';
import {
    initDb,
    getOrder,
    updateOrderStatus,
    updateDeviceLicense
} from './db.js';
import { generateToken } from './tinkoff.js';
import { getPlanByAmountRub } from './plans.js';
import { legacyFreeAccess } from './access-policy.js';

dotenv.config();

const app = express();
app.set('trust proxy', true);

const DEFAULT_ALLOWED_ORIGINS = [
    'https://macdictate.pro',
    'http://localhost:3000',
    'http://127.0.0.1:3000'
];
const DEVICE_ID_RE = /^[A-Za-z0-9][A-Za-z0-9_-]{3,63}$/;
const rateLimitBuckets = new Map();

function parsePositiveInt(rawValue, fallback) {
    const value = Number.parseInt(rawValue || '', 10);
    return Number.isFinite(value) && value > 0 ? value : fallback;
}

function parseAllowedOrigins(rawValue) {
    const origins = (rawValue || '')
        .split(',')
        .map((value) => value.trim())
        .filter(Boolean);

    return new Set(origins.length > 0 ? origins : DEFAULT_ALLOWED_ORIGINS);
}

function createCorsOptions() {
    const allowedOrigins = parseAllowedOrigins(process.env.ALLOWED_ORIGINS);

    return {
        origin(origin, callback) {
            if (!origin || allowedOrigins.has(origin)) {
                callback(null, true);
                return;
            }

            callback(new Error('CORS origin denied'));
        }
    };
}


function sendError(res, status, code, message) {
    res.status(status).json({ error: message, code });
}

function normalizeDeviceId(value) {
    return typeof value === 'string' ? value.trim() : '';
}


function validateDeviceId(deviceId) {
    return DEVICE_ID_RE.test(deviceId);
}


const slowRequestLogMs = parsePositiveInt(process.env.SLOW_REQUEST_LOG_MS, 1000);

function createRateLimiter({ windowMs, maxRequests }) {
    return (req, res, next) => {
        const now = Date.now();
        const key = `${req.path}:${req.ip}`;
        const existing = rateLimitBuckets.get(key);

        if (!existing || existing.resetAt <= now) {
            rateLimitBuckets.set(key, { count: 1, resetAt: now + windowMs });
            next();
            return;
        }

        existing.count += 1;
        if (existing.count > maxRequests) {
            const retryAfterSeconds = Math.ceil((existing.resetAt - now) / 1000);
            res.set('Retry-After', String(retryAfterSeconds));
            sendError(
                res,
                429,
                'RATE_LIMITED',
                'Too many requests. Please retry later.'
            );
            return;
        }

        next();
    };
}


app.disable('x-powered-by');
app.use(cors(createCorsOptions()));
app.use(express.json({ limit: '32kb' }));
app.use(express.urlencoded({ extended: true, limit: '32kb' }));
app.use((req, res, next) => {
    const start = process.hrtime.bigint();
    res.on('finish', () => {
        const durationMs = Number(process.hrtime.bigint() - start) / 1_000_000;
        if (durationMs >= slowRequestLogMs) {
            console.warn(
                JSON.stringify({
                    event: 'slow_request',
                    method: req.method,
                    path: req.path,
                    status: res.statusCode,
                    durationMs: Math.round(durationMs)
                })
            );
        }
    });
    next();
});

const licenseStatusLimiter = createRateLimiter({ windowMs: 60_000, maxRequests: 120 });
const plansLimiter = createRateLimiter({ windowMs: 60_000, maxRequests: 120 });
const paymentCreateLimiter = createRateLimiter({ windowMs: 15 * 60_000, maxRequests: 10 });

app.get(['/healthz', '/api/health'], (_req, res) => {
    res.json({
        status: 'ok',
        service: 'macdictate-api',
        uptimeSeconds: Math.round(process.uptime()),
        timestamp: new Date().toISOString()
    });
});

// Compatibility for older desktop apps; new apps never call this endpoint.
app.get('/api/license/status', licenseStatusLimiter, async (req, res) => {
    const deviceId = normalizeDeviceId(req.query.deviceId);
    if (!deviceId) {
        sendError(res, 400, 'DEVICE_ID_REQUIRED', 'deviceId required');
        return;
    }

    if (!validateDeviceId(deviceId)) {
        sendError(res, 400, 'INVALID_DEVICE_ID', 'deviceId is invalid');
        return;
    }

    res.json(legacyFreeAccess(deviceId));
});

app.get('/api/plans', plansLimiter, (_req, res) => {
    res.json({ plans: [], accessMode: 'free' });
});

// No new orders or provider requests after the free desktop transition.
// Existing order callbacks below remain supported for payment reconciliation.
app.post('/api/payment/create', paymentCreateLimiter, (_req, res) => {
    sendError(res, 410, 'PAYMENTS_DISABLED', 'MacDictate is free. Download it at https://macdictate.pro/');
});

// 3. Tinkoff Webhook Callback
app.post('/api/payment/webhook', async (req, res) => {
    const data = req.body;
    
    // Always return "OK" to Tinkoff immediately
    res.send('OK');

    try {
        // Validate Token
        const providedToken = data.Token;
        const calculatedToken = generateToken(data);
        
        if (providedToken !== calculatedToken) {
            console.error('Invalid Webhook Token!');
            return;
        }

        const order = await getOrder(data.OrderId);
        if (!order) {
            console.error(`Unknown order in webhook: ${data.OrderId}`);
            return;
        }

        if (data.Status === 'CONFIRMED') {
            if (order.status === 'CONFIRMED') {
                return;
            }

            const explicitPlanMonths = Number.parseInt(order.plan_months, 10);
            const legacyPlan = getPlanByAmountRub(Number.parseInt(order.amount, 10) / 100);
            const months = Number.isFinite(explicitPlanMonths)
                ? explicitPlanMonths
                : legacyPlan?.months;

            if (!months) {
                console.error(`Cannot resolve license duration for order ${data.OrderId}`);
                return;
            }

            await updateOrderStatus(data.OrderId, 'CONFIRMED', {
                providerPaymentId: data.PaymentId ? String(data.PaymentId) : order.provider_payment_id,
                providerOrderId: data.OrderId ? String(data.OrderId) : order.provider_order_id,
                confirmedAt: new Date().toISOString()
            });

            await updateDeviceLicense(order.device_id, order.email || data.Email || null, months);
            console.log(`License updated for device ${order.device_id}!`);
            return;
        }

        await updateOrderStatus(data.OrderId, data.Status || 'UNKNOWN', {
            providerPaymentId: data.PaymentId ? String(data.PaymentId) : order.provider_payment_id,
            providerOrderId: data.OrderId ? String(data.OrderId) : order.provider_order_id
        });
    } catch (e) {
        console.error('Webhook processing error:', e);
    }
});

const PORT = process.env.PORT || 3000;

app.use((err, _req, res, _next) => {
    if (err?.message === 'CORS origin denied') {
        sendError(res, 403, 'CORS_NOT_ALLOWED', 'Origin is not allowed');
        return;
    }

    sendError(res, 500, err?.code || 'INTERNAL_ERROR', err?.message || 'Internal server error');
});

async function startServer() {
    await initDb();

    const server = app.listen(PORT, () => {
        console.log(`MacDictate API running on port ${PORT}`);
    });

    server.requestTimeout = parsePositiveInt(process.env.SERVER_REQUEST_TIMEOUT_MS, 30_000);
    server.headersTimeout = parsePositiveInt(process.env.SERVER_HEADERS_TIMEOUT_MS, 35_000);
    server.keepAliveTimeout = parsePositiveInt(process.env.SERVER_KEEP_ALIVE_TIMEOUT_MS, 65_000);
}

startServer().catch((error) => {
    console.error('Failed to start MacDictate API:', error);
    process.exit(1);
});
