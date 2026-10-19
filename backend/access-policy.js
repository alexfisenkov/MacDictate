// Desktop is permanently free. Keep the old response fields for older apps;
// access does not represent a paid order and must not mutate billing history.
export function legacyFreeAccess(deviceId) {
    return {
        deviceId,
        isPaid: false,
        isActive: true,
        expiresAt: null,
        daysLeft: 0,
        accessMode: 'free'
    };
}
