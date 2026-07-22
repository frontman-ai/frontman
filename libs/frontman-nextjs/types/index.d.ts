export type ConfigInput = {
	isDev?: boolean;
	basePath?: string;
	serverName?: string;
	serverVersion?: string;
	host?: string;
	clientUrl?: string;
	clientCssUrl?: string;
	entrypointUrl?: string;
	projectRoot?: string;
	sourceRoot?: string;
};

export type Config = Required<Omit<ConfigInput, "clientCssUrl" | "entrypointUrl">> & {
	clientCssUrl?: string;
	entrypointUrl?: string;
};

export type FrontmanMiddleware = (request: any) => any | Promise<any>;

export function createMiddleware(config: ConfigInput): FrontmanMiddleware;
export function makeConfig(config: ConfigInput): Config;
