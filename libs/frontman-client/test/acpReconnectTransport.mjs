import { vi } from "vitest";

export function makeTransport() {
  let socket, tasksJoin, clientInfo;
  const frames = [], requests = [];
  const server = {
    requests, frames, holdInitialize: false, holdTasksJoin: false, holdSessionJoin: false, holdSessionNew: false, joinError: undefined,
    reply(frame, result, error, status = "ok") {
      const [joinRef, ref, topic, , payload] = frame;
      socket.onmessage({ data: JSON.stringify([joinRef, ref, topic, "phx_reply", {
        status, response: { "acp:message": {
          jsonrpc: "2.0", id: payload.id, ...(error ? { error } : { result })
        } }
      }]) });
    },
    initialize(index, error) {
      const frame = frames.filter(frame => frame[4].method === "initialize")[index];
      clientInfo = frame[4].params.clientInfo;
      server.reply(frame, {
        protocolVersion: 1,
        agentCapabilities: { _meta: { "frontman.dev": {
          agentAttribution: { version: 1 },
          agents: [{ id: "agent-1", name: "executor", displayName: "Executor", description: "Executes work", color: "#985DF7" }],
          defaultAgentId: "agent-1"
        } } }
      }, error);
    },
    lose(transport) {
      clientInfo = undefined;
      if (transport) { socket.readyState = 3; socket.onclose({ code: 1006 }); }
      else server.emit("phx_error", {});
    },
    emit(event, payload) {
      socket.onmessage({ data: JSON.stringify([tasksJoin[0], null, tasksJoin[2], event, payload]) });
    },
    listenerCount(channel, event) { return channel.bindings.filter(b => b.event === event).length; }
  };
  class Wire {
    readyState = 0;
    bufferedAmount = 0;
    skipHeartbeat = true;
    constructor() {
      socket = this;
      Promise.resolve().then(() => { this.readyState = 1; this.onopen({}); });
    }
    close() { this.readyState = 3; this.onclose?.({ code: 1000 }); }
    send(data) {
      const frame = JSON.parse(data);
      frames.push(frame);
      const [joinRef, ref, topic, event, payload] = frame;
      const receipt = (status, response) => this.onmessage({ data: JSON.stringify([
        joinRef, ref, topic, "phx_reply", { status, response }
      ]) });
      if (event === "phx_join") {
        if (topic === "tasks") { tasksJoin = frame; clientInfo = undefined; }
        if (!(topic === "tasks" ? server.holdTasksJoin : server.holdSessionJoin))
          Promise.resolve().then(() => receipt(server.joinError ? "error" : "ok", server.joinError ?? {}));
      } else if (event === "phx_leave") receipt("ok", {});
      else if (event === "acp:message") {
        requests.push(payload);
        if (payload.method === "initialize" && !server.holdInitialize) {
          Promise.resolve().then(() => server.initialize(requests.filter(r => r.method === "initialize").length - 1));
        } else if (payload.method === "session/new" && !server.holdSessionNew) {
          const error = clientInfo?._meta?.framework ? undefined : { code: -32602, message: "Missing framework in clientInfo" };
          Promise.resolve().then(() => server.reply(frame, { sessionId: payload.params.sessionId }, error));
        }
      }
    }
  }
  vi.stubGlobal("WebSocket", Wire);
  vi.stubGlobal("window", { location: { origin: "https://wordpress.test" } });
  return server;
}
