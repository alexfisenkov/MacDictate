import dotenv from 'dotenv';
import express from 'express';
import cors from 'cors';
import crypto from 'crypto';
import {
    initDb,
    getOrCreateDevice,
    createOrder,
    getOrder,
    updateOrderStatus,
    updateDeviceLicense
} from './db.js';
import {
    initPayment,
    generateToken,
    assertPaymentConfig,
    PaymentConfigurationError
} from './tinkoff.js';
import { getPublicPlans, resolvePlanSelection, getPlanByAmountRub } from './plans.js';

dotenv.config();

const app = express();
app.set('trust proxy', true);

const DEFAULT_ALLOWED_ORIGINS = [
    'https://macdictate.pro',
    'http://localhost:3000',
    'http://127.0.0.1:3000'
];
const DEVICE_ID_RE = /^[A-Za-z0-9][A-Za-z0-9_-]{3,63}$/;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const rateLimitBuckets = new Map();

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

function apiError(code, message, status = 400) {
    const error = new Error(message);
    error.code = code;
    error.status = status;
    return error;
}

function sendError(res, status, code, message) {
    res.status(status).json({ error: message, code });
}

function normalizeDeviceId(value) {
    return typeof value === 'string' ? value.trim() : '';
}

function normalizeEmail(value) {
    return typeof value === 'string' ? value.trim().toLowerCase() : '';
}

function validateDeviceId(deviceId) {
    return DEVICE_ID_RE.test(deviceId);
}

function validateEmail(email) {
    return email.length <= 254 && EMAIL_RE.test(email);
}

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

function readPaymentSelection(body) {
    const deviceId = normalizeDeviceId(body.deviceId);
    const email = normalizeEmail(body.email);

    if (!validateDeviceId(deviceId)) {
        throw apiError('INVALID_DEVICE_ID', 'deviceId is invalid', 400);
    }

    if (!validateEmail(email)) {
        throw apiError('INVALID_EMAIL', 'email is invalid', 400);
    }

    const plan = resolvePlanSelection({
        planId: body.planId,
        planMonths: body.planMonths,
        amount: body.amount
    });

    if (!plan) {
        throw apiError(
            'INVALID_PLAN',
            'planId is invalid or legacy amount/months do not match the server catalog',
            400
        );
    }

    return { deviceId, email, plan };
}

app.use(cors(createCorsOptions()));
app.use(express.json({ limit: '32kb' }));
app.use(express.urlencoded({ extended: true, limit: '32kb' }));

const licenseStatusLimiter = createRateLimiter({ windowMs: 60_000, maxRequests: 120 });
const plansLimiter = createRateLimiter({ windowMs: 60_000, maxRequests: 120 });
const paymentCreateLimiter = createRateLimiter({ windowMs: 15 * 60_000, maxRequests: 10 });

// 1. App calling to check license status
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

    try {
        const device = await getOrCreateDevice(deviceId);
        const expires = new Date(device.expires_at);
        const now = new Date();
        const isActive = device.is_paid || expires > now;
        
        res.json({
            deviceId: device.device_id,
            isPaid: !!device.is_paid,
            isActive: isActive,
            expiresAt: device.expires_at,
            daysLeft: Math.max(0, Math.ceil((expires - now) / (1000 * 60 * 60 * 24)))
        });
    } catch (e) {
        sendError(res, 500, 'LICENSE_STATUS_ERROR', e.message);
    }
});

app.get('/api/plans', plansLimiter, (_req, res) => {
    res.json({ plans: getPublicPlans() });
});

// 2. Generate Payment Link
app.post('/api/payment/create', paymentCreateLimiter, async (req, res) => {
    let selection;

    try {
        selection = readPaymentSelection(req.body);
    } catch (error) {
        sendError(res, error.status || 400, error.code || 'BAD_REQUEST', error.message);
        return;
    }

    try {
        assertPaymentConfig();
    } catch (error) {
        if (error instanceof PaymentConfigurationError) {
            sendError(res, 503, error.code, error.message);
            return;
        }

        sendError(res, 500, 'PAYMENT_CONFIG_ERROR', error.message);
        return;
    }

    const amountKopecks = selection.plan.amountRub * 100;
    const orderId = `MD-${Date.now()}-${crypto.randomBytes(4).toString('hex')}`;

    try {
        await createOrder({
            orderId,
            deviceId: selection.deviceId,
            email: selection.email,
            planId: selection.plan.planId,
            planMonths: selection.plan.months,
            amount: amountKopecks,
            status: 'NEW'
        });
        
        const tinkoffRes = await initPayment({
            orderId,
            amountKopecks,
            deviceId: selection.deviceId,
            email: selection.email,
            plan: selection.plan
        });
        
        if (tinkoffRes.Success && tinkoffRes.PaymentURL) {
            await updateOrderStatus(orderId, 'INITIATED', {
                providerPaymentId: tinkoffRes.PaymentId ? String(tinkoffRes.PaymentId) : null,
                providerOrderId: tinkoffRes.OrderId ? String(tinkoffRes.OrderId) : orderId
            });

            res.json({
                paymentUrl: tinkoffRes.PaymentURL,
                orderId,
                planId: selection.plan.planId
            });
        } else {
            await updateOrderStatus(orderId, 'INIT_FAILED', {
                providerPaymentId: tinkoffRes.PaymentId ? String(tinkoffRes.PaymentId) : null,
                providerOrderId: tinkoffRes.OrderId ? String(tinkoffRes.OrderId) : orderId
            });

            sendError(
                res,
                400,
                'PAYMENT_INIT_FAILED',
                tinkoffRes.Details || tinkoffRes.Message || 'Payment initialization failed'
            );
        }
    } catch (e) {
        if (e instanceof PaymentConfigurationError) {
            sendError(res, 503, e.code, e.message);
            return;
        }

        const providerMessage = e.response?.data?.Details || e.response?.data?.Message;
        if (providerMessage) {
            sendError(res, 502, 'PAYMENT_PROVIDER_ERROR', providerMessage);
            return;
        }

        sendError(res, 500, 'PAYMENT_CREATE_ERROR', e.message);
    }
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

    app.listen(PORT, () => {
        console.log(`MacDictate API running on port ${PORT}`);
    });
}

startServer().catch((error) => {
    console.error('Failed to start MacDictate API:', error);
    process.exit(1);
});
