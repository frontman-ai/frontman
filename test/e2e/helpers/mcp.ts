import { connect } from "node:net";

export const MCP_ORIGIN = "https://mcp-client.example";
export const MCP_TOKEN = "black-box-token";
export const MCP_VERSION = "2026-07-28";

type RequestId = string | number;

export function mcpBody(
  method: string,
  id: RequestId,
  params: Record<string, unknown> = {},
): string {
  return JSON.stringify({
    jsonrpc: "2.0",
    id,
    method,
    params: {
      _meta: {
        "io.modelcontextprotocol/protocolVersion": MCP_VERSION,
        "io.modelcontextprotocol/clientCapabilities": {},
      },
      ...params,
    },
  });
}

export function mcpHeaders(
  method: string,
  options: { name?: string; authorization?: string; origin?: string } = {},
): Record<string, string> {
  const headers: Record<string, string> = {
    Origin: options.origin ?? MCP_ORIGIN,
    Authorization: options.authorization ?? `Bearer ${MCP_TOKEN}`,
    "Content-Type": "application/json",
    Accept: "application/json, text/event-stream",
    "MCP-Protocol-Version": MCP_VERSION,
    "Mcp-Method": method,
  };
  if (options.name) headers["Mcp-Name"] = options.name;
  return headers;
}

export async function mcpRequest(
  baseUrl: string,
  method: string,
  id: RequestId,
  params: Record<string, unknown> = {},
  headers: Record<string, string> = {},
): Promise<Response> {
  return fetch(`${baseUrl}/mcp`, {
    method: "POST",
    headers: {...mcpHeaders(method, {name: params.name as string | undefined}), ...headers},
    body: mcpBody(method, id, params),
  });
}

export async function incompleteBodyResponse(port: number): Promise<{
  status: number;
  headers: Map<string, string>;
  body: Buffer;
}> {
  return new Promise((resolve, reject) => {
    const socket = connect({host: "127.0.0.1", port});
    const chunks: Buffer[] = [];
    const timer = setTimeout(() => {
      socket.destroy();
      reject(new Error("Timed out waiting for the MCP absolute deadline response"));
    }, 20_000);
    socket.on("connect", () => {
      socket.write(
        [
          "POST /mcp HTTP/1.1",
          `Host: 127.0.0.1:${port}`,
          `Origin: ${MCP_ORIGIN}`,
          `Authorization: Bearer ${MCP_TOKEN}`,
          "Content-Type: application/json",
          "Accept: application/json, text/event-stream",
          `MCP-Protocol-Version: ${MCP_VERSION}`,
          "Mcp-Method: server/discover",
          "Content-Length: 1000",
          "Connection: close",
          "",
          "{",
        ].join("\r\n"),
      );
    });
    socket.on("data", (chunk) => chunks.push(chunk));
    socket.on("error", reject);
    socket.on("close", () => {
      clearTimeout(timer);
      const response = Buffer.concat(chunks);
      const separator = response.indexOf("\r\n\r\n");
      if (separator < 0) {
        reject(new Error(`Invalid raw HTTP response: ${response.toString()}`));
        return;
      }
      const headerLines = response.subarray(0, separator).toString().split("\r\n");
      const status = Number(headerLines[0]?.split(" ")[1]);
      const headers = new Map<string, string>();
      for (const line of headerLines.slice(1)) {
        const colon = line.indexOf(":");
        headers.set(line.slice(0, colon).toLowerCase(), line.slice(colon + 1).trim());
      }
      const framedBody = response.subarray(separator + 4);
      const body = headers.get("transfer-encoding") === "chunked"
        ? framedBody.equals(Buffer.from("0\r\n\r\n"))
          ? Buffer.alloc(0)
          : framedBody
        : framedBody;
      resolve({status, headers, body});
    });
  });
}

export async function disconnectIncompleteRequest(port: number): Promise<void> {
  await new Promise<void>((resolve, reject) => {
    const socket = connect({host: "127.0.0.1", port});
    socket.on("connect", () => {
      socket.write(
        [
          "POST /mcp HTTP/1.1",
          `Host: 127.0.0.1:${port}`,
          `Origin: ${MCP_ORIGIN}`,
          `Authorization: Bearer ${MCP_TOKEN}`,
          "Content-Type: application/json",
          "Accept: application/json, text/event-stream",
          `MCP-Protocol-Version: ${MCP_VERSION}`,
          "Mcp-Method: server/discover",
          "Content-Length: 1000",
          "",
          "{",
        ].join("\r\n"),
      );
      setTimeout(() => socket.destroy(), 25);
    });
    socket.on("error", (error) => {
      if ((error as NodeJS.ErrnoException).code !== "ECONNRESET") reject(error);
    });
    socket.on("close", () => resolve());
  });
}
