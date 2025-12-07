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
		name: 'facebook',
		link: '/',
		icon: 'fb-icon'
	},
	{
		name: 'twitter',
		link: '/',
		icon: 'twitter-icon'
	},
	{
		name: 'discord',
		link: '/',
		icon: 'discord-icon'
	}
]
