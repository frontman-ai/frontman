export const countArticleWords = (body) => body
	.replace(/```[\s\S]*?```/g, '')
	.replace(/<[^>]*>/g, ' ')
	.replace(/[#*_\[\]()>|`~-]/g, '')
	.split(/\s+/)
	.filter(Boolean).length
