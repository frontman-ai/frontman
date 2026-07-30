export const getWebPageId = (url) => `${url}#webpage`

export const createWebPageSchema = ({ url, title, description }) => {
	const schema = {
		'@type': 'WebPage',
		'@id': getWebPageId(url),
		url,
		name: title,
		description
	}

	if (url === 'https://frontman.sh/') {
		schema.speakable = {
			'@type': 'SpeakableSpecification',
			cssSelector: ['#intro .hero-section__subtitle', '#intro .hero-section__geo-lead']
		}
	}

	return schema
}
