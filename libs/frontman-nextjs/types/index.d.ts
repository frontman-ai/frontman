export type McpAuthorization =
	| "authorized"
	| "missing-authentication"
	| "insufficient-authorization";

export type McpSecurityConfig = {
	allowedOrigins: readonly string[];
	authorize: (headers: Headers) => Promise<McpAuthorization>;
	principal?: (headers: Headers) => string;
};

export type SourceLocationSecurityConfig = {
	allowedOrigins: readonly string[];
};

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
	mcpBrowserToken?: string;
	mcp?: McpSecurityConfig;
	sourceLocation?: SourceLocationSecurityConfig;
};

export type Config = Required<Omit<ConfigInput, "clientCssUrl" | "entrypointUrl" | "mcpBrowserToken" | "mcp" | "sourceLocation">> & {
	clientCssUrl?: string;
	entrypointUrl?: string;
	mcpBrowserToken?: string;
	mcpSecurity?: unknown;
	sourceLocationSecurity?: unknown;
};

export type FrontmanMiddleware = (request: any) => any | Promise<any>;
export type FrontmanMcpHandler = (request: any, response: any) => Promise<void>;

export function createMiddleware(config: ConfigInput): FrontmanMiddleware;
export function createMcpHandler(config: ConfigInput & { mcp: McpSecurityConfig }): FrontmanMcpHandler;
export function makeConfig(config: ConfigInput): Config;
