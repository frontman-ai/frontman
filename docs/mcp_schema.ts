export type JSONRPCMessage =
	| JSONRPCRequest
	| JSONRPCNotification
	| JSONRPCResponse
	| JSONRPCError;

export const LATEST_PROTOCOL_VERSION = "2024-11-05";
export const JSONRPC_VERSION = "2.0";

export type ProgressToken = string | number;

export type Cursor = string;

export interface Request {
	method: string;
	params?: {
		_meta?: {
			progressToken?: ProgressToken;
		};
		[key: string]: unknown;
	};
}

export interface Notification {
	method: string;
	params?: {
		_meta?: { [key: string]: unknown };
		[key: string]: unknown;
	};
}

export interface Result {
	_meta?: { [key: string]: unknown };
	[key: string]: unknown;
}

export type RequestId = string | number;

export interface JSONRPCRequest extends Request {
	jsonrpc: typeof JSONRPC_VERSION;
	id: RequestId;
}

export interface JSONRPCNotification extends Notification {
	jsonrpc: typeof JSONRPC_VERSION;
}

export interface JSONRPCResponse {
	jsonrpc: typeof JSONRPC_VERSION;
	id: RequestId;
	result: Result;
}

export const PARSE_ERROR = -32700;
export const INVALID_REQUEST = -32600;
export const METHOD_NOT_FOUND = -32601;
export const INVALID_PARAMS = -32602;
export const INTERNAL_ERROR = -32603;

export interface JSONRPCError {
	jsonrpc: typeof JSONRPC_VERSION;
	id: RequestId;
	error: {
		code: number;
		message: string;
		data?: unknown;
	};
}

export type EmptyResult = Result;

export interface CancelledNotification extends Notification {
	method: "notifications/cancelled";
	params: {
		requestId: RequestId;

		reason?: string;
	};
}

export interface InitializeRequest extends Request {
	method: "initialize";
	params: {
		protocolVersion: string;
		capabilities: ClientCapabilities;
		clientInfo: Implementation;
	};
}

export interface InitializeResult extends Result {
	protocolVersion: string;
	capabilities: ServerCapabilities;
	serverInfo: Implementation;
	instructions?: string;
}

export interface InitializedNotification extends Notification {
	method: "notifications/initialized";
}

export interface ClientCapabilities {
	experimental?: { [key: string]: object };
	roots?: {
		listChanged?: boolean;
	};
	sampling?: object;
}

export interface ServerCapabilities {
	experimental?: { [key: string]: object };
	logging?: object;
	prompts?: {
		listChanged?: boolean;
	};
	resources?: {
		subscribe?: boolean;
		listChanged?: boolean;
	};
	tools?: {
		listChanged?: boolean;
	};
}

export interface Implementation {
	name: string;
	version: string;
}

export interface PingRequest extends Request {
	method: "ping";
}

export interface ProgressNotification extends Notification {
	method: "notifications/progress";
	params: {
		progressToken: ProgressToken;
		progress: number;
		total?: number;
	};
}

export interface PaginatedRequest extends Request {
	params?: {
		cursor?: Cursor;
	};
}

export interface PaginatedResult extends Result {
	nextCursor?: Cursor;
}

export interface ListResourcesRequest extends PaginatedRequest {
	method: "resources/list";
}

export interface ListResourcesResult extends PaginatedResult {
	resources: Resource[];
}

export interface ListResourceTemplatesRequest extends PaginatedRequest {
	method: "resources/templates/list";
}

export interface ListResourceTemplatesResult extends PaginatedResult {
	resourceTemplates: ResourceTemplate[];
}

export interface ReadResourceRequest extends Request {
	method: "resources/read";
	params: {
		uri: string;
	};
}

export interface ReadResourceResult extends Result {
	contents: (TextResourceContents | BlobResourceContents)[];
}

export interface ResourceListChangedNotification extends Notification {
	method: "notifications/resources/list_changed";
}

export interface SubscribeRequest extends Request {
	method: "resources/subscribe";
	params: {
		uri: string;
	};
}

export interface UnsubscribeRequest extends Request {
	method: "resources/unsubscribe";
	params: {
		uri: string;
	};
}

export interface ResourceUpdatedNotification extends Notification {
	method: "notifications/resources/updated";
	params: {
		uri: string;
	};
}

export interface Resource extends Annotated {
	uri: string;

	name: string;

	description?: string;

	mimeType?: string;

	size?: number;
}

export interface ResourceTemplate extends Annotated {
	uriTemplate: string;

	name: string;

	description?: string;

	mimeType?: string;
}

export interface ResourceContents {
	uri: string;
	mimeType?: string;
}

export interface TextResourceContents extends ResourceContents {
	text: string;
}

export interface BlobResourceContents extends ResourceContents {
	blob: string;
}

export interface ListPromptsRequest extends PaginatedRequest {
	method: "prompts/list";
}

export interface ListPromptsResult extends PaginatedResult {
	prompts: Prompt[];
}

export interface GetPromptRequest extends Request {
	method: "prompts/get";
	params: {
		name: string;
		arguments?: { [key: string]: string };
	};
}

