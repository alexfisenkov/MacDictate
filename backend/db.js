import sqlite3 from 'sqlite3';
import dotenv from 'dotenv';
import { mkdirSync } from 'fs';
import { join, dirname as pathDirname } from 'path';
import { fileURLToPath } from 'url';

dotenv.config();

const __dirname = pathDirname(fileURLToPath(import.meta.url));
const dbPath = process.env.DB_PATH || join(__dirname, 'database.sqlite');

if (dbPath !== ':memory:') {
    mkdirSync(pathDirname(dbPath), { recursive: true });
}

const db = new sqlite3.Database(dbPath);

function run(sql, params = []) {
    return new Promise((resolve, reject) => {
        db.run(sql, params, function onRun(err) {
            if (err) {
                reject(err);
                return;
            }

            resolve(this);
        });
    });
}

function get(sql, params = []) {
    return new Promise((resolve, reject) => {
        db.get(sql, params, (err, row) => {
            if (err) {
                reject(err);
                return;
            }

            resolve(row);
        });
    });
}

function all(sql, params = []) {
    return new Promise((resolve, reject) => {
        db.all(sql, params, (err, rows) => {
            if (err) {
                reject(err);
                return;
            }

            resolve(rows);
        });
    });
}

async function ensureColumn(tableName, columnName, definition) {
    const columns = await all(`PRAGMA table_info(${tableName})`);
    if (columns.some((column) => column.name === columnName)) {
        return;
    }

    await run(`ALTER TABLE ${tableName} ADD COLUMN ${definition}`);
}

export async function initDb() {
    await run(`CREATE TABLE IF NOT EXISTS devices (
        device_id TEXT PRIMARY KEY,
        email TEXT,
        started_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        expires_at DATETIME,
        is_paid BOOLEAN DEFAULT 0
    )`);

    await run(`CREATE TABLE IF NOT EXISTS orders (
        order_id TEXT PRIMARY KEY,
        device_id TEXT,
        amount INTEGER,
        status TEXT DEFAULT 'NEW',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (device_id) REFERENCES devices (device_id)
    )`);

    await ensureColumn('orders', 'email', 'email TEXT');
    await ensureColumn('orders', 'plan_id', 'plan_id TEXT');
    await ensureColumn('orders', 'plan_months', 'plan_months INTEGER');
    await ensureColumn('orders', 'provider_payment_id', 'provider_payment_id TEXT');
    await ensureColumn('orders', 'provider_order_id', 'provider_order_id TEXT');
    await ensureColumn('orders', 'confirmed_at', 'confirmed_at DATETIME');

    await run('CREATE INDEX IF NOT EXISTS idx_orders_device_id ON orders (device_id)');
    await run('CREATE INDEX IF NOT EXISTS idx_orders_status ON orders (status)');
}

async function getDevice(deviceId) {
    return get('SELECT * FROM devices WHERE device_id = ?', [deviceId]);
}

export async function getOrCreateDevice(deviceId) {
    const existingDevice = await getDevice(deviceId);
    if (existingDevice) {
        return existingDevice;
    }

    const expires = new Date();
    expires.setDate(expires.getDate() + 60);

    await run(
        'INSERT INTO devices (device_id, expires_at) VALUES (?, ?)',
        [deviceId, expires.toISOString()]
    );

    return getDevice(deviceId);
}

export async function updateDeviceLicense(deviceId, email, planMonths) {
    const device = await getOrCreateDevice(deviceId);
    let currentExpires = new Date(device.expires_at);
    const now = new Date();

    if (currentExpires < now) {
        currentExpires = now;
    }

    currentExpires.setMonth(currentExpires.getMonth() + planMonths);

    await run(
        `UPDATE devices
         SET is_paid = 1,
             email = COALESCE(?, email),
             expires_at = ?
         WHERE device_id = ?`,
        [email || null, currentExpires.toISOString(), deviceId]
    );

    return true;
}

export async function createOrder({
    orderId,
    deviceId,
    email,
    planId,
    planMonths,
    amount,
    status = 'NEW',
    providerPaymentId = null,
    providerOrderId = null
}) {
    await run(
        `INSERT INTO orders (
            order_id,
            device_id,
            email,
            plan_id,
            plan_months,
            amount,
            status,
            provider_payment_id,
            provider_order_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
            orderId,
            deviceId,
            email || null,
            planId || null,
            planMonths ?? null,
            amount,
            status,
            providerPaymentId,
            providerOrderId
        ]
    );

    return true;
}

export async function getOrder(orderId) {
    return get('SELECT * FROM orders WHERE order_id = ?', [orderId]);
}

export async function updateOrderStatus(orderId, status, metadata = {}) {
    const updates = ['status = ?'];
    const values = [status];

    if (Object.prototype.hasOwnProperty.call(metadata, 'providerPaymentId')) {
        updates.push('provider_payment_id = ?');
        values.push(metadata.providerPaymentId);
    }

    if (Object.prototype.hasOwnProperty.call(metadata, 'providerOrderId')) {
        updates.push('provider_order_id = ?');
        values.push(metadata.providerOrderId);
    }

    if (Object.prototype.hasOwnProperty.call(metadata, 'confirmedAt')) {
        updates.push('confirmed_at = ?');
        values.push(metadata.confirmedAt);
    }

    values.push(orderId);

    await run(`UPDATE orders SET ${updates.join(', ')} WHERE order_id = ?`, values);
    return true;
}
