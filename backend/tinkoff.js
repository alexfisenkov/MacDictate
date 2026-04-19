import crypto from 'crypto';
import axios from 'axios';
import { HttpsProxyAgent } from 'https-proxy-agent';
import dotenv from 'dotenv';
import { getPlanDescription, getPlanReceiptName } from './plans.js';

dotenv.config();

const API_URL = 'https://securepay.tinkoff.ru/v2';
const DEFAULT_PUBLIC_BASE_URL = 'https://macdictate.pro';

export class PaymentConfigurationError extends Error {
    constructor(message) {
        super(message);
        this.name = 'PaymentConfigurationError';
        this.code = 'PAYMENTS_NOT_CONFIGURED';
    }
}

function getPaymentConfig() {
    const terminalKey = process.env.TINKOFF_TERMINAL_KEY?.trim();
    const terminalPassword = process.env.TINKOFF_PASSWORD?.trim();
    const publicBaseUrl = (process.env.PUBLIC_BASE_URL || DEFAULT_PUBLIC_BASE_URL).replace(/\/+$/, '');

    if (!terminalKey || !terminalPassword) {
        throw new PaymentConfigurationError(
            'Tinkoff payment credentials are not configured in environment variables'
        );
    }

    return {
        terminalKey,
        terminalPassword,
        publicBaseUrl
    };
}

function createRequestConfig() {
    const timeout = Number.parseInt(process.env.PAYMENT_TIMEOUT_MS || '10000', 10);
    const proxyUrl = process.env.OUTBOUND_PROXY_URL?.trim();
    const config = {
        timeout: Number.isFinite(timeout) ? timeout : 10000
    };

    if (proxyUrl) {
        config.httpsAgent = new HttpsProxyAgent(proxyUrl);
        config.proxy = false;
    }

    return config;
}

export function assertPaymentConfig() {
    return getPaymentConfig();
}

export function generateToken(params) {
    const { terminalPassword } = getPaymentConfig();
    const data = { ...params };
    
    // According to Tinkoff Docs, these fields are ignored in token calculation
    delete data.Token;
    delete data.Shops;
    delete data.Receipt;
    delete data.DATA;

    data.Password = terminalPassword;

    // Sort keys alphabetically
    const keys = Object.keys(data).sort();
    
    // Concatenate string values
    let concatenatedString = "";
    keys.forEach(k => {
        if (typeof data[k] !== 'object' && data[k] !== undefined && data[k] !== null) {
            concatenatedString += String(data[k]);
        }
    });

    // Hash with SHA-256
    return crypto.createHash('sha256').update(concatenatedString).digest('hex');
}

export async function initPayment({ orderId, amountKopecks, deviceId, email, plan }) {
    const { terminalKey, publicBaseUrl } = getPaymentConfig();
    const params = {
        TerminalKey: terminalKey,
        Amount: amountKopecks,
        OrderId: orderId,
        Description: getPlanDescription(plan),
        NotificationURL: `${publicBaseUrl}/api/payment/webhook`,
        SuccessURL: `${publicBaseUrl}/success.html`,
        FailURL: `${publicBaseUrl}/fail.html`,
        DATA: {
            deviceId,
            planId: plan.planId
        },
        Receipt: {
            Email: email,
            Taxation: 'usn_income',
            Items: [
                {
                    Name: getPlanReceiptName(plan),
                    Price: amountKopecks,
                    Quantity: 1,
                    Amount: amountKopecks,
                    PaymentMethod: 'full_prepayment',
                    PaymentObject: 'service',
                    Tax: 'none'
                }
            ]
        }
    };

    params.Token = generateToken(params);

    try {
        const response = await axios.post(`${API_URL}/Init`, params, createRequestConfig());
        return response.data;
    } catch (e) {
        console.error('Tinkoff Init Error:', e.response?.data || e.message);
        throw e;
    }
}
