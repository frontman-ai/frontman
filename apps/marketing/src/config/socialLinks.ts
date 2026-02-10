// Social Links
// ------------
// Description: The social links data for the website.

export interface SocialLink {
	name: string
	link: string
	icon: string
}

export const socialLinks: SocialLink[] = [
	{
		name: 'github',
		link: 'https://github.com/frontman-ai/frontman',
		icon: 'github-icon'
	},
	{
		name: 'discord',
		link: 'https://discord.gg/J77jBzMM',
		icon: 'discord-icon'
	},
	{
		name: 'twitter',
		link: 'https://twitter.com/frontman_agent',
		icon: 'twitter-icon'
	}
]
