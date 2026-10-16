export const pricing = { monthly: 15, yearly: 150, currency: 'EUR', freeRuns: 5, trialDays: 7 } as const
export const yearlyMonthly = (pricing.yearly / 12).toFixed(2)
export const yearlySavings = pricing.monthly * 12 - pricing.yearly
export const savingsPercent = Math.round(yearlySavings / (pricing.monthly * 12) * 100)
export const billingPlans = {
	monthly: { amount: String(pricing.monthly), period: 'per seat / month', note: `Billed monthly. Switch to yearly to save ${savingsPercent}% per seat.` },
	yearly: { amount: yearlyMonthly, period: 'per seat / month', note: `€${pricing.yearly} per seat billed yearly. Save €${yearlySavings} a year compared to monthly billing.` },
}
export const subscriptionTerms = `${pricing.freeRuns} lifetime free BYOK runs without a credit card. These runs do not expire. Then start a ${pricing.trialDays}-day free Pro trial; credit card required. Cancel before the trial ends to avoid billing. Otherwise, the trial converts to a paid subscription at €${pricing.monthly} per seat/month or €${pricing.yearly} per seat/year, according to your selected billing frequency. Subscriptions renew monthly or yearly until canceled. Cancel before the next renewal; access continues until the end of the paid billing period. Prices exclude VAT and other applicable taxes unless checkout states otherwise. Taxes are calculated at checkout. AI-provider access and usage costs are separate.`
