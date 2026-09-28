export const countArticleWords = (body, faq = []) => {
	const visibleCopy = faq.length > 0
		? `${body}\nFAQ\n${faq.flatMap(({question, answer}) => [question, answer]).join('\n')}`
		: body

	return visibleCopy
		.replace(/```[\s\S]*?```/g, '')
		.replace(/<[^>]*>/g, ' ')
		.replace(/[#*_\[\]()>|`~-]/g, '')
		.split(/\s+/)
		.filter(Boolean).length
}
