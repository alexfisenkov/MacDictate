const PLAN_CATALOG = Object.freeze([
    {
        planId: 'monthly',
        amountRub: 399,
        months: 1,
        isPopular: false,
        label: '1 Месяц',
        labelEn: '1 Month'
    },
    {
        planId: 'quarterly',
        amountRub: 799,
        months: 3,
        isPopular: false,
        label: '3 Месяца',
        labelEn: '3 Months'
    },
    {
        planId: 'half_year',
        amountRub: 1299,
        months: 6,
        isPopular: true,
        label: 'Полгода',
        labelEn: 'Half Year'
    },
    {
        planId: 'yearly',
        amountRub: 1799,
        months: 12,
        isPopular: false,
        label: '1 Год',
        labelEn: '1 Year'
    }
]);

const planById = new Map(PLAN_CATALOG.map((plan) => [plan.planId, plan]));
const planByLegacyKey = new Map(
    PLAN_CATALOG.map((plan) => [`${plan.months}:${plan.amountRub}`, plan])
);
const planByAmountRub = new Map(PLAN_CATALOG.map((plan) => [plan.amountRub, plan]));

function parseInteger(value) {
    if (value === undefined || value === null || value === '') {
        return null;
    }

    const parsed = Number.parseInt(String(value), 10);
    return Number.isFinite(parsed) ? parsed : null;
}

export function getPublicPlans() {
    return PLAN_CATALOG.map((plan) => ({
        planId: plan.planId,
        amountRub: plan.amountRub,
        currency: 'RUB',
        months: plan.months,
        isPopular: plan.isPopular,
        label: plan.label,
        labelEn: plan.labelEn
    }));
}

export function getPlanById(planId) {
    if (typeof planId !== 'string') {
        return null;
    }

    return planById.get(planId.trim()) || null;
}

export function getPlanByAmountRub(amountRub) {
    const parsedAmount = parseInteger(amountRub);
    if (parsedAmount === null) {
        return null;
    }

    return planByAmountRub.get(parsedAmount) || null;
}

export function resolvePlanSelection({ planId, planMonths, amount }) {
    if (planId) {
        const plan = getPlanById(planId);
        if (!plan) {
            return null;
        }

        const parsedMonths = parseInteger(planMonths);
        if (parsedMonths !== null && parsedMonths !== plan.months) {
            return null;
        }

        const parsedAmount = parseInteger(amount);
        if (parsedAmount !== null && parsedAmount !== plan.amountRub) {
            return null;
        }

        return plan;
    }

    const parsedMonths = parseInteger(planMonths);
    const parsedAmount = parseInteger(amount);
    if (parsedMonths === null || parsedAmount === null) {
        return null;
    }

    return planByLegacyKey.get(`${parsedMonths}:${parsedAmount}`) || null;
}

export function getPlanDescription(plan) {
    return `MacDictate License - ${plan.months} Month(s)`;
}

export function getPlanReceiptName(plan) {
    return `Лицензия MacDictate (${plan.months} мес.)`;
}
