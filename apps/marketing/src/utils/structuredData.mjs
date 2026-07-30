export const createWebPageSchema = ({ url, title, description }) => {
	const schema = {
		'@type': 'WebPage',
		'@id': `${url}#webpage`,
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
