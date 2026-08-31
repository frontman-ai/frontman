export function hasE2EOpenAICredentials(): boolean {
	return Boolean(
		process.env.E2E_OPENAI_ACCESS_TOKEN && process.env.E2E_OPENAI_REFRESH_TOKEN,
	);
}
