import type { Preview } from "@storybook/react";
import "../src/index.css";
import "../src/styles/frontman-theme.css";

const preview: Preview = {
	parameters: {
		controls: {
			matchers: {
				color: /(background|color)$/i,
				date: /Date$/i,
			},
		},
		backgrounds: {
			default: "dark",
			values: [
				{
					name: "dark",
					value: "#0a0a0f",
				},
				{
					name: "light",
					value: "#ffffff",
				},
				{
					name: "zinc",
					value: "#18181b",
				},
			],
		},
	},
};

export default preview;
