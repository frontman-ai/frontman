export const legalInfo = {
	brandName: 'Frontman',
	companyName: 'Boilerplate Ventures UG (haftungsbeschränkt)',
	companyNameAscii: 'Boilerplate Ventures UG (haftungsbeschraenkt)',
	shortCompanyName: 'Boilerplate Ventures UG',
	streetAddress: 'Galenusstraße 63D',
	postalCode: '13187',
	city: 'Berlin',
	country: 'Germany',
	registerCourt: 'Amtsgericht Charlottenburg',
	registerNumber: 'HRB 273526 B',
	managingDirector: 'Fridland Dimitri',
	supportEmail: 'support@frontman.sh',
	vatId: 'not yet issued'
} as const

export const legalPlaceholders = {
	'{{brand.name}}': legalInfo.brandName,
	'{{company.name}}': legalInfo.companyName,
	'{{company.nameAscii}}': legalInfo.companyNameAscii,
	'{{company.shortName}}': legalInfo.shortCompanyName,
	'{{company.streetAddress}}': legalInfo.streetAddress,
	'{{company.postalCode}}': legalInfo.postalCode,
	'{{company.city}}': legalInfo.city,
	'{{company.country}}': legalInfo.country,
	'{{company.registerCourt}}': legalInfo.registerCourt,
	'{{company.registerNumber}}': legalInfo.registerNumber,
	'{{company.managingDirector}}': legalInfo.managingDirector,
	'{{company.supportEmail}}': legalInfo.supportEmail,
	'{{company.supportMailto}}': `[${legalInfo.supportEmail}](mailto:${legalInfo.supportEmail})`,
	'{{company.vatId}}': legalInfo.vatId,
	'{{company.fullAddress}}': `${legalInfo.streetAddress}, ${legalInfo.postalCode} ${legalInfo.city}, ${legalInfo.country}`
} as const

export const applyLegalPlaceholders = (content: string): string =>
	Object.entries(legalPlaceholders).reduce(
		(result, [placeholder, value]) => result.replaceAll(placeholder, value),
		content
	)
