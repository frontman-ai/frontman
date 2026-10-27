export const pricing = { monthly: 15, yearly: 150, currency: 'EUR', freeRuns: 5, trialDays: 7 } as const
export const yearlyMonthly = (pricing.yearly / 12).toFixed(2)
export const yearlySavings = pricing.monthly * 12 - pricing.yearly
export const savingsPercent = Math.round(yearlySavings / (pricing.monthly * 12) * 100)
export const billingPlans = {
	monthly: { amount: String(pricing.monthly), period: 'per seat / month', note: `Billed monthly. Switch to yearly to save ${savingsPercent}% per seat.` },
	yearly: { amount: yearlyMonthly, period: 'per seat / month', note: `€${pricing.yearly} per seat billed yearly. Save €${yearlySavings} a year compared to monthly billing.` },
}
export const subscriptionTerms = `${pricing.freeRuns} free uses. No card. Pro: ${pricing.trialDays} days free (credit card required). Then €${pricing.monthly}/seat/month or €${pricing.yearly}/seat/year unless canceled. Cancel before your trial ends to avoid billing. Plans renew monthly or yearly. Cancel before the next renewal. Access lasts through the paid period. Prices exclude VAT. Checkout shows tax. AI provider fees are separate.`