export interface GetPromptResult extends Result {
	description?: string;
	messages: PromptMessage[];
}

export interface Prompt {
	name: string;
	description?: string;
	arguments?: PromptArgument[];
}

export interface PromptArgument {
	name: string;
	description?: string;
	required?: boolean;
}

export type Role = "user" | "assistant";

export interface PromptMessage {
	role: Role;
	content: TextContent | ImageContent | EmbeddedResource;
}

export interface EmbeddedResource extends Annotated {
	type: "resource";
	resource: TextResourceContents | BlobResourceContents;
}

export interface PromptListChangedNotification extends Notification {
	method: "notifications/prompts/list_changed";
}

export interface ListToolsRequest extends PaginatedRequest {
	method: "tools/list";
}

export interface ListToolsResult extends PaginatedResult {
	tools: Tool[];
}

export interface CallToolResult extends Result {
	content: (TextContent | ImageContent | EmbeddedResource)[];

	isError?: boolean;
}

export interface CallToolRequest extends Request {
	method: "tools/call";
	params: {
		name: string;
		arguments?: { [key: string]: unknown };
	};
}

export interface ToolListChangedNotification extends Notification {
	method: "notifications/tools/list_changed";
}

export interface Tool {
	name: string;
	description?: string;
	inputSchema: {
		type: "object";
		properties?: { [key: string]: object };
		required?: string[];
	};
}

export interface SetLevelRequest extends Request {
	method: "logging/setLevel";
	params: {
		level: LoggingLevel;
	};
}

export interface LoggingMessageNotification extends Notification {
	method: "notifications/message";
	params: {
		level: LoggingLevel;
		logger?: string;
		data: unknown;
	};
}

export type LoggingLevel =
	| "debug"
	| "info"
	| "notice"
	| "warning"
	| "error"
	| "critical"
	| "alert"
	| "emergency";

export interface CreateMessageRequest extends Request {
	method: "sampling/createMessage";
	params: {
		messages: SamplingMessage[];
		modelPreferences?: ModelPreferences;
		systemPrompt?: string;
		includeContext?: "none" | "thisServer" | "allServers";
		temperature?: number;
		maxTokens: number;
		stopSequences?: string[];
		metadata?: object;
	};
}

export interface CreateMessageResult extends Result, SamplingMessage {
	model: string;
	stopReason?: "endTurn" | "stopSequence" | "maxTokens" | string;
}

export interface SamplingMessage {
	role: Role;
	content: TextContent | ImageContent;
}

export interface Annotated {
	annotations?: {
		audience?: Role[];

		priority?: number;
	};
}

export interface TextContent extends Annotated {
	type: "text";
	text: string;
}

export interface ImageContent extends Annotated {
	type: "image";
	data: string;
	mimeType: string;
}

export interface ModelPreferences {
	hints?: ModelHint[];

	costPriority?: number;

	speedPriority?: number;

	intelligencePriority?: number;
}

export interface ModelHint {
	name?: string;
}

export interface CompleteRequest extends Request {
	method: "completion/complete";
	params: {
		ref: PromptReference | ResourceReference;
		argument: {
			name: string;
			value: string;
		};
	};
}

export interface CompleteResult extends Result {
	completion: {
		values: string[];
		total?: number;
		hasMore?: boolean;
	};
}

export interface ResourceReference {
	type: "ref/resource";
	uri: string;
}

export interface PromptReference {
	type: "ref/prompt";
	name: string;
}

export interface ListRootsRequest extends Request {
	method: "roots/list";
}

export interface ListRootsResult extends Result {
	roots: Root[];
}

export interface Root {
	uri: string;
	name?: string;
}

export interface RootsListChangedNotification extends Notification {
	method: "notifications/roots/list_changed";
}

export type ClientRequest =
	| PingRequest
	| InitializeRequest
	| CompleteRequest
	| SetLevelRequest
	| GetPromptRequest
	| ListPromptsRequest
	| ListResourcesRequest
	| ListResourceTemplatesRequest
	| ReadResourceRequest
	| SubscribeRequest
	| UnsubscribeRequest
	| CallToolRequest
	| ListToolsRequest;

export type ClientNotification =
	| CancelledNotification
	| ProgressNotification
	| InitializedNotification
	| RootsListChangedNotification;

export type ClientResult = EmptyResult | CreateMessageResult | ListRootsResult;

export type ServerRequest =
	| PingRequest
	| CreateMessageRequest
	| ListRootsRequest;

export type ServerNotification =
	| CancelledNotification
	| ProgressNotification
	| LoggingMessageNotification
	| ResourceUpdatedNotification
	| ResourceListChangedNotification
	| ToolListChangedNotification
	| PromptListChangedNotification;

export type ServerResult =
	| EmptyResult
	| InitializeResult
	| CompleteResult
	| GetPromptResult
	| ListPromptsResult
	| ListResourcesResult
	| ListResourceTemplatesResult
	| ReadResourceResult
	| CallToolResult
	| ListToolsResult;
