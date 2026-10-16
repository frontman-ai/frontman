export const blogImageWidth = 1200
export const blogImageHeight = 450

export const comparisonReviewCheckedAt = '2026-07-21'

export const frontmanLicenseShort =
	'Source-available: Apache-2.0 browser/JS; GPL-2.0-or-later WordPress; AGPL-3.0-only server plus AI Supplementary Terms'

export const frontmanLicensePricingFeature =
	'Apache-2.0 browser/JS; GPL-2.0-or-later WordPress; AGPL-3.0-only server plus AI Supplementary Terms'

export const frontmanPricingFeatures = [
	'Five lifetime free BYOK runs; no credit card; no expiry',
	'Optional 7-day free Pro trial anytime; credit card required',
	'After trial: EUR 15/seat/month or EUR 150/seat/year unless canceled',
	'Bring your own API keys (Claude, ChatGPT, OpenRouter)',
	'Or sign in with Claude/ChatGPT subscription via OAuth',
	frontmanLicensePricingFeature,
	'AI provider usage is billed separately from Frontman Pro'
] as const

export const frontmanComparisonSources = [
	{ label: 'Frontman documentation', url: 'https://frontman.sh/docs/' },
	{ label: 'Frontman source repository', url: 'https://github.com/frontman-ai/frontman' }
] as const

export const createComparisonReview = <Source extends { label: string; url: string }>(sources: Source[]) => ({
	checkedAt: comparisonReviewCheckedAt,
	sources: [...frontmanComparisonSources, ...sources]
})
