var __defProp = Object.defineProperty;
var __export = (target, all) => {
  for (var name3 in all)
    __defProp(target, name3, { get: all[name3], enumerable: true });
};

// ../../../libs/frontman-client/src/FrontmanClient__ACP.res.mjs
var FrontmanClient_ACP_res_exports = {};
__export(FrontmanClient_ACP_res_exports, {
  Channel: () => Channel2,
  Client: () => Client,
  JsonRpc: () => JsonRpc,
  Socket: () => Socket2,
  Types: () => Types,
  connect: () => connect,
  createSession: () => createSession,
  getState: () => getState,
  isInitialized: () => isInitialized2,
  joinChannel: () => joinChannel,
  joinSession: () => joinSession,
  makeConfig: () => makeConfig,
  sendInitialize: () => sendInitialize,
  sendPrompt: () => sendPrompt,
  waitForSocket: () => waitForSocket
});

// ../../../node_modules/phoenix/priv/static/phoenix.mjs
var closure = (value) => {
  if (typeof value === "function") {
    return value;
  } else {
    let closure2 = function() {
      return value;
    };
    return closure2;
  }
};
var globalSelf = typeof self !== "undefined" ? self : null;
var phxWindow = typeof window !== "undefined" ? window : null;
var global = globalSelf || phxWindow || globalThis;
var DEFAULT_VSN = "2.0.0";
var SOCKET_STATES = { connecting: 0, open: 1, closing: 2, closed: 3 };
var DEFAULT_TIMEOUT = 1e4;
var WS_CLOSE_NORMAL = 1e3;
var CHANNEL_STATES = {
  closed: "closed",
  errored: "errored",
  joined: "joined",
  joining: "joining",
  leaving: "leaving"
};
var CHANNEL_EVENTS = {
  close: "phx_close",
  error: "phx_error",
  join: "phx_join",
  reply: "phx_reply",
  leave: "phx_leave"
};
var TRANSPORTS = {
  longpoll: "longpoll",
  websocket: "websocket"
};
var XHR_STATES = {
  complete: 4
};
var AUTH_TOKEN_PREFIX = "base64url.bearer.phx.";
var Push = class {
  constructor(channel, event, payload, timeout) {
    this.channel = channel;
    this.event = event;
    this.payload = payload || function() {
      return {};
    };
    this.receivedResp = null;
    this.timeout = timeout;
    this.timeoutTimer = null;
    this.recHooks = [];
    this.sent = false;
  }
  /**
   *
   * @param {number} timeout
   */
  resend(timeout) {
    this.timeout = timeout;
    this.reset();
    this.send();
  }
  /**
   *
   */
  send() {
    if (this.hasReceived("timeout")) {
      return;
    }
    this.startTimeout();
    this.sent = true;
    this.channel.socket.push({
      topic: this.channel.topic,
      event: this.event,
      payload: this.payload(),
      ref: this.ref,
      join_ref: this.channel.joinRef()
    });
  }
  /**
   *
   * @param {*} status
   * @param {*} callback
   */
  receive(status, callback) {
    if (this.hasReceived(status)) {
      callback(this.receivedResp.response);
    }
    this.recHooks.push({ status, callback });
    return this;
  }
  /**
   * @private
   */
  reset() {
    this.cancelRefEvent();
    this.ref = null;
    this.refEvent = null;
    this.receivedResp = null;
    this.sent = false;
  }
  /**
   * @private
   */
  matchReceive({ status, response, _ref }) {
    this.recHooks.filter((h) => h.status === status).forEach((h) => h.callback(response));
  }
  /**
   * @private
   */
  cancelRefEvent() {
    if (!this.refEvent) {
      return;
    }
    this.channel.off(this.refEvent);
  }
  /**
   * @private
   */
  cancelTimeout() {
    clearTimeout(this.timeoutTimer);
    this.timeoutTimer = null;
  }
  /**
   * @private
   */
  startTimeout() {
    if (this.timeoutTimer) {
      this.cancelTimeout();
    }
    this.ref = this.channel.socket.makeRef();
    this.refEvent = this.channel.replyEventName(this.ref);
    this.channel.on(this.refEvent, (payload) => {
      this.cancelRefEvent();
      this.cancelTimeout();
      this.receivedResp = payload;
      this.matchReceive(payload);
    });
    this.timeoutTimer = setTimeout(() => {
      this.trigger("timeout", {});
    }, this.timeout);
  }
  /**
   * @private
   */
  hasReceived(status) {
    return this.receivedResp && this.receivedResp.status === status;
  }
  /**
   * @private
   */
  trigger(status, response) {
    this.channel.trigger(this.refEvent, { status, response });
  }
};
var Timer = class {
  constructor(callback, timerCalc) {
    this.callback = callback;
    this.timerCalc = timerCalc;
    this.timer = null;
    this.tries = 0;
  }
  reset() {
    this.tries = 0;
    clearTimeout(this.timer);
  }
  /**
   * Cancels any previous scheduleTimeout and schedules callback
   */
  scheduleTimeout() {
    clearTimeout(this.timer);
    this.timer = setTimeout(() => {
      this.tries = this.tries + 1;
      this.callback();
    }, this.timerCalc(this.tries + 1));
  }
};
var Channel = class {
  constructor(topic, params2, socket) {
    this.state = CHANNEL_STATES.closed;
    this.topic = topic;
    this.params = closure(params2 || {});
    this.socket = socket;
    this.bindings = [];
    this.bindingRef = 0;
    this.timeout = this.socket.timeout;
    this.joinedOnce = false;
    this.joinPush = new Push(this, CHANNEL_EVENTS.join, this.params, this.timeout);
    this.pushBuffer = [];
    this.stateChangeRefs = [];
    this.rejoinTimer = new Timer(() => {
      if (this.socket.isConnected()) {
        this.rejoin();
      }
    }, this.socket.rejoinAfterMs);
    this.stateChangeRefs.push(this.socket.onError(() => this.rejoinTimer.reset()));
    this.stateChangeRefs.push(
      this.socket.onOpen(() => {
        this.rejoinTimer.reset();
        if (this.isErrored()) {
          this.rejoin();
        }
      })
    );
    this.joinPush.receive("ok", () => {
      this.state = CHANNEL_STATES.joined;
      this.rejoinTimer.reset();
      this.pushBuffer.forEach((pushEvent) => pushEvent.send());
      this.pushBuffer = [];
    });
    this.joinPush.receive("error", () => {
      this.state = CHANNEL_STATES.errored;
      if (this.socket.isConnected()) {
        this.rejoinTimer.scheduleTimeout();
      }
    });
    this.onClose(() => {
      this.rejoinTimer.reset();
      if (this.socket.hasLogger())
        this.socket.log("channel", `close ${this.topic} ${this.joinRef()}`);
      this.state = CHANNEL_STATES.closed;
      this.socket.remove(this);
    });
    this.onError((reason2) => {
      if (this.socket.hasLogger())
        this.socket.log("channel", `error ${this.topic}`, reason2);
      if (this.isJoining()) {
        this.joinPush.reset();
      }
      this.state = CHANNEL_STATES.errored;
      if (this.socket.isConnected()) {
        this.rejoinTimer.scheduleTimeout();
      }
    });
    this.joinPush.receive("timeout", () => {
      if (this.socket.hasLogger())
        this.socket.log("channel", `timeout ${this.topic} (${this.joinRef()})`, this.joinPush.timeout);
      let leavePush = new Push(this, CHANNEL_EVENTS.leave, closure({}), this.timeout);
      leavePush.send();
      this.state = CHANNEL_STATES.errored;
      this.joinPush.reset();
      if (this.socket.isConnected()) {
        this.rejoinTimer.scheduleTimeout();
      }
    });
    this.on(CHANNEL_EVENTS.reply, (payload, ref) => {
      this.trigger(this.replyEventName(ref), payload);
    });
  }
  /**
   * Join the channel
   * @param {integer} timeout
   * @returns {Push}
   */
  join(timeout = this.timeout) {
    if (this.joinedOnce) {
      throw new Error("tried to join multiple times. 'join' can only be called a single time per channel instance");
    } else {
      this.timeout = timeout;
      this.joinedOnce = true;
      this.rejoin();
      return this.joinPush;
    }
  }
  /**
   * Hook into channel close
   * @param {Function} callback
   */
  onClose(callback) {
    this.on(CHANNEL_EVENTS.close, callback);
  }
  /**
   * Hook into channel errors
   * @param {Function} callback
   */
  onError(callback) {
    return this.on(CHANNEL_EVENTS.error, (reason2) => callback(reason2));
  }
  /**
   * Subscribes on channel events
   *
   * Subscription returns a ref counter, which can be used later to
   * unsubscribe the exact event listener
   *
   * @example
   * const ref1 = channel.on("event", do_stuff)
   * const ref2 = channel.on("event", do_other_stuff)
   * channel.off("event", ref1)
   * // Since unsubscription, do_stuff won't fire,
   * // while do_other_stuff will keep firing on the "event"
   *
   * @param {string} event
   * @param {Function} callback
   * @returns {integer} ref
   */
  on(event, callback) {
    let ref = this.bindingRef++;
    this.bindings.push({ event, ref, callback });
    return ref;
  }
  /**
   * Unsubscribes off of channel events
   *
   * Use the ref returned from a channel.on() to unsubscribe one
   * handler, or pass nothing for the ref to unsubscribe all
   * handlers for the given event.
   *
   * @example
   * // Unsubscribe the do_stuff handler
   * const ref1 = channel.on("event", do_stuff)
   * channel.off("event", ref1)
   *
   * // Unsubscribe all handlers from event
   * channel.off("event")
   *
   * @param {string} event
   * @param {integer} ref
   */
  off(event, ref) {
    this.bindings = this.bindings.filter((bind) => {
      return !(bind.event === event && (typeof ref === "undefined" || ref === bind.ref));
    });
  }
  /**
   * @private
   */
  canPush() {
    return this.socket.isConnected() && this.isJoined();
  }
  /**
   * Sends a message `event` to phoenix with the payload `payload`.
   * Phoenix receives this in the `handle_in(event, payload, socket)`
   * function. if phoenix replies or it times out (default 10000ms),
   * then optionally the reply can be received.
   *
   * @example
   * channel.push("event")
   *   .receive("ok", payload => console.log("phoenix replied:", payload))
   *   .receive("error", err => console.log("phoenix errored", err))
   *   .receive("timeout", () => console.log("timed out pushing"))
   * @param {string} event
   * @param {Object} payload
   * @param {number} [timeout]
   * @returns {Push}
   */
  push(event, payload, timeout = this.timeout) {
    payload = payload || {};
    if (!this.joinedOnce) {
      throw new Error(`tried to push '${event}' to '${this.topic}' before joining. Use channel.join() before pushing events`);
    }
    let pushEvent = new Push(this, event, function() {
      return payload;
    }, timeout);
    if (this.canPush()) {
      pushEvent.send();
    } else {
      pushEvent.startTimeout();
      this.pushBuffer.push(pushEvent);
    }
    return pushEvent;
  }
  /** Leaves the channel
   *
   * Unsubscribes from server events, and
   * instructs channel to terminate on server
   *
   * Triggers onClose() hooks
   *
   * To receive leave acknowledgements, use the `receive`
   * hook to bind to the server ack, ie:
   *
   * @example
   * channel.leave().receive("ok", () => alert("left!") )
   *
   * @param {integer} timeout
   * @returns {Push}
   */
  leave(timeout = this.timeout) {
    this.rejoinTimer.reset();
    this.joinPush.cancelTimeout();
    this.state = CHANNEL_STATES.leaving;
    let onClose = () => {
      if (this.socket.hasLogger())
        this.socket.log("channel", `leave ${this.topic}`);
      this.trigger(CHANNEL_EVENTS.close, "leave");
    };
    let leavePush = new Push(this, CHANNEL_EVENTS.leave, closure({}), timeout);
    leavePush.receive("ok", () => onClose()).receive("timeout", () => onClose());
    leavePush.send();
    if (!this.canPush()) {
      leavePush.trigger("ok", {});
    }
    return leavePush;
  }
  /**
   * Overridable message hook
   *
   * Receives all events for specialized message handling
   * before dispatching to the channel callbacks.
   *
   * Must return the payload, modified or unmodified
   * @param {string} event
   * @param {Object} payload
   * @param {integer} ref
   * @returns {Object}
   */
  onMessage(_event, payload, _ref) {
    return payload;
  }
  /**
   * @private
   */
  isMember(topic, event, payload, joinRef) {
    if (this.topic !== topic) {
      return false;
    }
    if (joinRef && joinRef !== this.joinRef()) {
      if (this.socket.hasLogger())
        this.socket.log("channel", "dropping outdated message", { topic, event, payload, joinRef });
      return false;
    } else {
      return true;
    }
  }
  /**
   * @private
   */
  joinRef() {
    return this.joinPush.ref;
  }
  /**
   * @private
   */
  rejoin(timeout = this.timeout) {
    if (this.isLeaving()) {
      return;
    }
    this.socket.leaveOpenTopic(this.topic);
    this.state = CHANNEL_STATES.joining;
    this.joinPush.resend(timeout);
  }
  /**
   * @private
   */
  trigger(event, payload, ref, joinRef) {
    let handledPayload = this.onMessage(event, payload, ref, joinRef);
    if (payload && !handledPayload) {
      throw new Error("channel onMessage callbacks must return the payload, modified or unmodified");
    }
    let eventBindings = this.bindings.filter((bind) => bind.event === event);
    for (let i = 0; i < eventBindings.length; i++) {
      let bind = eventBindings[i];
      bind.callback(handledPayload, ref, joinRef || this.joinRef());
    }
  }
  /**
   * @private
   */
  replyEventName(ref) {
    return `chan_reply_${ref}`;
  }
  /**
   * @private
   */
  isClosed() {
    return this.state === CHANNEL_STATES.closed;
  }
  /**
   * @private
   */
  isErrored() {
    return this.state === CHANNEL_STATES.errored;
  }
  /**
   * @private
   */
  isJoined() {
    return this.state === CHANNEL_STATES.joined;
  }
  /**
   * @private
   */
  isJoining() {
    return this.state === CHANNEL_STATES.joining;
  }
  /**
   * @private
   */
  isLeaving() {
    return this.state === CHANNEL_STATES.leaving;
  }
};
var Ajax = class {
  static request(method2, endPoint, headers, body, timeout, ontimeout, callback) {
    if (global.XDomainRequest) {
      let req = new global.XDomainRequest();
      return this.xdomainRequest(req, method2, endPoint, body, timeout, ontimeout, callback);
    } else if (global.XMLHttpRequest) {
      let req = new global.XMLHttpRequest();
      return this.xhrRequest(req, method2, endPoint, headers, body, timeout, ontimeout, callback);
    } else if (global.fetch && global.AbortController) {
      return this.fetchRequest(method2, endPoint, headers, body, timeout, ontimeout, callback);
    } else {
      throw new Error("No suitable XMLHttpRequest implementation found");
    }
  }
  static fetchRequest(method2, endPoint, headers, body, timeout, ontimeout, callback) {
    let options = {
      method: method2,
      headers,
      body
    };
    let controller = null;
    if (timeout) {
      controller = new AbortController();
      const _timeoutId = setTimeout(() => controller.abort(), timeout);
      options.signal = controller.signal;
    }
    global.fetch(endPoint, options).then((response) => response.text()).then((data2) => this.parseJSON(data2)).then((data2) => callback && callback(data2)).catch((err) => {
      if (err.name === "AbortError" && ontimeout) {
        ontimeout();
      } else {
        callback && callback(null);
      }
    });
    return controller;
  }
  static xdomainRequest(req, method2, endPoint, body, timeout, ontimeout, callback) {
    req.timeout = timeout;
    req.open(method2, endPoint);
    req.onload = () => {
      let response = this.parseJSON(req.responseText);
      callback && callback(response);
    };
    if (ontimeout) {
      req.ontimeout = ontimeout;
    }
    req.onprogress = () => {
    };
    req.send(body);
    return req;
  }
  static xhrRequest(req, method2, endPoint, headers, body, timeout, ontimeout, callback) {
    req.open(method2, endPoint, true);
    req.timeout = timeout;
    for (let [key, value] of Object.entries(headers)) {
      req.setRequestHeader(key, value);
    }
    req.onerror = () => callback && callback(null);
    req.onreadystatechange = () => {
      if (req.readyState === XHR_STATES.complete && callback) {
        let response = this.parseJSON(req.responseText);
        callback(response);
      }
    };
    if (ontimeout) {
      req.ontimeout = ontimeout;
    }
    req.send(body);
    return req;
  }
  static parseJSON(resp) {
    if (!resp || resp === "") {
      return null;
    }
    try {
      return JSON.parse(resp);
    } catch {
      console && console.log("failed to parse JSON response", resp);
      return null;
    }
  }
  static serialize(obj, parentKey) {
    let queryStr = [];
    for (var key in obj) {
      if (!Object.prototype.hasOwnProperty.call(obj, key)) {
        continue;
      }
      let paramKey = parentKey ? `${parentKey}[${key}]` : key;
      let paramVal = obj[key];
      if (typeof paramVal === "object") {
        queryStr.push(this.serialize(paramVal, paramKey));
      } else {
        queryStr.push(encodeURIComponent(paramKey) + "=" + encodeURIComponent(paramVal));
      }
    }
    return queryStr.join("&");
  }
  static appendParams(url2, params2) {
    if (Object.keys(params2).length === 0) {
      return url2;
    }
    let prefix = url2.match(/\?/) ? "&" : "?";
    return `${url2}${prefix}${this.serialize(params2)}`;
  }
};
var arrayBufferToBase64 = (buffer) => {
  let binary = "";
  let bytes = new Uint8Array(buffer);
  let len = bytes.byteLength;
  for (let i = 0; i < len; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
};
var LongPoll = class {
  constructor(endPoint, protocols) {
    if (protocols && protocols.length === 2 && protocols[1].startsWith(AUTH_TOKEN_PREFIX)) {
      this.authToken = atob(protocols[1].slice(AUTH_TOKEN_PREFIX.length));
    }
    this.endPoint = null;
    this.token = null;
    this.skipHeartbeat = true;
    this.reqs = /* @__PURE__ */ new Set();
    this.awaitingBatchAck = false;
    this.currentBatch = null;
    this.currentBatchTimer = null;
    this.batchBuffer = [];
    this.onopen = function() {
    };
    this.onerror = function() {
    };
    this.onmessage = function() {
    };
    this.onclose = function() {
    };
    this.pollEndpoint = this.normalizeEndpoint(endPoint);
    this.readyState = SOCKET_STATES.connecting;
    setTimeout(() => this.poll(), 0);
  }
  normalizeEndpoint(endPoint) {
    return endPoint.replace("ws://", "http://").replace("wss://", "https://").replace(new RegExp("(.*)/" + TRANSPORTS.websocket), "$1/" + TRANSPORTS.longpoll);
  }
  endpointURL() {
    return Ajax.appendParams(this.pollEndpoint, { token: this.token });
  }
  closeAndRetry(code2, reason2, wasClean) {
    this.close(code2, reason2, wasClean);
    this.readyState = SOCKET_STATES.connecting;
  }
  ontimeout() {
    this.onerror("timeout");
    this.closeAndRetry(1005, "timeout", false);
  }
  isActive() {
    return this.readyState === SOCKET_STATES.open || this.readyState === SOCKET_STATES.connecting;
  }
  poll() {
    const headers = { "Accept": "application/json" };
    if (this.authToken) {
      headers["X-Phoenix-AuthToken"] = this.authToken;
    }
    this.ajax("GET", headers, null, () => this.ontimeout(), (resp) => {
      if (resp) {
        var { status, token, messages } = resp;
        this.token = token;
      } else {
        status = 0;
      }
      switch (status) {
        case 200:
          messages.forEach((msg) => {
            setTimeout(() => this.onmessage({ data: msg }), 0);
          });
          this.poll();
          break;
        case 204:
          this.poll();
          break;
        case 410:
          this.readyState = SOCKET_STATES.open;
          this.onopen({});
          this.poll();
          break;
        case 403:
          this.onerror(403);
          this.close(1008, "forbidden", false);
          break;
        case 0:
        case 500:
          this.onerror(500);
          this.closeAndRetry(1011, "internal server error", 500);
          break;
        default:
          throw new Error(`unhandled poll status ${status}`);
      }
    });
  }
  // we collect all pushes within the current event loop by
  // setTimeout 0, which optimizes back-to-back procedural
  // pushes against an empty buffer
  send(body) {
    if (typeof body !== "string") {
      body = arrayBufferToBase64(body);
    }
    if (this.currentBatch) {
      this.currentBatch.push(body);
    } else if (this.awaitingBatchAck) {
      this.batchBuffer.push(body);
    } else {
      this.currentBatch = [body];
      this.currentBatchTimer = setTimeout(() => {
        this.batchSend(this.currentBatch);
        this.currentBatch = null;
      }, 0);
    }
  }
  batchSend(messages) {
    this.awaitingBatchAck = true;
    this.ajax("POST", { "Content-Type": "application/x-ndjson" }, messages.join("\n"), () => this.onerror("timeout"), (resp) => {
      this.awaitingBatchAck = false;
      if (!resp || resp.status !== 200) {
        this.onerror(resp && resp.status);
        this.closeAndRetry(1011, "internal server error", false);
      } else if (this.batchBuffer.length > 0) {
        this.batchSend(this.batchBuffer);
        this.batchBuffer = [];
      }
    });
  }
  close(code2, reason2, wasClean) {
    for (let req of this.reqs) {
      req.abort();
    }
    this.readyState = SOCKET_STATES.closed;
    let opts = Object.assign({ code: 1e3, reason: void 0, wasClean: true }, { code: code2, reason: reason2, wasClean });
    this.batchBuffer = [];
    clearTimeout(this.currentBatchTimer);
    this.currentBatchTimer = null;
    if (typeof CloseEvent !== "undefined") {
      this.onclose(new CloseEvent("close", opts));
    } else {
      this.onclose(opts);
    }
  }
  ajax(method2, headers, body, onCallerTimeout, callback) {
    let req;
    let ontimeout = () => {
      this.reqs.delete(req);
      onCallerTimeout();
    };
    req = Ajax.request(method2, this.endpointURL(), headers, body, this.timeout, ontimeout, (resp) => {
      this.reqs.delete(req);
      if (this.isActive()) {
        callback(resp);
      }
    });
    this.reqs.add(req);
  }
};
var serializer_default = {
  HEADER_LENGTH: 1,
  META_LENGTH: 4,
  KINDS: { push: 0, reply: 1, broadcast: 2 },
  encode(msg, callback) {
    if (msg.payload.constructor === ArrayBuffer) {
      return callback(this.binaryEncode(msg));
    } else {
      let payload = [msg.join_ref, msg.ref, msg.topic, msg.event, msg.payload];
      return callback(JSON.stringify(payload));
    }
  },
  decode(rawPayload, callback) {
    if (rawPayload.constructor === ArrayBuffer) {
      return callback(this.binaryDecode(rawPayload));
    } else {
      let [join_ref, ref, topic, event, payload] = JSON.parse(rawPayload);
      return callback({ join_ref, ref, topic, event, payload });
    }
  },
  // private
  binaryEncode(message4) {
    let { join_ref, ref, event, topic, payload } = message4;
    let metaLength = this.META_LENGTH + join_ref.length + ref.length + topic.length + event.length;
    let header = new ArrayBuffer(this.HEADER_LENGTH + metaLength);
    let view = new DataView(header);
    let offset = 0;
    view.setUint8(offset++, this.KINDS.push);
    view.setUint8(offset++, join_ref.length);
    view.setUint8(offset++, ref.length);
    view.setUint8(offset++, topic.length);
    view.setUint8(offset++, event.length);
    Array.from(join_ref, (char) => view.setUint8(offset++, char.charCodeAt(0)));
    Array.from(ref, (char) => view.setUint8(offset++, char.charCodeAt(0)));
    Array.from(topic, (char) => view.setUint8(offset++, char.charCodeAt(0)));
    Array.from(event, (char) => view.setUint8(offset++, char.charCodeAt(0)));
    var combined = new Uint8Array(header.byteLength + payload.byteLength);
    combined.set(new Uint8Array(header), 0);
    combined.set(new Uint8Array(payload), header.byteLength);
    return combined.buffer;
  },
  binaryDecode(buffer) {
    let view = new DataView(buffer);
    let kind = view.getUint8(0);
    let decoder = new TextDecoder();
    switch (kind) {
      case this.KINDS.push:
        return this.decodePush(buffer, view, decoder);
      case this.KINDS.reply:
        return this.decodeReply(buffer, view, decoder);
      case this.KINDS.broadcast:
        return this.decodeBroadcast(buffer, view, decoder);
    }
  },
  decodePush(buffer, view, decoder) {
    let joinRefSize = view.getUint8(1);
    let topicSize = view.getUint8(2);
    let eventSize = view.getUint8(3);
    let offset = this.HEADER_LENGTH + this.META_LENGTH - 1;
    let joinRef = decoder.decode(buffer.slice(offset, offset + joinRefSize));
    offset = offset + joinRefSize;
    let topic = decoder.decode(buffer.slice(offset, offset + topicSize));
    offset = offset + topicSize;
    let event = decoder.decode(buffer.slice(offset, offset + eventSize));
    offset = offset + eventSize;
    let data2 = buffer.slice(offset, buffer.byteLength);
    return { join_ref: joinRef, ref: null, topic, event, payload: data2 };
  },
  decodeReply(buffer, view, decoder) {
    let joinRefSize = view.getUint8(1);
    let refSize = view.getUint8(2);
    let topicSize = view.getUint8(3);
    let eventSize = view.getUint8(4);
    let offset = this.HEADER_LENGTH + this.META_LENGTH;
    let joinRef = decoder.decode(buffer.slice(offset, offset + joinRefSize));
    offset = offset + joinRefSize;
    let ref = decoder.decode(buffer.slice(offset, offset + refSize));
    offset = offset + refSize;
    let topic = decoder.decode(buffer.slice(offset, offset + topicSize));
    offset = offset + topicSize;
    let event = decoder.decode(buffer.slice(offset, offset + eventSize));
    offset = offset + eventSize;
    let data2 = buffer.slice(offset, buffer.byteLength);
    let payload = { status: event, response: data2 };
    return { join_ref: joinRef, ref, topic, event: CHANNEL_EVENTS.reply, payload };
  },
  decodeBroadcast(buffer, view, decoder) {
    let topicSize = view.getUint8(1);
    let eventSize = view.getUint8(2);
    let offset = this.HEADER_LENGTH + 2;
    let topic = decoder.decode(buffer.slice(offset, offset + topicSize));
    offset = offset + topicSize;
    let event = decoder.decode(buffer.slice(offset, offset + eventSize));
    offset = offset + eventSize;
    let data2 = buffer.slice(offset, buffer.byteLength);
    return { join_ref: null, ref: null, topic, event, payload: data2 };
  }
};
var Socket = class {
  constructor(endPoint, opts = {}) {
    this.stateChangeCallbacks = { open: [], close: [], error: [], message: [] };
    this.channels = [];
    this.sendBuffer = [];
    this.ref = 0;
    this.timeout = opts.timeout || DEFAULT_TIMEOUT;
    this.transport = opts.transport || global.WebSocket || LongPoll;
    this.primaryPassedHealthCheck = false;
    this.longPollFallbackMs = opts.longPollFallbackMs;
    this.fallbackTimer = null;
    this.sessionStore = opts.sessionStorage || global && global.sessionStorage;
    this.establishedConnections = 0;
    this.defaultEncoder = serializer_default.encode.bind(serializer_default);
    this.defaultDecoder = serializer_default.decode.bind(serializer_default);
    this.closeWasClean = false;
    this.disconnecting = false;
    this.binaryType = opts.binaryType || "arraybuffer";
    this.connectClock = 1;
    if (this.transport !== LongPoll) {
      this.encode = opts.encode || this.defaultEncoder;
      this.decode = opts.decode || this.defaultDecoder;
    } else {
      this.encode = this.defaultEncoder;
      this.decode = this.defaultDecoder;
    }
    let awaitingConnectionOnPageShow = null;
    if (phxWindow && phxWindow.addEventListener) {
      phxWindow.addEventListener("pagehide", (_e) => {
        if (this.conn) {
          this.disconnect();
          awaitingConnectionOnPageShow = this.connectClock;
        }
      });
      phxWindow.addEventListener("pageshow", (_e) => {
        if (awaitingConnectionOnPageShow === this.connectClock) {
          awaitingConnectionOnPageShow = null;
          this.connect();
        }
      });
    }
    this.heartbeatIntervalMs = opts.heartbeatIntervalMs || 3e4;
    this.rejoinAfterMs = (tries) => {
      if (opts.rejoinAfterMs) {
        return opts.rejoinAfterMs(tries);
      } else {
        return [1e3, 2e3, 5e3][tries - 1] || 1e4;
      }
    };
    this.reconnectAfterMs = (tries) => {
      if (opts.reconnectAfterMs) {
        return opts.reconnectAfterMs(tries);
      } else {
        return [10, 50, 100, 150, 200, 250, 500, 1e3, 2e3][tries - 1] || 5e3;
      }
    };
    this.logger = opts.logger || null;
    if (!this.logger && opts.debug) {
      this.logger = (kind, msg, data2) => {
        console.log(`${kind}: ${msg}`, data2);
      };
    }
    this.longpollerTimeout = opts.longpollerTimeout || 2e4;
    this.params = closure(opts.params || {});
    this.endPoint = `${endPoint}/${TRANSPORTS.websocket}`;
    this.vsn = opts.vsn || DEFAULT_VSN;
    this.heartbeatTimeoutTimer = null;
    this.heartbeatTimer = null;
    this.pendingHeartbeatRef = null;
    this.reconnectTimer = new Timer(() => {
      this.teardown(() => this.connect());
    }, this.reconnectAfterMs);
    this.authToken = opts.authToken;
  }
  /**
   * Returns the LongPoll transport reference
   */
  getLongPollTransport() {
    return LongPoll;
  }
  /**
   * Disconnects and replaces the active transport
   *
   * @param {Function} newTransport - The new transport class to instantiate
   *
   */
  replaceTransport(newTransport) {
    this.connectClock++;
    this.closeWasClean = true;
    clearTimeout(this.fallbackTimer);
    this.reconnectTimer.reset();
    if (this.conn) {
      this.conn.close();
      this.conn = null;
    }
    this.transport = newTransport;
  }
  /**
   * Returns the socket protocol
   *
   * @returns {string}
   */
  protocol() {
    return location.protocol.match(/^https/) ? "wss" : "ws";
  }
  /**
   * The fully qualified socket url
   *
   * @returns {string}
   */
  endPointURL() {
    let uri = Ajax.appendParams(
      Ajax.appendParams(this.endPoint, this.params()),
      { vsn: this.vsn }
    );
    if (uri.charAt(0) !== "/") {
      return uri;
    }
    if (uri.charAt(1) === "/") {
      return `${this.protocol()}:${uri}`;
    }
    return `${this.protocol()}://${location.host}${uri}`;
  }
  /**
   * Disconnects the socket
   *
   * See https://developer.mozilla.org/en-US/docs/Web/API/CloseEvent#Status_codes for valid status codes.
   *
   * @param {Function} callback - Optional callback which is called after socket is disconnected.
   * @param {integer} code - A status code for disconnection (Optional).
   * @param {string} reason - A textual description of the reason to disconnect. (Optional)
   */
  disconnect(callback, code2, reason2) {
    this.connectClock++;
    this.disconnecting = true;
    this.closeWasClean = true;
    clearTimeout(this.fallbackTimer);
    this.reconnectTimer.reset();
    this.teardown(() => {
      this.disconnecting = false;
      callback && callback();
    }, code2, reason2);
  }
  /**
   *
   * @param {Object} params - The params to send when connecting, for example `{user_id: userToken}`
   *
   * Passing params to connect is deprecated; pass them in the Socket constructor instead:
   * `new Socket("/socket", {params: {user_id: userToken}})`.
   */
  connect(params2) {
    if (params2) {
      console && console.log("passing params to connect is deprecated. Instead pass :params to the Socket constructor");
      this.params = closure(params2);
    }
    if (this.conn && !this.disconnecting) {
      return;
    }
    if (this.longPollFallbackMs && this.transport !== LongPoll) {
      this.connectWithFallback(LongPoll, this.longPollFallbackMs);
    } else {
      this.transportConnect();
    }
  }
  /**
   * Logs the message. Override `this.logger` for specialized logging. noops by default
   * @param {string} kind
   * @param {string} msg
   * @param {Object} data
   */
  log(kind, msg, data2) {
    this.logger && this.logger(kind, msg, data2);
  }
  /**
   * Returns true if a logger has been set on this socket.
   */
  hasLogger() {
    return this.logger !== null;
  }
  /**
   * Registers callbacks for connection open events
   *
   * @example socket.onOpen(function(){ console.info("the socket was opened") })
   *
   * @param {Function} callback
   */
  onOpen(callback) {
    let ref = this.makeRef();
    this.stateChangeCallbacks.open.push([ref, callback]);
    return ref;
  }
  /**
   * Registers callbacks for connection close events
   * @param {Function} callback
   */
  onClose(callback) {
    let ref = this.makeRef();
    this.stateChangeCallbacks.close.push([ref, callback]);
    return ref;
  }
  /**
   * Registers callbacks for connection error events
   *
   * @example socket.onError(function(error){ alert("An error occurred") })
   *
   * @param {Function} callback
   */
  onError(callback) {
    let ref = this.makeRef();
    this.stateChangeCallbacks.error.push([ref, callback]);
    return ref;
  }
  /**
   * Registers callbacks for connection message events
   * @param {Function} callback
   */
  onMessage(callback) {
    let ref = this.makeRef();
    this.stateChangeCallbacks.message.push([ref, callback]);
    return ref;
  }
  /**
   * Pings the server and invokes the callback with the RTT in milliseconds
   * @param {Function} callback
   *
   * Returns true if the ping was pushed or false if unable to be pushed.
   */
  ping(callback) {
    if (!this.isConnected()) {
      return false;
    }
    let ref = this.makeRef();
    let startTime = Date.now();
    this.push({ topic: "phoenix", event: "heartbeat", payload: {}, ref });
    let onMsgRef = this.onMessage((msg) => {
      if (msg.ref === ref) {
        this.off([onMsgRef]);
        callback(Date.now() - startTime);
      }
    });
    return true;
  }
  /**
   * @private
   */
  transportConnect() {
    this.connectClock++;
    this.closeWasClean = false;
    let protocols = void 0;
    if (this.authToken) {
      protocols = ["phoenix", `${AUTH_TOKEN_PREFIX}${btoa(this.authToken).replace(/=/g, "")}`];
    }
    this.conn = new this.transport(this.endPointURL(), protocols);
    this.conn.binaryType = this.binaryType;
    this.conn.timeout = this.longpollerTimeout;
    this.conn.onopen = () => this.onConnOpen();
    this.conn.onerror = (error2) => this.onConnError(error2);
    this.conn.onmessage = (event) => this.onConnMessage(event);
    this.conn.onclose = (event) => this.onConnClose(event);
  }
  getSession(key) {
    return this.sessionStore && this.sessionStore.getItem(key);
  }
  storeSession(key, val2) {
    this.sessionStore && this.sessionStore.setItem(key, val2);
  }
  connectWithFallback(fallbackTransport, fallbackThreshold = 2500) {
    clearTimeout(this.fallbackTimer);
    let established = false;
    let primaryTransport = true;
    let openRef, errorRef;
    let fallback = (reason2) => {
      this.log("transport", `falling back to ${fallbackTransport.name}...`, reason2);
      this.off([openRef, errorRef]);
      primaryTransport = false;
      this.replaceTransport(fallbackTransport);
      this.transportConnect();
    };
    if (this.getSession(`phx:fallback:${fallbackTransport.name}`)) {
      return fallback("memorized");
    }
    this.fallbackTimer = setTimeout(fallback, fallbackThreshold);
    errorRef = this.onError((reason2) => {
      this.log("transport", "error", reason2);
      if (primaryTransport && !established) {
        clearTimeout(this.fallbackTimer);
        fallback(reason2);
      }
    });
    this.onOpen(() => {
      established = true;
      if (!primaryTransport) {
        if (!this.primaryPassedHealthCheck) {
          this.storeSession(`phx:fallback:${fallbackTransport.name}`, "true");
        }
        return this.log("transport", `established ${fallbackTransport.name} fallback`);
      }
      clearTimeout(this.fallbackTimer);
      this.fallbackTimer = setTimeout(fallback, fallbackThreshold);
      this.ping((rtt) => {
        this.log("transport", "connected to primary after", rtt);
        this.primaryPassedHealthCheck = true;
        clearTimeout(this.fallbackTimer);
      });
    });
    this.transportConnect();
  }
  clearHeartbeats() {
    clearTimeout(this.heartbeatTimer);
    clearTimeout(this.heartbeatTimeoutTimer);
  }
  onConnOpen() {
    if (this.hasLogger())
      this.log("transport", `${this.transport.name} connected to ${this.endPointURL()}`);
    this.closeWasClean = false;
    this.disconnecting = false;
    this.establishedConnections++;
    this.flushSendBuffer();
    this.reconnectTimer.reset();
    this.resetHeartbeat();
    this.stateChangeCallbacks.open.forEach(([, callback]) => callback());
  }
  /**
   * @private
   */
  heartbeatTimeout() {
    if (this.pendingHeartbeatRef) {
      this.pendingHeartbeatRef = null;
      if (this.hasLogger()) {
        this.log("transport", "heartbeat timeout. Attempting to re-establish connection");
      }
      this.triggerChanError();
      this.closeWasClean = false;
      this.teardown(() => this.reconnectTimer.scheduleTimeout(), WS_CLOSE_NORMAL, "heartbeat timeout");
    }
  }
  resetHeartbeat() {
    if (this.conn && this.conn.skipHeartbeat) {
      return;
    }
    this.pendingHeartbeatRef = null;
    this.clearHeartbeats();
    this.heartbeatTimer = setTimeout(() => this.sendHeartbeat(), this.heartbeatIntervalMs);
  }
  teardown(callback, code2, reason2) {
    if (!this.conn) {
      return callback && callback();
    }
    let connectClock = this.connectClock;
    this.waitForBufferDone(() => {
      if (connectClock !== this.connectClock) {
        return;
      }
      if (this.conn) {
        if (code2) {
          this.conn.close(code2, reason2 || "");
        } else {
          this.conn.close();
        }
      }
      this.waitForSocketClosed(() => {
        if (connectClock !== this.connectClock) {
          return;
        }
        if (this.conn) {
          this.conn.onopen = function() {
          };
          this.conn.onerror = function() {
          };
          this.conn.onmessage = function() {
          };
          this.conn.onclose = function() {
          };
          this.conn = null;
        }
        callback && callback();
      });
    });
  }
  waitForBufferDone(callback, tries = 1) {
    if (tries === 5 || !this.conn || !this.conn.bufferedAmount) {
      callback();
      return;
    }
    setTimeout(() => {
      this.waitForBufferDone(callback, tries + 1);
    }, 150 * tries);
  }
  waitForSocketClosed(callback, tries = 1) {
    if (tries === 5 || !this.conn || this.conn.readyState === SOCKET_STATES.closed) {
      callback();
      return;
    }
    setTimeout(() => {
      this.waitForSocketClosed(callback, tries + 1);
    }, 150 * tries);
  }
  onConnClose(event) {
    let closeCode = event && event.code;
    if (this.hasLogger())
      this.log("transport", "close", event);
    this.triggerChanError();
    this.clearHeartbeats();
    if (!this.closeWasClean && closeCode !== 1e3) {
      this.reconnectTimer.scheduleTimeout();
    }
    this.stateChangeCallbacks.close.forEach(([, callback]) => callback(event));
  }
  /**
   * @private
   */
  onConnError(error2) {
    if (this.hasLogger())
      this.log("transport", error2);
    let transportBefore = this.transport;
    let establishedBefore = this.establishedConnections;
    this.stateChangeCallbacks.error.forEach(([, callback]) => {
      callback(error2, transportBefore, establishedBefore);
    });
    if (transportBefore === this.transport || establishedBefore > 0) {
      this.triggerChanError();
    }
  }
  /**
   * @private
   */
  triggerChanError() {
    this.channels.forEach((channel) => {
      if (!(channel.isErrored() || channel.isLeaving() || channel.isClosed())) {
        channel.trigger(CHANNEL_EVENTS.error);
      }
    });
  }
  /**
   * @returns {string}
   */
  connectionState() {
    switch (this.conn && this.conn.readyState) {
      case SOCKET_STATES.connecting:
        return "connecting";
      case SOCKET_STATES.open:
        return "open";
      case SOCKET_STATES.closing:
        return "closing";
      default:
        return "closed";
    }
  }
  /**
   * @returns {boolean}
   */
  isConnected() {
    return this.connectionState() === "open";
  }
  /**
   * @private
   *
   * @param {Channel}
   */
  remove(channel) {
    this.off(channel.stateChangeRefs);
    this.channels = this.channels.filter((c) => c !== channel);
  }
  /**
   * Removes `onOpen`, `onClose`, `onError,` and `onMessage` registrations.
   *
   * @param {refs} - list of refs returned by calls to
   *                 `onOpen`, `onClose`, `onError,` and `onMessage`
   */
  off(refs) {
    for (let key in this.stateChangeCallbacks) {
      this.stateChangeCallbacks[key] = this.stateChangeCallbacks[key].filter(([ref]) => {
        return refs.indexOf(ref) === -1;
      });
    }
  }
  /**
   * Initiates a new channel for the given topic
   *
   * @param {string} topic
   * @param {Object} chanParams - Parameters for the channel
   * @returns {Channel}
   */
  channel(topic, chanParams = {}) {
    let chan = new Channel(topic, chanParams, this);
    this.channels.push(chan);
    return chan;
  }
  /**
   * @param {Object} data
   */
  push(data2) {
    if (this.hasLogger()) {
      let { topic, event, payload, ref, join_ref } = data2;
      this.log("push", `${topic} ${event} (${join_ref}, ${ref})`, payload);
    }
    if (this.isConnected()) {
      this.encode(data2, (result2) => this.conn.send(result2));
    } else {
      this.sendBuffer.push(() => this.encode(data2, (result2) => this.conn.send(result2)));
    }
  }
  /**
   * Return the next message ref, accounting for overflows
   * @returns {string}
   */
  makeRef() {
    let newRef = this.ref + 1;
    if (newRef === this.ref) {
      this.ref = 0;
    } else {
      this.ref = newRef;
    }
    return this.ref.toString();
  }
  sendHeartbeat() {
    if (this.pendingHeartbeatRef && !this.isConnected()) {
      return;
    }
    this.pendingHeartbeatRef = this.makeRef();
    this.push({ topic: "phoenix", event: "heartbeat", payload: {}, ref: this.pendingHeartbeatRef });
    this.heartbeatTimeoutTimer = setTimeout(() => this.heartbeatTimeout(), this.heartbeatIntervalMs);
  }
  flushSendBuffer() {
    if (this.isConnected() && this.sendBuffer.length > 0) {
      this.sendBuffer.forEach((callback) => callback());
      this.sendBuffer = [];
    }
  }
  onConnMessage(rawMessage) {
    this.decode(rawMessage.data, (msg) => {
      let { topic, event, payload, ref, join_ref } = msg;
      if (ref && ref === this.pendingHeartbeatRef) {
        this.clearHeartbeats();
        this.pendingHeartbeatRef = null;
        this.heartbeatTimer = setTimeout(() => this.sendHeartbeat(), this.heartbeatIntervalMs);
      }
      if (this.hasLogger())
        this.log("receive", `${payload.status || ""} ${topic} ${event} ${ref && "(" + ref + ")" || ""}`, payload);
      for (let i = 0; i < this.channels.length; i++) {
        const channel = this.channels[i];
        if (!channel.isMember(topic, event, payload, join_ref)) {
          continue;
        }
        channel.trigger(event, payload, ref, join_ref);
      }
      for (let i = 0; i < this.stateChangeCallbacks.message.length; i++) {
        let [, callback] = this.stateChangeCallbacks.message[i];
        callback(msg);
      }
    });
  }
  leaveOpenTopic(topic) {
    let dupChannel = this.channels.find((c) => c.topic === topic && (c.isJoined() || c.isJoining()));
    if (dupChannel) {
      if (this.hasLogger())
        this.log("transport", `leaving duplicate topic "${topic}"`);
      dupChannel.leave();
    }
  }
};

// ../../../node_modules/@rescript/runtime/lib/es6/Primitive_option.js
function some(x) {
  if (x === void 0) {
    return {
      BS_PRIVATE_NESTED_SOME_NONE: 0
    };
  } else if (x !== null && x.BS_PRIVATE_NESTED_SOME_NONE !== void 0) {
    return {
      BS_PRIVATE_NESTED_SOME_NONE: x.BS_PRIVATE_NESTED_SOME_NONE + 1 | 0
    };
  } else {
    return x;
  }
}
function fromNullable(x) {
  if (x == null) {
    return;
  } else {
    return some(x);
  }
}
function valFromOption(x) {
  if (x === null || x.BS_PRIVATE_NESTED_SOME_NONE === void 0) {
    return x;
  }
  let depth = x.BS_PRIVATE_NESTED_SOME_NONE;
  if (depth === 0) {
    return;
  } else {
    return {
      BS_PRIVATE_NESTED_SOME_NONE: depth - 1 | 0
    };
  }
}

// ../../../node_modules/@rescript/runtime/lib/es6/Stdlib_Option.js
function forEach(opt, f) {
  if (opt !== void 0) {
    return f(valFromOption(opt));
  }
}
function map(opt, f) {
  if (opt !== void 0) {
    return some(f(valFromOption(opt)));
  }
}
function flatMap(opt, f) {
  if (opt !== void 0) {
    return f(valFromOption(opt));
  }
}
function getOr(opt, $$default) {
  if (opt !== void 0) {
    return valFromOption(opt);
  } else {
    return $$default;
  }
}
function isSome(x) {
  return x !== void 0;
}
function isNone(x) {
  return x === void 0;
}

// ../../../node_modules/@rescript/runtime/lib/es6/Stdlib_Result.js
function map2(opt, f) {
  if (opt.TAG === "Ok") {
    return {
      TAG: "Ok",
      _0: f(opt._0)
    };
  } else {
    return opt;
  }
}
async function flatMapOkAsync(res, f) {
  let value = await res;
  if (value.TAG === "Ok") {
    return await f(value._0);
  } else {
    return {
      TAG: "Error",
      _0: value._0
    };
  }
}

// ../../../node_modules/@rescript/runtime/lib/es6/Primitive_exceptions.js
function isExtension(e) {
  if (e == null) {
    return false;
  } else {
    return typeof e.RE_EXN_ID === "string";
  }
}
function internalToException(e) {
  if (isExtension(e)) {
    return e;
  } else {
    return {
      RE_EXN_ID: "JsExn",
      _1: e
    };
  }
}
var idMap = {};
function create(str) {
  let v = idMap[str];
  if (v !== void 0) {
    let id2 = v + 1 | 0;
    idMap[str] = id2;
    return str + ("/" + id2);
  }
  idMap[str] = 1;
  return str;
}

// ../../../node_modules/sury/src/Sury.res.mjs
var immutableEmpty = {};
var immutableEmpty$1 = [];
function capitalize(string4) {
  return string4.slice(0, 1).toUpperCase() + string4.slice(1);
}
var copy = (d2) => ({ ...d2 });
function fromString(string4) {
  let _idx = 0;
  while (true) {
    let idx = _idx;
    let match = string4[idx];
    if (match === void 0) {
      return `"` + string4 + `"`;
    }
    switch (match) {
      case '"':
      case "\n":
        return JSON.stringify(string4);
      default:
        _idx = idx + 1 | 0;
        continue;
    }
  }
  ;
}
function toArray2(path) {
  if (path === "") {
    return [];
  } else {
    return JSON.parse(path.split(`"]["`).join(`","`));
  }
}
var vendor = "sury";
var s = Symbol(vendor);
var itemSymbol = Symbol(vendor + ":item");
var $$Error = /* @__PURE__ */ create("Sury.Error");
var constField = "const";
function isOptional(schema4) {
  let match = schema4.type;
  switch (match) {
    case "undefined":
      return true;
    case "union":
      return "undefined" in schema4.has;
    default:
      return false;
  }
}
function has(acc, flag) {
  return (acc & flag) !== 0;
}
var flags = {
  unknown: 1,
  string: 2,
  number: 4,
  boolean: 8,
  undefined: 16,
  null: 32,
  object: 64,
  array: 128,
  union: 256,
  ref: 512,
  bigint: 1024,
  nan: 2048,
  "function": 4096,
  instance: 8192,
  never: 16384,
  symbol: 32768
};
function stringify(unknown2) {
  let tagFlag = flags[typeof unknown2];
  if (tagFlag & 16) {
    return "undefined";
  }
  if (!(tagFlag & 64)) {
    if (tagFlag & 2) {
      return `"` + unknown2 + `"`;
    } else if (tagFlag & 1024) {
      return unknown2 + `n`;
    } else {
      return unknown2.toString();
    }
  }
  if (unknown2 === null) {
    return "null";
  }
  if (Array.isArray(unknown2)) {
    let string4 = "[";
    for (let i = 0, i_finish = unknown2.length; i < i_finish; ++i) {
      if (i !== 0) {
        string4 = string4 + ", ";
      }
      string4 = string4 + stringify(unknown2[i]);
    }
    return string4 + "]";
  }
  if (unknown2.constructor !== Object) {
    return Object.prototype.toString.call(unknown2);
  }
  let keys = Object.keys(unknown2);
  let string$1 = "{ ";
  for (let i$1 = 0, i_finish$1 = keys.length; i$1 < i_finish$1; ++i$1) {
    let key = keys[i$1];
    let value = unknown2[key];
    string$1 = string$1 + key + `: ` + stringify(value) + `; `;
  }
  return string$1 + "}";
}
function toExpression(schema4) {
  let tag = schema4.type;
  let $$const = schema4.const;
  let name3 = schema4.name;
  if (name3 !== void 0) {
    return name3;
  }
  if ($$const !== void 0) {
    return stringify($$const);
  }
  let format = schema4.format;
  let anyOf = schema4.anyOf;
  if (anyOf !== void 0) {
    return anyOf.map(toExpression).join(" | ");
  }
  if (format !== void 0) {
    return format;
  }
  switch (tag) {
    case "nan":
      return "NaN";
    case "object":
      let additionalItems = schema4.additionalItems;
      let properties = schema4.properties;
      let locations = Object.keys(properties);
      if (locations.length === 0) {
        if (typeof additionalItems === "object") {
          return `{ [key: string]: ` + toExpression(additionalItems) + `; }`;
        } else {
          return `{}`;
        }
      } else {
        return `{ ` + locations.map((location2) => location2 + `: ` + toExpression(properties[location2]) + `;`).join(" ") + ` }`;
      }
    default:
      if (schema4.b) {
        return tag;
      }
      switch (tag) {
        case "instance":
          return schema4.class.name;
        case "array":
          let additionalItems$1 = schema4.additionalItems;
          let items = schema4.items;
          if (typeof additionalItems$1 !== "object") {
            return `[` + items.map((item) => toExpression(item.schema)).join(", ") + `]`;
          }
          let itemName = toExpression(additionalItems$1);
          return (additionalItems$1.type === "union" ? `(` + itemName + `)` : itemName) + "[]";
        default:
          return tag;
      }
  }
}
var SuryError = class extends Error {
  constructor(code2, flag, path) {
    super();
    this.flag = flag;
    this.code = code2;
    this.path = path;
  }
};
var d = Object.defineProperty;
var p = SuryError.prototype;
d(p, "message", {
  get() {
    return message(this);
  }
});
d(p, "reason", {
  get() {
    return reason(this);
  }
});
d(p, "name", { value: "SuryError" });
d(p, "s", { value: s });
d(p, "_1", {
  get() {
    return this;
  }
});
d(p, "RE_EXN_ID", {
  value: $$Error
});
var Schema = function(type) {
  this.type = type;
};
var sp = /* @__PURE__ */ Object.create(null);
d(sp, "with", {
  get() {
    return (fn, ...args) => fn(this, ...args);
  }
});
Schema.prototype = sp;
function getOrRethrow(exn) {
  if (exn && exn.s === s) {
    return exn;
  }
  throw exn;
}
function reason(error2, nestedLevelOpt) {
  let nestedLevel = nestedLevelOpt !== void 0 ? nestedLevelOpt : 0;
  let reason$1 = error2.code;
  if (typeof reason$1 !== "object") {
    return "Encountered unexpected async transform or refine. Use parseAsyncOrThrow operation instead";
  }
  switch (reason$1.TAG) {
    case "OperationFailed":
      return reason$1._0;
    case "InvalidOperation":
      return reason$1.description;
    case "InvalidType":
      let unionErrors = reason$1.unionErrors;
      let m = `Expected ` + toExpression(reason$1.expected) + `, received ` + stringify(reason$1.received);
      if (unionErrors !== void 0) {
        let lineBreak = `
` + " ".repeat(nestedLevel << 1);
        let reasonsDict = {};
        for (let idx = 0, idx_finish = unionErrors.length; idx < idx_finish; ++idx) {
          let error$1 = unionErrors[idx];
          let reason$2 = reason(error$1, nestedLevel + 1);
          let nonEmptyPath = error$1.path;
          let location2 = nonEmptyPath === "" ? "" : `At ` + nonEmptyPath + `: `;
          let line = `- ` + location2 + reason$2;
          if (!reasonsDict[line]) {
            reasonsDict[line] = 1;
            m = m + lineBreak + line;
          }
        }
      }
      return m;
    case "UnsupportedTransformation":
      return `Unsupported transformation from ` + toExpression(reason$1.from) + ` to ` + toExpression(reason$1.to);
    case "ExcessField":
      return `Unrecognized key "` + reason$1._0 + `"`;
    case "InvalidJsonSchema":
      return toExpression(reason$1._0) + ` is not valid JSON`;
  }
}
function message(error2) {
  let op = error2.flag;
  let text = "Failed ";
  if (op & 2) {
    text = text + "async ";
  }
  text = text + (op & 1 ? op & 4 ? "asserting" : "parsing" : "converting");
  if (op & 8) {
    text = text + " to JSON" + (op & 16 ? " string" : "");
  }
  let nonEmptyPath = error2.path;
  let tmp = nonEmptyPath === "" ? "" : ` at ` + nonEmptyPath;
  return text + tmp + `: ` + reason(error2, void 0);
}
var globalConfig = {
  m: message,
  d: void 0,
  a: "strip",
  n: false
};
var shakenRef = "as";
var shakenTraps = {
  get: (target, prop) => {
    let l = target[shakenRef];
    if (l === void 0) {
      return target[prop];
    }
    if (prop === shakenRef) {
      return target[prop];
    }
    let l$1 = valFromOption(l);
    let message4 = `Schema S.` + l$1 + ` is not enabled. To start using it, add S.enable` + capitalize(l$1) + `() at the project root.`;
    throw new Error(`[Sury] ` + message4);
  }
};
function shaken(apiName) {
  let mut = new Schema("never");
  mut[shakenRef] = apiName;
  return new Proxy(mut, shakenTraps);
}
var unknown = new Schema("unknown");
var bool = new Schema("boolean");
var symbol = new Schema("symbol");
var string = new Schema("string");
var int = new Schema("number");
int.format = "int32";
var float = new Schema("number");
var bigint = new Schema("bigint");
var unit = new Schema("undefined");
unit.const = void 0;
var copyWithoutCache = (schema4) => {
  let c = new Schema(schema4.type);
  for (let k in schema4) {
    if (k > "a" || k === "$ref" || k === "$defs") {
      c[k] = schema4[k];
    }
  }
  return c;
};
function updateOutput(schema4, fn) {
  let root = copyWithoutCache(schema4);
  let mut = root;
  while (mut.to) {
    let next = copyWithoutCache(mut.to);
    mut.to = next;
    mut = next;
  }
  ;
  fn(mut);
  return root;
}
function embed(b, value) {
  let e = b.g.e;
  let l = e.length;
  e[l] = value;
  return `e[` + l + `]`;
}
function inlineConst(b, schema4) {
  let tagFlag = flags[schema4.type];
  let $$const = schema4.const;
  if (tagFlag & 16) {
    return "void 0";
  } else if (tagFlag & 2) {
    return fromString($$const);
  } else if (tagFlag & 1024) {
    return $$const + "n";
  } else if (tagFlag & 45056) {
    return embed(b, schema4.const);
  } else {
    return $$const;
  }
}
function inlineLocation(b, location2) {
  let key = `"` + location2 + `"`;
  let i = b.g[key];
  if (i !== void 0) {
    return i;
  }
  let inlinedLocation = fromString(location2);
  b.g[key] = inlinedLocation;
  return inlinedLocation;
}
function secondAllocate(v) {
  let b = this;
  b.l = b.l + "," + v;
}
function initialAllocate(v) {
  let b = this;
  b.l = v;
  b.a = secondAllocate;
}
function rootScope(flag, defs) {
  let global3 = {
    c: "",
    l: "",
    a: initialAllocate,
    v: -1,
    o: flag,
    f: "",
    e: [],
    d: defs
  };
  global3.g = global3;
  return global3;
}
function allocateScope(b) {
  delete b.a;
  let varsAllocation = b.l;
  if (varsAllocation === "") {
    return b.f + b.c;
  } else {
    return b.f + `let ` + varsAllocation + `;` + b.c;
  }
}
function varWithoutAllocation(global3) {
  let newCounter = global3.v + 1;
  global3.v = newCounter;
  return `v` + newCounter;
}
function _var(_b) {
  return this.i;
}
function _notVar(b) {
  let val2 = this;
  let v = varWithoutAllocation(b.g);
  let i = val2.i;
  if (i === "") {
    val2.b.a(v);
  } else if (b.a !== void 0) {
    b.a(v + `=` + i);
  } else {
    b.c = b.c + (v + `=` + i + `;`);
    b.g.a(v);
  }
  val2.v = _var;
  val2.i = v;
  return v;
}
function allocateVal(b, schema4) {
  let v = varWithoutAllocation(b.g);
  b.a(v);
  return {
    b,
    v: _var,
    i: v,
    f: 0,
    type: schema4.type
  };
}
function val(b, initial, schema4) {
  return {
    b,
    v: _notVar,
    i: initial,
    f: 0,
    type: schema4.type
  };
}
function constVal(b, schema4) {
  return {
    b,
    v: _notVar,
    i: inlineConst(b, schema4),
    f: 0,
    type: schema4.type,
    const: schema4.const
  };
}
function asyncVal(b, initial) {
  return {
    b,
    v: _notVar,
    i: initial,
    f: 2,
    type: "unknown"
  };
}
function objectJoin(inlinedLocation, value) {
  return inlinedLocation + `:` + value + `,`;
}
function arrayJoin(_inlinedLocation, value) {
  return value + ",";
}
function make(b, isArray) {
  return {
    b,
    v: _notVar,
    i: "",
    f: 0,
    type: isArray ? "array" : "object",
    properties: {},
    additionalItems: "strict",
    j: isArray ? arrayJoin : objectJoin,
    c: 0,
    r: ""
  };
}
function add(objectVal, location2, val2) {
  let inlinedLocation = inlineLocation(objectVal.b, location2);
  objectVal.properties[location2] = val2;
  if (val2.f & 2) {
    objectVal.r = objectVal.r + val2.i + ",";
    objectVal.i = objectVal.i + objectVal.j(inlinedLocation, `a[` + objectVal.c++ + `]`);
  } else {
    objectVal.i = objectVal.i + objectVal.j(inlinedLocation, val2.i);
  }
}
function merge(target, subObjectVal) {
  let locations = Object.keys(subObjectVal.properties);
  for (let idx = 0, idx_finish = locations.length; idx < idx_finish; ++idx) {
    let location2 = locations[idx];
    add(target, location2, subObjectVal.properties[location2]);
  }
}
function complete(objectVal, isArray) {
  objectVal.i = isArray ? "[" + objectVal.i + "]" : "{" + objectVal.i + "}";
  if (objectVal.c) {
    objectVal.f = objectVal.f | 2;
    objectVal.i = `Promise.all([` + objectVal.r + `]).then(a=>(` + objectVal.i + `))`;
  }
  objectVal.additionalItems = "strict";
  return objectVal;
}
function addKey(b, input, key, val2) {
  return input.v(b) + `[` + key + `]=` + val2.i;
}
function set(b, input, val2) {
  if (input === val2) {
    return "";
  }
  let inputVar = input.v(b);
  let match = input.f & 2;
  let match$1 = val2.f & 2;
  if (match) {
    if (!match$1) {
      return inputVar + `=Promise.resolve(` + val2.i + `)`;
    }
  } else if (match$1) {
    input.f = input.f | 2;
    return inputVar + `=` + val2.i;
  }
  return inputVar + `=` + val2.i;
}
function get(b, targetVal, location2) {
  let properties = targetVal.properties;
  let val2 = properties[location2];
  if (val2 !== void 0) {
    return val2;
  }
  let schema4 = targetVal.additionalItems;
  let schema$12;
  if (schema4 === "strip" || schema4 === "strict") {
    if (schema4 === "strip") {
      throw new Error(`[Sury] The schema doesn't have additional items`);
    }
    throw new Error(`[Sury] The schema doesn't have additional items`);
  } else {
    schema$12 = schema4;
  }
  let val$1 = {
    b,
    v: _notVar,
    i: targetVal.v(b) + (`[` + fromString(location2) + `]`),
    f: 0,
    type: schema$12.type
  };
  properties[location2] = val$1;
  return val$1;
}
function setInlined(b, input, inlined) {
  return input.v(b) + `=` + inlined;
}
function map3(inlinedFn, input) {
  return {
    b: input.b,
    v: _notVar,
    i: inlinedFn + `(` + input.i + `)`,
    f: 0,
    type: "unknown"
  };
}
function $$throw(b, code2, path) {
  throw new SuryError(code2, b.g.o, path);
}
function failWithArg(b, path, fn, arg) {
  return embed(b, (arg2) => $$throw(b, fn(arg2), path)) + `(` + arg + `)`;
}
function invalidOperation(b, path, description2) {
  return $$throw(b, {
    TAG: "InvalidOperation",
    description: description2
  }, path);
}
function withPathPrepend(b, input, path, maybeDynamicLocationVar, appendSafe, fn) {
  if (path === "" && maybeDynamicLocationVar === void 0) {
    return fn(b, input, path);
  }
  try {
    let $$catch = (b2, errorVar2) => {
      b2.c = errorVar2 + `.path=` + fromString(path) + `+` + (maybeDynamicLocationVar !== void 0 ? `'["'+` + maybeDynamicLocationVar + `+'"]'+` : "") + errorVar2 + `.path`;
    };
    let fn$1 = (b2) => fn(b2, input, "");
    let prevCode = b.c;
    b.c = "";
    let errorVar = varWithoutAllocation(b.g);
    let maybeResolveVal = $$catch(b, errorVar);
    let catchCode = `if(` + (errorVar + `&&` + errorVar + `.s===s`) + `){` + b.c;
    b.c = "";
    let bb = {
      c: "",
      l: "",
      a: initialAllocate,
      f: "",
      g: b.g
    };
    let fnOutput = fn$1(bb);
    b.c = b.c + allocateScope(bb);
    let isNoop = fnOutput.i === input.i && b.c === "";
    if (appendSafe !== void 0) {
      appendSafe(b, fnOutput);
    }
    if (isNoop) {
      return fnOutput;
    }
    let isAsync2 = fnOutput.f & 2;
    let output = input === fnOutput ? input : appendSafe !== void 0 ? fnOutput : {
      b,
      v: _notVar,
      i: "",
      f: isAsync2 ? 2 : 0,
      type: "unknown"
    };
    let catchCode$1 = maybeResolveVal !== void 0 ? (catchLocation) => catchCode + (catchLocation === 1 ? `return ` + maybeResolveVal.i : set(b, output, maybeResolveVal)) + (`}else{throw ` + errorVar + `}`) : (param) => catchCode + `}throw ` + errorVar;
    b.c = prevCode + (`try{` + b.c + (isAsync2 ? setInlined(b, output, fnOutput.i + `.catch(` + errorVar + `=>{` + catchCode$1(1) + `})`) : set(b, output, fnOutput)) + `}catch(` + errorVar + `){` + catchCode$1(0) + `}`);
    return output;
  } catch (exn) {
    let error2 = getOrRethrow(exn);
    throw new SuryError(error2.code, error2.flag, path + "[]" + error2.path);
  }
}
function validation(b, inputVar, schema4, negative) {
  let eq = negative ? "!==" : "===";
  let and_ = negative ? "||" : "&&";
  let exp = negative ? "!" : "";
  let tag = schema4.type;
  let tagFlag = flags[tag];
  if (tagFlag & 2048) {
    return exp + (`Number.isNaN(` + inputVar + `)`);
  }
  if (constField in schema4) {
    return inputVar + eq + inlineConst(b, schema4);
  }
  if (tagFlag & 4) {
    return `typeof ` + inputVar + eq + `"` + tag + `"`;
  }
  if (tagFlag & 64) {
    return `typeof ` + inputVar + eq + `"` + tag + `"` + and_ + exp + inputVar;
  }
  if (tagFlag & 128) {
    return exp + `Array.isArray(` + inputVar + `)`;
  }
  if (!(tagFlag & 8192)) {
    return `typeof ` + inputVar + eq + `"` + tag + `"`;
  }
  let c = inputVar + ` instanceof ` + embed(b, schema4.class);
  if (negative) {
    return `!(` + c + `)`;
  } else {
    return c;
  }
}
function refinement(b, inputVar, schema4, negative) {
  let eq = negative ? "!==" : "===";
  let and_ = negative ? "||" : "&&";
  let not_ = negative ? "" : "!";
  let lt = negative ? ">" : "<";
  let gt = negative ? "<" : ">";
  let match = schema4.type;
  let tag;
  let exit = 0;
  let match$1 = schema4.const;
  if (match$1 !== void 0) {
    return "";
  }
  let match$2 = schema4.format;
  if (match$2 !== void 0) {
    switch (match$2) {
      case "int32":
        return and_ + inputVar + lt + `2147483647` + and_ + inputVar + gt + `-2147483648` + and_ + inputVar + `%1` + eq + `0`;
      case "port":
      case "json":
        exit = 2;
        break;
    }
  } else {
    exit = 2;
  }
  if (exit === 2) {
    switch (match) {
      case "number":
        if (globalConfig.n) {
          return "";
        } else {
          return and_ + not_ + `Number.isNaN(` + inputVar + `)`;
        }
      case "array":
      case "object":
        tag = match;
        break;
      default:
        return "";
    }
  }
  let additionalItems = schema4.additionalItems;
  let items = schema4.items;
  let length2 = items.length;
  let code2 = tag === "array" ? additionalItems === "strip" || additionalItems === "strict" ? additionalItems === "strip" ? and_ + inputVar + `.length` + gt + length2 : and_ + inputVar + `.length` + eq + length2 : "" : additionalItems === "strip" ? "" : and_ + not_ + `Array.isArray(` + inputVar + `)`;
  for (let idx = 0, idx_finish = items.length; idx < idx_finish; ++idx) {
    let match$3 = items[idx];
    let location2 = match$3.location;
    let item = match$3.schema;
    let itemCode;
    if (constField in item || schema4.unnest) {
      let inlinedLocation = inlineLocation(b, location2);
      itemCode = validation(b, inputVar + (`[` + inlinedLocation + `]`), item, negative);
    } else if (item.items) {
      let inlinedLocation$1 = inlineLocation(b, location2);
      let inputVar$1 = inputVar + (`[` + inlinedLocation$1 + `]`);
      itemCode = validation(b, inputVar$1, item, negative) + refinement(b, inputVar$1, item, negative);
    } else {
      itemCode = "";
    }
    if (itemCode !== "") {
      code2 = code2 + and_ + itemCode;
    }
  }
  return code2;
}
function makeRefinedOf(b, input, schema4) {
  let mut = {
    b,
    v: input.v,
    i: input.i,
    f: input.f,
    type: schema4.type
  };
  let loop = (mut2, schema5) => {
    if (constField in schema5) {
      mut2.const = schema5.const;
    }
    let items = schema5.items;
    if (items === void 0) {
      return;
    }
    let properties = {};
    items.forEach((item) => {
      let schema6 = item.schema;
      let isConst = constField in schema6;
      if (!(isConst || schema6.items)) {
        return;
      }
      let tmp;
      if (isConst) {
        tmp = inlineConst(b, schema6);
      } else {
        let inlinedLocation = inlineLocation(b, item.location);
        tmp = mut2.v(b) + (`[` + inlinedLocation + `]`);
      }
      let mut$1 = {
        b: mut2.b,
        v: _notVar,
        i: tmp,
        f: 0,
        type: schema6.type
      };
      loop(mut$1, schema6);
      properties[item.location] = mut$1;
    });
    mut2.properties = properties;
    mut2.additionalItems = unknown;
  };
  loop(mut, schema4);
  return mut;
}
function typeFilterCode(b, schema4, input, path) {
  if (schema4.noValidation || flags[schema4.type] & 17153) {
    return "";
  }
  let inputVar = input.v(b);
  return `if(` + validation(b, inputVar, schema4, true) + refinement(b, inputVar, schema4, true) + `){` + failWithArg(b, path, (input2) => ({
    TAG: "InvalidType",
    expected: schema4,
    received: input2
  }), inputVar) + `}`;
}
function unsupportedTransform(b, from, target, path) {
  return $$throw(b, {
    TAG: "UnsupportedTransformation",
    from,
    to: target
  }, path);
}
function noopOperation(i) {
  return i;
}
function setHas(has2, tag) {
  has2[tag === "union" || tag === "ref" ? "unknown" : tag] = true;
}
var jsonName = `JSON`;
var jsonString = shaken("jsonString");
function inputToString(b, input) {
  return val(b, `""+` + input.i, string);
}
function parse(prevB, schema4, inputArg, path) {
  let b = {
    c: "",
    l: "",
    a: initialAllocate,
    f: "",
    g: prevB.g
  };
  if (schema4.$defs) {
    b.g.d = schema4.$defs;
  }
  let input = inputArg;
  let isFromLiteral = constField in input;
  let isSchemaLiteral = constField in schema4;
  let isSameTag = input.type === schema4.type;
  let schemaTagFlag = flags[schema4.type];
  let inputTagFlag = flags[input.type];
  let isUnsupported = false;
  if (!(schemaTagFlag & 257 || schema4.format === "json")) {
    if (schema4.name === jsonName && !(inputTagFlag & 1)) {
      if (!(inputTagFlag & 14)) {
        if (inputTagFlag & 1024) {
          input = inputToString(b, input);
        } else {
          isUnsupported = true;
        }
      }
    } else if (isSchemaLiteral) {
      if (isFromLiteral) {
        if (input.const !== schema4.const) {
          input = constVal(b, schema4);
        }
      } else if (inputTagFlag & 2 && schemaTagFlag & 3132) {
        let inputVar = input.v(b);
        b.f = schema4.noValidation ? "" : input.i + `==="` + schema4.const + `"||` + failWithArg(b, path, (input2) => ({
          TAG: "InvalidType",
          expected: schema4,
          received: input2
        }), inputVar) + `;`;
        input = constVal(b, schema4);
      } else if (schema4.noValidation) {
        input = constVal(b, schema4);
      } else {
        b.f = typeFilterCode(prevB, schema4, input, path);
        input.type = schema4.type;
        input.const = schema4.const;
      }
    } else if (isFromLiteral && !isSchemaLiteral) {
      if (!isSameTag) {
        if (schemaTagFlag & 2 && inputTagFlag & 3132) {
          let $$const = "" + input.const;
          input = {
            b,
            v: _notVar,
            i: `"` + $$const + `"`,
            f: 0,
            type: "string",
            const: $$const
          };
        } else {
          isUnsupported = true;
        }
      }
    } else if (inputTagFlag & 1) {
      let ref = schema4.$ref;
      if (ref !== void 0) {
        let defs = b.g.d;
        let identifier = ref.slice(8);
        let def = defs[identifier];
        let flag = schema4.noValidation ? (b.g.o | 1) ^ 1 : b.g.o;
        let fn = def[flag];
        let recOperation;
        if (fn !== void 0) {
          let fn$1 = valFromOption(fn);
          recOperation = fn$1 === 0 ? embed(b, def) + (`[` + flag + `]`) : embed(b, fn$1);
        } else {
          def[flag] = 0;
          let fn$2 = internalCompile(def, flag, b.g.d);
          def[flag] = fn$2;
          recOperation = embed(b, fn$2);
        }
        input = withPathPrepend(b, input, path, void 0, void 0, (param, input2, param$1) => {
          let output = map3(recOperation, input2);
          if (def.isAsync === void 0) {
            let defsMut = copy(defs);
            defsMut[identifier] = unknown;
            isAsyncInternal(def, defsMut);
          }
          if (def.isAsync) {
            output.f = output.f | 2;
          }
          return output;
        });
        input.v(b);
      } else {
        if (b.g.o & 1) {
          b.f = typeFilterCode(prevB, schema4, input, path);
        }
        let refined = makeRefinedOf(b, input, schema4);
        input.type = refined.type;
        input.i = refined.i;
        input.v = refined.v;
        input.additionalItems = refined.additionalItems;
        input.properties = refined.properties;
        if (constField in refined) {
          input.const = refined.const;
        }
      }
    } else if (schemaTagFlag & 2 && inputTagFlag & 1036) {
      input = inputToString(b, input);
    } else if (!isSameTag) {
      if (inputTagFlag & 2) {
        let inputVar$1 = input.v(b);
        if (schemaTagFlag & 8) {
          let output = allocateVal(b, schema4);
          b.c = b.c + (`(` + output.i + `=` + inputVar$1 + `==="true")||` + inputVar$1 + `==="false"||` + failWithArg(b, path, (input2) => ({
            TAG: "InvalidType",
            expected: schema4,
            received: input2
          }), inputVar$1) + `;`);
          input = output;
        } else if (schemaTagFlag & 4) {
          let output$1 = val(b, `+` + inputVar$1, schema4);
          let outputVar = output$1.v(b);
          let match = schema4.format;
          b.c = b.c + (match !== void 0 ? `(` + refinement(b, outputVar, schema4, true).slice(2) + `)` : `Number.isNaN(` + outputVar + `)`) + (`&&` + failWithArg(b, path, (input2) => ({
            TAG: "InvalidType",
            expected: schema4,
            received: input2
          }), inputVar$1) + `;`);
          input = output$1;
        } else if (schemaTagFlag & 1024) {
          let output$2 = allocateVal(b, schema4);
          b.c = b.c + (`try{` + output$2.i + `=BigInt(` + inputVar$1 + `)}catch(_){` + failWithArg(b, path, (input2) => ({
            TAG: "InvalidType",
            expected: schema4,
            received: input2
          }), inputVar$1) + `}`);
          input = output$2;
        } else {
          isUnsupported = true;
        }
      } else if (inputTagFlag & 4 && schemaTagFlag & 1024) {
        input = val(b, `BigInt(` + input.i + `)`, schema4);
      } else {
        isUnsupported = true;
      }
    }
  }
  if (isUnsupported) {
    unsupportedTransform(b, input, schema4, path);
  }
  let compiler2 = schema4.compiler;
  if (compiler2 !== void 0) {
    input = compiler2(b, input, schema4, path);
  }
  if (input.t !== true) {
    let refiner = schema4.refiner;
    if (refiner !== void 0) {
      b.c = b.c + refiner(b, input.v(b), schema4, path);
    }
  }
  let to2 = schema4.to;
  if (to2 !== void 0) {
    let parser2 = schema4.parser;
    if (parser2 !== void 0) {
      input = parser2(b, input, schema4, path);
    }
    if (input.t !== true) {
      input = parse(b, to2, input, path);
    }
  }
  prevB.c = prevB.c + allocateScope(b);
  return input;
}
function isAsyncInternal(schema4, defs) {
  try {
    let b = rootScope(2, defs);
    let input = {
      b,
      v: _var,
      i: "i",
      f: 0,
      type: "unknown"
    };
    let output = parse(b, schema4, input, "");
    let isAsync2 = has(output.f, 2);
    schema4.isAsync = isAsync2;
    return isAsync2;
  } catch (exn) {
    getOrRethrow(exn);
    return false;
  }
}
function internalCompile(schema4, flag, defs) {
  let b = rootScope(flag, defs);
  if (flag & 8) {
    let output = reverse(schema4);
    jsonableValidation(output, output, "", flag);
  }
  let input = {
    b,
    v: _var,
    i: "i",
    f: 0,
    type: "unknown"
  };
  let schema$12 = flag & 4 ? updateOutput(schema4, (mut) => {
    let t = new Schema(unit.type);
    t.const = unit.const;
    t.noValidation = true;
    mut.to = t;
  }) : flag & 16 ? updateOutput(schema4, (mut) => {
    mut.to = jsonString;
  }) : schema4;
  let output$1 = parse(b, schema$12, input, "");
  let code2 = allocateScope(b);
  let isAsync2 = has(output$1.f, 2);
  schema$12.isAsync = isAsync2;
  if (code2 === "" && output$1 === input && !(flag & 2)) {
    return noopOperation;
  }
  let inlinedOutput = output$1.i;
  if (flag & 2 && !isAsync2 && !defs) {
    inlinedOutput = `Promise.resolve(` + inlinedOutput + `)`;
  }
  let inlinedFunction = `i=>{` + code2 + `return ` + inlinedOutput + `}`;
  let ctxVarValue1 = b.g.e;
  return new Function("e", "s", `return ` + inlinedFunction)(ctxVarValue1, s);
}
function reverse(schema4) {
  let reversedHead;
  let current = schema4;
  while (current) {
    let mut = copyWithoutCache(current);
    let next = mut.to;
    let to2 = reversedHead;
    if (to2 !== void 0) {
      mut.to = to2;
    } else {
      delete mut.to;
    }
    let parser2 = mut.parser;
    let serializer = mut.serializer;
    if (serializer !== void 0) {
      mut.parser = serializer;
    } else {
      delete mut.parser;
    }
    if (parser2 !== void 0) {
      mut.serializer = parser2;
    } else {
      delete mut.serializer;
    }
    let fromDefault = mut.fromDefault;
    let $$default = mut.default;
    if ($$default !== void 0) {
      mut.fromDefault = $$default;
    } else {
      delete mut.fromDefault;
    }
    if (fromDefault !== void 0) {
      mut.default = fromDefault;
    } else {
      delete mut.default;
    }
    let items = mut.items;
    if (items !== void 0) {
      let properties = {};
      let newItems = new Array(items.length);
      for (let idx = 0, idx_finish = items.length; idx < idx_finish; ++idx) {
        let item = items[idx];
        let reversed_schema = reverse(item.schema);
        let reversed_location = item.location;
        let reversed = {
          schema: reversed_schema,
          location: reversed_location
        };
        if (item.r) {
          reversed.r = item.r;
        }
        properties[item.location] = reversed_schema;
        newItems[idx] = reversed;
      }
      mut.items = newItems;
      let match = mut.properties;
      if (match !== void 0) {
        mut.properties = properties;
      }
    }
    if (typeof mut.additionalItems === "object") {
      mut.additionalItems = reverse(mut.additionalItems);
    }
    let anyOf = mut.anyOf;
    if (anyOf !== void 0) {
      let has2 = {};
      let newAnyOf = [];
      for (let idx$1 = 0, idx_finish$1 = anyOf.length; idx$1 < idx_finish$1; ++idx$1) {
        let s2 = anyOf[idx$1];
        let reversed$1 = reverse(s2);
        newAnyOf.push(reversed$1);
        setHas(has2, reversed$1.type);
      }
      mut.has = has2;
      mut.anyOf = newAnyOf;
    }
    let defs = mut.$defs;
    if (defs !== void 0) {
      let reversedDefs = {};
      for (let idx$2 = 0, idx_finish$2 = Object.keys(defs).length; idx$2 < idx_finish$2; ++idx$2) {
        let key = Object.keys(defs)[idx$2];
        reversedDefs[key] = reverse(defs[key]);
      }
      mut.$defs = reversedDefs;
    }
    reversedHead = mut;
    current = next;
  }
  ;
  return reversedHead;
}
function jsonableValidation(output, parent, path, flag) {
  let tagFlag = flags[output.type];
  if (tagFlag & 48129 || tagFlag & 16 && parent.type !== "object") {
    throw new SuryError({
      TAG: "InvalidJsonSchema",
      _0: parent
    }, flag, path);
  }
  if (tagFlag & 256) {
    output.anyOf.forEach((s2) => jsonableValidation(s2, parent, path, flag));
    return;
  }
  if (!(tagFlag & 192)) {
    return;
  }
  let additionalItems = output.additionalItems;
  if (additionalItems === "strip" || additionalItems === "strict") {
    additionalItems === "strip";
  } else {
    jsonableValidation(additionalItems, parent, path, flag);
  }
  let p2 = output.properties;
  if (p2 !== void 0) {
    let keys = Object.keys(p2);
    for (let idx = 0, idx_finish = keys.length; idx < idx_finish; ++idx) {
      let key = keys[idx];
      jsonableValidation(p2[key], parent, path, flag);
    }
    return;
  }
  output.items.forEach((item) => jsonableValidation(item.schema, output, path + (`[` + fromString(item.location) + `]`), flag));
}
function getOutputSchema(_schema) {
  while (true) {
    let schema4 = _schema;
    let to2 = schema4.to;
    if (to2 === void 0) {
      return schema4;
    }
    _schema = to2;
    continue;
  }
  ;
}
function operationFn(s2, o) {
  if (o in s2) {
    return s2[o];
  }
  let f = internalCompile(o & 32 ? reverse(s2) : s2, o, 0);
  s2[o] = f;
  return f;
}
d(sp, "~standard", {
  get: function() {
    let schema4 = this;
    return {
      version: 1,
      vendor,
      validate: (input) => {
        try {
          return {
            value: operationFn(schema4, 1)(input)
          };
        } catch (exn) {
          let error2 = getOrRethrow(exn);
          return {
            issues: [{
              message: reason(error2, void 0),
              path: error2.path === "" ? void 0 : toArray2(error2.path)
            }]
          };
        }
      }
    };
  }
});
function parseOrThrow(any, schema4) {
  return operationFn(schema4, 1)(any);
}
function reverseConvertToJsonOrThrow(value, schema4) {
  return operationFn(schema4, 40)(value);
}
var $$null = new Schema("null");
$$null.const = null;
function parse$1(value) {
  if (value === null) {
    return $$null;
  }
  let $$typeof = typeof value;
  let schema4;
  if ($$typeof === "object") {
    let i = new Schema("instance");
    i.class = value.constructor;
    schema4 = i;
  } else {
    schema4 = $$typeof === "undefined" ? unit : $$typeof === "number" ? Number.isNaN(value) ? new Schema("nan") : new Schema($$typeof) : new Schema($$typeof);
  }
  schema4.const = value;
  return schema4;
}
var defsPath = `#/$defs/`;
function appendRefiner(maybeExistingRefiner, refiner) {
  if (maybeExistingRefiner !== void 0) {
    return (b, inputVar, selfSchema, path) => maybeExistingRefiner(b, inputVar, selfSchema, path) + refiner(b, inputVar, selfSchema, path);
  } else {
    return refiner;
  }
}
var nullAsUnit = new Schema("null");
nullAsUnit.const = null;
nullAsUnit.to = unit;
function neverBuilder(b, input, selfSchema, path) {
  b.c = b.c + failWithArg(b, path, (input2) => ({
    TAG: "InvalidType",
    expected: selfSchema,
    received: input2
  }), input.i) + ";";
  return input;
}
var never = new Schema("never");
never.compiler = neverBuilder;
var nestedLoc = "BS_PRIVATE_NESTED_SOME_NONE";
function getItemCode(b, schema4, input, output, deopt, path) {
  try {
    let globalFlag = b.g.o;
    if (deopt) {
      b.g.o = globalFlag | 1;
    }
    let bb = {
      c: "",
      l: "",
      a: initialAllocate,
      f: "",
      g: b.g
    };
    let input$1 = deopt ? copy(input) : makeRefinedOf(bb, input, schema4);
    let itemOutput = parse(bb, schema4, input$1, path);
    if (itemOutput !== input$1) {
      itemOutput.b = bb;
      if (itemOutput.f & 2) {
        output.f = output.f | 2;
      }
      bb.c = bb.c + (output.v(b) + `=` + itemOutput.i);
    }
    b.g.o = globalFlag;
    return allocateScope(bb);
  } catch (exn) {
    return "throw " + embed(b, getOrRethrow(exn));
  }
}
function isPriority(tagFlag, byKey) {
  if (tagFlag & 8320 && "object" in byKey) {
    return true;
  } else if (tagFlag & 2048) {
    return "number" in byKey;
  } else {
    return false;
  }
}
function isWiderUnionSchema(schemaAnyOf, inputAnyOf) {
  return inputAnyOf.every((inputSchema2, idx) => {
    let schema4 = schemaAnyOf[idx];
    if (schema4 !== void 0 && !(flags[inputSchema2.type] & 9152) && inputSchema2.type === schema4.type) {
      return inputSchema2.const === schema4.const;
    } else {
      return false;
    }
  });
}
function compiler(b, input, selfSchema, path) {
  let schemas = selfSchema.anyOf;
  let inputAnyOf = input.anyOf;
  if (inputAnyOf !== void 0) {
    if (isWiderUnionSchema(schemas, inputAnyOf)) {
      return input;
    } else {
      return unsupportedTransform(b, input, selfSchema, path);
    }
  }
  let fail = (caught2) => embed(b, function() {
    let args = arguments;
    return $$throw(b, {
      TAG: "InvalidType",
      expected: selfSchema,
      received: args[0],
      unionErrors: args.length > 1 ? Array.from(args).slice(1) : void 0
    }, path);
  }) + `(` + input.v(b) + caught2 + `)`;
  let typeValidation = b.g.o & 1;
  let initialInline = input.i;
  let deoptIdx = -1;
  let lastIdx = schemas.length - 1 | 0;
  let byKey = {};
  let keys = [];
  for (let idx = 0; idx <= lastIdx; ++idx) {
    let target = selfSchema.to;
    let schema4 = target !== void 0 && !selfSchema.parser && target.type !== "union" ? updateOutput(schemas[idx], (mut) => {
      let refiner = selfSchema.refiner;
      if (refiner !== void 0) {
        mut.refiner = appendRefiner(mut.refiner, refiner);
      }
      mut.to = target;
    }) : schemas[idx];
    let tag = schema4.type;
    let tagFlag = flags[tag];
    if (!(tagFlag & 16 && "fromDefault" in selfSchema)) {
      if (tagFlag & 17153 || !(flags[input.type] & 1) && input.type !== tag) {
        deoptIdx = idx;
        byKey = {};
        keys = [];
      } else {
        let key = tagFlag & 8192 ? schema4.class.name : tag;
        let arr = byKey[key];
        if (arr !== void 0) {
          if (tagFlag & 64 && nestedLoc in schema4.properties) {
            arr.unshift(schema4);
          } else if (!(tagFlag & 2096)) {
            arr.push(schema4);
          }
        } else {
          if (isPriority(tagFlag, byKey)) {
            keys.unshift(key);
          } else {
            keys.push(key);
          }
          byKey[key] = [schema4];
        }
      }
    }
  }
  let deoptIdx$1 = deoptIdx;
  let byKey$1 = byKey;
  let keys$1 = keys;
  let start = "";
  let end = "";
  let caught = "";
  let exit = false;
  if (deoptIdx$1 !== -1) {
    for (let idx$1 = 0; idx$1 <= deoptIdx$1; ++idx$1) {
      if (!exit) {
        let schema$12 = schemas[idx$1];
        let itemCode = getItemCode(b, schema$12, input, input, true, path);
        if (itemCode) {
          let errorVar = `e` + idx$1;
          start = start + (`try{` + itemCode + `}catch(` + errorVar + `){`);
          end = "}" + end;
          caught = caught + `,` + errorVar;
        } else {
          exit = true;
        }
      }
    }
  }
  if (!exit) {
    let nextElse = false;
    let noop = "";
    for (let idx$2 = 0, idx_finish = keys$1.length; idx$2 < idx_finish; ++idx$2) {
      let schemas$1 = byKey$1[keys$1[idx$2]];
      let isMultiple = schemas$1.length > 1;
      let firstSchema = schemas$1[0];
      let cond = 0;
      let body;
      if (isMultiple) {
        let inputVar = input.v(b);
        let itemStart = "";
        let itemEnd = "";
        let itemNextElse = false;
        let itemNoop = {
          contents: ""
        };
        let caught$1 = "";
        let byDiscriminant = {};
        let itemIdx = 0;
        let lastIdx$1 = schemas$1.length - 1 | 0;
        while (itemIdx <= lastIdx$1) {
          let schema$22 = schemas$1[itemIdx];
          let itemCond = (constField in schema$22 ? validation(b, inputVar, schema$22, false) : "") + refinement(b, inputVar, schema$22, false).slice(2);
          let itemCode$1 = getItemCode(b, schema$22, input, input, false, path);
          if (itemCond) {
            if (itemCode$1) {
              let match = byDiscriminant[itemCond];
              if (match !== void 0) {
                if (typeof match === "string") {
                  byDiscriminant[itemCond] = [
                    match,
                    itemCode$1
                  ];
                } else {
                  match.push(itemCode$1);
                }
              } else {
                byDiscriminant[itemCond] = itemCode$1;
              }
            } else {
              itemNoop.contents = itemNoop.contents ? itemNoop.contents + `||` + itemCond : itemCond;
            }
          }
          if (!itemCond || itemIdx === lastIdx$1) {
            let accedDiscriminants = Object.keys(byDiscriminant);
            for (let idx$3 = 0, idx_finish$1 = accedDiscriminants.length; idx$3 < idx_finish$1; ++idx$3) {
              let discrim = accedDiscriminants[idx$3];
              let if_ = itemNextElse ? "else if" : "if";
              itemStart = itemStart + if_ + (`(` + discrim + `){`);
              let code2 = byDiscriminant[discrim];
              if (typeof code2 === "string") {
                itemStart = itemStart + code2 + "}";
              } else {
                let caught$2 = "";
                for (let idx$4 = 0, idx_finish$2 = code2.length; idx$4 < idx_finish$2; ++idx$4) {
                  let code$1 = code2[idx$4];
                  let errorVar$1 = `e` + idx$4;
                  itemStart = itemStart + (`try{` + code$1 + `}catch(` + errorVar$1 + `){`);
                  caught$2 = caught$2 + `,` + errorVar$1;
                }
                itemStart = itemStart + fail(caught$2) + "}".repeat(code2.length) + "}";
              }
              itemNextElse = true;
            }
            byDiscriminant = {};
          }
          if (!itemCond) {
            if (itemCode$1) {
              if (itemNoop.contents) {
                let if_$1 = itemNextElse ? "else if" : "if";
                itemStart = itemStart + if_$1 + (`(!(` + itemNoop.contents + `)){`);
                itemEnd = "}" + itemEnd;
                itemNoop.contents = "";
                itemNextElse = false;
              }
              let errorVar$2 = `e` + itemIdx;
              itemStart = itemStart + ((itemNextElse ? "else{" : "") + `try{` + itemCode$1 + `}catch(` + errorVar$2 + `){`);
              itemEnd = (itemNextElse ? "}" : "") + "}" + itemEnd;
              caught$1 = caught$1 + `,` + errorVar$2;
              itemNextElse = false;
            } else {
              itemNoop.contents = "";
              itemIdx = lastIdx$1;
            }
          }
          itemIdx = itemIdx + 1;
        }
        ;
        cond = (inputVar2) => validation(b, inputVar2, {
          type: firstSchema.type,
          parser: 0
        }, false);
        if (itemNoop.contents) {
          if (itemStart) {
            if (typeValidation) {
              let if_$2 = itemNextElse ? "else if" : "if";
              itemStart = itemStart + if_$2 + (`(!(` + itemNoop.contents + `)){` + fail(caught$1) + `}`);
            }
          } else {
            let condBefore = cond;
            cond = (inputVar2) => condBefore(inputVar2) + (`&&(` + itemNoop.contents + `)`);
          }
        } else if (typeValidation && itemStart) {
          let errorCode = fail(caught$1);
          itemStart = itemStart + (itemNextElse ? `else{` + errorCode + `}` : errorCode);
        }
        body = itemStart + itemEnd;
      } else {
        cond = (inputVar) => validation(b, inputVar, firstSchema, false) + refinement(b, inputVar, firstSchema, false);
        body = getItemCode(b, firstSchema, input, input, false, path);
      }
      if (body || isPriority(flags[firstSchema.type], byKey$1)) {
        let if_$3 = nextElse ? "else if" : "if";
        start = start + if_$3 + (`(` + cond(input.v(b)) + `){` + body + `}`);
        nextElse = true;
      } else if (typeValidation) {
        let cond$1 = cond(input.v(b));
        noop = noop ? noop + `||` + cond$1 : cond$1;
      }
    }
    if (typeValidation || deoptIdx$1 === lastIdx) {
      let errorCode$1 = fail(caught);
      let tmp;
      if (noop) {
        let if_$4 = nextElse ? "else if" : "if";
        tmp = if_$4 + (`(!(` + noop + `)){` + errorCode$1 + `}`);
      } else {
        tmp = nextElse ? `else{` + errorCode$1 + `}` : errorCode$1;
      }
      start = start + tmp;
    }
  }
  b.c = b.c + start + end;
  let o = input.f & 2 ? asyncVal(b, `Promise.resolve(` + input.i + `)`) : input.v === _var ? b.c === "" && input.b.c === "" && (input.b.l === input.i + `=` + initialInline || initialInline === "i") ? (input.b.l = "", input.b.a = initialAllocate, input.v = _notVar, input.i = initialInline, input) : copy(input) : input;
  o.anyOf = selfSchema.anyOf;
  let to2 = selfSchema.to;
  o.type = to2 !== void 0 && to2.type !== "union" ? (o.t = true, getOutputSchema(to2).type) : "union";
  return o;
}
function factory(schemas) {
  let len = schemas.length;
  if (len === 1) {
    return schemas[0];
  }
  if (len !== 0) {
    let has2 = {};
    let anyOf = /* @__PURE__ */ new Set();
    for (let idx = 0, idx_finish = schemas.length; idx < idx_finish; ++idx) {
      let schema4 = schemas[idx];
      if (schema4.type === "union" && schema4.to === void 0) {
        schema4.anyOf.forEach((item) => {
          anyOf.add(item);
        });
        Object.assign(has2, schema4.has);
      } else {
        anyOf.add(schema4);
        setHas(has2, schema4.type);
      }
    }
    let mut = new Schema("union");
    mut.anyOf = Array.from(anyOf);
    mut.compiler = compiler;
    mut.has = has2;
    return mut;
  }
  throw new Error(`[Sury] S.union requires at least one item`);
}
function nestedNone() {
  let itemSchema = parse$1(0);
  let item = {
    schema: itemSchema,
    location: nestedLoc
  };
  let properties = {};
  properties[nestedLoc] = itemSchema;
  return {
    type: "object",
    serializer: (b, param, selfSchema, param$1) => constVal(b, selfSchema.to),
    additionalItems: "strip",
    items: [item],
    properties
  };
}
function parser(b, param, selfSchema, param$1) {
  return val(b, `{` + nestedLoc + `:` + getOutputSchema(selfSchema).items[0].schema.const + `}`, selfSchema.to);
}
function nestedOption(item) {
  return updateOutput(item, (mut) => {
    mut.to = nestedNone();
    mut.parser = parser;
  });
}
function factory$1(item, unitOpt) {
  let unit$1 = unitOpt !== void 0 ? unitOpt : unit;
  let match = getOutputSchema(item);
  let match$1 = match.type;
  switch (match$1) {
    case "undefined":
      return factory([
        unit$1,
        nestedOption(item)
      ]);
    case "union":
      let has2 = match.has;
      let anyOf = match.anyOf;
      return updateOutput(item, (mut) => {
        let mutHas = copy(has2);
        let newAnyOf = [];
        for (let idx = 0, idx_finish = anyOf.length; idx < idx_finish; ++idx) {
          let schema4 = anyOf[idx];
          let match2 = getOutputSchema(schema4);
          let match$12 = match2.type;
          let tmp;
          if (match$12 === "undefined") {
            mutHas[unit$1.type] = true;
            newAnyOf.push(unit$1);
            tmp = nestedOption(schema4);
          } else {
            let properties = match2.properties;
            if (properties !== void 0) {
              let nestedSchema = properties[nestedLoc];
              tmp = nestedSchema !== void 0 ? updateOutput(schema4, (mut2) => {
                let newItem_schema = {
                  type: nestedSchema.type,
                  parser: nestedSchema.parser,
                  const: nestedSchema.const + 1
                };
                let newItem = {
                  schema: newItem_schema,
                  location: nestedLoc
                };
                let properties2 = {};
                properties2[nestedLoc] = newItem_schema;
                mut2.items = [newItem];
                mut2.properties = properties2;
              }) : schema4;
            } else {
              tmp = schema4;
            }
          }
          newAnyOf.push(tmp);
        }
        if (newAnyOf.length === anyOf.length) {
          mutHas[unit$1.type] = true;
          newAnyOf.push(unit$1);
        }
        mut.anyOf = newAnyOf;
        mut.has = mutHas;
      });
    default:
      return factory([
        item,
        unit$1
      ]);
  }
}
function getWithDefault(schema4, $$default) {
  return updateOutput(schema4, (mut) => {
    let anyOf = mut.anyOf;
    if (anyOf !== void 0) {
      let item;
      let itemOutputSchema;
      for (let idx = 0, idx_finish = anyOf.length; idx < idx_finish; ++idx) {
        let schema5 = anyOf[idx];
        let outputSchema2 = getOutputSchema(schema5);
        let match = outputSchema2.type;
        if (match !== "undefined") {
          let match$1 = item;
          if (match$1 !== void 0) {
            let message4 = `Can't set default for ` + toExpression(mut);
            throw new Error(`[Sury] ` + message4);
          }
          item = schema5;
          itemOutputSchema = outputSchema2;
        }
      }
      let s2 = item;
      let item$1;
      if (s2 !== void 0) {
        item$1 = s2;
      } else {
        let message$1 = `Can't set default for ` + toExpression(mut);
        throw new Error(`[Sury] ` + message$1);
      }
      mut.parser = (b, input, selfSchema, param) => {
        let operation = (b2, input2) => {
          let inputVar = input2.v(b2);
          let tmp;
          tmp = $$default.TAG === "Value" ? inlineConst(b2, parse$1($$default._0)) : embed(b2, $$default._0) + `()`;
          return val(b2, inputVar + `===void 0?` + tmp + `:` + inputVar, selfSchema.to);
        };
        if (!(input.f & 2)) {
          return operation(b, input);
        }
        let bb = {
          c: "",
          l: "",
          a: initialAllocate,
          f: "",
          g: b.g
        };
        let operationInput = {
          b,
          v: _var,
          i: varWithoutAllocation(bb.g),
          f: 0,
          type: "unknown"
        };
        let operationOutputVal = operation(bb, operationInput);
        let operationCode = allocateScope(bb);
        return asyncVal(input.b, input.i + `.then(` + operationInput.v(b) + `=>{` + operationCode + `return ` + operationOutputVal.i + `})`);
      };
      let to2 = copyWithoutCache(itemOutputSchema);
      let compiler2 = to2.compiler;
      if (compiler2 !== void 0) {
        to2.serializer = compiler2;
        delete to2.compiler;
      } else {
        to2.serializer = (_b, input, param, param$1) => input;
      }
      mut.to = to2;
      if ($$default.TAG !== "Value") {
        return;
      }
      try {
        mut.default = operationFn(item$1, 32)($$default._0);
        return;
      } catch (exn) {
        return;
      }
    } else {
      let message$2 = `Can't set default for ` + toExpression(mut);
      throw new Error(`[Sury] ` + message$2);
    }
  });
}
var metadataId = `m:Array.refinements`;
function refinements(schema4) {
  let m = schema4[metadataId];
  if (m !== void 0) {
    return m;
  } else {
    return [];
  }
}
function arrayCompiler(b, input, selfSchema, path) {
  let item = selfSchema.additionalItems;
  let inputVar = input.v(b);
  let iteratorVar = varWithoutAllocation(b.g);
  let bb = {
    c: "",
    l: "",
    a: initialAllocate,
    f: "",
    g: b.g
  };
  let itemInput = val(bb, inputVar + `[` + iteratorVar + `]`, unknown);
  let itemOutput = withPathPrepend(bb, itemInput, path, iteratorVar, void 0, (b2, input2, path2) => parse(b2, item, input2, path2));
  let itemCode = allocateScope(bb);
  let isTransformed = itemInput !== itemOutput;
  let output = isTransformed ? val(b, `new Array(` + inputVar + `.length)`, selfSchema) : input;
  output.type = selfSchema.type;
  output.additionalItems = selfSchema.additionalItems;
  if (isTransformed || itemCode !== "") {
    b.c = b.c + (`for(let ` + iteratorVar + `=0;` + iteratorVar + `<` + inputVar + `.length;++` + iteratorVar + `){` + itemCode + (isTransformed ? addKey(b, output, iteratorVar, itemOutput) : "") + `}`);
  }
  if (itemOutput.f & 2) {
    return asyncVal(output.b, `Promise.all(` + output.i + `)`);
  } else {
    return output;
  }
}
function factory$2(item) {
  let mut = new Schema("array");
  mut.additionalItems = item;
  mut.items = immutableEmpty$1;
  mut.compiler = arrayCompiler;
  return mut;
}
function dictCompiler(b, input, selfSchema, path) {
  let item = selfSchema.additionalItems;
  let inputVar = input.v(b);
  let keyVar = varWithoutAllocation(b.g);
  let bb = {
    c: "",
    l: "",
    a: initialAllocate,
    f: "",
    g: b.g
  };
  let itemInput = val(bb, inputVar + `[` + keyVar + `]`, unknown);
  let itemOutput = withPathPrepend(bb, itemInput, path, keyVar, void 0, (b2, input2, path2) => parse(b2, item, input2, path2));
  let itemCode = allocateScope(bb);
  let isTransformed = itemInput !== itemOutput;
  let output = isTransformed ? val(b, "{}", selfSchema) : input;
  output.type = selfSchema.type;
  output.additionalItems = selfSchema.additionalItems;
  if (isTransformed || itemCode !== "") {
    b.c = b.c + (`for(let ` + keyVar + ` in ` + inputVar + `){` + itemCode + (isTransformed ? addKey(b, output, keyVar, itemOutput) : "") + `}`);
  }
  if (!(itemOutput.f & 2)) {
    return output;
  }
  let resolveVar = varWithoutAllocation(b.g);
  let rejectVar = varWithoutAllocation(b.g);
  let asyncParseResultVar = varWithoutAllocation(b.g);
  let counterVar = varWithoutAllocation(b.g);
  let outputVar = output.v(b);
  return asyncVal(b, `new Promise((` + resolveVar + `,` + rejectVar + `)=>{let ` + counterVar + `=Object.keys(` + outputVar + `).length;for(let ` + keyVar + ` in ` + outputVar + `){` + outputVar + `[` + keyVar + `].then(` + asyncParseResultVar + `=>{` + outputVar + `[` + keyVar + `]=` + asyncParseResultVar + `;if(` + counterVar + `--===1){` + resolveVar + `(` + outputVar + `)}},` + rejectVar + `)}})`);
}
function factory$3(item) {
  let mut = new Schema("object");
  mut.properties = immutableEmpty;
  mut.items = immutableEmpty$1;
  mut.additionalItems = item;
  mut.compiler = dictCompiler;
  return mut;
}
var metadataId$1 = `m:String.refinements`;
function refinements$1(schema4) {
  let m = schema4[metadataId$1];
  if (m !== void 0) {
    return m;
  } else {
    return [];
  }
}
var json = shaken("json");
function enableJson() {
  if (!json[shakenRef]) {
    return;
  }
  delete json.as;
  let jsonRef = new Schema("ref");
  jsonRef.$ref = defsPath + jsonName;
  jsonRef.name = jsonName;
  json.type = jsonRef.type;
  json.$ref = jsonRef.$ref;
  json.name = jsonName;
  let defs = {};
  defs[jsonName] = {
    type: "union",
    compiler,
    name: jsonName,
    has: {
      string: true,
      boolean: true,
      number: true,
      null: true,
      object: true,
      array: true
    },
    anyOf: [
      string,
      bool,
      float,
      $$null,
      factory$3(jsonRef),
      factory$2(jsonRef)
    ]
  };
  json.$defs = defs;
}
var metadataId$2 = `m:Int.refinements`;
function refinements$2(schema4) {
  let m = schema4[metadataId$2];
  if (m !== void 0) {
    return m;
  } else {
    return [];
  }
}
var metadataId$3 = `m:Float.refinements`;
function refinements$3(schema4) {
  let m = schema4[metadataId$3];
  if (m !== void 0) {
    return m;
  } else {
    return [];
  }
}
function getFullDitemPath(ditem) {
  switch (ditem.k) {
    case 0:
      return `[` + fromString(ditem.location) + `]`;
    case 1:
      return getFullDitemPath(ditem.of) + ditem.p;
    case 2:
      return ditem.p;
  }
}
function definitionToOutput(b, definition, getItemOutput, outputSchema2) {
  if (constField in outputSchema2) {
    return constVal(b, outputSchema2);
  }
  let item = definition[itemSymbol];
  if (item !== void 0) {
    return getItemOutput(item);
  }
  let isArray = flags[outputSchema2.type] & 128;
  let objectVal = make(b, isArray);
  outputSchema2.items.forEach((item2) => add(objectVal, item2.location, definitionToOutput(b, definition[item2.location], getItemOutput, item2.schema)));
  return complete(objectVal, isArray);
}
function objectStrictModeCheck(b, input, items, selfSchema, path) {
  if (!(selfSchema.type === "object" && selfSchema.additionalItems === "strict" && b.g.o & 1)) {
    return;
  }
  let key = allocateVal(b, unknown);
  let keyVar = key.i;
  b.c = b.c + (`for(` + keyVar + ` in ` + input.v(b) + `){if(`);
  if (items.length !== 0) {
    for (let idx = 0, idx_finish = items.length; idx < idx_finish; ++idx) {
      let match = items[idx];
      if (idx !== 0) {
        b.c = b.c + "&&";
      }
      b.c = b.c + (keyVar + `!==` + inlineLocation(b, match.location));
    }
  } else {
    b.c = b.c + "true";
  }
  b.c = b.c + (`){` + failWithArg(b, path, (exccessFieldName) => ({
    TAG: "ExcessField",
    _0: exccessFieldName
  }), keyVar) + `}}`);
}
function proxify(item) {
  return new Proxy(immutableEmpty, {
    get: (param, prop) => {
      if (prop === itemSymbol) {
        return item;
      }
      let inlinedLocation = fromString(prop);
      let targetReversed = getOutputSchema(item.schema);
      let items = targetReversed.items;
      let properties = targetReversed.properties;
      let maybeField;
      if (properties !== void 0) {
        maybeField = properties[prop];
      } else if (items !== void 0) {
        let i = items[prop];
        maybeField = i !== void 0 ? i.schema : void 0;
      } else {
        maybeField = void 0;
      }
      if (maybeField === void 0) {
        let message4 = `Cannot read property ` + inlinedLocation + ` of ` + toExpression(targetReversed);
        throw new Error(`[Sury] ` + message4);
      }
      return proxify({
        k: 1,
        location: prop,
        schema: maybeField,
        of: item,
        p: `[` + inlinedLocation + `]`
      });
    }
  });
}
function schemaCompiler(b, input, selfSchema, path) {
  let additionalItems = selfSchema.additionalItems;
  let items = selfSchema.items;
  let isArray = flags[selfSchema.type] & 128;
  if (b.g.o & 64) {
    let objectVal = make(b, isArray);
    for (let idx = 0, idx_finish = items.length; idx < idx_finish; ++idx) {
      let match = items[idx];
      let location2 = match.location;
      add(objectVal, location2, input.properties[location2]);
    }
    return complete(objectVal, isArray);
  }
  let objectVal$1 = make(b, isArray);
  for (let idx$1 = 0, idx_finish$1 = items.length; idx$1 < idx_finish$1; ++idx$1) {
    let match$1 = items[idx$1];
    let location$1 = match$1.location;
    let itemInput = get(b, input, location$1);
    let inlinedLocation = inlineLocation(b, location$1);
    let path$1 = path + (`[` + inlinedLocation + `]`);
    add(objectVal$1, location$1, parse(b, match$1.schema, itemInput, path$1));
  }
  objectStrictModeCheck(b, input, items, selfSchema, path);
  if ((additionalItems !== "strip" || b.g.o & 32) && items.every((item) => objectVal$1.properties[item.location] === input.properties[item.location])) {
    input.additionalItems = "strip";
    return input;
  } else {
    return complete(objectVal$1, isArray);
  }
}
function definitionToSchema(definition) {
  if (typeof definition !== "object" || definition === null) {
    return parse$1(definition);
  }
  if (definition["~standard"]) {
    return definition;
  }
  if (Array.isArray(definition)) {
    for (let idx = 0, idx_finish = definition.length; idx < idx_finish; ++idx) {
      let schema4 = definitionToSchema(definition[idx]);
      let location2 = idx.toString();
      definition[idx] = {
        schema: schema4,
        location: location2
      };
    }
    let mut = new Schema("array");
    mut.items = definition;
    mut.additionalItems = "strict";
    mut.compiler = schemaCompiler;
    return mut;
  }
  let cnstr = definition.constructor;
  if (cnstr && cnstr !== Object) {
    return {
      type: "instance",
      const: definition,
      class: cnstr
    };
  }
  let fieldNames = Object.keys(definition);
  let length2 = fieldNames.length;
  let items = [];
  for (let idx$1 = 0; idx$1 < length2; ++idx$1) {
    let location$1 = fieldNames[idx$1];
    let schema$12 = definitionToSchema(definition[location$1]);
    let item = {
      schema: schema$12,
      location: location$1
    };
    definition[location$1] = schema$12;
    items[idx$1] = item;
  }
  let mut$1 = new Schema("object");
  mut$1.items = items;
  mut$1.properties = definition;
  mut$1.additionalItems = globalConfig.a;
  mut$1.compiler = schemaCompiler;
  return mut$1;
}
function nested(fieldName) {
  let parentCtx = this;
  let cacheId = `~` + fieldName;
  let ctx2 = parentCtx[cacheId];
  if (ctx2 !== void 0) {
    return valFromOption(ctx2);
  }
  let schemas = [];
  let properties = {};
  let items = [];
  let schema4 = new Schema("object");
  schema4.items = items;
  schema4.properties = properties;
  schema4.additionalItems = globalConfig.a;
  schema4.compiler = schemaCompiler;
  let target = parentCtx.f(fieldName, schema4)[itemSymbol];
  let field = (fieldName2, schema5) => {
    let inlinedLocation = fromString(fieldName2);
    if (fieldName2 in properties) {
      throw new Error(`[Sury] ` + (`The field ` + inlinedLocation + ` defined twice`));
    }
    let ditem_3 = `[` + inlinedLocation + `]`;
    let ditem = {
      k: 1,
      location: fieldName2,
      schema: schema5,
      of: target,
      p: ditem_3
    };
    properties[fieldName2] = schema5;
    items.push(ditem);
    schemas.push(schema5);
    return proxify(ditem);
  };
  let tag = (tag$1, asValue) => {
    field(tag$1, definitionToSchema(asValue));
  };
  let fieldOr = (fieldName2, schema5, or) => {
    let schema$12 = factory$1(schema5, void 0);
    return field(fieldName2, getWithDefault(schema$12, {
      TAG: "Value",
      _0: or
    }));
  };
  let flatten = (schema5) => {
    let match = schema5.type;
    if (match === "object") {
      let to2 = schema5.to;
      let flattenedItems = schema5.items;
      if (to2) {
        let message4 = `Unsupported nested flatten for transformed object schema ` + toExpression(schema5);
        throw new Error(`[Sury] ` + message4);
      }
      let result2 = {};
      for (let idx = 0, idx_finish = flattenedItems.length; idx < idx_finish; ++idx) {
        let item = flattenedItems[idx];
        result2[item.location] = field(item.location, item.schema);
      }
      return result2;
    }
    let message$1 = `Can't flatten ` + toExpression(schema5) + ` schema`;
    throw new Error(`[Sury] ` + message$1);
  };
  let ctx$1 = {
    field,
    f: field,
    fieldOr,
    tag,
    nested,
    flatten
  };
  parentCtx[cacheId] = ctx$1;
  return ctx$1;
}
function definitionToRitem(definition, path, ritemsByItemPath) {
  if (typeof definition !== "object" || definition === null) {
    return {
      k: 1,
      p: path,
      s: copyWithoutCache(parse$1(definition))
    };
  }
  let item = definition[itemSymbol];
  if (item !== void 0) {
    let ritemSchema = copyWithoutCache(getOutputSchema(item.schema));
    delete ritemSchema.serializer;
    let ritem = {
      k: 0,
      p: path,
      s: ritemSchema
    };
    item.r = ritem;
    ritemsByItemPath[getFullDitemPath(item)] = ritem;
    return ritem;
  }
  if (Array.isArray(definition)) {
    let items = [];
    for (let idx = 0, idx_finish = definition.length; idx < idx_finish; ++idx) {
      let location2 = idx.toString();
      let inlinedLocation = `"` + location2 + `"`;
      let ritem$1 = definitionToRitem(definition[idx], path + (`[` + inlinedLocation + `]`), ritemsByItemPath);
      let item_schema = ritem$1.s;
      let item$1 = {
        schema: item_schema,
        location: location2
      };
      items[idx] = item$1;
    }
    let mut = new Schema("array");
    return {
      k: 2,
      p: path,
      s: (mut.items = items, mut.additionalItems = "strict", mut.serializer = neverBuilder, mut)
    };
  }
  let fieldNames = Object.keys(definition);
  let properties = {};
  let items$1 = [];
  for (let idx$1 = 0, idx_finish$1 = fieldNames.length; idx$1 < idx_finish$1; ++idx$1) {
    let location$1 = fieldNames[idx$1];
    let inlinedLocation$1 = fromString(location$1);
    let ritem$2 = definitionToRitem(definition[location$1], path + (`[` + inlinedLocation$1 + `]`), ritemsByItemPath);
    let item_schema$1 = ritem$2.s;
    let item$2 = {
      schema: item_schema$1,
      location: location$1
    };
    items$1[idx$1] = item$2;
    properties[location$1] = item_schema$1;
  }
  let mut$1 = new Schema("object");
  return {
    k: 2,
    p: path,
    s: (mut$1.items = items$1, mut$1.properties = properties, mut$1.additionalItems = globalConfig.a, mut$1.serializer = neverBuilder, mut$1)
  };
}
function definitionToTarget(definition, to2, flattened) {
  let ritemsByItemPath = {};
  let ritem = definitionToRitem(definition, "", ritemsByItemPath);
  let mut = ritem.s;
  delete mut.refiner;
  delete mut.compiler;
  mut.serializer = (b, input, selfSchema, path) => {
    let getRitemInput = (ritem2) => {
      let ritemPath = ritem2.p;
      if (ritemPath === "") {
        return input;
      }
      let _input = input;
      let _locations = toArray2(ritemPath);
      while (true) {
        let locations = _locations;
        let input$1 = _input;
        if (locations.length === 0) {
          return input$1;
        }
        let location2 = locations[0];
        _locations = locations.slice(1);
        _input = get(b, input$1, location2);
        continue;
      }
      ;
    };
    let schemaToOutput = (schema4, originalPath) => {
      let outputSchema2 = getOutputSchema(schema4);
      if (constField in outputSchema2) {
        return constVal(b, outputSchema2);
      }
      if (constField in schema4) {
        return parse(b, schema4, constVal(b, schema4), path);
      }
      let tag = outputSchema2.type;
      let additionalItems = outputSchema2.additionalItems;
      let items2 = outputSchema2.items;
      if (items2 !== void 0 && typeof additionalItems === "string") {
        let isArray2 = flags[tag] & 128;
        let objectVal2 = make(b, isArray2);
        for (let idx = 0, idx_finish = items2.length; idx < idx_finish; ++idx) {
          let item = items2[idx];
          let inlinedLocation = inlineLocation(b, item.location);
          let itemPath = originalPath + (`[` + inlinedLocation + `]`);
          let ritem2 = ritemsByItemPath[itemPath];
          let itemInput = ritem2 !== void 0 ? parse(b, item.schema, getRitemInput(ritem2), ritem2.p) : schemaToOutput(item.schema, itemPath);
          add(objectVal2, item.location, itemInput);
        }
        return complete(objectVal2, isArray2);
      }
      let tmp = originalPath === "" ? `Schema isn't registered` : `Schema for ` + originalPath + ` isn't registered`;
      return invalidOperation(b, path, tmp);
    };
    let getItemOutput = (item, itemPath, shouldReverse) => {
      let ritem2 = item.r;
      if (ritem2 === void 0) {
        return schemaToOutput(item.schema, itemPath);
      }
      let targetSchema = shouldReverse ? reverse(item.schema) : itemPath === "" ? getOutputSchema(item.schema) : item.schema;
      let itemInput = getRitemInput(ritem2);
      let path$1 = path + ritem2.p;
      return parse(b, targetSchema, itemInput, path$1);
    };
    if (to2 !== void 0) {
      return getItemOutput(to2, "", false);
    }
    let originalSchema = selfSchema.to;
    objectStrictModeCheck(b, input, selfSchema.items, selfSchema, path);
    let isArray = originalSchema.type === "array";
    let items = originalSchema.items;
    let objectVal = make(b, isArray);
    if (flattened !== void 0) {
      for (let idx = 0, idx_finish = flattened.length; idx < idx_finish; ++idx) {
        merge(objectVal, getItemOutput(flattened[idx], "", true));
      }
    }
    for (let idx$1 = 0, idx_finish$1 = items.length; idx$1 < idx_finish$1; ++idx$1) {
      let item = items[idx$1];
      if (!(item.location in objectVal.properties)) {
        let inlinedLocation = inlineLocation(b, item.location);
        add(objectVal, item.location, getItemOutput(item, `[` + inlinedLocation + `]`, false));
      }
    }
    return complete(objectVal, isArray);
  };
  return mut;
}
function advancedBuilder(definition, flattened) {
  return (b, input, selfSchema, path) => {
    let isFlatten = b.g.o & 64;
    let outputs = isFlatten ? input.properties : {};
    if (!isFlatten) {
      let items = selfSchema.items;
      for (let idx = 0, idx_finish = items.length; idx < idx_finish; ++idx) {
        let match = items[idx];
        let location2 = match.location;
        let itemInput = get(b, input, location2);
        let inlinedLocation = inlineLocation(b, location2);
        let path$1 = path + (`[` + inlinedLocation + `]`);
        outputs[location2] = parse(b, match.schema, itemInput, path$1);
      }
      objectStrictModeCheck(b, input, items, selfSchema, path);
    }
    if (flattened !== void 0) {
      let prevFlag = b.g.o;
      b.g.o = prevFlag | 64;
      for (let idx$1 = 0, idx_finish$1 = flattened.length; idx$1 < idx_finish$1; ++idx$1) {
        let item = flattened[idx$1];
        outputs[item.i] = parse(b, item.schema, input, path);
      }
      b.g.o = prevFlag;
    }
    let getItemOutput = (item) => {
      switch (item.k) {
        case 0:
          return outputs[item.location];
        case 1:
          return get(b, getItemOutput(item.of), item.location);
        case 2:
          return outputs[item.i];
      }
    };
    return definitionToOutput(b, definition, getItemOutput, selfSchema.to);
  };
}
function object(definer) {
  let flattened = void 0;
  let items = [];
  let properties = {};
  let flatten = (schema4) => {
    let match = schema4.type;
    if (match === "object") {
      let flattenedItems = schema4.items;
      for (let idx = 0, idx_finish = flattenedItems.length; idx < idx_finish; ++idx) {
        let match$1 = flattenedItems[idx];
        let location2 = match$1.location;
        let flattenedSchema = match$1.schema;
        let schema$12 = properties[location2];
        if (schema$12 !== void 0) {
          if (schema$12 !== flattenedSchema) {
            throw new Error(`[Sury] ` + (`The field "` + location2 + `" defined twice with incompatible schemas`));
          }
        } else {
          let item = {
            k: 0,
            schema: flattenedSchema,
            location: location2
          };
          items.push(item);
          properties[location2] = flattenedSchema;
        }
      }
      let f = flattened || (flattened = []);
      let item_2 = f.length;
      let item$1 = {
        k: 2,
        schema: schema4,
        p: "",
        i: item_2
      };
      f.push(item$1);
      return proxify(item$1);
    }
    let message4 = `The '` + toExpression(schema4) + `' schema can't be flattened`;
    throw new Error(`[Sury] ` + message4);
  };
  let field = (fieldName, schema4) => {
    if (fieldName in properties) {
      throw new Error(`[Sury] ` + (`The field "` + fieldName + `" defined twice with incompatible schemas`));
    }
    let ditem = {
      k: 0,
      schema: schema4,
      location: fieldName
    };
    properties[fieldName] = schema4;
    items.push(ditem);
    return proxify(ditem);
  };
  let tag = (tag$1, asValue) => {
    field(tag$1, definitionToSchema(asValue));
  };
  let fieldOr = (fieldName, schema4, or) => {
    let schema$12 = factory$1(schema4, void 0);
    return field(fieldName, getWithDefault(schema$12, {
      TAG: "Value",
      _0: or
    }));
  };
  let ctx2 = {
    field,
    f: field,
    fieldOr,
    tag,
    nested,
    flatten
  };
  let definition = definer(ctx2);
  let mut = new Schema("object");
  mut.items = items;
  mut.properties = properties;
  mut.additionalItems = globalConfig.a;
  mut.parser = advancedBuilder(definition, flattened);
  mut.to = definitionToTarget(definition, void 0, flattened);
  return mut;
}
function matches(schema4) {
  return schema4;
}
var ctx = {
  m: matches
};
function factory$4(definer) {
  return definitionToSchema(definer(ctx));
}
var js_schema = definitionToSchema;
function option(item) {
  return factory$1(item, unit);
}
var jsonSchemaMetadataId = `m:JSONSchema`;
function internalToJSONSchema(schema4, defs) {
  let jsonSchema = {};
  switch (schema4.type) {
    case "never":
      jsonSchema.not = {};
      break;
    case "unknown":
      break;
    case "string":
      let $$const = schema4.const;
      jsonSchema.type = "string";
      refinements$1(schema4).forEach((refinement2) => {
        let match = refinement2.kind;
        if (typeof match !== "object") {
          switch (match) {
            case "Email":
              jsonSchema.format = "email";
              return;
            case "Uuid":
              jsonSchema.format = "uuid";
              return;
            case "Cuid":
              return;
            case "Url":
              jsonSchema.format = "uri";
              return;
            case "Datetime":
              jsonSchema.format = "date-time";
              return;
          }
        } else {
          switch (match.TAG) {
            case "Min":
              jsonSchema.minLength = match.length;
              return;
            case "Max":
              jsonSchema.maxLength = match.length;
              return;
            case "Length":
              let length2 = match.length;
              jsonSchema.minLength = length2;
              jsonSchema.maxLength = length2;
              return;
            case "Pattern":
              jsonSchema.pattern = String(match.re);
              return;
          }
        }
      });
      if ($$const !== void 0) {
        jsonSchema.const = $$const;
      }
      break;
    case "number":
      let format = schema4.format;
      let $$const$1 = schema4.const;
      if (format !== void 0) {
        if (format === "int32") {
          jsonSchema.type = "integer";
          refinements$2(schema4).forEach((refinement2) => {
            let match = refinement2.kind;
            if (match.TAG === "Min") {
              jsonSchema.minimum = match.value;
            } else {
              jsonSchema.maximum = match.value;
            }
          });
        } else {
          jsonSchema.type = "integer";
          jsonSchema.maximum = 65535;
          jsonSchema.minimum = 0;
        }
      } else {
        jsonSchema.type = "number";
        refinements$3(schema4).forEach((refinement2) => {
          let match = refinement2.kind;
          if (match.TAG === "Min") {
            jsonSchema.minimum = match.value;
          } else {
            jsonSchema.maximum = match.value;
          }
        });
      }
      if ($$const$1 !== void 0) {
        jsonSchema.const = $$const$1;
      }
      break;
    case "boolean":
      let $$const$2 = schema4.const;
      jsonSchema.type = "boolean";
      if ($$const$2 !== void 0) {
        jsonSchema.const = $$const$2;
      }
      break;
    case "null":
      jsonSchema.type = "null";
      break;
    case "array":
      let additionalItems = schema4.additionalItems;
      let exit = 0;
      if (additionalItems === "strip" || additionalItems === "strict") {
        exit = 1;
      } else {
        jsonSchema.items = internalToJSONSchema(additionalItems, defs);
        jsonSchema.type = "array";
        refinements(schema4).forEach((refinement2) => {
          let match = refinement2.kind;
          switch (match.TAG) {
            case "Min":
              jsonSchema.minItems = match.length;
              return;
            case "Max":
              jsonSchema.maxItems = match.length;
              return;
            case "Length":
              let length2 = match.length;
              jsonSchema.maxItems = length2;
              jsonSchema.minItems = length2;
              return;
          }
        });
      }
      if (exit === 1) {
        let items = schema4.items.map((item) => internalToJSONSchema(item.schema, defs));
        let itemsNumber = items.length;
        jsonSchema.items = some(items);
        jsonSchema.type = "array";
        jsonSchema.minItems = itemsNumber;
        jsonSchema.maxItems = itemsNumber;
      }
      break;
    case "object":
      let additionalItems$1 = schema4.additionalItems;
      let exit$1 = 0;
      if (additionalItems$1 === "strip" || additionalItems$1 === "strict") {
        exit$1 = 1;
      } else {
        jsonSchema.type = "object";
        jsonSchema.additionalProperties = internalToJSONSchema(additionalItems$1, defs);
      }
      if (exit$1 === 1) {
        let properties = {};
        let required = [];
        schema4.items.forEach((item) => {
          let fieldSchema = internalToJSONSchema(item.schema, defs);
          if (!isOptional(item.schema)) {
            required.push(item.location);
          }
          properties[item.location] = fieldSchema;
        });
        jsonSchema.type = "object";
        jsonSchema.properties = properties;
        let tmp;
        tmp = additionalItems$1 === "strip" || additionalItems$1 === "strict" ? additionalItems$1 === "strip" : true;
        jsonSchema.additionalProperties = tmp;
        if (required.length !== 0) {
          jsonSchema.required = required;
        }
      }
      break;
    case "union":
      let literals = [];
      let items$1 = [];
      schema4.anyOf.forEach((childSchema) => {
        if (childSchema.type === "undefined") {
          return;
        }
        items$1.push(internalToJSONSchema(childSchema, defs));
        if (constField in childSchema) {
          literals.push(childSchema.const);
          return;
        }
      });
      let itemsNumber$1 = items$1.length;
      let $$default = schema4.default;
      if ($$default !== void 0) {
        jsonSchema.default = valFromOption($$default);
      }
      if (itemsNumber$1 === 1) {
        Object.assign(jsonSchema, items$1[0]);
      } else if (literals.length === itemsNumber$1) {
        jsonSchema.enum = literals;
      } else {
        jsonSchema.anyOf = items$1;
      }
      break;
    case "ref":
      let ref = schema4.$ref;
      if (ref === defsPath + jsonName) {
      } else {
        jsonSchema.$ref = ref;
      }
      break;
    default:
      throw new Error(`[Sury] Unexpected schema type`);
  }
  let m = schema4.description;
  if (m !== void 0) {
    jsonSchema.description = m;
  }
  let m$1 = schema4.title;
  if (m$1 !== void 0) {
    jsonSchema.title = m$1;
  }
  let deprecated = schema4.deprecated;
  if (deprecated !== void 0) {
    jsonSchema.deprecated = deprecated;
  }
  let examples = schema4.examples;
  if (examples !== void 0) {
    jsonSchema.examples = examples;
  }
  let schemaDefs = schema4.$defs;
  if (schemaDefs !== void 0) {
    Object.assign(defs, schemaDefs);
  }
  let metadataRawSchema = schema4[jsonSchemaMetadataId];
  if (metadataRawSchema !== void 0) {
    Object.assign(jsonSchema, metadataRawSchema);
  }
  return jsonSchema;
}
function toJSONSchema(schema4) {
  jsonableValidation(schema4, schema4, "", 8);
  let defs = {};
  let jsonSchema = internalToJSONSchema(schema4, defs);
  delete defs.JSON;
  let defsKeys = Object.keys(defs);
  if (defsKeys.length) {
    defsKeys.forEach((key) => {
      defs[key] = internalToJSONSchema(defs[key], 0);
    });
    jsonSchema.$defs = defs;
  }
  return jsonSchema;
}
var literal = js_schema;
var array = factory$2;
var dict = factory$3;
var union = factory;
var schema = factory$4;

// ../../../node_modules/sury/src/S.res.mjs
var $$Error2 = $$Error;
var string2 = string;
var bool2 = bool;
var int2 = int;
var json2 = json;
var enableJson2 = enableJson;
var literal2 = literal;
var array2 = array;
var dict2 = dict;
var option2 = option;
var union2 = union;
var parseOrThrow2 = parseOrThrow;
var reverseConvertToJsonOrThrow2 = reverseConvertToJsonOrThrow;
var schema2 = schema;
var object2 = object;
var toJSONSchema2 = toJSONSchema;

// ../../../libs/frontman-client/src/FrontmanClient__JsonRpc.res.mjs
enableJson2();
var version = "2.0";
var errorCodeSchema = union2([
  literal2(-32700),
  literal2(-32600),
  literal2(-32601),
  literal2(-32602),
  literal2(-32603)
]);
var schema3 = schema2((s2) => ({
  code: s2.m(errorCodeSchema),
  message: s2.m(string2),
  data: s2.m(option2(json2))
}));
function make2(code2, message4, data2) {
  return {
    code: code2,
    message: message4,
    data: data2
  };
}
function code(t) {
  return t.code;
}
function message2(t) {
  return t.message;
}
function data(t) {
  return t.data;
}
var RpcError = {
  make: make2,
  code,
  message: message2,
  data,
  schema: schema3
};
var schema$1 = schema2((s2) => ({
  jsonrpc: s2.m(string2),
  id: s2.m(int2),
  method: s2.m(string2),
  params: s2.m(option2(json2))
}));
function make$1(id2, method2, params2) {
  return {
    jsonrpc: version,
    id: id2,
    method: method2,
    params: params2
  };
}
function id(t) {
  return t.id;
}
function method(t) {
  return t.method;
}
function params(t) {
  return t.params;
}
function toJson(t) {
  return reverseConvertToJsonOrThrow2(t, schema$1);
}
var Request = {
  make: make$1,
  id,
  method,
  params,
  toJson,
  schema: schema$1
};
var schema$2 = schema2((s2) => ({
  jsonrpc: s2.m(string2),
  id: s2.m(int2),
  result: s2.m(option2(json2)),
  error: s2.m(option2(schema3))
}));
function makeSuccess(id2, result2) {
  return {
    jsonrpc: version,
    id: id2,
    result: result2,
    error: void 0
  };
}
function makeError(id2, error2) {
  return {
    jsonrpc: version,
    id: id2,
    result: void 0,
    error: some(error2)
  };
}
function id$1(t) {
  return t.id;
}
function result(t) {
  return t.result;
}
function error(t) {
  return t.error;
}
function isSuccess(t) {
  return isSome(t.result);
}
function isError(t) {
  return isSome(t.error);
}
function fromJsonExn(json3) {
  return parseOrThrow2(json3, schema$2);
}
var Response = {
  makeSuccess,
  makeError,
  id: id$1,
  result,
  error,
  isSuccess,
  isError,
  fromJsonExn,
  schema: schema$2
};
var schema$3 = schema2((s2) => ({
  jsonrpc: s2.m(string2),
  method: s2.m(string2),
  params: s2.m(option2(json2))
}));

// ../../../node_modules/@rescript/runtime/lib/es6/Stdlib_Dict.js
function $$delete$1(dict3, string4) {
  delete dict3[string4];
}

// ../../../libs/frontman-client/src/FrontmanClient__ACP__Types.res.mjs
enableJson2();
var implementationSchema = schema2((s2) => ({
  name: s2.m(string2),
  version: s2.m(string2),
  title: s2.m(option2(string2))
}));
var fileSystemCapabilitySchema = schema2((s2) => ({
  readTextFile: s2.m(option2(bool2)),
  writeTextFile: s2.m(option2(bool2))
}));
var clientCapabilitiesSchema = schema2((s2) => ({
  fs: s2.m(option2(fileSystemCapabilitySchema)),
  terminal: s2.m(option2(bool2))
}));
var promptCapabilitiesSchema = schema2((s2) => ({
  image: s2.m(option2(bool2)),
  audio: s2.m(option2(bool2)),
  embeddedContext: s2.m(option2(bool2))
}));
var mcpCapabilitiesSchema = schema2((s2) => ({
  http: s2.m(option2(bool2)),
  sse: s2.m(option2(bool2)),
  websocket: s2.m(option2(bool2))
}));
var agentCapabilitiesSchema = schema2((s2) => ({
  loadSession: s2.m(option2(bool2)),
  mcpCapabilities: s2.m(option2(mcpCapabilitiesSchema)),
  promptCapabilities: s2.m(option2(promptCapabilitiesSchema))
}));
var authMethodSchema = schema2((s2) => ({
  id: s2.m(string2),
  name: s2.m(string2),
  description: s2.m(option2(string2))
}));
var initializeParamsSchema = schema2((s2) => ({
  protocolVersion: s2.m(int2),
  clientCapabilities: s2.m(option2(clientCapabilitiesSchema)),
  clientInfo: s2.m(option2(implementationSchema))
}));
var initializeResultSchema = schema2((s2) => ({
  protocolVersion: s2.m(int2),
  agentCapabilities: s2.m(option2(agentCapabilitiesSchema)),
  agentInfo: s2.m(option2(implementationSchema)),
  authMethods: s2.m(option2(array2(authMethodSchema)))
}));
var sessionNewResultSchema = schema2((s2) => ({
  sessionId: s2.m(string2)
}));
var contentBlockSchema = schema2((s2) => ({
  type: s2.m(string2),
  text: s2.m(option2(string2))
}));
var promptResultSchema = schema2((s2) => ({
  stopReason: s2.m(string2)
}));
var sessionUpdateSchema = schema2((s2) => ({
  sessionUpdate: s2.m(string2),
  content: s2.m(contentBlockSchema)
}));
var sessionUpdateParamsSchema = schema2((s2) => ({
  sessionId: s2.m(string2),
  update: s2.m(sessionUpdateSchema)
}));
var sessionUpdateNotificationSchema = schema2((s2) => ({
  jsonrpc: s2.m(string2),
  method: s2.m(string2),
  params: s2.m(sessionUpdateParamsSchema)
}));
var currentProtocolVersion = 1;

// ../../../libs/frontman-client/src/FrontmanClient__ACP__Client.res.mjs
var initialState_pendingRequests = {};
var initialState = {
  currentId: 0,
  connectionState: "Disconnected",
  pendingRequests: initialState_pendingRequests
};
function reduce(state, action) {
  switch (action.TAG) {
    case "RequestSent":
      let id2 = action._0;
      let newPending = Object.assign({}, state.pendingRequests);
      newPending[id2.toString()] = action._1;
      return {
        currentId: id2,
        connectionState: state.connectionState,
        pendingRequests: newPending
      };
    case "ResponseReceived":
      let newPending$1 = Object.assign({}, state.pendingRequests);
      $$delete$1(newPending$1, action._0.toString());
      return {
        currentId: state.currentId,
        connectionState: state.connectionState,
        pendingRequests: newPending$1
      };
    case "ConnectionStateChanged":
      return {
        currentId: state.currentId,
        connectionState: action._0,
        pendingRequests: state.pendingRequests
      };
  }
}
function handleResponse(state, payload) {
  try {
    let response = Response.fromJsonExn(payload);
    let id2 = Response.id(response);
    let idStr = id2.toString();
    let match = state.pendingRequests[idStr];
    if (match !== void 0) {
      let reject = match.reject;
      let result2 = Response.result(response);
      if (result2 !== void 0) {
        match.resolve(result2);
      } else {
        let err = Response.error(response);
        if (err !== void 0) {
          reject(RpcError.message(valFromOption(err)));
        } else {
          reject("Unknown error");
        }
      }
      return reduce(state, {
        TAG: "ResponseReceived",
        _0: id2
      });
    }
    console.warn(`Received response for unknown request: ` + idStr);
    return state;
  } catch (exn) {
    console.log("Received non-response message:", payload);
    return state;
  }
}
function buildInitializeParams(config) {
  let params_clientCapabilities = config.clientCapabilities;
  let params_clientInfo = config.clientInfo;
  let params2 = {
    protocolVersion: currentProtocolVersion,
    clientCapabilities: params_clientCapabilities,
    clientInfo: params_clientInfo
  };
  return reverseConvertToJsonOrThrow2(params2, initializeParamsSchema);
}
function parseInitializeResult(json3) {
  try {
    return {
      TAG: "Ok",
      _0: parseOrThrow2(json3, initializeResultSchema)
    };
  } catch (raw_e) {
    let e = internalToException(raw_e);
    if (e.RE_EXN_ID === $$Error2) {
      return {
        TAG: "Error",
        _0: e._1.message
      };
    }
    throw e;
  }
}
function parseSessionNewResult(json3) {
  try {
    return {
      TAG: "Ok",
      _0: parseOrThrow2(json3, sessionNewResultSchema)
    };
  } catch (raw_e) {
    let e = internalToException(raw_e);
    if (e.RE_EXN_ID === $$Error2) {
      return {
        TAG: "Error",
        _0: e._1.message
      };
    }
    throw e;
  }
}
function parsePromptResult(json3) {
  try {
    return {
      TAG: "Ok",
      _0: parseOrThrow2(json3, promptResultSchema)
    };
  } catch (raw_e) {
    let e = internalToException(raw_e);
    if (e.RE_EXN_ID === $$Error2) {
      return {
        TAG: "Error",
        _0: e._1.message
      };
    }
    throw e;
  }
}
function parseSessionUpdateNotification(json3) {
  try {
    return {
      TAG: "Ok",
      _0: parseOrThrow2(json3, sessionUpdateNotificationSchema)
    };
  } catch (raw_e) {
    let e = internalToException(raw_e);
    if (e.RE_EXN_ID === $$Error2) {
      return {
        TAG: "Error",
        _0: e._1.message
      };
    }
    throw e;
  }
}
function isInitialized(state) {
  let match = state.connectionState;
  return typeof match === "object";
}
function getConnectionState(state) {
  return state.connectionState;
}

// ../../../libs/frontman-client/src/FrontmanClient__ACP.res.mjs
function makeConfig(endpoint, name3, version2, onMessage) {
  return {
    endpoint,
    clientInfo: {
      name: name3,
      version: version2,
      title: void 0
    },
    clientCapabilities: {
      fs: {
        readTextFile: true,
        writeTextFile: true
      },
      terminal: false
    },
    onMessage
  };
}
function waitForSocket(socket) {
  return new Promise((resolve, param) => {
    socket.onError((param2) => resolve({
      TAG: "Error",
      _0: "Socket connection failed"
    }));
    socket.onOpen(() => resolve({
      TAG: "Ok",
      _0: void 0
    }));
    socket.connect();
  });
}
function joinChannel(channel) {
  return new Promise((resolve, param) => {
    channel.join().receive("ok", (param2) => resolve({
      TAG: "Ok",
      _0: void 0
    })).receive("error", (err) => resolve({
      TAG: "Error",
      _0: `Join failed: ` + JSON.stringify(err)
    }));
  });
}
function sendInitialize(channel, state, clientConfig, onMessage) {
  return new Promise((resolve, param) => {
    let id2 = state.contents.currentId + 1 | 0;
    let params2 = buildInitializeParams(clientConfig);
    let request = Request.make(id2, "initialize", params2);
    let pending_resolve = (json3) => {
      let result2 = parseInitializeResult(json3);
      if (result2.TAG === "Ok") {
        return resolve({
          TAG: "Ok",
          _0: result2._0
        });
      } else {
        return resolve({
          TAG: "Error",
          _0: result2._0
        });
      }
    };
    let pending_reject = (e) => resolve({
      TAG: "Error",
      _0: e
    });
    let pending = {
      resolve: pending_resolve,
      reject: pending_reject
    };
    state.contents = reduce(state.contents, {
      TAG: "RequestSent",
      _0: id2,
      _1: pending
    });
    let payload = Request.toJson(request);
    forEach(onMessage, (cb) => cb("Send", payload));
    channel.push("acp:message", payload);
  });
}
async function connect(config) {
  let socket = new Socket(config.endpoint);
  let channel = socket.channel("sessions");
  let state = {
    contents: initialState
  };
  let clientConfig_clientInfo = config.clientInfo;
  let clientConfig_clientCapabilities = config.clientCapabilities;
  let clientConfig = {
    channel,
    clientInfo: clientConfig_clientInfo,
    clientCapabilities: clientConfig_clientCapabilities
  };
  channel.on("acp:message", (payload) => {
    forEach(config.onMessage, (cb) => cb("Receive", payload));
    state.contents = handleResponse(state.contents, payload);
  });
  let initResult = await flatMapOkAsync(flatMapOkAsync(waitForSocket(socket), () => joinChannel(channel)), () => sendInitialize(channel, state, clientConfig, config.onMessage));
  return map2(initResult, (result2) => {
    state.contents = reduce(state.contents, {
      TAG: "ConnectionStateChanged",
      _0: {
        TAG: "Initialized",
        _0: result2
      }
    });
    return {
      socket,
      channel,
      clientConfig,
      state,
      onMessage: config.onMessage
    };
  });
}
function getState(conn) {
  return getConnectionState(conn.state.contents);
}
function isInitialized2(conn) {
  return isInitialized(conn.state.contents);
}
async function joinSession(conn, sessionId, onUpdate) {
  let sessionChannel = conn.socket.channel(`session:` + sessionId);
  sessionChannel.on("acp:message", (payload) => {
    forEach(conn.onMessage, (cb) => cb("Receive", payload));
    let notification = parseSessionUpdateNotification(payload);
    if (notification.TAG === "Ok") {
      return onUpdate(notification._0.params.update);
    } else {
      conn.state.contents = handleResponse(conn.state.contents, payload);
      return;
    }
  });
  let joinResult = await joinChannel(sessionChannel);
  return map2(joinResult, () => ({
    sessionId,
    channel: sessionChannel,
    connection: conn,
    onUpdate
  }));
}
async function createSession(conn, onUpdate) {
  let sessionNewResult = await new Promise((resolve, param) => {
    let id2 = conn.state.contents.currentId + 1 | 0;
    let request = Request.make(id2, "session/new", {});
    let pending_resolve = (json3) => {
      let result2 = parseSessionNewResult(json3);
      if (result2.TAG === "Ok") {
        return resolve({
          TAG: "Ok",
          _0: result2._0
        });
      } else {
        return resolve({
          TAG: "Error",
          _0: result2._0
        });
      }
    };
    let pending_reject = (e) => resolve({
      TAG: "Error",
      _0: e
    });
    let pending = {
      resolve: pending_resolve,
      reject: pending_reject
    };
    conn.state.contents = reduce(conn.state.contents, {
      TAG: "RequestSent",
      _0: id2,
      _1: pending
    });
    let payload = Request.toJson(request);
    forEach(conn.onMessage, (cb) => cb("Send", payload));
    conn.channel.push("acp:message", payload);
  });
  if (sessionNewResult.TAG === "Ok") {
    return await joinSession(conn, sessionNewResult._0.sessionId, onUpdate);
  } else {
    return {
      TAG: "Error",
      _0: sessionNewResult._0
    };
  }
}
async function sendPrompt(session, text) {
  let id2 = session.connection.state.contents.currentId + 1 | 0;
  let promptParams = Object.fromEntries([
    [
      "sessionId",
      session.sessionId
    ],
    [
      "prompt",
      [Object.fromEntries([
        [
          "type",
          "text"
        ],
        [
          "text",
          text
        ]
      ])]
    ]
  ]);
  let request = Request.make(id2, "session/prompt", promptParams);
  return await new Promise((resolve, param) => {
    let pending_resolve = (json3) => {
      let result2 = parsePromptResult(json3);
      if (result2.TAG === "Ok") {
        return resolve({
          TAG: "Ok",
          _0: result2._0
        });
      } else {
        return resolve({
          TAG: "Error",
          _0: result2._0
        });
      }
    };
    let pending_reject = (e) => resolve({
      TAG: "Error",
      _0: e
    });
    let pending = {
      resolve: pending_resolve,
      reject: pending_reject
    };
    session.connection.state.contents = reduce(session.connection.state.contents, {
      TAG: "RequestSent",
      _0: id2,
      _1: pending
    });
    let payload = Request.toJson(request);
    forEach(session.connection.onMessage, (cb) => cb("Send", payload));
    session.channel.push("acp:message", payload);
  });
}
var Types;
var Client;
var Channel2;
var Socket2;
var JsonRpc;

// ../../../libs/frontman-client/src/FrontmanClient__MCP.res.mjs
var FrontmanClient_MCP_res_exports = {};
__export(FrontmanClient_MCP_res_exports, {
  Channel: () => Channel3,
  JsonRpc: () => JsonRpc2,
  Server: () => Server,
  Types: () => Types4,
  attach: () => attach,
  detach: () => detach,
  handleInitialize: () => handleInitialize,
  handleMessage: () => handleMessage,
  handleToolsCall: () => handleToolsCall,
  handleToolsList: () => handleToolsList,
  hasIdField: () => hasIdField,
  notificationSchema: () => notificationSchema,
  parse: () => parse2,
  requestSchema: () => requestSchema,
  sendError: () => sendError,
  sendResponse: () => sendResponse
});

// ../../../node_modules/@rescript/runtime/lib/es6/Stdlib_JSON.js
function bool3(json3) {
  if (typeof json3 === "boolean") {
    return json3;
  }
}
function $$null2(json3) {
  if (json3 === null) {
    return null;
  }
}
function string3(json3) {
  if (typeof json3 === "string") {
    return json3;
  }
}
function float2(json3) {
  if (typeof json3 === "number") {
    return json3;
  }
}
function object3(json3) {
  if (typeof json3 === "object" && json3 !== null && !Array.isArray(json3)) {
    return json3;
  }
}
function array3(json3) {
  if (Array.isArray(json3)) {
    return json3;
  }
}
var Decode = {
  bool: bool3,
  $$null: $$null2,
  string: string3,
  float: float2,
  object: object3,
  array: array3
};

// ../../../libs/frontman-protocol/src/FrontmanProtocol__MCP.res.mjs
enableJson2();
var capabilitiesSchema = schema2((s2) => ({
  tools: s2.m(option2(dict2(json2))),
  resources: s2.m(option2(dict2(json2))),
  prompts: s2.m(option2(dict2(json2)))
}));
var infoSchema = schema2((s2) => ({
  name: s2.m(string2),
  version: s2.m(string2)
}));
var initializeParamsSchema2 = schema2((s2) => ({
  protocolVersion: s2.m(string2),
  capabilities: s2.m(capabilitiesSchema),
  clientInfo: s2.m(infoSchema)
}));
var initializeResultSchema2 = schema2((s2) => ({
  protocolVersion: s2.m(string2),
  capabilities: s2.m(capabilitiesSchema),
  serverInfo: s2.m(infoSchema)
}));
var toolCallParamsSchema = schema2((s2) => ({
  callId: s2.m(string2),
  name: s2.m(string2),
  arguments: s2.m(option2(dict2(json2)))
}));
var toolResultContentSchema = schema2((s2) => ({
  type: s2.m(string2),
  text: s2.m(string2)
}));
var toolErrorSchema = schema2((s2) => ({
  code: s2.m(int2),
  message: s2.m(string2)
}));
var callToolResultSchema = schema2((s2) => ({
  content: s2.m(array2(toolResultContentSchema)),
  isError: s2.m(option2(bool2))
}));
var toolsListResultSchema = schema2((s2) => ({
  tools: s2.m(array2(json2))
}));
var ErrorCode = {
  invalidParams: -32602,
  serverError: -32e3,
  methodNotFound: -32601
};
var protocolVersion = "DRAFT-2025-v3";

// ../../../libs/frontman-client/src/FrontmanClient__MCP__Types.res.mjs
var protocolVersion2 = protocolVersion;
var initializeResultSchema3 = initializeResultSchema2;
var toolCallParamsSchema2 = toolCallParamsSchema;
var callToolResultSchema2 = callToolResultSchema;
var toolsListResultSchema2 = toolsListResultSchema;

// ../../../libs/frontman-client/src/FrontmanClient__MCP__Server.res.mjs
var FrontmanClient_MCP_Server_res_exports = {};
__export(FrontmanClient_MCP_Server_res_exports, {
  Relay: () => Relay,
  Tool: () => Tool,
  Types: () => Types3,
  buildInitializeResult: () => buildInitializeResult,
  buildToolsListResult: () => buildToolsListResult,
  executeLocalTool: () => executeLocalTool,
  executeTool: () => executeTool2,
  getToolByName: () => getToolByName,
  getToolsJson: () => getToolsJson2,
  make: () => make4,
  registerToolModule: () => registerToolModule,
  serializeTool: () => serializeTool,
  toolWireSchema: () => toolWireSchema
});

// ../../../libs/frontman-client/src/FrontmanClient__Relay.res.mjs
var FrontmanClient_Relay_res_exports = {};
__export(FrontmanClient_Relay_res_exports, {
  MCPTypes: () => MCPTypes,
  SSE: () => SSE,
  Types: () => Types2,
  connect: () => connect2,
  disconnect: () => disconnect,
  executeTool: () => executeTool,
  getState: () => getState2,
  getToolsJson: () => getToolsJson,
  hasTool: () => hasTool,
  isConnected: () => isConnected,
  make: () => make3
});

// ../../../node_modules/@rescript/runtime/lib/es6/Stdlib_Array.js
function reduceWithIndex(arr, init, f) {
  return arr.reduce(f, init);
}

// ../../../node_modules/@rescript/runtime/lib/es6/Stdlib_JsExn.js
function fromException(exn) {
  if (exn.RE_EXN_ID === "JsExn") {
    return some(exn._1);
  }
}
var getOrUndefined = (fieldName) => (t) => t && typeof t[fieldName] === "string" ? t[fieldName] : void 0;
var stack = getOrUndefined("stack");
var message3 = getOrUndefined("message");
var name = getOrUndefined("name");
var fileName = getOrUndefined("fileName");

// ../../../libs/frontman-client/src/FrontmanClient__SSE.res.mjs
function parseEventType(s2) {
  switch (s2) {
    case "error":
      return "error";
    case "progress":
      return "progress";
    case "result":
      return "result";
    default:
      return "unknown";
  }
}
function parseEventBlock(block) {
  let lines = block.split("\n");
  let eventTypeStr = getOr(map(lines.find((line) => line.startsWith("event:")), (line) => line.slice(6, line.length).trim()), "");
  let data2 = lines.filter((line) => line.startsWith("data:")).map((line) => line.slice(5, line.length).trim()).join("\n");
  if (data2 === "") {
    return;
  } else {
    return {
      eventType: parseEventType(eventTypeStr),
      data: data2
    };
  }
}
function processEvent(event, onProgress) {
  let match = event.eventType;
  if (match === "error") {
    return {
      TAG: "Error",
      _0: event.data
    };
  }
  if (match === "progress") {
    forEach(onProgress, (cb) => cb(event.data));
    return;
  }
  if (match !== "result") {
    return;
  }
  let tmp;
  try {
    tmp = {
      TAG: "Ok",
      _0: JSON.parse(event.data)
    };
  } catch (raw_exn) {
    let exn = internalToException(raw_exn);
    let msg = getOr(flatMap(fromException(exn), message3), "unknown");
    tmp = {
      TAG: "Error",
      _0: `Failed to parse result JSON: ` + msg
    };
  }
  return tmp;
}
function exnMessage(exn) {
  return getOr(flatMap(fromException(exn), message3), "unknown");
}
function processBlocks(blocks, onProgress) {
  return reduceWithIndex(blocks, void 0, (acc, block, _i) => {
    if (acc !== void 0) {
      return acc;
    }
    let event = parseEventBlock(block);
    if (event !== void 0) {
      return processEvent(event, onProgress);
    }
  });
}
async function readStream(response, onProgress) {
  let body = response.body;
  if (body === null) {
    return {
      TAG: "Error",
      _0: "No response body"
    };
  }
  let reader = body.getReader();
  let decoder = new TextDecoder();
  let incompleteChunk = {
    contents: ""
  };
  let result2 = {
    contents: void 0
  };
  try {
    while (isNone(result2.contents)) {
      let chunk = await reader.read();
      if (chunk.done) {
        result2.contents = {
          TAG: "Error",
          _0: "Stream ended without result"
        };
      } else {
        getOr(map(fromNullable(chunk.value), (bytes) => {
          let text = decoder.decode(bytes, {
            stream: true
          });
          let fullText = incompleteChunk.contents + text;
          let parts = fullText.split("\n\n");
          let partsCount = parts.length;
          incompleteChunk.contents = parts[partsCount - 1 | 0];
          let completeBlocks = parts.slice(0, partsCount - 1 | 0);
          result2.contents = processBlocks(completeBlocks, onProgress);
        }), void 0);
      }
    }
    ;
    return getOr(result2.contents, {
      TAG: "Error",
      _0: "Stream ended without result"
    });
  } catch (raw_exn) {
    let exn = internalToException(raw_exn);
    return {
      TAG: "Error",
      _0: `Stream read error: ` + exnMessage(exn)
    };
  }
}

// ../../../libs/frontman-protocol/src/FrontmanProtocol__Relay.res.mjs
var remoteToolSchema = schema2((s2) => ({
  name: s2.m(string2),
  description: s2.m(string2),
  inputSchema: s2.m(json2)
}));
var toolsResponseSchema = schema2((s2) => ({
  tools: s2.m(array2(remoteToolSchema)),
  serverInfo: s2.m(infoSchema)
}));
var toolCallRequestSchema = schema2((s2) => ({
  name: s2.m(string2),
  arguments: s2.m(option2(dict2(json2)))
}));

// ../../../libs/frontman-client/src/FrontmanClient__Relay__Types.res.mjs
var toolsResponseSchema2 = toolsResponseSchema;
var toolCallRequestSchema2 = toolCallRequestSchema;

// ../../../libs/frontman-client/src/FrontmanClient__Relay.res.mjs
function make3(baseUrl) {
  return {
    baseUrl,
    state: "Disconnected"
  };
}
function isConnected(relay) {
  let match = relay.state;
  if (typeof match !== "object") {
    return false;
  } else {
    return match.TAG === "Connected";
  }
}
function getState2(relay) {
  return relay.state;
}
async function connect2(relay) {
  let url2 = relay.baseUrl + `/__frontman/tools`;
  let response = await fetch(url2);
  if (response.ok) {
    let json3 = await response.json();
    try {
      let data2 = parseOrThrow2(json3, toolsResponseSchema2);
      relay.state = {
        TAG: "Connected",
        tools: data2.tools,
        serverInfo: data2.serverInfo
      };
      return {
        TAG: "Ok",
        _0: void 0
      };
    } catch (raw_e) {
      let e = internalToException(raw_e);
      if (e.RE_EXN_ID === $$Error2) {
        let msg = `Invalid tools response: ` + e._1.message;
        relay.state = {
          TAG: "Error",
          _0: msg
        };
        return {
          TAG: "Error",
          _0: msg
        };
      }
      throw e;
    }
  } else {
    let msg$1 = `HTTP ` + response.status.toString() + `: ` + response.statusText;
    relay.state = {
      TAG: "Error",
      _0: msg$1
    };
    return {
      TAG: "Error",
      _0: msg$1
    };
  }
}
function disconnect(relay) {
  relay.state = "Disconnected";
}
function getToolsJson(relay) {
  let match = relay.state;
  if (typeof match !== "object") {
    return [];
  } else if (match.TAG === "Connected") {
    return match.tools.map((tool) => ({
      name: tool.name,
      description: tool.description,
      inputSchema: tool.inputSchema
    }));
  } else {
    return [];
  }
}
function hasTool(relay, name3) {
  let match = relay.state;
  if (typeof match !== "object" || match.TAG !== "Connected") {
    return false;
  } else {
    return match.tools.some((tool) => tool.name === name3);
  }
}
async function executeTool(relay, name3, $$arguments, onProgress) {
  if (!isConnected(relay)) {
    return {
      TAG: "Error",
      _0: "Relay not connected"
    };
  }
  let url2 = relay.baseUrl + `/__frontman/tools/call`;
  let request = {
    name: name3,
    arguments: $$arguments
  };
  let body = reverseConvertToJsonOrThrow2(request, toolCallRequestSchema2);
  let response = await fetch(url2, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "text/event-stream"
    },
    body: some(JSON.stringify(body))
  });
  if (!response.ok) {
    return {
      TAG: "Error",
      _0: `HTTP ` + response.status.toString() + `: ` + response.statusText
    };
  }
  let json3 = await readStream(response, onProgress);
  if (json3.TAG !== "Ok") {
    return {
      TAG: "Error",
      _0: json3._0
    };
  }
  try {
    let result2 = parseOrThrow2(json3._0, callToolResultSchema2);
    return {
      TAG: "Ok",
      _0: result2
    };
  } catch (raw_e) {
    let e = internalToException(raw_e);
    if (e.RE_EXN_ID === $$Error2) {
      return {
        TAG: "Error",
        _0: `Invalid result: ` + e._1.message
      };
    }
    throw e;
  }
}
var Types2;
var MCPTypes;
var SSE;

// ../../../libs/frontman-client/src/FrontmanClient__MCP__Server.res.mjs
function make4(relay, serverNameOpt, serverVersionOpt) {
  let serverName = serverNameOpt !== void 0 ? serverNameOpt : "frontman-browser";
  let serverVersion = serverVersionOpt !== void 0 ? serverVersionOpt : "1.0.0";
  return {
    tools: [],
    relay,
    serverInfo: {
      name: serverName,
      version: serverVersion
    }
  };
}
function registerToolModule(server, toolModule) {
  return {
    tools: server.tools.concat([toolModule]),
    relay: server.relay,
    serverInfo: server.serverInfo
  };
}
var toolWireSchema = object2((s2) => ({
  name: s2.f("name", string2),
  description: s2.f("description", string2),
  inputSchema: s2.f("inputSchema", json2)
}));
function serializeTool(m) {
  return reverseConvertToJsonOrThrow2({
    name: m.name,
    description: m.description,
    inputSchema: toJSONSchema2(m.inputSchema)
  }, toolWireSchema);
}
function getToolsJson2(server) {
  let localTools = server.tools.map(serializeTool);
  let relayTools = getToolsJson(server.relay);
  return localTools.concat(relayTools);
}
function getToolByName(server, name3) {
  return server.tools.find((m) => m.name === name3);
}
async function executeLocalTool(toolModule, $$arguments) {
  let inputJson = getOr($$arguments, {});
  try {
    let input = parseOrThrow2(inputJson, toolModule.inputSchema);
    let result2 = await toolModule.execute(input);
    if (result2.TAG !== "Ok") {
      return {
        content: [{
          type: "text",
          text: result2._0
        }],
        isError: true
      };
    }
    let outputJson = reverseConvertToJsonOrThrow2(result2._0, toolModule.outputSchema);
    return {
      content: [{
        type: "text",
        text: JSON.stringify(outputJson)
      }],
      isError: void 0
    };
  } catch (raw_e) {
    let e = internalToException(raw_e);
    if (e.RE_EXN_ID === $$Error2) {
      return {
        content: [{
          type: "text",
          text: `Invalid input: ` + e._1.message
        }],
        isError: true
      };
    }
    throw e;
  }
}
async function executeTool2(server, name3, $$arguments, onProgress) {
  let toolModule = getToolByName(server, name3);
  if (toolModule !== void 0) {
    return await executeLocalTool(toolModule, $$arguments);
  }
  if (!hasTool(server.relay, name3)) {
    return {
      content: [{
        type: "text",
        text: `Tool not found: ` + name3
      }],
      isError: true
    };
  }
  let result2 = await executeTool(server.relay, name3, $$arguments, onProgress);
  if (result2.TAG === "Ok") {
    return result2._0;
  } else {
    return {
      content: [{
        type: "text",
        text: result2._0
      }],
      isError: true
    };
  }
}
function buildInitializeResult(server) {
  return {
    protocolVersion: protocolVersion2,
    capabilities: {
      tools: {},
      resources: void 0,
      prompts: void 0
    },
    serverInfo: server.serverInfo
  };
}
function buildToolsListResult(server) {
  return {
    tools: getToolsJson2(server)
  };
}
var Types3;
var Tool;
var Relay;

// ../../../libs/frontman-client/src/FrontmanClient__MCP.res.mjs
var requestSchema = object2((s2) => {
  s2.f("jsonrpc", literal2("2.0"));
  let id2 = s2.f("id", int2);
  let method2 = s2.f("method", string2);
  let params2 = s2.f("params", option2(json2));
  return {
    TAG: "Request",
    id: id2,
    method: method2,
    params: params2
  };
});
var notificationSchema = object2((s2) => {
  s2.f("jsonrpc", literal2("2.0"));
  let method2 = s2.f("method", string2);
  let params2 = s2.f("params", option2(json2));
  return {
    TAG: "Notification",
    method: method2,
    params: params2
  };
});
function hasIdField(json3) {
  let obj = Decode.object(json3);
  if (obj !== void 0) {
    return isSome(obj["id"]);
  } else {
    return false;
  }
}
function parse2(json3) {
  let schema4 = hasIdField(json3) ? requestSchema : notificationSchema;
  try {
    return {
      TAG: "Ok",
      _0: parseOrThrow2(json3, schema4)
    };
  } catch (raw_e) {
    let e = internalToException(raw_e);
    if (e.RE_EXN_ID === $$Error2) {
      return {
        TAG: "Error",
        _0: e._1.message
      };
    }
    throw e;
  }
}
function sendResponse(handler, id2, result2) {
  let response = Response.makeSuccess(id2, result2);
  let payload = reverseConvertToJsonOrThrow2(response, Response.schema);
  forEach(handler.onMessage, (cb) => cb("Send", payload));
  handler.channel.push("mcp:message", payload);
}
function sendError(handler, id2, _code, message4) {
  let error2 = RpcError.make(-32601, message4, void 0);
  let response = Response.makeError(id2, error2);
  let payload = reverseConvertToJsonOrThrow2(response, Response.schema);
  forEach(handler.onMessage, (cb) => cb("Send", payload));
  handler.channel.push("mcp:message", payload);
}
function handleInitialize(handler, id2, _params) {
  let result2 = buildInitializeResult(handler.server);
  let resultJson = reverseConvertToJsonOrThrow2(result2, initializeResultSchema3);
  sendResponse(handler, id2, resultJson);
}
function handleToolsList(handler, id2) {
  let result2 = buildToolsListResult(handler.server);
  let resultJson = reverseConvertToJsonOrThrow2(result2, toolsListResultSchema2);
  sendResponse(handler, id2, resultJson);
}
async function handleToolsCall(handler, id2, params2) {
  if (params2 === void 0) {
    return sendError(handler, id2, ErrorCode.invalidParams, "Missing params for tools/call");
  }
  try {
    let match = parseOrThrow2(params2, toolCallParamsSchema2);
    let result2 = await executeTool2(handler.server, match.name, match.arguments, void 0);
    let resultJson = reverseConvertToJsonOrThrow2(result2, callToolResultSchema2);
    return sendResponse(handler, id2, resultJson);
  } catch (raw_e) {
    let e = internalToException(raw_e);
    if (e.RE_EXN_ID === $$Error2) {
      return sendError(handler, id2, ErrorCode.invalidParams, `Invalid params: ` + e._1.message);
    }
    throw e;
  }
}
async function handleMessage(handler, payload) {
  forEach(handler.onMessage, (cb) => cb("Receive", payload));
  let msg = parse2(payload);
  if (msg.TAG === "Ok") {
    let match = msg._0;
    if (match.TAG !== "Request") {
      return;
    }
    let params2 = match.params;
    let method2 = match.method;
    let id2 = match.id;
    switch (method2) {
      case "initialize":
        return handleInitialize(handler, id2, params2);
      case "tools/call":
        return await handleToolsCall(handler, id2, params2);
      case "tools/list":
        return handleToolsList(handler, id2);
      default:
        return sendError(handler, id2, ErrorCode.methodNotFound, `Method not found: ` + method2);
    }
  } else {
    console.error(`Failed to parse MCP message: ` + msg._0);
    return;
  }
}
function attach(channel, server, onMessage) {
  let handler = {
    server,
    channel,
    onMessage
  };
  channel.on("mcp:message", (payload) => {
    handleMessage(handler, payload);
  });
  return handler;
}
function detach(handler) {
  handler.channel.off("mcp:message");
}
var Types4;
var Server;
var Channel3;
var JsonRpc2;

// ../../../libs/frontman-client/src/FrontmanClient__MCP__Tool__ConsoleLog.res.mjs
var FrontmanClient_MCP_Tool_ConsoleLog_res_exports = {};
__export(FrontmanClient_MCP_Tool_ConsoleLog_res_exports, {
  description: () => description,
  execute: () => execute,
  inputSchema: () => inputSchema,
  name: () => name2,
  outputSchema: () => outputSchema
});
var inputSchema = schema2((s2) => ({
  message: s2.m(string2)
}));
var outputSchema = schema2((s2) => ({
  logged: s2.m(bool2)
}));
async function execute(input) {
  console.log(`[MCP Tool] ` + input.message);
  return {
    TAG: "Ok",
    _0: {
      logged: true
    }
  };
}
var name2 = "console_log";
var description = "Logs a message to the browser console";
export {
  FrontmanClient_ACP_res_exports as ACP,
  FrontmanClient_MCP_Tool_ConsoleLog_res_exports as ConsoleLogTool,
  FrontmanClient_MCP_res_exports as MCP,
  FrontmanClient_MCP_Server_res_exports as MCPServer,
  FrontmanClient_Relay_res_exports as Relay
};
//# sourceMappingURL=data:application/json;base64,ewogICJ2ZXJzaW9uIjogMywKICAic291cmNlcyI6IFsiLi4vLi4vLi4vLi4vLi4vbGlicy9mcm9udG1hbi1jbGllbnQvc3JjL0Zyb250bWFuQ2xpZW50X19BQ1AucmVzLm1qcyIsICIuLi8uLi8uLi8uLi8uLi9ub2RlX21vZHVsZXMvcGhvZW5peC9hc3NldHMvanMvcGhvZW5peC91dGlscy5qcyIsICIuLi8uLi8uLi8uLi8uLi9ub2RlX21vZHVsZXMvcGhvZW5peC9hc3NldHMvanMvcGhvZW5peC9jb25zdGFudHMuanMiLCAiLi4vLi4vLi4vLi4vLi4vbm9kZV9tb2R1bGVzL3Bob2VuaXgvYXNzZXRzL2pzL3Bob2VuaXgvcHVzaC5qcyIsICIuLi8uLi8uLi8uLi8uLi9ub2RlX21vZHVsZXMvcGhvZW5peC9hc3NldHMvanMvcGhvZW5peC90aW1lci5qcyIsICIuLi8uLi8uLi8uLi8uLi9ub2RlX21vZHVsZXMvcGhvZW5peC9hc3NldHMvanMvcGhvZW5peC9jaGFubmVsLmpzIiwgIi4uLy4uLy4uLy4uLy4uL25vZGVfbW9kdWxlcy9waG9lbml4L2Fzc2V0cy9qcy9waG9lbml4L2FqYXguanMiLCAiLi4vLi4vLi4vLi4vLi4vbm9kZV9tb2R1bGVzL3Bob2VuaXgvYXNzZXRzL2pzL3Bob2VuaXgvbG9uZ3BvbGwuanMiLCAiLi4vLi4vLi4vLi4vLi4vbm9kZV9tb2R1bGVzL3Bob2VuaXgvYXNzZXRzL2pzL3Bob2VuaXgvcHJlc2VuY2UuanMiLCAiLi4vLi4vLi4vLi4vLi4vbm9kZV9tb2R1bGVzL3Bob2VuaXgvYXNzZXRzL2pzL3Bob2VuaXgvc2VyaWFsaXplci5qcyIsICIuLi8uLi8uLi8uLi8uLi9ub2RlX21vZHVsZXMvcGhvZW5peC9hc3NldHMvanMvcGhvZW5peC9zb2NrZXQuanMiLCAiLi4vLi4vLi4vLi4vLi4vbm9kZV9tb2R1bGVzL0ByZXNjcmlwdC9ydW50aW1lL2xpYi9lczYvUHJpbWl0aXZlX29wdGlvbi5qcyIsICIuLi8uLi8uLi8uLi8uLi9ub2RlX21vZHVsZXMvQHJlc2NyaXB0L3J1bnRpbWUvbGliL2VzNi9TdGRsaWJfT3B0aW9uLmpzIiwgIi4uLy4uLy4uLy4uLy4uL25vZGVfbW9kdWxlcy9AcmVzY3JpcHQvcnVudGltZS9saWIvZXM2L1N0ZGxpYl9SZXN1bHQuanMiLCAiLi4vLi4vLi4vLi4vLi4vbm9kZV9tb2R1bGVzL0ByZXNjcmlwdC9ydW50aW1lL2xpYi9lczYvUHJpbWl0aXZlX2V4Y2VwdGlvbnMuanMiLCAiLi4vLi4vLi4vLi4vLi4vbm9kZV9tb2R1bGVzL3N1cnkvc3JjL1N1cnkucmVzLm1qcyIsICIuLi8uLi8uLi8uLi8uLi9ub2RlX21vZHVsZXMvc3VyeS9zcmMvUy5yZXMubWpzIiwgIi4uLy4uLy4uLy4uLy4uL2xpYnMvZnJvbnRtYW4tY2xpZW50L3NyYy9Gcm9udG1hbkNsaWVudF9fSnNvblJwYy5yZXMubWpzIiwgIi4uLy4uLy4uLy4uLy4uL25vZGVfbW9kdWxlcy9AcmVzY3JpcHQvcnVudGltZS9saWIvZXM2L1N0ZGxpYl9EaWN0LmpzIiwgIi4uLy4uLy4uLy4uLy4uL2xpYnMvZnJvbnRtYW4tY2xpZW50L3NyYy9Gcm9udG1hbkNsaWVudF9fQUNQX19UeXBlcy5yZXMubWpzIiwgIi4uLy4uLy4uLy4uLy4uL2xpYnMvZnJvbnRtYW4tY2xpZW50L3NyYy9Gcm9udG1hbkNsaWVudF9fQUNQX19DbGllbnQucmVzLm1qcyIsICIuLi8uLi8uLi8uLi8uLi9saWJzL2Zyb250bWFuLWNsaWVudC9zcmMvRnJvbnRtYW5DbGllbnRfX01DUC5yZXMubWpzIiwgIi4uLy4uLy4uLy4uLy4uL25vZGVfbW9kdWxlcy9AcmVzY3JpcHQvcnVudGltZS9saWIvZXM2L1N0ZGxpYl9KU09OLmpzIiwgIi4uLy4uLy4uLy4uLy4uL2xpYnMvZnJvbnRtYW4tcHJvdG9jb2wvc3JjL0Zyb250bWFuUHJvdG9jb2xfX01DUC5yZXMubWpzIiwgIi4uLy4uLy4uLy4uLy4uL2xpYnMvZnJvbnRtYW4tY2xpZW50L3NyYy9Gcm9udG1hbkNsaWVudF9fTUNQX19UeXBlcy5yZXMubWpzIiwgIi4uLy4uLy4uLy4uLy4uL2xpYnMvZnJvbnRtYW4tY2xpZW50L3NyYy9Gcm9udG1hbkNsaWVudF9fTUNQX19TZXJ2ZXIucmVzLm1qcyIsICIuLi8uLi8uLi8uLi8uLi9saWJzL2Zyb250bWFuLWNsaWVudC9zcmMvRnJvbnRtYW5DbGllbnRfX1JlbGF5LnJlcy5tanMiLCAiLi4vLi4vLi4vLi4vLi4vbm9kZV9tb2R1bGVzL0ByZXNjcmlwdC9ydW50aW1lL2xpYi9lczYvU3RkbGliX0FycmF5LmpzIiwgIi4uLy4uLy4uLy4uLy4uL25vZGVfbW9kdWxlcy9AcmVzY3JpcHQvcnVudGltZS9saWIvZXM2L1N0ZGxpYl9Kc0V4bi5qcyIsICIuLi8uLi8uLi8uLi8uLi9saWJzL2Zyb250bWFuLWNsaWVudC9zcmMvRnJvbnRtYW5DbGllbnRfX1NTRS5yZXMubWpzIiwgIi4uLy4uLy4uLy4uLy4uL2xpYnMvZnJvbnRtYW4tcHJvdG9jb2wvc3JjL0Zyb250bWFuUHJvdG9jb2xfX1JlbGF5LnJlcy5tanMiLCAiLi4vLi4vLi4vLi4vLi4vbGlicy9mcm9udG1hbi1jbGllbnQvc3JjL0Zyb250bWFuQ2xpZW50X19SZWxheV9fVHlwZXMucmVzLm1qcyIsICIuLi8uLi8uLi8uLi8uLi9saWJzL2Zyb250bWFuLWNsaWVudC9zcmMvRnJvbnRtYW5DbGllbnRfX01DUF9fVG9vbF9fQ29uc29sZUxvZy5yZXMubWpzIl0sCiAgInNvdXJjZXNDb250ZW50IjogWyIvLyBHZW5lcmF0ZWQgYnkgUmVTY3JpcHQsIFBMRUFTRSBFRElUIFdJVEggQ0FSRVxuXG5pbXBvcnQgKiBhcyBQaG9lbml4IGZyb20gXCJwaG9lbml4XCI7XG5pbXBvcnQgKiBhcyBTdGRsaWJfT3B0aW9uIGZyb20gXCJAcmVzY3JpcHQvcnVudGltZS9saWIvZXM2L1N0ZGxpYl9PcHRpb24uanNcIjtcbmltcG9ydCAqIGFzIFN0ZGxpYl9SZXN1bHQgZnJvbSBcIkByZXNjcmlwdC9ydW50aW1lL2xpYi9lczYvU3RkbGliX1Jlc3VsdC5qc1wiO1xuaW1wb3J0ICogYXMgRnJvbnRtYW5DbGllbnRfX0pzb25ScGMkQXNrVGhlTGxtRnJvbnRtYW5DbGllbnQgZnJvbSBcIi4vRnJvbnRtYW5DbGllbnRfX0pzb25ScGMucmVzLm1qc1wiO1xuaW1wb3J0ICogYXMgRnJvbnRtYW5DbGllbnRfX0FDUF9fQ2xpZW50JEFza1RoZUxsbUZyb250bWFuQ2xpZW50IGZyb20gXCIuL0Zyb250bWFuQ2xpZW50X19BQ1BfX0NsaWVudC5yZXMubWpzXCI7XG5cbmZ1bmN0aW9uIG1ha2VDb25maWcoZW5kcG9pbnQsIG5hbWUsIHZlcnNpb24sIG9uTWVzc2FnZSkge1xuICByZXR1cm4ge1xuICAgIGVuZHBvaW50OiBlbmRwb2ludCxcbiAgICBjbGllbnRJbmZvOiB7XG4gICAgICBuYW1lOiBuYW1lLFxuICAgICAgdmVyc2lvbjogdmVyc2lvbixcbiAgICAgIHRpdGxlOiB1bmRlZmluZWRcbiAgICB9LFxuICAgIGNsaWVudENhcGFiaWxpdGllczoge1xuICAgICAgZnM6IHtcbiAgICAgICAgcmVhZFRleHRGaWxlOiB0cnVlLFxuICAgICAgICB3cml0ZVRleHRGaWxlOiB0cnVlXG4gICAgICB9LFxuICAgICAgdGVybWluYWw6IGZhbHNlXG4gICAgfSxcbiAgICBvbk1lc3NhZ2U6IG9uTWVzc2FnZVxuICB9O1xufVxuXG5mdW5jdGlvbiB3YWl0Rm9yU29ja2V0KHNvY2tldCkge1xuICByZXR1cm4gbmV3IFByb21pc2UoKHJlc29sdmUsIHBhcmFtKSA9PiB7XG4gICAgc29ja2V0Lm9uRXJyb3IocGFyYW0gPT4gcmVzb2x2ZSh7XG4gICAgICBUQUc6IFwiRXJyb3JcIixcbiAgICAgIF8wOiBcIlNvY2tldCBjb25uZWN0aW9uIGZhaWxlZFwiXG4gICAgfSkpO1xuICAgIHNvY2tldC5vbk9wZW4oKCkgPT4gcmVzb2x2ZSh7XG4gICAgICBUQUc6IFwiT2tcIixcbiAgICAgIF8wOiB1bmRlZmluZWRcbiAgICB9KSk7XG4gICAgc29ja2V0LmNvbm5lY3QoKTtcbiAgfSk7XG59XG5cbmZ1bmN0aW9uIGpvaW5DaGFubmVsKGNoYW5uZWwpIHtcbiAgcmV0dXJuIG5ldyBQcm9taXNlKChyZXNvbHZlLCBwYXJhbSkgPT4ge1xuICAgIGNoYW5uZWwuam9pbigpLnJlY2VpdmUoXCJva1wiLCBwYXJhbSA9PiByZXNvbHZlKHtcbiAgICAgIFRBRzogXCJPa1wiLFxuICAgICAgXzA6IHVuZGVmaW5lZFxuICAgIH0pKS5yZWNlaXZlKFwiZXJyb3JcIiwgZXJyID0+IHJlc29sdmUoe1xuICAgICAgVEFHOiBcIkVycm9yXCIsXG4gICAgICBfMDogYEpvaW4gZmFpbGVkOiBgICsgSlNPTi5zdHJpbmdpZnkoZXJyKVxuICAgIH0pKTtcbiAgfSk7XG59XG5cbmZ1bmN0aW9uIHNlbmRJbml0aWFsaXplKGNoYW5uZWwsIHN0YXRlLCBjbGllbnRDb25maWcsIG9uTWVzc2FnZSkge1xuICByZXR1cm4gbmV3IFByb21pc2UoKHJlc29sdmUsIHBhcmFtKSA9PiB7XG4gICAgbGV0IGlkID0gc3RhdGUuY29udGVudHMuY3VycmVudElkICsgMSB8IDA7XG4gICAgbGV0IHBhcmFtcyA9IEZyb250bWFuQ2xpZW50X19BQ1BfX0NsaWVudCRBc2tUaGVMbG1Gcm9udG1hbkNsaWVudC5idWlsZEluaXRpYWxpemVQYXJhbXMoY2xpZW50Q29uZmlnKTtcbiAgICBsZXQgcmVxdWVzdCA9IEZyb250bWFuQ2xpZW50X19Kc29uUnBjJEFza1RoZUxsbUZyb250bWFuQ2xpZW50LlJlcXVlc3QubWFrZShpZCwgXCJpbml0aWFsaXplXCIsIHBhcmFtcyk7XG4gICAgbGV0IHBlbmRpbmdfcmVzb2x2ZSA9IGpzb24gPT4ge1xuICAgICAgbGV0IHJlc3VsdCA9IEZyb250bWFuQ2xpZW50X19BQ1BfX0NsaWVudCRBc2tUaGVMbG1Gcm9udG1hbkNsaWVudC5wYXJzZUluaXRpYWxpemVSZXN1bHQoanNvbik7XG4gICAgICBpZiAocmVzdWx0LlRBRyA9PT0gXCJPa1wiKSB7XG4gICAgICAgIHJldHVybiByZXNvbHZlKHtcbiAgICAgICAgICBUQUc6IFwiT2tcIixcbiAgICAgICAgICBfMDogcmVzdWx0Ll8wXG4gICAgICAgIH0pO1xuICAgICAgfSBlbHNlIHtcbiAgICAgICAgcmV0dXJuIHJlc29sdmUoe1xuICAgICAgICAgIFRBRzogXCJFcnJvclwiLFxuICAgICAgICAgIF8wOiByZXN1bHQuXzBcbiAgICAgICAgfSk7XG4gICAgICB9XG4gICAgfTtcbiAgICBsZXQgcGVuZGluZ19yZWplY3QgPSBlID0+IHJlc29sdmUoe1xuICAgICAgVEFHOiBcIkVycm9yXCIsXG4gICAgICBfMDogZVxuICAgIH0pO1xuICAgIGxldCBwZW5kaW5nID0ge1xuICAgICAgcmVzb2x2ZTogcGVuZGluZ19yZXNvbHZlLFxuICAgICAgcmVqZWN0OiBwZW5kaW5nX3JlamVjdFxuICAgIH07XG4gICAgc3RhdGUuY29udGVudHMgPSBGcm9udG1hbkNsaWVudF9fQUNQX19DbGllbnQkQXNrVGhlTGxtRnJvbnRtYW5DbGllbnQucmVkdWNlKHN0YXRlLmNvbnRlbnRzLCB7XG4gICAgICBUQUc6IFwiUmVxdWVzdFNlbnRcIixcbiAgICAgIF8wOiBpZCxcbiAgICAgIF8xOiBwZW5kaW5nXG4gICAgfSk7XG4gICAgbGV0IHBheWxvYWQgPSBGcm9udG1hbkNsaWVudF9fSnNvblJwYyRBc2tUaGVMbG1Gcm9udG1hbkNsaWVudC5SZXF1ZXN0LnRvSnNvbihyZXF1ZXN0KTtcbiAgICBTdGRsaWJfT3B0aW9uLmZvckVhY2gob25NZXNzYWdlLCBjYiA9PiBjYihcIlNlbmRcIiwgcGF5bG9hZCkpO1xuICAgIGNoYW5uZWwucHVzaChcImFjcDptZXNzYWdlXCIsIHBheWxvYWQpO1xuICB9KTtcbn1cblxuYXN5bmMgZnVuY3Rpb24gY29ubmVjdChjb25maWcpIHtcbiAgbGV0IHNvY2tldCA9IG5ldyBQaG9lbml4LlNvY2tldChjb25maWcuZW5kcG9pbnQpO1xuICBsZXQgY2hhbm5lbCA9IHNvY2tldC5jaGFubmVsKFwic2Vzc2lvbnNcIik7XG4gIGxldCBzdGF0ZSA9IHtcbiAgICBjb250ZW50czogRnJvbnRtYW5DbGllbnRfX0FDUF9fQ2xpZW50JEFza1RoZUxsbUZyb250bWFuQ2xpZW50LmluaXRpYWxTdGF0ZVxuICB9O1xuICBsZXQgY2xpZW50Q29uZmlnX2NsaWVudEluZm8gPSBjb25maWcuY2xpZW50SW5mbztcbiAgbGV0IGNsaWVudENvbmZpZ19jbGllbnRDYXBhYmlsaXRpZXMgPSBjb25maWcuY2xpZW50Q2FwYWJpbGl0aWVzO1xuICBsZXQgY2xpZW50Q29uZmlnID0ge1xuICAgIGNoYW5uZWw6IGNoYW5uZWwsXG4gICAgY2xpZW50SW5mbzogY2xpZW50Q29uZmlnX2NsaWVudEluZm8sXG4gICAgY2xpZW50Q2FwYWJpbGl0aWVzOiBjbGllbnRDb25maWdfY2xpZW50Q2FwYWJpbGl0aWVzXG4gIH07XG4gIGNoYW5uZWwub24oXCJhY3A6bWVzc2FnZVwiLCBwYXlsb2FkID0+IHtcbiAgICBTdGRsaWJfT3B0aW9uLmZvckVhY2goY29uZmlnLm9uTWVzc2FnZSwgY2IgPT4gY2IoXCJSZWNlaXZlXCIsIHBheWxvYWQpKTtcbiAgICBzdGF0ZS5jb250ZW50cyA9IEZyb250bWFuQ2xpZW50X19BQ1BfX0NsaWVudCRBc2tUaGVMbG1Gcm9udG1hbkNsaWVudC5oYW5kbGVSZXNwb25zZShzdGF0ZS5jb250ZW50cywgcGF5bG9hZCk7XG4gIH0pO1xuICBsZXQgaW5pdFJlc3VsdCA9IGF3YWl0IFN0ZGxpYl9SZXN1bHQuZmxhdE1hcE9rQXN5bmMoU3RkbGliX1Jlc3VsdC5mbGF0TWFwT2tBc3luYyh3YWl0Rm9yU29ja2V0KHNvY2tldCksICgpID0+IGpvaW5DaGFubmVsKGNoYW5uZWwpKSwgKCkgPT4gc2VuZEluaXRpYWxpemUoY2hhbm5lbCwgc3RhdGUsIGNsaWVudENvbmZpZywgY29uZmlnLm9uTWVzc2FnZSkpO1xuICByZXR1cm4gU3RkbGliX1Jlc3VsdC5tYXAoaW5pdFJlc3VsdCwgcmVzdWx0ID0+IHtcbiAgICBzdGF0ZS5jb250ZW50cyA9IEZyb250bWFuQ2xpZW50X19BQ1BfX0NsaWVudCRBc2tUaGVMbG1Gcm9udG1hbkNsaWVudC5yZWR1Y2Uoc3RhdGUuY29udGVudHMsIHtcbiAgICAgIFRBRzogXCJDb25uZWN0aW9uU3RhdGVDaGFuZ2VkXCIsXG4gICAgICBfMDoge1xuICAgICAgICBUQUc6IFwiSW5pdGlhbGl6ZWRcIixcbiAgICAgICAgXzA6IHJlc3VsdFxuICAgICAgfVxuICAgIH0pO1xuICAgIHJldHVybiB7XG4gICAgICBzb2NrZXQ6IHNvY2tldCxcbiAgICAgIGNoYW5uZWw6IGNoYW5uZWwsXG4gICAgICBjbGllbnRDb25maWc6IGNsaWVudENvbmZpZyxcbiAgICAgIHN0YXRlOiBzdGF0ZSxcbiAgICAgIG9uTWVzc2FnZTogY29uZmlnLm9uTWVzc2FnZVxuICAgIH07XG4gIH0pO1xufVxuXG5mdW5jdGlvbiBnZXRTdGF0ZShjb25uKSB7XG4gIHJldHVybiBGcm9udG1hbkNsaWVudF9fQUNQX19DbGllbnQkQXNrVGhlTGxtRnJvbnRtYW5DbGllbnQuZ2V0Q29ubmVjdGlvblN0YXRlKGNvbm4uc3RhdGUuY29udGVudHMpO1xufVxuXG5mdW5jdGlvbiBpc0luaXRpYWxpemVkKGNvbm4pIHtcbiAgcmV0dXJuIEZyb250bWFuQ2xpZW50X19BQ1BfX0NsaWVudCRBc2tUaGVMbG1Gcm9udG1hbkNsaWVudC5pc0luaXRpYWxpemVkKGNvbm4uc3RhdGUuY29udGVudHMpO1xufVxuXG5hc3luYyBmdW5jdGlvbiBqb2luU2Vzc2lvbihjb25uLCBzZXNzaW9uSWQsIG9uVXBkYXRlKSB7XG4gIGxldCBzZXNzaW9uQ2hhbm5lbCA9IGNvbm4uc29ja2V0LmNoYW5uZWwoYHNlc3Npb246YCArIHNlc3Npb25JZCk7XG4gIHNlc3Npb25DaGFubmVsLm9uKFwiYWNwOm1lc3NhZ2VcIiwgcGF5bG9hZCA9PiB7XG4gICAgU3RkbGliX09wdGlvbi5mb3JFYWNoKGNvbm4ub25NZXNzYWdlLCBjYiA9PiBjYihcIlJlY2VpdmVcIiwgcGF5bG9hZCkpO1xuICAgIGxldCBub3RpZmljYXRpb24gPSBGcm9udG1hbkNsaWVudF9fQUNQX19DbGllbnQkQXNrVGhlTGxtRnJvbnRtYW5DbGllbnQucGFyc2VTZXNzaW9uVXBkYXRlTm90aWZpY2F0aW9uKHBheWxvYWQpO1xuICAgIGlmIChub3RpZmljYXRpb24uVEFHID09PSBcIk9rXCIpIHtcbiAgICAgIHJldHVybiBvblVwZGF0ZShub3RpZmljYXRpb24uXzAucGFyYW1zLnVwZGF0ZSk7XG4gICAgfSBlbHNlIHtcbiAgICAgIGNvbm4uc3RhdGUuY29udGVudHMgPSBGcm9udG1hbkNsaWVudF9fQUNQX19DbGllbnQkQXNrVGhlTGxtRnJvbnRtYW5DbGllbnQuaGFuZGxlUmVzcG9uc2UoY29ubi5zdGF0ZS5jb250ZW50cywgcGF5bG9hZCk7XG4gICAgICByZXR1cm47XG4gICAgfVxuICB9KTtcbiAgbGV0IGpvaW5SZXN1bHQgPSBhd2FpdCBqb2luQ2hhbm5lbChzZXNzaW9uQ2hhbm5lbCk7XG4gIHJldHVybiBTdGRsaWJfUmVzdWx0Lm1hcChqb2luUmVzdWx0LCAoKSA9PiAoe1xuICAgIHNlc3Npb25JZDogc2Vzc2lvbklkLFxuICAgIGNoYW5uZWw6IHNlc3Npb25DaGFubmVsLFxuICAgIGNvbm5lY3Rpb246IGNvbm4sXG4gICAgb25VcGRhdGU6IG9uVXBkYXRlXG4gIH0pKTtcbn1cblxuYXN5bmMgZnVuY3Rpb24gY3JlYXRlU2Vzc2lvbihjb25uLCBvblVwZGF0ZSkge1xuICBsZXQgc2Vzc2lvbk5ld1Jlc3VsdCA9IGF3YWl0IG5ldyBQcm9taXNlKChyZXNvbHZlLCBwYXJhbSkgPT4ge1xuICAgIGxldCBpZCA9IGNvbm4uc3RhdGUuY29udGVudHMuY3VycmVudElkICsgMSB8IDA7XG4gICAgbGV0IHJlcXVlc3QgPSBGcm9udG1hbkNsaWVudF9fSnNvblJwYyRBc2tUaGVMbG1Gcm9udG1hbkNsaWVudC5SZXF1ZXN0Lm1ha2UoaWQsIFwic2Vzc2lvbi9uZXdcIiwge30pO1xuICAgIGxldCBwZW5kaW5nX3Jlc29sdmUgPSBqc29uID0+IHtcbiAgICAgIGxldCByZXN1bHQgPSBGcm9udG1hbkNsaWVudF9fQUNQX19DbGllbnQkQXNrVGhlTGxtRnJvbnRtYW5DbGllbnQucGFyc2VTZXNzaW9uTmV3UmVzdWx0KGpzb24pO1xuICAgICAgaWYgKHJlc3VsdC5UQUcgPT09IFwiT2tcIikge1xuICAgICAgICByZXR1cm4gcmVzb2x2ZSh7XG4gICAgICAgICAgVEFHOiBcIk9rXCIsXG4gICAgICAgICAgXzA6IHJlc3VsdC5fMFxuICAgICAgICB9KTtcbiAgICAgIH0gZWxzZSB7XG4gICAgICAgIHJldHVybiByZXNvbHZlKHtcbiAgICAgICAgICBUQUc6IFwiRXJyb3JcIixcbiAgICAgICAgICBfMDogcmVzdWx0Ll8wXG4gICAgICAgIH0pO1xuICAgICAgfVxuICAgIH07XG4gICAgbGV0IHBlbmRpbmdfcmVqZWN0ID0gZSA9PiByZXNvbHZlKHtcbiAgICAgIFRBRzogXCJFcnJvclwiLFxuICAgICAgXzA6IGVcbiAgICB9KTtcbiAgICBsZXQgcGVuZGluZyA9IHtcbiAgICAgIHJlc29sdmU6IHBlbmRpbmdfcmVzb2x2ZSxcbiAgICAgIHJlamVjdDogcGVuZGluZ19yZWplY3RcbiAgICB9O1xuICAgIGNvbm4uc3RhdGUuY29udGVudHMgPSBGcm9udG1hbkNsaWVudF9fQUNQX19DbGllbnQkQXNrVGhlTGxtRnJvbnRtYW5DbGllbnQucmVkdWNlKGNvbm4uc3RhdGUuY29udGVudHMsIHtcbiAgICAgIFRBRzogXCJSZXF1ZXN0U2VudFwiLFxuICAgICAgXzA6IGlkLFxuICAgICAgXzE6IHBlbmRpbmdcbiAgICB9KTtcbiAgICBsZXQgcGF5bG9hZCA9IEZyb250bWFuQ2xpZW50X19Kc29uUnBjJEFza1RoZUxsbUZyb250bWFuQ2xpZW50LlJlcXVlc3QudG9Kc29uKHJlcXVlc3QpO1xuICAgIFN0ZGxpYl9PcHRpb24uZm9yRWFjaChjb25uLm9uTWVzc2FnZSwgY2IgPT4gY2IoXCJTZW5kXCIsIHBheWxvYWQpKTtcbiAgICBjb25uLmNoYW5uZWwucHVzaChcImFjcDptZXNzYWdlXCIsIHBheWxvYWQpO1xuICB9KTtcbiAgaWYgKHNlc3Npb25OZXdSZXN1bHQuVEFHID09PSBcIk9rXCIpIHtcbiAgICByZXR1cm4gYXdhaXQgam9pblNlc3Npb24oY29ubiwgc2Vzc2lvbk5ld1Jlc3VsdC5fMC5zZXNzaW9uSWQsIG9uVXBkYXRlKTtcbiAgfSBlbHNlIHtcbiAgICByZXR1cm4ge1xuICAgICAgVEFHOiBcIkVycm9yXCIsXG4gICAgICBfMDogc2Vzc2lvbk5ld1Jlc3VsdC5fMFxuICAgIH07XG4gIH1cbn1cblxuYXN5bmMgZnVuY3Rpb24gc2VuZFByb21wdChzZXNzaW9uLCB0ZXh0KSB7XG4gIGxldCBpZCA9IHNlc3Npb24uY29ubmVjdGlvbi5zdGF0ZS5jb250ZW50cy5jdXJyZW50SWQgKyAxIHwgMDtcbiAgbGV0IHByb21wdFBhcmFtcyA9IE9iamVjdC5mcm9tRW50cmllcyhbXG4gICAgW1xuICAgICAgXCJzZXNzaW9uSWRcIixcbiAgICAgIHNlc3Npb24uc2Vzc2lvbklkXG4gICAgXSxcbiAgICBbXG4gICAgICBcInByb21wdFwiLFxuICAgICAgW09iamVjdC5mcm9tRW50cmllcyhbXG4gICAgICAgICAgW1xuICAgICAgICAgICAgXCJ0eXBlXCIsXG4gICAgICAgICAgICBcInRleHRcIlxuICAgICAgICAgIF0sXG4gICAgICAgICAgW1xuICAgICAgICAgICAgXCJ0ZXh0XCIsXG4gICAgICAgICAgICB0ZXh0XG4gICAgICAgICAgXVxuICAgICAgICBdKV1cbiAgICBdXG4gIF0pO1xuICBsZXQgcmVxdWVzdCA9IEZyb250bWFuQ2xpZW50X19Kc29uUnBjJEFza1RoZUxsbUZyb250bWFuQ2xpZW50LlJlcXVlc3QubWFrZShpZCwgXCJzZXNzaW9uL3Byb21wdFwiLCBwcm9tcHRQYXJhbXMpO1xuICByZXR1cm4gYXdhaXQgbmV3IFByb21pc2UoKHJlc29sdmUsIHBhcmFtKSA9PiB7XG4gICAgbGV0IHBlbmRpbmdfcmVzb2x2ZSA9IGpzb24gPT4ge1xuICAgICAgbGV0IHJlc3VsdCA9IEZyb250bWFuQ2xpZW50X19BQ1BfX0NsaWVudCRBc2tUaGVMbG1Gcm9udG1hbkNsaWVudC5wYXJzZVByb21wdFJlc3VsdChqc29uKTtcbiAgICAgIGlmIChyZXN1bHQuVEFHID09PSBcIk9rXCIpIHtcbiAgICAgICAgcmV0dXJuIHJlc29sdmUoe1xuICAgICAgICAgIFRBRzogXCJPa1wiLFxuICAgICAgICAgIF8wOiByZXN1bHQuXzBcbiAgICAgICAgfSk7XG4gICAgICB9IGVsc2Uge1xuICAgICAgICByZXR1cm4gcmVzb2x2ZSh7XG4gICAgICAgICAgVEFHOiBcIkVycm9yXCIsXG4gICAgICAgICAgXzA6IHJlc3VsdC5fMFxuICAgICAgICB9KTtcbiAgICAgIH1cbiAgICB9O1xuICAgIGxldCBwZW5kaW5nX3JlamVjdCA9IGUgPT4gcmVzb2x2ZSh7XG4gICAgICBUQUc6IFwiRXJyb3JcIixcbiAgICAgIF8wOiBlXG4gICAgfSk7XG4gICAgbGV0IHBlbmRpbmcgPSB7XG4gICAgICByZXNvbHZlOiBwZW5kaW5nX3Jlc29sdmUsXG4gICAgICByZWplY3Q6IHBlbmRpbmdfcmVqZWN0XG4gICAgfTtcbiAgICBzZXNzaW9uLmNvbm5lY3Rpb24uc3RhdGUuY29udGVudHMgPSBGcm9udG1hbkNsaWVudF9fQUNQX19DbGllbnQkQXNrVGhlTGxtRnJvbnRtYW5DbGllbnQucmVkdWNlKHNlc3Npb24uY29ubmVjdGlvbi5zdGF0ZS5jb250ZW50cywge1xuICAgICAgVEFHOiBcIlJlcXVlc3RTZW50XCIsXG4gICAgICBfMDogaWQsXG4gICAgICBfMTogcGVuZGluZ1xuICAgIH0pO1xuICAgIGxldCBwYXlsb2FkID0gRnJvbnRtYW5DbGllbnRfX0pzb25ScGMkQXNrVGhlTGxtRnJvbnRtYW5DbGllbnQuUmVxdWVzdC50b0pzb24ocmVxdWVzdCk7XG4gICAgU3RkbGliX09wdGlvbi5mb3JFYWNoKHNlc3Npb24uY29ubmVjdGlvbi5vbk1lc3NhZ2UsIGNiID0+IGNiKFwiU2VuZFwiLCBwYXlsb2FkKSk7XG4gICAgc2Vzc2lvbi5jaGFubmVsLnB1c2goXCJhY3A6bWVzc2FnZVwiLCBwYXlsb2FkKTtcbiAgfSk7XG59XG5cbmxldCBUeXBlcztcblxubGV0IENsaWVudDtcblxubGV0IENoYW5uZWw7XG5cbmxldCBTb2NrZXQ7XG5cbmxldCBKc29uUnBjO1xuXG5leHBvcnQge1xuICBUeXBlcyxcbiAgQ2xpZW50LFxuICBDaGFubmVsLFxuICBTb2NrZXQsXG4gIEpzb25ScGMsXG4gIG1ha2VDb25maWcsXG4gIHdhaXRGb3JTb2NrZXQsXG4gIGpvaW5DaGFubmVsLFxuICBzZW5kSW5pdGlhbGl6ZSxcbiAgY29ubmVjdCxcbiAgZ2V0U3RhdGUsXG4gIGlzSW5pdGlhbGl6ZWQsXG4gIGpvaW5TZXNzaW9uLFxuICBjcmVhdGVTZXNzaW9uLFxuICBzZW5kUHJvbXB0LFxufVxuLyogcGhvZW5peCBOb3QgYSBwdXJlIG1vZHVsZSAqL1xuIiwgIi8vIHdyYXBzIHZhbHVlIGluIGNsb3N1cmUgb3IgcmV0dXJucyBjbG9zdXJlXG5leHBvcnQgbGV0IGNsb3N1cmUgPSAodmFsdWUpID0+IHtcbiAgaWYodHlwZW9mIHZhbHVlID09PSBcImZ1bmN0aW9uXCIpe1xuICAgIHJldHVybiB2YWx1ZVxuICB9IGVsc2Uge1xuICAgIGxldCBjbG9zdXJlID0gZnVuY3Rpb24gKCl7IHJldHVybiB2YWx1ZSB9XG4gICAgcmV0dXJuIGNsb3N1cmVcbiAgfVxufVxuIiwgImV4cG9ydCBjb25zdCBnbG9iYWxTZWxmID0gdHlwZW9mIHNlbGYgIT09IFwidW5kZWZpbmVkXCIgPyBzZWxmIDogbnVsbFxuZXhwb3J0IGNvbnN0IHBoeFdpbmRvdyA9IHR5cGVvZiB3aW5kb3cgIT09IFwidW5kZWZpbmVkXCIgPyB3aW5kb3cgOiBudWxsXG5leHBvcnQgY29uc3QgZ2xvYmFsID0gZ2xvYmFsU2VsZiB8fCBwaHhXaW5kb3cgfHwgZ2xvYmFsVGhpc1xuZXhwb3J0IGNvbnN0IERFRkFVTFRfVlNOID0gXCIyLjAuMFwiXG5leHBvcnQgY29uc3QgU09DS0VUX1NUQVRFUyA9IHtjb25uZWN0aW5nOiAwLCBvcGVuOiAxLCBjbG9zaW5nOiAyLCBjbG9zZWQ6IDN9XG5leHBvcnQgY29uc3QgREVGQVVMVF9USU1FT1VUID0gMTAwMDBcbmV4cG9ydCBjb25zdCBXU19DTE9TRV9OT1JNQUwgPSAxMDAwXG5leHBvcnQgY29uc3QgQ0hBTk5FTF9TVEFURVMgPSB7XG4gIGNsb3NlZDogXCJjbG9zZWRcIixcbiAgZXJyb3JlZDogXCJlcnJvcmVkXCIsXG4gIGpvaW5lZDogXCJqb2luZWRcIixcbiAgam9pbmluZzogXCJqb2luaW5nXCIsXG4gIGxlYXZpbmc6IFwibGVhdmluZ1wiLFxufVxuZXhwb3J0IGNvbnN0IENIQU5ORUxfRVZFTlRTID0ge1xuICBjbG9zZTogXCJwaHhfY2xvc2VcIixcbiAgZXJyb3I6IFwicGh4X2Vycm9yXCIsXG4gIGpvaW46IFwicGh4X2pvaW5cIixcbiAgcmVwbHk6IFwicGh4X3JlcGx5XCIsXG4gIGxlYXZlOiBcInBoeF9sZWF2ZVwiXG59XG5cbmV4cG9ydCBjb25zdCBUUkFOU1BPUlRTID0ge1xuICBsb25ncG9sbDogXCJsb25ncG9sbFwiLFxuICB3ZWJzb2NrZXQ6IFwid2Vic29ja2V0XCJcbn1cbmV4cG9ydCBjb25zdCBYSFJfU1RBVEVTID0ge1xuICBjb21wbGV0ZTogNFxufVxuZXhwb3J0IGNvbnN0IEFVVEhfVE9LRU5fUFJFRklYID0gXCJiYXNlNjR1cmwuYmVhcmVyLnBoeC5cIlxuIiwgIi8qKlxuICogSW5pdGlhbGl6ZXMgdGhlIFB1c2hcbiAqIEBwYXJhbSB7Q2hhbm5lbH0gY2hhbm5lbCAtIFRoZSBDaGFubmVsXG4gKiBAcGFyYW0ge3N0cmluZ30gZXZlbnQgLSBUaGUgZXZlbnQsIGZvciBleGFtcGxlIGBcInBoeF9qb2luXCJgXG4gKiBAcGFyYW0ge09iamVjdH0gcGF5bG9hZCAtIFRoZSBwYXlsb2FkLCBmb3IgZXhhbXBsZSBge3VzZXJfaWQ6IDEyM31gXG4gKiBAcGFyYW0ge251bWJlcn0gdGltZW91dCAtIFRoZSBwdXNoIHRpbWVvdXQgaW4gbWlsbGlzZWNvbmRzXG4gKi9cbmV4cG9ydCBkZWZhdWx0IGNsYXNzIFB1c2gge1xuICBjb25zdHJ1Y3RvcihjaGFubmVsLCBldmVudCwgcGF5bG9hZCwgdGltZW91dCl7XG4gICAgdGhpcy5jaGFubmVsID0gY2hhbm5lbFxuICAgIHRoaXMuZXZlbnQgPSBldmVudFxuICAgIHRoaXMucGF5bG9hZCA9IHBheWxvYWQgfHwgZnVuY3Rpb24gKCl7IHJldHVybiB7fSB9XG4gICAgdGhpcy5yZWNlaXZlZFJlc3AgPSBudWxsXG4gICAgdGhpcy50aW1lb3V0ID0gdGltZW91dFxuICAgIHRoaXMudGltZW91dFRpbWVyID0gbnVsbFxuICAgIHRoaXMucmVjSG9va3MgPSBbXVxuICAgIHRoaXMuc2VudCA9IGZhbHNlXG4gIH1cblxuICAvKipcbiAgICpcbiAgICogQHBhcmFtIHtudW1iZXJ9IHRpbWVvdXRcbiAgICovXG4gIHJlc2VuZCh0aW1lb3V0KXtcbiAgICB0aGlzLnRpbWVvdXQgPSB0aW1lb3V0XG4gICAgdGhpcy5yZXNldCgpXG4gICAgdGhpcy5zZW5kKClcbiAgfVxuXG4gIC8qKlxuICAgKlxuICAgKi9cbiAgc2VuZCgpe1xuICAgIGlmKHRoaXMuaGFzUmVjZWl2ZWQoXCJ0aW1lb3V0XCIpKXsgcmV0dXJuIH1cbiAgICB0aGlzLnN0YXJ0VGltZW91dCgpXG4gICAgdGhpcy5zZW50ID0gdHJ1ZVxuICAgIHRoaXMuY2hhbm5lbC5zb2NrZXQucHVzaCh7XG4gICAgICB0b3BpYzogdGhpcy5jaGFubmVsLnRvcGljLFxuICAgICAgZXZlbnQ6IHRoaXMuZXZlbnQsXG4gICAgICBwYXlsb2FkOiB0aGlzLnBheWxvYWQoKSxcbiAgICAgIHJlZjogdGhpcy5yZWYsXG4gICAgICBqb2luX3JlZjogdGhpcy5jaGFubmVsLmpvaW5SZWYoKVxuICAgIH0pXG4gIH1cblxuICAvKipcbiAgICpcbiAgICogQHBhcmFtIHsqfSBzdGF0dXNcbiAgICogQHBhcmFtIHsqfSBjYWxsYmFja1xuICAgKi9cbiAgcmVjZWl2ZShzdGF0dXMsIGNhbGxiYWNrKXtcbiAgICBpZih0aGlzLmhhc1JlY2VpdmVkKHN0YXR1cykpe1xuICAgICAgY2FsbGJhY2sodGhpcy5yZWNlaXZlZFJlc3AucmVzcG9uc2UpXG4gICAgfVxuXG4gICAgdGhpcy5yZWNIb29rcy5wdXNoKHtzdGF0dXMsIGNhbGxiYWNrfSlcbiAgICByZXR1cm4gdGhpc1xuICB9XG5cbiAgLyoqXG4gICAqIEBwcml2YXRlXG4gICAqL1xuICByZXNldCgpe1xuICAgIHRoaXMuY2FuY2VsUmVmRXZlbnQoKVxuICAgIHRoaXMucmVmID0gbnVsbFxuICAgIHRoaXMucmVmRXZlbnQgPSBudWxsXG4gICAgdGhpcy5yZWNlaXZlZFJlc3AgPSBudWxsXG4gICAgdGhpcy5zZW50ID0gZmFsc2VcbiAgfVxuXG4gIC8qKlxuICAgKiBAcHJpdmF0ZVxuICAgKi9cbiAgbWF0Y2hSZWNlaXZlKHtzdGF0dXMsIHJlc3BvbnNlLCBfcmVmfSl7XG4gICAgdGhpcy5yZWNIb29rcy5maWx0ZXIoaCA9PiBoLnN0YXR1cyA9PT0gc3RhdHVzKVxuICAgICAgLmZvckVhY2goaCA9PiBoLmNhbGxiYWNrKHJlc3BvbnNlKSlcbiAgfVxuXG4gIC8qKlxuICAgKiBAcHJpdmF0ZVxuICAgKi9cbiAgY2FuY2VsUmVmRXZlbnQoKXtcbiAgICBpZighdGhpcy5yZWZFdmVudCl7IHJldHVybiB9XG4gICAgdGhpcy5jaGFubmVsLm9mZih0aGlzLnJlZkV2ZW50KVxuICB9XG5cbiAgLyoqXG4gICAqIEBwcml2YXRlXG4gICAqL1xuICBjYW5jZWxUaW1lb3V0KCl7XG4gICAgY2xlYXJUaW1lb3V0KHRoaXMudGltZW91dFRpbWVyKVxuICAgIHRoaXMudGltZW91dFRpbWVyID0gbnVsbFxuICB9XG5cbiAgLyoqXG4gICAqIEBwcml2YXRlXG4gICAqL1xuICBzdGFydFRpbWVvdXQoKXtcbiAgICBpZih0aGlzLnRpbWVvdXRUaW1lcil7IHRoaXMuY2FuY2VsVGltZW91dCgpIH1cbiAgICB0aGlzLnJlZiA9IHRoaXMuY2hhbm5lbC5zb2NrZXQubWFrZVJlZigpXG4gICAgdGhpcy5yZWZFdmVudCA9IHRoaXMuY2hhbm5lbC5yZXBseUV2ZW50TmFtZSh0aGlzLnJlZilcblxuICAgIHRoaXMuY2hhbm5lbC5vbih0aGlzLnJlZkV2ZW50LCBwYXlsb2FkID0+IHtcbiAgICAgIHRoaXMuY2FuY2VsUmVmRXZlbnQoKVxuICAgICAgdGhpcy5jYW5jZWxUaW1lb3V0KClcbiAgICAgIHRoaXMucmVjZWl2ZWRSZXNwID0gcGF5bG9hZFxuICAgICAgdGhpcy5tYXRjaFJlY2VpdmUocGF5bG9hZClcbiAgICB9KVxuXG4gICAgdGhpcy50aW1lb3V0VGltZXIgPSBzZXRUaW1lb3V0KCgpID0+IHtcbiAgICAgIHRoaXMudHJpZ2dlcihcInRpbWVvdXRcIiwge30pXG4gICAgfSwgdGhpcy50aW1lb3V0KVxuICB9XG5cbiAgLyoqXG4gICAqIEBwcml2YXRlXG4gICAqL1xuICBoYXNSZWNlaXZlZChzdGF0dXMpe1xuICAgIHJldHVybiB0aGlzLnJlY2VpdmVkUmVzcCAmJiB0aGlzLnJlY2VpdmVkUmVzcC5zdGF0dXMgPT09IHN0YXR1c1xuICB9XG5cbiAgLyoqXG4gICAqIEBwcml2YXRlXG4gICAqL1xuICB0cmlnZ2VyKHN0YXR1cywgcmVzcG9uc2Upe1xuICAgIHRoaXMuY2hhbm5lbC50cmlnZ2VyKHRoaXMucmVmRXZlbnQsIHtzdGF0dXMsIHJlc3BvbnNlfSlcbiAgfVxufVxuIiwgIi8qKlxuICpcbiAqIENyZWF0ZXMgYSB0aW1lciB0aGF0IGFjY2VwdHMgYSBgdGltZXJDYWxjYCBmdW5jdGlvbiB0byBwZXJmb3JtXG4gKiBjYWxjdWxhdGVkIHRpbWVvdXQgcmV0cmllcywgc3VjaCBhcyBleHBvbmVudGlhbCBiYWNrb2ZmLlxuICpcbiAqIEBleGFtcGxlXG4gKiBsZXQgcmVjb25uZWN0VGltZXIgPSBuZXcgVGltZXIoKCkgPT4gdGhpcy5jb25uZWN0KCksIGZ1bmN0aW9uKHRyaWVzKXtcbiAqICAgcmV0dXJuIFsxMDAwLCA1MDAwLCAxMDAwMF1bdHJpZXMgLSAxXSB8fCAxMDAwMFxuICogfSlcbiAqIHJlY29ubmVjdFRpbWVyLnNjaGVkdWxlVGltZW91dCgpIC8vIGZpcmVzIGFmdGVyIDEwMDBcbiAqIHJlY29ubmVjdFRpbWVyLnNjaGVkdWxlVGltZW91dCgpIC8vIGZpcmVzIGFmdGVyIDUwMDBcbiAqIHJlY29ubmVjdFRpbWVyLnJlc2V0KClcbiAqIHJlY29ubmVjdFRpbWVyLnNjaGVkdWxlVGltZW91dCgpIC8vIGZpcmVzIGFmdGVyIDEwMDBcbiAqXG4gKiBAcGFyYW0ge0Z1bmN0aW9ufSBjYWxsYmFja1xuICogQHBhcmFtIHtGdW5jdGlvbn0gdGltZXJDYWxjXG4gKi9cbmV4cG9ydCBkZWZhdWx0IGNsYXNzIFRpbWVyIHtcbiAgY29uc3RydWN0b3IoY2FsbGJhY2ssIHRpbWVyQ2FsYyl7XG4gICAgdGhpcy5jYWxsYmFjayA9IGNhbGxiYWNrXG4gICAgdGhpcy50aW1lckNhbGMgPSB0aW1lckNhbGNcbiAgICB0aGlzLnRpbWVyID0gbnVsbFxuICAgIHRoaXMudHJpZXMgPSAwXG4gIH1cblxuICByZXNldCgpe1xuICAgIHRoaXMudHJpZXMgPSAwXG4gICAgY2xlYXJUaW1lb3V0KHRoaXMudGltZXIpXG4gIH1cblxuICAvKipcbiAgICogQ2FuY2VscyBhbnkgcHJldmlvdXMgc2NoZWR1bGVUaW1lb3V0IGFuZCBzY2hlZHVsZXMgY2FsbGJhY2tcbiAgICovXG4gIHNjaGVkdWxlVGltZW91dCgpe1xuICAgIGNsZWFyVGltZW91dCh0aGlzLnRpbWVyKVxuXG4gICAgdGhpcy50aW1lciA9IHNldFRpbWVvdXQoKCkgPT4ge1xuICAgICAgdGhpcy50cmllcyA9IHRoaXMudHJpZXMgKyAxXG4gICAgICB0aGlzLmNhbGxiYWNrKClcbiAgICB9LCB0aGlzLnRpbWVyQ2FsYyh0aGlzLnRyaWVzICsgMSkpXG4gIH1cbn1cbiIsICJpbXBvcnQge2Nsb3N1cmV9IGZyb20gXCIuL3V0aWxzXCJcbmltcG9ydCB7XG4gIENIQU5ORUxfRVZFTlRTLFxuICBDSEFOTkVMX1NUQVRFUyxcbn0gZnJvbSBcIi4vY29uc3RhbnRzXCJcblxuaW1wb3J0IFB1c2ggZnJvbSBcIi4vcHVzaFwiXG5pbXBvcnQgVGltZXIgZnJvbSBcIi4vdGltZXJcIlxuXG4vKipcbiAqXG4gKiBAcGFyYW0ge3N0cmluZ30gdG9waWNcbiAqIEBwYXJhbSB7KE9iamVjdHxmdW5jdGlvbil9IHBhcmFtc1xuICogQHBhcmFtIHtTb2NrZXR9IHNvY2tldFxuICovXG5leHBvcnQgZGVmYXVsdCBjbGFzcyBDaGFubmVsIHtcbiAgY29uc3RydWN0b3IodG9waWMsIHBhcmFtcywgc29ja2V0KXtcbiAgICB0aGlzLnN0YXRlID0gQ0hBTk5FTF9TVEFURVMuY2xvc2VkXG4gICAgdGhpcy50b3BpYyA9IHRvcGljXG4gICAgdGhpcy5wYXJhbXMgPSBjbG9zdXJlKHBhcmFtcyB8fCB7fSlcbiAgICB0aGlzLnNvY2tldCA9IHNvY2tldFxuICAgIHRoaXMuYmluZGluZ3MgPSBbXVxuICAgIHRoaXMuYmluZGluZ1JlZiA9IDBcbiAgICB0aGlzLnRpbWVvdXQgPSB0aGlzLnNvY2tldC50aW1lb3V0XG4gICAgdGhpcy5qb2luZWRPbmNlID0gZmFsc2VcbiAgICB0aGlzLmpvaW5QdXNoID0gbmV3IFB1c2godGhpcywgQ0hBTk5FTF9FVkVOVFMuam9pbiwgdGhpcy5wYXJhbXMsIHRoaXMudGltZW91dClcbiAgICB0aGlzLnB1c2hCdWZmZXIgPSBbXVxuICAgIHRoaXMuc3RhdGVDaGFuZ2VSZWZzID0gW11cblxuICAgIHRoaXMucmVqb2luVGltZXIgPSBuZXcgVGltZXIoKCkgPT4ge1xuICAgICAgaWYodGhpcy5zb2NrZXQuaXNDb25uZWN0ZWQoKSl7IHRoaXMucmVqb2luKCkgfVxuICAgIH0sIHRoaXMuc29ja2V0LnJlam9pbkFmdGVyTXMpXG4gICAgdGhpcy5zdGF0ZUNoYW5nZVJlZnMucHVzaCh0aGlzLnNvY2tldC5vbkVycm9yKCgpID0+IHRoaXMucmVqb2luVGltZXIucmVzZXQoKSkpXG4gICAgdGhpcy5zdGF0ZUNoYW5nZVJlZnMucHVzaCh0aGlzLnNvY2tldC5vbk9wZW4oKCkgPT4ge1xuICAgICAgdGhpcy5yZWpvaW5UaW1lci5yZXNldCgpXG4gICAgICBpZih0aGlzLmlzRXJyb3JlZCgpKXsgdGhpcy5yZWpvaW4oKSB9XG4gICAgfSlcbiAgICApXG4gICAgdGhpcy5qb2luUHVzaC5yZWNlaXZlKFwib2tcIiwgKCkgPT4ge1xuICAgICAgdGhpcy5zdGF0ZSA9IENIQU5ORUxfU1RBVEVTLmpvaW5lZFxuICAgICAgdGhpcy5yZWpvaW5UaW1lci5yZXNldCgpXG4gICAgICB0aGlzLnB1c2hCdWZmZXIuZm9yRWFjaChwdXNoRXZlbnQgPT4gcHVzaEV2ZW50LnNlbmQoKSlcbiAgICAgIHRoaXMucHVzaEJ1ZmZlciA9IFtdXG4gICAgfSlcbiAgICB0aGlzLmpvaW5QdXNoLnJlY2VpdmUoXCJlcnJvclwiLCAoKSA9PiB7XG4gICAgICB0aGlzLnN0YXRlID0gQ0hBTk5FTF9TVEFURVMuZXJyb3JlZFxuICAgICAgaWYodGhpcy5zb2NrZXQuaXNDb25uZWN0ZWQoKSl7IHRoaXMucmVqb2luVGltZXIuc2NoZWR1bGVUaW1lb3V0KCkgfVxuICAgIH0pXG4gICAgdGhpcy5vbkNsb3NlKCgpID0+IHtcbiAgICAgIHRoaXMucmVqb2luVGltZXIucmVzZXQoKVxuICAgICAgaWYodGhpcy5zb2NrZXQuaGFzTG9nZ2VyKCkpIHRoaXMuc29ja2V0LmxvZyhcImNoYW5uZWxcIiwgYGNsb3NlICR7dGhpcy50b3BpY30gJHt0aGlzLmpvaW5SZWYoKX1gKVxuICAgICAgdGhpcy5zdGF0ZSA9IENIQU5ORUxfU1RBVEVTLmNsb3NlZFxuICAgICAgdGhpcy5zb2NrZXQucmVtb3ZlKHRoaXMpXG4gICAgfSlcbiAgICB0aGlzLm9uRXJyb3IocmVhc29uID0+IHtcbiAgICAgIGlmKHRoaXMuc29ja2V0Lmhhc0xvZ2dlcigpKSB0aGlzLnNvY2tldC5sb2coXCJjaGFubmVsXCIsIGBlcnJvciAke3RoaXMudG9waWN9YCwgcmVhc29uKVxuICAgICAgaWYodGhpcy5pc0pvaW5pbmcoKSl7IHRoaXMuam9pblB1c2gucmVzZXQoKSB9XG4gICAgICB0aGlzLnN0YXRlID0gQ0hBTk5FTF9TVEFURVMuZXJyb3JlZFxuICAgICAgaWYodGhpcy5zb2NrZXQuaXNDb25uZWN0ZWQoKSl7IHRoaXMucmVqb2luVGltZXIuc2NoZWR1bGVUaW1lb3V0KCkgfVxuICAgIH0pXG4gICAgdGhpcy5qb2luUHVzaC5yZWNlaXZlKFwidGltZW91dFwiLCAoKSA9PiB7XG4gICAgICBpZih0aGlzLnNvY2tldC5oYXNMb2dnZXIoKSkgdGhpcy5zb2NrZXQubG9nKFwiY2hhbm5lbFwiLCBgdGltZW91dCAke3RoaXMudG9waWN9ICgke3RoaXMuam9pblJlZigpfSlgLCB0aGlzLmpvaW5QdXNoLnRpbWVvdXQpXG4gICAgICBsZXQgbGVhdmVQdXNoID0gbmV3IFB1c2godGhpcywgQ0hBTk5FTF9FVkVOVFMubGVhdmUsIGNsb3N1cmUoe30pLCB0aGlzLnRpbWVvdXQpXG4gICAgICBsZWF2ZVB1c2guc2VuZCgpXG4gICAgICB0aGlzLnN0YXRlID0gQ0hBTk5FTF9TVEFURVMuZXJyb3JlZFxuICAgICAgdGhpcy5qb2luUHVzaC5yZXNldCgpXG4gICAgICBpZih0aGlzLnNvY2tldC5pc0Nvbm5lY3RlZCgpKXsgdGhpcy5yZWpvaW5UaW1lci5zY2hlZHVsZVRpbWVvdXQoKSB9XG4gICAgfSlcbiAgICB0aGlzLm9uKENIQU5ORUxfRVZFTlRTLnJlcGx5LCAocGF5bG9hZCwgcmVmKSA9PiB7XG4gICAgICB0aGlzLnRyaWdnZXIodGhpcy5yZXBseUV2ZW50TmFtZShyZWYpLCBwYXlsb2FkKVxuICAgIH0pXG4gIH1cblxuICAvKipcbiAgICogSm9pbiB0aGUgY2hhbm5lbFxuICAgKiBAcGFyYW0ge2ludGVnZXJ9IHRpbWVvdXRcbiAgICogQHJldHVybnMge1B1c2h9XG4gICAqL1xuICBqb2luKHRpbWVvdXQgPSB0aGlzLnRpbWVvdXQpe1xuICAgIGlmKHRoaXMuam9pbmVkT25jZSl7XG4gICAgICB0aHJvdyBuZXcgRXJyb3IoXCJ0cmllZCB0byBqb2luIG11bHRpcGxlIHRpbWVzLiAnam9pbicgY2FuIG9ubHkgYmUgY2FsbGVkIGEgc2luZ2xlIHRpbWUgcGVyIGNoYW5uZWwgaW5zdGFuY2VcIilcbiAgICB9IGVsc2Uge1xuICAgICAgdGhpcy50aW1lb3V0ID0gdGltZW91dFxuICAgICAgdGhpcy5qb2luZWRPbmNlID0gdHJ1ZVxuICAgICAgdGhpcy5yZWpvaW4oKVxuICAgICAgcmV0dXJuIHRoaXMuam9pblB1c2hcbiAgICB9XG4gIH1cblxuICAvKipcbiAgICogSG9vayBpbnRvIGNoYW5uZWwgY2xvc2VcbiAgICogQHBhcmFtIHtGdW5jdGlvbn0gY2FsbGJhY2tcbiAgICovXG4gIG9uQ2xvc2UoY2FsbGJhY2spe1xuICAgIHRoaXMub24oQ0hBTk5FTF9FVkVOVFMuY2xvc2UsIGNhbGxiYWNrKVxuICB9XG5cbiAgLyoqXG4gICAqIEhvb2sgaW50byBjaGFubmVsIGVycm9yc1xuICAgKiBAcGFyYW0ge0Z1bmN0aW9ufSBjYWxsYmFja1xuICAgKi9cbiAgb25FcnJvcihjYWxsYmFjayl7XG4gICAgcmV0dXJuIHRoaXMub24oQ0hBTk5FTF9FVkVOVFMuZXJyb3IsIHJlYXNvbiA9PiBjYWxsYmFjayhyZWFzb24pKVxuICB9XG5cbiAgLyoqXG4gICAqIFN1YnNjcmliZXMgb24gY2hhbm5lbCBldmVudHNcbiAgICpcbiAgICogU3Vic2NyaXB0aW9uIHJldHVybnMgYSByZWYgY291bnRlciwgd2hpY2ggY2FuIGJlIHVzZWQgbGF0ZXIgdG9cbiAgICogdW5zdWJzY3JpYmUgdGhlIGV4YWN0IGV2ZW50IGxpc3RlbmVyXG4gICAqXG4gICAqIEBleGFtcGxlXG4gICAqIGNvbnN0IHJlZjEgPSBjaGFubmVsLm9uKFwiZXZlbnRcIiwgZG9fc3R1ZmYpXG4gICAqIGNvbnN0IHJlZjIgPSBjaGFubmVsLm9uKFwiZXZlbnRcIiwgZG9fb3RoZXJfc3R1ZmYpXG4gICAqIGNoYW5uZWwub2ZmKFwiZXZlbnRcIiwgcmVmMSlcbiAgICogLy8gU2luY2UgdW5zdWJzY3JpcHRpb24sIGRvX3N0dWZmIHdvbid0IGZpcmUsXG4gICAqIC8vIHdoaWxlIGRvX290aGVyX3N0dWZmIHdpbGwga2VlcCBmaXJpbmcgb24gdGhlIFwiZXZlbnRcIlxuICAgKlxuICAgKiBAcGFyYW0ge3N0cmluZ30gZXZlbnRcbiAgICogQHBhcmFtIHtGdW5jdGlvbn0gY2FsbGJhY2tcbiAgICogQHJldHVybnMge2ludGVnZXJ9IHJlZlxuICAgKi9cbiAgb24oZXZlbnQsIGNhbGxiYWNrKXtcbiAgICBsZXQgcmVmID0gdGhpcy5iaW5kaW5nUmVmKytcbiAgICB0aGlzLmJpbmRpbmdzLnB1c2goe2V2ZW50LCByZWYsIGNhbGxiYWNrfSlcbiAgICByZXR1cm4gcmVmXG4gIH1cblxuICAvKipcbiAgICogVW5zdWJzY3JpYmVzIG9mZiBvZiBjaGFubmVsIGV2ZW50c1xuICAgKlxuICAgKiBVc2UgdGhlIHJlZiByZXR1cm5lZCBmcm9tIGEgY2hhbm5lbC5vbigpIHRvIHVuc3Vic2NyaWJlIG9uZVxuICAgKiBoYW5kbGVyLCBvciBwYXNzIG5vdGhpbmcgZm9yIHRoZSByZWYgdG8gdW5zdWJzY3JpYmUgYWxsXG4gICAqIGhhbmRsZXJzIGZvciB0aGUgZ2l2ZW4gZXZlbnQuXG4gICAqXG4gICAqIEBleGFtcGxlXG4gICAqIC8vIFVuc3Vic2NyaWJlIHRoZSBkb19zdHVmZiBoYW5kbGVyXG4gICAqIGNvbnN0IHJlZjEgPSBjaGFubmVsLm9uKFwiZXZlbnRcIiwgZG9fc3R1ZmYpXG4gICAqIGNoYW5uZWwub2ZmKFwiZXZlbnRcIiwgcmVmMSlcbiAgICpcbiAgICogLy8gVW5zdWJzY3JpYmUgYWxsIGhhbmRsZXJzIGZyb20gZXZlbnRcbiAgICogY2hhbm5lbC5vZmYoXCJldmVudFwiKVxuICAgKlxuICAgKiBAcGFyYW0ge3N0cmluZ30gZXZlbnRcbiAgICogQHBhcmFtIHtpbnRlZ2VyfSByZWZcbiAgICovXG4gIG9mZihldmVudCwgcmVmKXtcbiAgICB0aGlzLmJpbmRpbmdzID0gdGhpcy5iaW5kaW5ncy5maWx0ZXIoKGJpbmQpID0+IHtcbiAgICAgIHJldHVybiAhKGJpbmQuZXZlbnQgPT09IGV2ZW50ICYmICh0eXBlb2YgcmVmID09PSBcInVuZGVmaW5lZFwiIHx8IHJlZiA9PT0gYmluZC5yZWYpKVxuICAgIH0pXG4gIH1cblxuICAvKipcbiAgICogQHByaXZhdGVcbiAgICovXG4gIGNhblB1c2goKXsgcmV0dXJuIHRoaXMuc29ja2V0LmlzQ29ubmVjdGVkKCkgJiYgdGhpcy5pc0pvaW5lZCgpIH1cblxuICAvKipcbiAgICogU2VuZHMgYSBtZXNzYWdlIGBldmVudGAgdG8gcGhvZW5peCB3aXRoIHRoZSBwYXlsb2FkIGBwYXlsb2FkYC5cbiAgICogUGhvZW5peCByZWNlaXZlcyB0aGlzIGluIHRoZSBgaGFuZGxlX2luKGV2ZW50LCBwYXlsb2FkLCBzb2NrZXQpYFxuICAgKiBmdW5jdGlvbi4gaWYgcGhvZW5peCByZXBsaWVzIG9yIGl0IHRpbWVzIG91dCAoZGVmYXVsdCAxMDAwMG1zKSxcbiAgICogdGhlbiBvcHRpb25hbGx5IHRoZSByZXBseSBjYW4gYmUgcmVjZWl2ZWQuXG4gICAqXG4gICAqIEBleGFtcGxlXG4gICAqIGNoYW5uZWwucHVzaChcImV2ZW50XCIpXG4gICAqICAgLnJlY2VpdmUoXCJva1wiLCBwYXlsb2FkID0+IGNvbnNvbGUubG9nKFwicGhvZW5peCByZXBsaWVkOlwiLCBwYXlsb2FkKSlcbiAgICogICAucmVjZWl2ZShcImVycm9yXCIsIGVyciA9PiBjb25zb2xlLmxvZyhcInBob2VuaXggZXJyb3JlZFwiLCBlcnIpKVxuICAgKiAgIC5yZWNlaXZlKFwidGltZW91dFwiLCAoKSA9PiBjb25zb2xlLmxvZyhcInRpbWVkIG91dCBwdXNoaW5nXCIpKVxuICAgKiBAcGFyYW0ge3N0cmluZ30gZXZlbnRcbiAgICogQHBhcmFtIHtPYmplY3R9IHBheWxvYWRcbiAgICogQHBhcmFtIHtudW1iZXJ9IFt0aW1lb3V0XVxuICAgKiBAcmV0dXJucyB7UHVzaH1cbiAgICovXG4gIHB1c2goZXZlbnQsIHBheWxvYWQsIHRpbWVvdXQgPSB0aGlzLnRpbWVvdXQpe1xuICAgIHBheWxvYWQgPSBwYXlsb2FkIHx8IHt9XG4gICAgaWYoIXRoaXMuam9pbmVkT25jZSl7XG4gICAgICB0aHJvdyBuZXcgRXJyb3IoYHRyaWVkIHRvIHB1c2ggJyR7ZXZlbnR9JyB0byAnJHt0aGlzLnRvcGljfScgYmVmb3JlIGpvaW5pbmcuIFVzZSBjaGFubmVsLmpvaW4oKSBiZWZvcmUgcHVzaGluZyBldmVudHNgKVxuICAgIH1cbiAgICBsZXQgcHVzaEV2ZW50ID0gbmV3IFB1c2godGhpcywgZXZlbnQsIGZ1bmN0aW9uICgpeyByZXR1cm4gcGF5bG9hZCB9LCB0aW1lb3V0KVxuICAgIGlmKHRoaXMuY2FuUHVzaCgpKXtcbiAgICAgIHB1c2hFdmVudC5zZW5kKClcbiAgICB9IGVsc2Uge1xuICAgICAgcHVzaEV2ZW50LnN0YXJ0VGltZW91dCgpXG4gICAgICB0aGlzLnB1c2hCdWZmZXIucHVzaChwdXNoRXZlbnQpXG4gICAgfVxuXG4gICAgcmV0dXJuIHB1c2hFdmVudFxuICB9XG5cbiAgLyoqIExlYXZlcyB0aGUgY2hhbm5lbFxuICAgKlxuICAgKiBVbnN1YnNjcmliZXMgZnJvbSBzZXJ2ZXIgZXZlbnRzLCBhbmRcbiAgICogaW5zdHJ1Y3RzIGNoYW5uZWwgdG8gdGVybWluYXRlIG9uIHNlcnZlclxuICAgKlxuICAgKiBUcmlnZ2VycyBvbkNsb3NlKCkgaG9va3NcbiAgICpcbiAgICogVG8gcmVjZWl2ZSBsZWF2ZSBhY2tub3dsZWRnZW1lbnRzLCB1c2UgdGhlIGByZWNlaXZlYFxuICAgKiBob29rIHRvIGJpbmQgdG8gdGhlIHNlcnZlciBhY2ssIGllOlxuICAgKlxuICAgKiBAZXhhbXBsZVxuICAgKiBjaGFubmVsLmxlYXZlKCkucmVjZWl2ZShcIm9rXCIsICgpID0+IGFsZXJ0KFwibGVmdCFcIikgKVxuICAgKlxuICAgKiBAcGFyYW0ge2ludGVnZXJ9IHRpbWVvdXRcbiAgICogQHJldHVybnMge1B1c2h9XG4gICAqL1xuICBsZWF2ZSh0aW1lb3V0ID0gdGhpcy50aW1lb3V0KXtcbiAgICB0aGlzLnJlam9pblRpbWVyLnJlc2V0KClcbiAgICB0aGlzLmpvaW5QdXNoLmNhbmNlbFRpbWVvdXQoKVxuXG4gICAgdGhpcy5zdGF0ZSA9IENIQU5ORUxfU1RBVEVTLmxlYXZpbmdcbiAgICBsZXQgb25DbG9zZSA9ICgpID0+IHtcbiAgICAgIGlmKHRoaXMuc29ja2V0Lmhhc0xvZ2dlcigpKSB0aGlzLnNvY2tldC5sb2coXCJjaGFubmVsXCIsIGBsZWF2ZSAke3RoaXMudG9waWN9YClcbiAgICAgIHRoaXMudHJpZ2dlcihDSEFOTkVMX0VWRU5UUy5jbG9zZSwgXCJsZWF2ZVwiKVxuICAgIH1cbiAgICBsZXQgbGVhdmVQdXNoID0gbmV3IFB1c2godGhpcywgQ0hBTk5FTF9FVkVOVFMubGVhdmUsIGNsb3N1cmUoe30pLCB0aW1lb3V0KVxuICAgIGxlYXZlUHVzaC5yZWNlaXZlKFwib2tcIiwgKCkgPT4gb25DbG9zZSgpKVxuICAgICAgLnJlY2VpdmUoXCJ0aW1lb3V0XCIsICgpID0+IG9uQ2xvc2UoKSlcbiAgICBsZWF2ZVB1c2guc2VuZCgpXG4gICAgaWYoIXRoaXMuY2FuUHVzaCgpKXsgbGVhdmVQdXNoLnRyaWdnZXIoXCJva1wiLCB7fSkgfVxuXG4gICAgcmV0dXJuIGxlYXZlUHVzaFxuICB9XG5cbiAgLyoqXG4gICAqIE92ZXJyaWRhYmxlIG1lc3NhZ2UgaG9va1xuICAgKlxuICAgKiBSZWNlaXZlcyBhbGwgZXZlbnRzIGZvciBzcGVjaWFsaXplZCBtZXNzYWdlIGhhbmRsaW5nXG4gICAqIGJlZm9yZSBkaXNwYXRjaGluZyB0byB0aGUgY2hhbm5lbCBjYWxsYmFja3MuXG4gICAqXG4gICAqIE11c3QgcmV0dXJuIHRoZSBwYXlsb2FkLCBtb2RpZmllZCBvciB1bm1vZGlmaWVkXG4gICAqIEBwYXJhbSB7c3RyaW5nfSBldmVudFxuICAgKiBAcGFyYW0ge09iamVjdH0gcGF5bG9hZFxuICAgKiBAcGFyYW0ge2ludGVnZXJ9IHJlZlxuICAgKiBAcmV0dXJucyB7T2JqZWN0fVxuICAgKi9cbiAgb25NZXNzYWdlKF9ldmVudCwgcGF5bG9hZCwgX3JlZil7IHJldHVybiBwYXlsb2FkIH1cblxuICAvKipcbiAgICogQHByaXZhdGVcbiAgICovXG4gIGlzTWVtYmVyKHRvcGljLCBldmVudCwgcGF5bG9hZCwgam9pblJlZil7XG4gICAgaWYodGhpcy50b3BpYyAhPT0gdG9waWMpeyByZXR1cm4gZmFsc2UgfVxuXG4gICAgaWYoam9pblJlZiAmJiBqb2luUmVmICE9PSB0aGlzLmpvaW5SZWYoKSl7XG4gICAgICBpZih0aGlzLnNvY2tldC5oYXNMb2dnZXIoKSkgdGhpcy5zb2NrZXQubG9nKFwiY2hhbm5lbFwiLCBcImRyb3BwaW5nIG91dGRhdGVkIG1lc3NhZ2VcIiwge3RvcGljLCBldmVudCwgcGF5bG9hZCwgam9pblJlZn0pXG4gICAgICByZXR1cm4gZmFsc2VcbiAgICB9IGVsc2Uge1xuICAgICAgcmV0dXJuIHRydWVcbiAgICB9XG4gIH1cblxuICAvKipcbiAgICogQHByaXZhdGVcbiAgICovXG4gIGpvaW5SZWYoKXsgcmV0dXJuIHRoaXMuam9pblB1c2gucmVmIH1cblxuICAvKipcbiAgICogQHByaXZhdGVcbiAgICovXG4gIHJlam9pbih0aW1lb3V0ID0gdGhpcy50aW1lb3V0KXtcbiAgICBpZih0aGlzLmlzTGVhdmluZygpKXsgcmV0dXJuIH1cbiAgICB0aGlzLnNvY2tldC5sZWF2ZU9wZW5Ub3BpYyh0aGlzLnRvcGljKVxuICAgIHRoaXMuc3RhdGUgPSBDSEFOTkVMX1NUQVRFUy5qb2luaW5nXG4gICAgdGhpcy5qb2luUHVzaC5yZXNlbmQodGltZW91dClcbiAgfVxuXG4gIC8qKlxuICAgKiBAcHJpdmF0ZVxuICAgKi9cbiAgdHJpZ2dlcihldmVudCwgcGF5bG9hZCwgcmVmLCBqb2luUmVmKXtcbiAgICBsZXQgaGFuZGxlZFBheWxvYWQgPSB0aGlzLm9uTWVzc2FnZShldmVudCwgcGF5bG9hZCwgcmVmLCBqb2luUmVmKVxuICAgIGlmKHBheWxvYWQgJiYgIWhhbmRsZWRQYXlsb2FkKXsgdGhyb3cgbmV3IEVycm9yKFwiY2hhbm5lbCBvbk1lc3NhZ2UgY2FsbGJhY2tzIG11c3QgcmV0dXJuIHRoZSBwYXlsb2FkLCBtb2RpZmllZCBvciB1bm1vZGlmaWVkXCIpIH1cblxuICAgIGxldCBldmVudEJpbmRpbmdzID0gdGhpcy5iaW5kaW5ncy5maWx0ZXIoYmluZCA9PiBiaW5kLmV2ZW50ID09PSBldmVudClcblxuICAgIGZvcihsZXQgaSA9IDA7IGkgPCBldmVudEJpbmRpbmdzLmxlbmd0aDsgaSsrKXtcbiAgICAgIGxldCBiaW5kID0gZXZlbnRCaW5kaW5nc1tpXVxuICAgICAgYmluZC5jYWxsYmFjayhoYW5kbGVkUGF5bG9hZCwgcmVmLCBqb2luUmVmIHx8IHRoaXMuam9pblJlZigpKVxuICAgIH1cbiAgfVxuXG4gIC8qKlxuICAgKiBAcHJpdmF0ZVxuICAgKi9cbiAgcmVwbHlFdmVudE5hbWUocmVmKXsgcmV0dXJuIGBjaGFuX3JlcGx5XyR7cmVmfWAgfVxuXG4gIC8qKlxuICAgKiBAcHJpdmF0ZVxuICAgKi9cbiAgaXNDbG9zZWQoKXsgcmV0dXJuIHRoaXMuc3RhdGUgPT09IENIQU5ORUxfU1RBVEVTLmNsb3NlZCB9XG5cbiAgLyoqXG4gICAqIEBwcml2YXRlXG4gICAqL1xuICBpc0Vycm9yZWQoKXsgcmV0dXJuIHRoaXMuc3RhdGUgPT09IENIQU5ORUxfU1RBVEVTLmVycm9yZWQgfVxuXG4gIC8qKlxuICAgKiBAcHJpdmF0ZVxuICAgKi9cbiAgaXNKb2luZWQoKXsgcmV0dXJuIHRoaXMuc3RhdGUgPT09IENIQU5ORUxfU1RBVEVTLmpvaW5lZCB9XG5cbiAgLyoqXG4gICAqIEBwcml2YXRlXG4gICAqL1xuICBpc0pvaW5pbmcoKXsgcmV0dXJuIHRoaXMuc3RhdGUgPT09IENIQU5ORUxfU1RBVEVTLmpvaW5pbmcgfVxuXG4gIC8qKlxuICAgKiBAcHJpdmF0ZVxuICAgKi9cbiAgaXNMZWF2aW5nKCl7IHJldHVybiB0aGlzLnN0YXRlID09PSBDSEFOTkVMX1NUQVRFUy5sZWF2aW5nIH1cbn1cbiIsICJpbXBvcnQge1xuICBnbG9iYWwsXG4gIFhIUl9TVEFURVNcbn0gZnJvbSBcIi4vY29uc3RhbnRzXCJcblxuZXhwb3J0IGRlZmF1bHQgY2xhc3MgQWpheCB7XG5cbiAgc3RhdGljIHJlcXVlc3QobWV0aG9kLCBlbmRQb2ludCwgaGVhZGVycywgYm9keSwgdGltZW91dCwgb250aW1lb3V0LCBjYWxsYmFjayl7XG4gICAgaWYoZ2xvYmFsLlhEb21haW5SZXF1ZXN0KXtcbiAgICAgIGxldCByZXEgPSBuZXcgZ2xvYmFsLlhEb21haW5SZXF1ZXN0KCkgLy8gSUU4LCBJRTlcbiAgICAgIHJldHVybiB0aGlzLnhkb21haW5SZXF1ZXN0KHJlcSwgbWV0aG9kLCBlbmRQb2ludCwgYm9keSwgdGltZW91dCwgb250aW1lb3V0LCBjYWxsYmFjaylcbiAgICB9IGVsc2UgaWYoZ2xvYmFsLlhNTEh0dHBSZXF1ZXN0KXtcbiAgICAgIGxldCByZXEgPSBuZXcgZ2xvYmFsLlhNTEh0dHBSZXF1ZXN0KCkgLy8gSUU3KywgRmlyZWZveCwgQ2hyb21lLCBPcGVyYSwgU2FmYXJpXG4gICAgICByZXR1cm4gdGhpcy54aHJSZXF1ZXN0KHJlcSwgbWV0aG9kLCBlbmRQb2ludCwgaGVhZGVycywgYm9keSwgdGltZW91dCwgb250aW1lb3V0LCBjYWxsYmFjaylcbiAgICB9IGVsc2UgaWYoZ2xvYmFsLmZldGNoICYmIGdsb2JhbC5BYm9ydENvbnRyb2xsZXIpe1xuICAgICAgLy8gRmV0Y2ggd2l0aCBBYm9ydENvbnRyb2xsZXIgZm9yIG1vZGVybiBicm93c2Vyc1xuICAgICAgcmV0dXJuIHRoaXMuZmV0Y2hSZXF1ZXN0KG1ldGhvZCwgZW5kUG9pbnQsIGhlYWRlcnMsIGJvZHksIHRpbWVvdXQsIG9udGltZW91dCwgY2FsbGJhY2spXG4gICAgfSBlbHNlIHtcbiAgICAgIHRocm93IG5ldyBFcnJvcihcIk5vIHN1aXRhYmxlIFhNTEh0dHBSZXF1ZXN0IGltcGxlbWVudGF0aW9uIGZvdW5kXCIpXG4gICAgfVxuICB9XG5cbiAgc3RhdGljIGZldGNoUmVxdWVzdChtZXRob2QsIGVuZFBvaW50LCBoZWFkZXJzLCBib2R5LCB0aW1lb3V0LCBvbnRpbWVvdXQsIGNhbGxiYWNrKXtcbiAgICBsZXQgb3B0aW9ucyA9IHtcbiAgICAgIG1ldGhvZCxcbiAgICAgIGhlYWRlcnMsXG4gICAgICBib2R5LFxuICAgIH1cbiAgICBsZXQgY29udHJvbGxlciA9IG51bGxcbiAgICBpZih0aW1lb3V0KXtcbiAgICAgIGNvbnRyb2xsZXIgPSBuZXcgQWJvcnRDb250cm9sbGVyKClcbiAgICAgIGNvbnN0IF90aW1lb3V0SWQgPSBzZXRUaW1lb3V0KCgpID0+IGNvbnRyb2xsZXIuYWJvcnQoKSwgdGltZW91dClcbiAgICAgIG9wdGlvbnMuc2lnbmFsID0gY29udHJvbGxlci5zaWduYWxcbiAgICB9XG4gICAgZ2xvYmFsLmZldGNoKGVuZFBvaW50LCBvcHRpb25zKVxuICAgICAgLnRoZW4ocmVzcG9uc2UgPT4gcmVzcG9uc2UudGV4dCgpKVxuICAgICAgLnRoZW4oZGF0YSA9PiB0aGlzLnBhcnNlSlNPTihkYXRhKSlcbiAgICAgIC50aGVuKGRhdGEgPT4gY2FsbGJhY2sgJiYgY2FsbGJhY2soZGF0YSkpXG4gICAgICAuY2F0Y2goZXJyID0+IHtcbiAgICAgICAgaWYoZXJyLm5hbWUgPT09IFwiQWJvcnRFcnJvclwiICYmIG9udGltZW91dCl7XG4gICAgICAgICAgb250aW1lb3V0KClcbiAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICBjYWxsYmFjayAmJiBjYWxsYmFjayhudWxsKVxuICAgICAgICB9XG4gICAgICB9KVxuICAgIHJldHVybiBjb250cm9sbGVyXG4gIH1cblxuICBzdGF0aWMgeGRvbWFpblJlcXVlc3QocmVxLCBtZXRob2QsIGVuZFBvaW50LCBib2R5LCB0aW1lb3V0LCBvbnRpbWVvdXQsIGNhbGxiYWNrKXtcbiAgICByZXEudGltZW91dCA9IHRpbWVvdXRcbiAgICByZXEub3BlbihtZXRob2QsIGVuZFBvaW50KVxuICAgIHJlcS5vbmxvYWQgPSAoKSA9PiB7XG4gICAgICBsZXQgcmVzcG9uc2UgPSB0aGlzLnBhcnNlSlNPTihyZXEucmVzcG9uc2VUZXh0KVxuICAgICAgY2FsbGJhY2sgJiYgY2FsbGJhY2socmVzcG9uc2UpXG4gICAgfVxuICAgIGlmKG9udGltZW91dCl7IHJlcS5vbnRpbWVvdXQgPSBvbnRpbWVvdXQgfVxuXG4gICAgLy8gV29yayBhcm91bmQgYnVnIGluIElFOSB0aGF0IHJlcXVpcmVzIGFuIGF0dGFjaGVkIG9ucHJvZ3Jlc3MgaGFuZGxlclxuICAgIHJlcS5vbnByb2dyZXNzID0gKCkgPT4geyB9XG5cbiAgICByZXEuc2VuZChib2R5KVxuICAgIHJldHVybiByZXFcbiAgfVxuXG4gIHN0YXRpYyB4aHJSZXF1ZXN0KHJlcSwgbWV0aG9kLCBlbmRQb2ludCwgaGVhZGVycywgYm9keSwgdGltZW91dCwgb250aW1lb3V0LCBjYWxsYmFjayl7XG4gICAgcmVxLm9wZW4obWV0aG9kLCBlbmRQb2ludCwgdHJ1ZSlcbiAgICByZXEudGltZW91dCA9IHRpbWVvdXRcbiAgICBmb3IobGV0IFtrZXksIHZhbHVlXSBvZiBPYmplY3QuZW50cmllcyhoZWFkZXJzKSl7XG4gICAgICByZXEuc2V0UmVxdWVzdEhlYWRlcihrZXksIHZhbHVlKVxuICAgIH1cbiAgICByZXEub25lcnJvciA9ICgpID0+IGNhbGxiYWNrICYmIGNhbGxiYWNrKG51bGwpXG4gICAgcmVxLm9ucmVhZHlzdGF0ZWNoYW5nZSA9ICgpID0+IHtcbiAgICAgIGlmKHJlcS5yZWFkeVN0YXRlID09PSBYSFJfU1RBVEVTLmNvbXBsZXRlICYmIGNhbGxiYWNrKXtcbiAgICAgICAgbGV0IHJlc3BvbnNlID0gdGhpcy5wYXJzZUpTT04ocmVxLnJlc3BvbnNlVGV4dClcbiAgICAgICAgY2FsbGJhY2socmVzcG9uc2UpXG4gICAgICB9XG4gICAgfVxuICAgIGlmKG9udGltZW91dCl7IHJlcS5vbnRpbWVvdXQgPSBvbnRpbWVvdXQgfVxuXG4gICAgcmVxLnNlbmQoYm9keSlcbiAgICByZXR1cm4gcmVxXG4gIH1cblxuICBzdGF0aWMgcGFyc2VKU09OKHJlc3Ape1xuICAgIGlmKCFyZXNwIHx8IHJlc3AgPT09IFwiXCIpeyByZXR1cm4gbnVsbCB9XG5cbiAgICB0cnkge1xuICAgICAgcmV0dXJuIEpTT04ucGFyc2UocmVzcClcbiAgICB9IGNhdGNoIHtcbiAgICAgIGNvbnNvbGUgJiYgY29uc29sZS5sb2coXCJmYWlsZWQgdG8gcGFyc2UgSlNPTiByZXNwb25zZVwiLCByZXNwKVxuICAgICAgcmV0dXJuIG51bGxcbiAgICB9XG4gIH1cblxuICBzdGF0aWMgc2VyaWFsaXplKG9iaiwgcGFyZW50S2V5KXtcbiAgICBsZXQgcXVlcnlTdHIgPSBbXVxuICAgIGZvcih2YXIga2V5IGluIG9iail7XG4gICAgICBpZighT2JqZWN0LnByb3RvdHlwZS5oYXNPd25Qcm9wZXJ0eS5jYWxsKG9iaiwga2V5KSl7IGNvbnRpbnVlIH1cbiAgICAgIGxldCBwYXJhbUtleSA9IHBhcmVudEtleSA/IGAke3BhcmVudEtleX1bJHtrZXl9XWAgOiBrZXlcbiAgICAgIGxldCBwYXJhbVZhbCA9IG9ialtrZXldXG4gICAgICBpZih0eXBlb2YgcGFyYW1WYWwgPT09IFwib2JqZWN0XCIpe1xuICAgICAgICBxdWVyeVN0ci5wdXNoKHRoaXMuc2VyaWFsaXplKHBhcmFtVmFsLCBwYXJhbUtleSkpXG4gICAgICB9IGVsc2Uge1xuICAgICAgICBxdWVyeVN0ci5wdXNoKGVuY29kZVVSSUNvbXBvbmVudChwYXJhbUtleSkgKyBcIj1cIiArIGVuY29kZVVSSUNvbXBvbmVudChwYXJhbVZhbCkpXG4gICAgICB9XG4gICAgfVxuICAgIHJldHVybiBxdWVyeVN0ci5qb2luKFwiJlwiKVxuICB9XG5cbiAgc3RhdGljIGFwcGVuZFBhcmFtcyh1cmwsIHBhcmFtcyl7XG4gICAgaWYoT2JqZWN0LmtleXMocGFyYW1zKS5sZW5ndGggPT09IDApeyByZXR1cm4gdXJsIH1cblxuICAgIGxldCBwcmVmaXggPSB1cmwubWF0Y2goL1xcPy8pID8gXCImXCIgOiBcIj9cIlxuICAgIHJldHVybiBgJHt1cmx9JHtwcmVmaXh9JHt0aGlzLnNlcmlhbGl6ZShwYXJhbXMpfWBcbiAgfVxufVxuIiwgImltcG9ydCB7XG4gIFNPQ0tFVF9TVEFURVMsXG4gIFRSQU5TUE9SVFMsXG4gIEFVVEhfVE9LRU5fUFJFRklYXG59IGZyb20gXCIuL2NvbnN0YW50c1wiXG5cbmltcG9ydCBBamF4IGZyb20gXCIuL2FqYXhcIlxuXG5sZXQgYXJyYXlCdWZmZXJUb0Jhc2U2NCA9IChidWZmZXIpID0+IHtcbiAgbGV0IGJpbmFyeSA9IFwiXCJcbiAgbGV0IGJ5dGVzID0gbmV3IFVpbnQ4QXJyYXkoYnVmZmVyKVxuICBsZXQgbGVuID0gYnl0ZXMuYnl0ZUxlbmd0aFxuICBmb3IobGV0IGkgPSAwOyBpIDwgbGVuOyBpKyspeyBiaW5hcnkgKz0gU3RyaW5nLmZyb21DaGFyQ29kZShieXRlc1tpXSkgfVxuICByZXR1cm4gYnRvYShiaW5hcnkpXG59XG5cbmV4cG9ydCBkZWZhdWx0IGNsYXNzIExvbmdQb2xsIHtcblxuICBjb25zdHJ1Y3RvcihlbmRQb2ludCwgcHJvdG9jb2xzKXtcbiAgICAvLyB3ZSBvbmx5IHN1cHBvcnQgc3VicHJvdG9jb2xzIGZvciBhdXRoVG9rZW5cbiAgICAvLyBbXCJwaG9lbml4XCIsIFwiYmFzZTY0dXJsLmJlYXJlci5waHguQkFTRTY0X0VOQ09ERURfVE9LRU5cIl1cbiAgICBpZihwcm90b2NvbHMgJiYgcHJvdG9jb2xzLmxlbmd0aCA9PT0gMiAmJiBwcm90b2NvbHNbMV0uc3RhcnRzV2l0aChBVVRIX1RPS0VOX1BSRUZJWCkpe1xuICAgICAgdGhpcy5hdXRoVG9rZW4gPSBhdG9iKHByb3RvY29sc1sxXS5zbGljZShBVVRIX1RPS0VOX1BSRUZJWC5sZW5ndGgpKVxuICAgIH1cbiAgICB0aGlzLmVuZFBvaW50ID0gbnVsbFxuICAgIHRoaXMudG9rZW4gPSBudWxsXG4gICAgdGhpcy5za2lwSGVhcnRiZWF0ID0gdHJ1ZVxuICAgIHRoaXMucmVxcyA9IG5ldyBTZXQoKVxuICAgIHRoaXMuYXdhaXRpbmdCYXRjaEFjayA9IGZhbHNlXG4gICAgdGhpcy5jdXJyZW50QmF0Y2ggPSBudWxsXG4gICAgdGhpcy5jdXJyZW50QmF0Y2hUaW1lciA9IG51bGxcbiAgICB0aGlzLmJhdGNoQnVmZmVyID0gW11cbiAgICB0aGlzLm9ub3BlbiA9IGZ1bmN0aW9uICgpeyB9IC8vIG5vb3BcbiAgICB0aGlzLm9uZXJyb3IgPSBmdW5jdGlvbiAoKXsgfSAvLyBub29wXG4gICAgdGhpcy5vbm1lc3NhZ2UgPSBmdW5jdGlvbiAoKXsgfSAvLyBub29wXG4gICAgdGhpcy5vbmNsb3NlID0gZnVuY3Rpb24gKCl7IH0gLy8gbm9vcFxuICAgIHRoaXMucG9sbEVuZHBvaW50ID0gdGhpcy5ub3JtYWxpemVFbmRwb2ludChlbmRQb2ludClcbiAgICB0aGlzLnJlYWR5U3RhdGUgPSBTT0NLRVRfU1RBVEVTLmNvbm5lY3RpbmdcbiAgICAvLyB3ZSBtdXN0IHdhaXQgZm9yIHRoZSBjYWxsZXIgdG8gZmluaXNoIHNldHRpbmcgdXAgb3VyIGNhbGxiYWNrcyBhbmQgdGltZW91dCBwcm9wZXJ0aWVzXG4gICAgc2V0VGltZW91dCgoKSA9PiB0aGlzLnBvbGwoKSwgMClcbiAgfVxuXG4gIG5vcm1hbGl6ZUVuZHBvaW50KGVuZFBvaW50KXtcbiAgICByZXR1cm4gKGVuZFBvaW50XG4gICAgICAucmVwbGFjZShcIndzOi8vXCIsIFwiaHR0cDovL1wiKVxuICAgICAgLnJlcGxhY2UoXCJ3c3M6Ly9cIiwgXCJodHRwczovL1wiKVxuICAgICAgLnJlcGxhY2UobmV3IFJlZ0V4cChcIiguKilcXC9cIiArIFRSQU5TUE9SVFMud2Vic29ja2V0KSwgXCIkMS9cIiArIFRSQU5TUE9SVFMubG9uZ3BvbGwpKVxuICB9XG5cbiAgZW5kcG9pbnRVUkwoKXtcbiAgICByZXR1cm4gQWpheC5hcHBlbmRQYXJhbXModGhpcy5wb2xsRW5kcG9pbnQsIHt0b2tlbjogdGhpcy50b2tlbn0pXG4gIH1cblxuICBjbG9zZUFuZFJldHJ5KGNvZGUsIHJlYXNvbiwgd2FzQ2xlYW4pe1xuICAgIHRoaXMuY2xvc2UoY29kZSwgcmVhc29uLCB3YXNDbGVhbilcbiAgICB0aGlzLnJlYWR5U3RhdGUgPSBTT0NLRVRfU1RBVEVTLmNvbm5lY3RpbmdcbiAgfVxuXG4gIG9udGltZW91dCgpe1xuICAgIHRoaXMub25lcnJvcihcInRpbWVvdXRcIilcbiAgICB0aGlzLmNsb3NlQW5kUmV0cnkoMTAwNSwgXCJ0aW1lb3V0XCIsIGZhbHNlKVxuICB9XG5cbiAgaXNBY3RpdmUoKXsgcmV0dXJuIHRoaXMucmVhZHlTdGF0ZSA9PT0gU09DS0VUX1NUQVRFUy5vcGVuIHx8IHRoaXMucmVhZHlTdGF0ZSA9PT0gU09DS0VUX1NUQVRFUy5jb25uZWN0aW5nIH1cblxuICBwb2xsKCl7XG4gICAgY29uc3QgaGVhZGVycyA9IHtcIkFjY2VwdFwiOiBcImFwcGxpY2F0aW9uL2pzb25cIn1cbiAgICBpZih0aGlzLmF1dGhUb2tlbil7XG4gICAgICBoZWFkZXJzW1wiWC1QaG9lbml4LUF1dGhUb2tlblwiXSA9IHRoaXMuYXV0aFRva2VuXG4gICAgfVxuICAgIHRoaXMuYWpheChcIkdFVFwiLCBoZWFkZXJzLCBudWxsLCAoKSA9PiB0aGlzLm9udGltZW91dCgpLCByZXNwID0+IHtcbiAgICAgIGlmKHJlc3Ape1xuICAgICAgICB2YXIge3N0YXR1cywgdG9rZW4sIG1lc3NhZ2VzfSA9IHJlc3BcbiAgICAgICAgdGhpcy50b2tlbiA9IHRva2VuXG4gICAgICB9IGVsc2Uge1xuICAgICAgICBzdGF0dXMgPSAwXG4gICAgICB9XG5cbiAgICAgIHN3aXRjaChzdGF0dXMpe1xuICAgICAgICBjYXNlIDIwMDpcbiAgICAgICAgICBtZXNzYWdlcy5mb3JFYWNoKG1zZyA9PiB7XG4gICAgICAgICAgICAvLyBUYXNrcyBhcmUgd2hhdCB0aGluZ3MgbGlrZSBldmVudCBoYW5kbGVycywgc2V0VGltZW91dCBjYWxsYmFja3MsXG4gICAgICAgICAgICAvLyBwcm9taXNlIHJlc29sdmVzIGFuZCBtb3JlIGFyZSBydW4gd2l0aGluLlxuICAgICAgICAgICAgLy8gSW4gbW9kZXJuIGJyb3dzZXJzLCB0aGVyZSBhcmUgdHdvIGRpZmZlcmVudCBraW5kcyBvZiB0YXNrcyxcbiAgICAgICAgICAgIC8vIG1pY3JvdGFza3MgYW5kIG1hY3JvdGFza3MuXG4gICAgICAgICAgICAvLyBNaWNyb3Rhc2tzIGFyZSBtYWlubHkgdXNlZCBmb3IgUHJvbWlzZXMsIHdoaWxlIG1hY3JvdGFza3MgYXJlXG4gICAgICAgICAgICAvLyB1c2VkIGZvciBldmVyeXRoaW5nIGVsc2UuXG4gICAgICAgICAgICAvLyBNaWNyb3Rhc2tzIGFsd2F5cyBoYXZlIHByaW9yaXR5IG92ZXIgbWFjcm90YXNrcy4gSWYgdGhlIEpTIGVuZ2luZVxuICAgICAgICAgICAgLy8gaXMgbG9va2luZyBmb3IgYSB0YXNrIHRvIHJ1biwgaXQgd2lsbCBhbHdheXMgdHJ5IHRvIGVtcHR5IHRoZVxuICAgICAgICAgICAgLy8gbWljcm90YXNrIHF1ZXVlIGJlZm9yZSBhdHRlbXB0aW5nIHRvIHJ1biBhbnl0aGluZyBmcm9tIHRoZVxuICAgICAgICAgICAgLy8gbWFjcm90YXNrIHF1ZXVlLlxuICAgICAgICAgICAgLy9cbiAgICAgICAgICAgIC8vIEZvciB0aGUgV2ViU29ja2V0IHRyYW5zcG9ydCwgbWVzc2FnZXMgYWx3YXlzIGFycml2ZSBpbiB0aGVpciBvd25cbiAgICAgICAgICAgIC8vIGV2ZW50LiBUaGlzIG1lYW5zIHRoYXQgaWYgYW55IHByb21pc2VzIGFyZSByZXNvbHZlZCBmcm9tIHdpdGhpbixcbiAgICAgICAgICAgIC8vIHRoZWlyIGNhbGxiYWNrcyB3aWxsIGFsd2F5cyBmaW5pc2ggZXhlY3V0aW9uIGJ5IHRoZSB0aW1lIHRoZVxuICAgICAgICAgICAgLy8gbmV4dCBtZXNzYWdlIGV2ZW50IGhhbmRsZXIgaXMgcnVuLlxuICAgICAgICAgICAgLy9cbiAgICAgICAgICAgIC8vIEluIG9yZGVyIHRvIGVtdWxhdGUgdGhpcyBiZWhhdmlvdXIsIHdlIG5lZWQgdG8gbWFrZSBzdXJlIGVhY2hcbiAgICAgICAgICAgIC8vIG9ubWVzc2FnZSBoYW5kbGVyIGlzIHJ1biB3aXRoaW4gaXRzIG93biBtYWNyb3Rhc2suXG4gICAgICAgICAgICBzZXRUaW1lb3V0KCgpID0+IHRoaXMub25tZXNzYWdlKHtkYXRhOiBtc2d9KSwgMClcbiAgICAgICAgICB9KVxuICAgICAgICAgIHRoaXMucG9sbCgpXG4gICAgICAgICAgYnJlYWtcbiAgICAgICAgY2FzZSAyMDQ6XG4gICAgICAgICAgdGhpcy5wb2xsKClcbiAgICAgICAgICBicmVha1xuICAgICAgICBjYXNlIDQxMDpcbiAgICAgICAgICB0aGlzLnJlYWR5U3RhdGUgPSBTT0NLRVRfU1RBVEVTLm9wZW5cbiAgICAgICAgICB0aGlzLm9ub3Blbih7fSlcbiAgICAgICAgICB0aGlzLnBvbGwoKVxuICAgICAgICAgIGJyZWFrXG4gICAgICAgIGNhc2UgNDAzOlxuICAgICAgICAgIHRoaXMub25lcnJvcig0MDMpXG4gICAgICAgICAgdGhpcy5jbG9zZSgxMDA4LCBcImZvcmJpZGRlblwiLCBmYWxzZSlcbiAgICAgICAgICBicmVha1xuICAgICAgICBjYXNlIDA6XG4gICAgICAgIGNhc2UgNTAwOlxuICAgICAgICAgIHRoaXMub25lcnJvcig1MDApXG4gICAgICAgICAgdGhpcy5jbG9zZUFuZFJldHJ5KDEwMTEsIFwiaW50ZXJuYWwgc2VydmVyIGVycm9yXCIsIDUwMClcbiAgICAgICAgICBicmVha1xuICAgICAgICBkZWZhdWx0OiB0aHJvdyBuZXcgRXJyb3IoYHVuaGFuZGxlZCBwb2xsIHN0YXR1cyAke3N0YXR1c31gKVxuICAgICAgfVxuICAgIH0pXG4gIH1cblxuICAvLyB3ZSBjb2xsZWN0IGFsbCBwdXNoZXMgd2l0aGluIHRoZSBjdXJyZW50IGV2ZW50IGxvb3AgYnlcbiAgLy8gc2V0VGltZW91dCAwLCB3aGljaCBvcHRpbWl6ZXMgYmFjay10by1iYWNrIHByb2NlZHVyYWxcbiAgLy8gcHVzaGVzIGFnYWluc3QgYW4gZW1wdHkgYnVmZmVyXG5cbiAgc2VuZChib2R5KXtcbiAgICBpZih0eXBlb2YoYm9keSkgIT09IFwic3RyaW5nXCIpeyBib2R5ID0gYXJyYXlCdWZmZXJUb0Jhc2U2NChib2R5KSB9XG4gICAgaWYodGhpcy5jdXJyZW50QmF0Y2gpe1xuICAgICAgdGhpcy5jdXJyZW50QmF0Y2gucHVzaChib2R5KVxuICAgIH0gZWxzZSBpZih0aGlzLmF3YWl0aW5nQmF0Y2hBY2spe1xuICAgICAgdGhpcy5iYXRjaEJ1ZmZlci5wdXNoKGJvZHkpXG4gICAgfSBlbHNlIHtcbiAgICAgIHRoaXMuY3VycmVudEJhdGNoID0gW2JvZHldXG4gICAgICB0aGlzLmN1cnJlbnRCYXRjaFRpbWVyID0gc2V0VGltZW91dCgoKSA9PiB7XG4gICAgICAgIHRoaXMuYmF0Y2hTZW5kKHRoaXMuY3VycmVudEJhdGNoKVxuICAgICAgICB0aGlzLmN1cnJlbnRCYXRjaCA9IG51bGxcbiAgICAgIH0sIDApXG4gICAgfVxuICB9XG5cbiAgYmF0Y2hTZW5kKG1lc3NhZ2VzKXtcbiAgICB0aGlzLmF3YWl0aW5nQmF0Y2hBY2sgPSB0cnVlXG4gICAgdGhpcy5hamF4KFwiUE9TVFwiLCB7XCJDb250ZW50LVR5cGVcIjogXCJhcHBsaWNhdGlvbi94LW5kanNvblwifSwgbWVzc2FnZXMuam9pbihcIlxcblwiKSwgKCkgPT4gdGhpcy5vbmVycm9yKFwidGltZW91dFwiKSwgcmVzcCA9PiB7XG4gICAgICB0aGlzLmF3YWl0aW5nQmF0Y2hBY2sgPSBmYWxzZVxuICAgICAgaWYoIXJlc3AgfHwgcmVzcC5zdGF0dXMgIT09IDIwMCl7XG4gICAgICAgIHRoaXMub25lcnJvcihyZXNwICYmIHJlc3Auc3RhdHVzKVxuICAgICAgICB0aGlzLmNsb3NlQW5kUmV0cnkoMTAxMSwgXCJpbnRlcm5hbCBzZXJ2ZXIgZXJyb3JcIiwgZmFsc2UpXG4gICAgICB9IGVsc2UgaWYodGhpcy5iYXRjaEJ1ZmZlci5sZW5ndGggPiAwKXtcbiAgICAgICAgdGhpcy5iYXRjaFNlbmQodGhpcy5iYXRjaEJ1ZmZlcilcbiAgICAgICAgdGhpcy5iYXRjaEJ1ZmZlciA9IFtdXG4gICAgICB9XG4gICAgfSlcbiAgfVxuXG4gIGNsb3NlKGNvZGUsIHJlYXNvbiwgd2FzQ2xlYW4pe1xuICAgIGZvcihsZXQgcmVxIG9mIHRoaXMucmVxcyl7IHJlcS5hYm9ydCgpIH1cbiAgICB0aGlzLnJlYWR5U3RhdGUgPSBTT0NLRVRfU1RBVEVTLmNsb3NlZFxuICAgIGxldCBvcHRzID0gT2JqZWN0LmFzc2lnbih7Y29kZTogMTAwMCwgcmVhc29uOiB1bmRlZmluZWQsIHdhc0NsZWFuOiB0cnVlfSwge2NvZGUsIHJlYXNvbiwgd2FzQ2xlYW59KVxuICAgIHRoaXMuYmF0Y2hCdWZmZXIgPSBbXVxuICAgIGNsZWFyVGltZW91dCh0aGlzLmN1cnJlbnRCYXRjaFRpbWVyKVxuICAgIHRoaXMuY3VycmVudEJhdGNoVGltZXIgPSBudWxsXG4gICAgaWYodHlwZW9mKENsb3NlRXZlbnQpICE9PSBcInVuZGVmaW5lZFwiKXtcbiAgICAgIHRoaXMub25jbG9zZShuZXcgQ2xvc2VFdmVudChcImNsb3NlXCIsIG9wdHMpKVxuICAgIH0gZWxzZSB7XG4gICAgICB0aGlzLm9uY2xvc2Uob3B0cylcbiAgICB9XG4gIH1cblxuICBhamF4KG1ldGhvZCwgaGVhZGVycywgYm9keSwgb25DYWxsZXJUaW1lb3V0LCBjYWxsYmFjayl7XG4gICAgbGV0IHJlcVxuICAgIGxldCBvbnRpbWVvdXQgPSAoKSA9PiB7XG4gICAgICB0aGlzLnJlcXMuZGVsZXRlKHJlcSlcbiAgICAgIG9uQ2FsbGVyVGltZW91dCgpXG4gICAgfVxuICAgIHJlcSA9IEFqYXgucmVxdWVzdChtZXRob2QsIHRoaXMuZW5kcG9pbnRVUkwoKSwgaGVhZGVycywgYm9keSwgdGhpcy50aW1lb3V0LCBvbnRpbWVvdXQsIHJlc3AgPT4ge1xuICAgICAgdGhpcy5yZXFzLmRlbGV0ZShyZXEpXG4gICAgICBpZih0aGlzLmlzQWN0aXZlKCkpeyBjYWxsYmFjayhyZXNwKSB9XG4gICAgfSlcbiAgICB0aGlzLnJlcXMuYWRkKHJlcSlcbiAgfVxufVxuIiwgIi8qKlxuICogSW5pdGlhbGl6ZXMgdGhlIFByZXNlbmNlXG4gKiBAcGFyYW0ge0NoYW5uZWx9IGNoYW5uZWwgLSBUaGUgQ2hhbm5lbFxuICogQHBhcmFtIHtPYmplY3R9IG9wdHMgLSBUaGUgb3B0aW9ucyxcbiAqICAgICAgICBmb3IgZXhhbXBsZSBge2V2ZW50czoge3N0YXRlOiBcInN0YXRlXCIsIGRpZmY6IFwiZGlmZlwifX1gXG4gKi9cbmV4cG9ydCBkZWZhdWx0IGNsYXNzIFByZXNlbmNlIHtcblxuICBjb25zdHJ1Y3RvcihjaGFubmVsLCBvcHRzID0ge30pe1xuICAgIGxldCBldmVudHMgPSBvcHRzLmV2ZW50cyB8fCB7c3RhdGU6IFwicHJlc2VuY2Vfc3RhdGVcIiwgZGlmZjogXCJwcmVzZW5jZV9kaWZmXCJ9XG4gICAgdGhpcy5zdGF0ZSA9IHt9XG4gICAgdGhpcy5wZW5kaW5nRGlmZnMgPSBbXVxuICAgIHRoaXMuY2hhbm5lbCA9IGNoYW5uZWxcbiAgICB0aGlzLmpvaW5SZWYgPSBudWxsXG4gICAgdGhpcy5jYWxsZXIgPSB7XG4gICAgICBvbkpvaW46IGZ1bmN0aW9uICgpeyB9LFxuICAgICAgb25MZWF2ZTogZnVuY3Rpb24gKCl7IH0sXG4gICAgICBvblN5bmM6IGZ1bmN0aW9uICgpeyB9XG4gICAgfVxuXG4gICAgdGhpcy5jaGFubmVsLm9uKGV2ZW50cy5zdGF0ZSwgbmV3U3RhdGUgPT4ge1xuICAgICAgbGV0IHtvbkpvaW4sIG9uTGVhdmUsIG9uU3luY30gPSB0aGlzLmNhbGxlclxuXG4gICAgICB0aGlzLmpvaW5SZWYgPSB0aGlzLmNoYW5uZWwuam9pblJlZigpXG4gICAgICB0aGlzLnN0YXRlID0gUHJlc2VuY2Uuc3luY1N0YXRlKHRoaXMuc3RhdGUsIG5ld1N0YXRlLCBvbkpvaW4sIG9uTGVhdmUpXG5cbiAgICAgIHRoaXMucGVuZGluZ0RpZmZzLmZvckVhY2goZGlmZiA9PiB7XG4gICAgICAgIHRoaXMuc3RhdGUgPSBQcmVzZW5jZS5zeW5jRGlmZih0aGlzLnN0YXRlLCBkaWZmLCBvbkpvaW4sIG9uTGVhdmUpXG4gICAgICB9KVxuICAgICAgdGhpcy5wZW5kaW5nRGlmZnMgPSBbXVxuICAgICAgb25TeW5jKClcbiAgICB9KVxuXG4gICAgdGhpcy5jaGFubmVsLm9uKGV2ZW50cy5kaWZmLCBkaWZmID0+IHtcbiAgICAgIGxldCB7b25Kb2luLCBvbkxlYXZlLCBvblN5bmN9ID0gdGhpcy5jYWxsZXJcblxuICAgICAgaWYodGhpcy5pblBlbmRpbmdTeW5jU3RhdGUoKSl7XG4gICAgICAgIHRoaXMucGVuZGluZ0RpZmZzLnB1c2goZGlmZilcbiAgICAgIH0gZWxzZSB7XG4gICAgICAgIHRoaXMuc3RhdGUgPSBQcmVzZW5jZS5zeW5jRGlmZih0aGlzLnN0YXRlLCBkaWZmLCBvbkpvaW4sIG9uTGVhdmUpXG4gICAgICAgIG9uU3luYygpXG4gICAgICB9XG4gICAgfSlcbiAgfVxuXG4gIG9uSm9pbihjYWxsYmFjayl7IHRoaXMuY2FsbGVyLm9uSm9pbiA9IGNhbGxiYWNrIH1cblxuICBvbkxlYXZlKGNhbGxiYWNrKXsgdGhpcy5jYWxsZXIub25MZWF2ZSA9IGNhbGxiYWNrIH1cblxuICBvblN5bmMoY2FsbGJhY2speyB0aGlzLmNhbGxlci5vblN5bmMgPSBjYWxsYmFjayB9XG5cbiAgbGlzdChieSl7IHJldHVybiBQcmVzZW5jZS5saXN0KHRoaXMuc3RhdGUsIGJ5KSB9XG5cbiAgaW5QZW5kaW5nU3luY1N0YXRlKCl7XG4gICAgcmV0dXJuICF0aGlzLmpvaW5SZWYgfHwgKHRoaXMuam9pblJlZiAhPT0gdGhpcy5jaGFubmVsLmpvaW5SZWYoKSlcbiAgfVxuXG4gIC8vIGxvd2VyLWxldmVsIHB1YmxpYyBzdGF0aWMgQVBJXG5cbiAgLyoqXG4gICAqIFVzZWQgdG8gc3luYyB0aGUgbGlzdCBvZiBwcmVzZW5jZXMgb24gdGhlIHNlcnZlclxuICAgKiB3aXRoIHRoZSBjbGllbnQncyBzdGF0ZS4gQW4gb3B0aW9uYWwgYG9uSm9pbmAgYW5kIGBvbkxlYXZlYCBjYWxsYmFjayBjYW5cbiAgICogYmUgcHJvdmlkZWQgdG8gcmVhY3QgdG8gY2hhbmdlcyBpbiB0aGUgY2xpZW50J3MgbG9jYWwgcHJlc2VuY2VzIGFjcm9zc1xuICAgKiBkaXNjb25uZWN0cyBhbmQgcmVjb25uZWN0cyB3aXRoIHRoZSBzZXJ2ZXIuXG4gICAqXG4gICAqIEByZXR1cm5zIHtQcmVzZW5jZX1cbiAgICovXG4gIHN0YXRpYyBzeW5jU3RhdGUoY3VycmVudFN0YXRlLCBuZXdTdGF0ZSwgb25Kb2luLCBvbkxlYXZlKXtcbiAgICBsZXQgc3RhdGUgPSB0aGlzLmNsb25lKGN1cnJlbnRTdGF0ZSlcbiAgICBsZXQgam9pbnMgPSB7fVxuICAgIGxldCBsZWF2ZXMgPSB7fVxuXG4gICAgdGhpcy5tYXAoc3RhdGUsIChrZXksIHByZXNlbmNlKSA9PiB7XG4gICAgICBpZighbmV3U3RhdGVba2V5XSl7XG4gICAgICAgIGxlYXZlc1trZXldID0gcHJlc2VuY2VcbiAgICAgIH1cbiAgICB9KVxuICAgIHRoaXMubWFwKG5ld1N0YXRlLCAoa2V5LCBuZXdQcmVzZW5jZSkgPT4ge1xuICAgICAgbGV0IGN1cnJlbnRQcmVzZW5jZSA9IHN0YXRlW2tleV1cbiAgICAgIGlmKGN1cnJlbnRQcmVzZW5jZSl7XG4gICAgICAgIGxldCBuZXdSZWZzID0gbmV3UHJlc2VuY2UubWV0YXMubWFwKG0gPT4gbS5waHhfcmVmKVxuICAgICAgICBsZXQgY3VyUmVmcyA9IGN1cnJlbnRQcmVzZW5jZS5tZXRhcy5tYXAobSA9PiBtLnBoeF9yZWYpXG4gICAgICAgIGxldCBqb2luZWRNZXRhcyA9IG5ld1ByZXNlbmNlLm1ldGFzLmZpbHRlcihtID0+IGN1clJlZnMuaW5kZXhPZihtLnBoeF9yZWYpIDwgMClcbiAgICAgICAgbGV0IGxlZnRNZXRhcyA9IGN1cnJlbnRQcmVzZW5jZS5tZXRhcy5maWx0ZXIobSA9PiBuZXdSZWZzLmluZGV4T2YobS5waHhfcmVmKSA8IDApXG4gICAgICAgIGlmKGpvaW5lZE1ldGFzLmxlbmd0aCA+IDApe1xuICAgICAgICAgIGpvaW5zW2tleV0gPSBuZXdQcmVzZW5jZVxuICAgICAgICAgIGpvaW5zW2tleV0ubWV0YXMgPSBqb2luZWRNZXRhc1xuICAgICAgICB9XG4gICAgICAgIGlmKGxlZnRNZXRhcy5sZW5ndGggPiAwKXtcbiAgICAgICAgICBsZWF2ZXNba2V5XSA9IHRoaXMuY2xvbmUoY3VycmVudFByZXNlbmNlKVxuICAgICAgICAgIGxlYXZlc1trZXldLm1ldGFzID0gbGVmdE1ldGFzXG4gICAgICAgIH1cbiAgICAgIH0gZWxzZSB7XG4gICAgICAgIGpvaW5zW2tleV0gPSBuZXdQcmVzZW5jZVxuICAgICAgfVxuICAgIH0pXG4gICAgcmV0dXJuIHRoaXMuc3luY0RpZmYoc3RhdGUsIHtqb2luczogam9pbnMsIGxlYXZlczogbGVhdmVzfSwgb25Kb2luLCBvbkxlYXZlKVxuICB9XG5cbiAgLyoqXG4gICAqXG4gICAqIFVzZWQgdG8gc3luYyBhIGRpZmYgb2YgcHJlc2VuY2Ugam9pbiBhbmQgbGVhdmVcbiAgICogZXZlbnRzIGZyb20gdGhlIHNlcnZlciwgYXMgdGhleSBoYXBwZW4uIExpa2UgYHN5bmNTdGF0ZWAsIGBzeW5jRGlmZmBcbiAgICogYWNjZXB0cyBvcHRpb25hbCBgb25Kb2luYCBhbmQgYG9uTGVhdmVgIGNhbGxiYWNrcyB0byByZWFjdCB0byBhIHVzZXJcbiAgICogam9pbmluZyBvciBsZWF2aW5nIGZyb20gYSBkZXZpY2UuXG4gICAqXG4gICAqIEByZXR1cm5zIHtQcmVzZW5jZX1cbiAgICovXG4gIHN0YXRpYyBzeW5jRGlmZihzdGF0ZSwgZGlmZiwgb25Kb2luLCBvbkxlYXZlKXtcbiAgICBsZXQge2pvaW5zLCBsZWF2ZXN9ID0gdGhpcy5jbG9uZShkaWZmKVxuICAgIGlmKCFvbkpvaW4peyBvbkpvaW4gPSBmdW5jdGlvbiAoKXsgfSB9XG4gICAgaWYoIW9uTGVhdmUpeyBvbkxlYXZlID0gZnVuY3Rpb24gKCl7IH0gfVxuXG4gICAgdGhpcy5tYXAoam9pbnMsIChrZXksIG5ld1ByZXNlbmNlKSA9PiB7XG4gICAgICBsZXQgY3VycmVudFByZXNlbmNlID0gc3RhdGVba2V5XVxuICAgICAgc3RhdGVba2V5XSA9IHRoaXMuY2xvbmUobmV3UHJlc2VuY2UpXG4gICAgICBpZihjdXJyZW50UHJlc2VuY2Upe1xuICAgICAgICBsZXQgam9pbmVkUmVmcyA9IHN0YXRlW2tleV0ubWV0YXMubWFwKG0gPT4gbS5waHhfcmVmKVxuICAgICAgICBsZXQgY3VyTWV0YXMgPSBjdXJyZW50UHJlc2VuY2UubWV0YXMuZmlsdGVyKG0gPT4gam9pbmVkUmVmcy5pbmRleE9mKG0ucGh4X3JlZikgPCAwKVxuICAgICAgICBzdGF0ZVtrZXldLm1ldGFzLnVuc2hpZnQoLi4uY3VyTWV0YXMpXG4gICAgICB9XG4gICAgICBvbkpvaW4oa2V5LCBjdXJyZW50UHJlc2VuY2UsIG5ld1ByZXNlbmNlKVxuICAgIH0pXG4gICAgdGhpcy5tYXAobGVhdmVzLCAoa2V5LCBsZWZ0UHJlc2VuY2UpID0+IHtcbiAgICAgIGxldCBjdXJyZW50UHJlc2VuY2UgPSBzdGF0ZVtrZXldXG4gICAgICBpZighY3VycmVudFByZXNlbmNlKXsgcmV0dXJuIH1cbiAgICAgIGxldCByZWZzVG9SZW1vdmUgPSBsZWZ0UHJlc2VuY2UubWV0YXMubWFwKG0gPT4gbS5waHhfcmVmKVxuICAgICAgY3VycmVudFByZXNlbmNlLm1ldGFzID0gY3VycmVudFByZXNlbmNlLm1ldGFzLmZpbHRlcihwID0+IHtcbiAgICAgICAgcmV0dXJuIHJlZnNUb1JlbW92ZS5pbmRleE9mKHAucGh4X3JlZikgPCAwXG4gICAgICB9KVxuICAgICAgb25MZWF2ZShrZXksIGN1cnJlbnRQcmVzZW5jZSwgbGVmdFByZXNlbmNlKVxuICAgICAgaWYoY3VycmVudFByZXNlbmNlLm1ldGFzLmxlbmd0aCA9PT0gMCl7XG4gICAgICAgIGRlbGV0ZSBzdGF0ZVtrZXldXG4gICAgICB9XG4gICAgfSlcbiAgICByZXR1cm4gc3RhdGVcbiAgfVxuXG4gIC8qKlxuICAgKiBSZXR1cm5zIHRoZSBhcnJheSBvZiBwcmVzZW5jZXMsIHdpdGggc2VsZWN0ZWQgbWV0YWRhdGEuXG4gICAqXG4gICAqIEBwYXJhbSB7T2JqZWN0fSBwcmVzZW5jZXNcbiAgICogQHBhcmFtIHtGdW5jdGlvbn0gY2hvb3NlclxuICAgKlxuICAgKiBAcmV0dXJucyB7UHJlc2VuY2V9XG4gICAqL1xuICBzdGF0aWMgbGlzdChwcmVzZW5jZXMsIGNob29zZXIpe1xuICAgIGlmKCFjaG9vc2VyKXsgY2hvb3NlciA9IGZ1bmN0aW9uIChrZXksIHByZXMpeyByZXR1cm4gcHJlcyB9IH1cblxuICAgIHJldHVybiB0aGlzLm1hcChwcmVzZW5jZXMsIChrZXksIHByZXNlbmNlKSA9PiB7XG4gICAgICByZXR1cm4gY2hvb3NlcihrZXksIHByZXNlbmNlKVxuICAgIH0pXG4gIH1cblxuICAvLyBwcml2YXRlXG5cbiAgc3RhdGljIG1hcChvYmosIGZ1bmMpe1xuICAgIHJldHVybiBPYmplY3QuZ2V0T3duUHJvcGVydHlOYW1lcyhvYmopLm1hcChrZXkgPT4gZnVuYyhrZXksIG9ialtrZXldKSlcbiAgfVxuXG4gIHN0YXRpYyBjbG9uZShvYmopeyByZXR1cm4gSlNPTi5wYXJzZShKU09OLnN0cmluZ2lmeShvYmopKSB9XG59XG4iLCAiLyogVGhlIGRlZmF1bHQgc2VyaWFsaXplciBmb3IgZW5jb2RpbmcgYW5kIGRlY29kaW5nIG1lc3NhZ2VzICovXG5pbXBvcnQge1xuICBDSEFOTkVMX0VWRU5UU1xufSBmcm9tIFwiLi9jb25zdGFudHNcIlxuXG5leHBvcnQgZGVmYXVsdCB7XG4gIEhFQURFUl9MRU5HVEg6IDEsXG4gIE1FVEFfTEVOR1RIOiA0LFxuICBLSU5EUzoge3B1c2g6IDAsIHJlcGx5OiAxLCBicm9hZGNhc3Q6IDJ9LFxuXG4gIGVuY29kZShtc2csIGNhbGxiYWNrKXtcbiAgICBpZihtc2cucGF5bG9hZC5jb25zdHJ1Y3RvciA9PT0gQXJyYXlCdWZmZXIpe1xuICAgICAgcmV0dXJuIGNhbGxiYWNrKHRoaXMuYmluYXJ5RW5jb2RlKG1zZykpXG4gICAgfSBlbHNlIHtcbiAgICAgIGxldCBwYXlsb2FkID0gW21zZy5qb2luX3JlZiwgbXNnLnJlZiwgbXNnLnRvcGljLCBtc2cuZXZlbnQsIG1zZy5wYXlsb2FkXVxuICAgICAgcmV0dXJuIGNhbGxiYWNrKEpTT04uc3RyaW5naWZ5KHBheWxvYWQpKVxuICAgIH1cbiAgfSxcblxuICBkZWNvZGUocmF3UGF5bG9hZCwgY2FsbGJhY2spe1xuICAgIGlmKHJhd1BheWxvYWQuY29uc3RydWN0b3IgPT09IEFycmF5QnVmZmVyKXtcbiAgICAgIHJldHVybiBjYWxsYmFjayh0aGlzLmJpbmFyeURlY29kZShyYXdQYXlsb2FkKSlcbiAgICB9IGVsc2Uge1xuICAgICAgbGV0IFtqb2luX3JlZiwgcmVmLCB0b3BpYywgZXZlbnQsIHBheWxvYWRdID0gSlNPTi5wYXJzZShyYXdQYXlsb2FkKVxuICAgICAgcmV0dXJuIGNhbGxiYWNrKHtqb2luX3JlZiwgcmVmLCB0b3BpYywgZXZlbnQsIHBheWxvYWR9KVxuICAgIH1cbiAgfSxcblxuICAvLyBwcml2YXRlXG5cbiAgYmluYXJ5RW5jb2RlKG1lc3NhZ2Upe1xuICAgIGxldCB7am9pbl9yZWYsIHJlZiwgZXZlbnQsIHRvcGljLCBwYXlsb2FkfSA9IG1lc3NhZ2VcbiAgICBsZXQgbWV0YUxlbmd0aCA9IHRoaXMuTUVUQV9MRU5HVEggKyBqb2luX3JlZi5sZW5ndGggKyByZWYubGVuZ3RoICsgdG9waWMubGVuZ3RoICsgZXZlbnQubGVuZ3RoXG4gICAgbGV0IGhlYWRlciA9IG5ldyBBcnJheUJ1ZmZlcih0aGlzLkhFQURFUl9MRU5HVEggKyBtZXRhTGVuZ3RoKVxuICAgIGxldCB2aWV3ID0gbmV3IERhdGFWaWV3KGhlYWRlcilcbiAgICBsZXQgb2Zmc2V0ID0gMFxuXG4gICAgdmlldy5zZXRVaW50OChvZmZzZXQrKywgdGhpcy5LSU5EUy5wdXNoKSAvLyBraW5kXG4gICAgdmlldy5zZXRVaW50OChvZmZzZXQrKywgam9pbl9yZWYubGVuZ3RoKVxuICAgIHZpZXcuc2V0VWludDgob2Zmc2V0KyssIHJlZi5sZW5ndGgpXG4gICAgdmlldy5zZXRVaW50OChvZmZzZXQrKywgdG9waWMubGVuZ3RoKVxuICAgIHZpZXcuc2V0VWludDgob2Zmc2V0KyssIGV2ZW50Lmxlbmd0aClcbiAgICBBcnJheS5mcm9tKGpvaW5fcmVmLCBjaGFyID0+IHZpZXcuc2V0VWludDgob2Zmc2V0KyssIGNoYXIuY2hhckNvZGVBdCgwKSkpXG4gICAgQXJyYXkuZnJvbShyZWYsIGNoYXIgPT4gdmlldy5zZXRVaW50OChvZmZzZXQrKywgY2hhci5jaGFyQ29kZUF0KDApKSlcbiAgICBBcnJheS5mcm9tKHRvcGljLCBjaGFyID0+IHZpZXcuc2V0VWludDgob2Zmc2V0KyssIGNoYXIuY2hhckNvZGVBdCgwKSkpXG4gICAgQXJyYXkuZnJvbShldmVudCwgY2hhciA9PiB2aWV3LnNldFVpbnQ4KG9mZnNldCsrLCBjaGFyLmNoYXJDb2RlQXQoMCkpKVxuXG4gICAgdmFyIGNvbWJpbmVkID0gbmV3IFVpbnQ4QXJyYXkoaGVhZGVyLmJ5dGVMZW5ndGggKyBwYXlsb2FkLmJ5dGVMZW5ndGgpXG4gICAgY29tYmluZWQuc2V0KG5ldyBVaW50OEFycmF5KGhlYWRlciksIDApXG4gICAgY29tYmluZWQuc2V0KG5ldyBVaW50OEFycmF5KHBheWxvYWQpLCBoZWFkZXIuYnl0ZUxlbmd0aClcblxuICAgIHJldHVybiBjb21iaW5lZC5idWZmZXJcbiAgfSxcblxuICBiaW5hcnlEZWNvZGUoYnVmZmVyKXtcbiAgICBsZXQgdmlldyA9IG5ldyBEYXRhVmlldyhidWZmZXIpXG4gICAgbGV0IGtpbmQgPSB2aWV3LmdldFVpbnQ4KDApXG4gICAgbGV0IGRlY29kZXIgPSBuZXcgVGV4dERlY29kZXIoKVxuICAgIHN3aXRjaChraW5kKXtcbiAgICAgIGNhc2UgdGhpcy5LSU5EUy5wdXNoOiByZXR1cm4gdGhpcy5kZWNvZGVQdXNoKGJ1ZmZlciwgdmlldywgZGVjb2RlcilcbiAgICAgIGNhc2UgdGhpcy5LSU5EUy5yZXBseTogcmV0dXJuIHRoaXMuZGVjb2RlUmVwbHkoYnVmZmVyLCB2aWV3LCBkZWNvZGVyKVxuICAgICAgY2FzZSB0aGlzLktJTkRTLmJyb2FkY2FzdDogcmV0dXJuIHRoaXMuZGVjb2RlQnJvYWRjYXN0KGJ1ZmZlciwgdmlldywgZGVjb2RlcilcbiAgICB9XG4gIH0sXG5cbiAgZGVjb2RlUHVzaChidWZmZXIsIHZpZXcsIGRlY29kZXIpe1xuICAgIGxldCBqb2luUmVmU2l6ZSA9IHZpZXcuZ2V0VWludDgoMSlcbiAgICBsZXQgdG9waWNTaXplID0gdmlldy5nZXRVaW50OCgyKVxuICAgIGxldCBldmVudFNpemUgPSB2aWV3LmdldFVpbnQ4KDMpXG4gICAgbGV0IG9mZnNldCA9IHRoaXMuSEVBREVSX0xFTkdUSCArIHRoaXMuTUVUQV9MRU5HVEggLSAxIC8vIHB1c2hlcyBoYXZlIG5vIHJlZlxuICAgIGxldCBqb2luUmVmID0gZGVjb2Rlci5kZWNvZGUoYnVmZmVyLnNsaWNlKG9mZnNldCwgb2Zmc2V0ICsgam9pblJlZlNpemUpKVxuICAgIG9mZnNldCA9IG9mZnNldCArIGpvaW5SZWZTaXplXG4gICAgbGV0IHRvcGljID0gZGVjb2Rlci5kZWNvZGUoYnVmZmVyLnNsaWNlKG9mZnNldCwgb2Zmc2V0ICsgdG9waWNTaXplKSlcbiAgICBvZmZzZXQgPSBvZmZzZXQgKyB0b3BpY1NpemVcbiAgICBsZXQgZXZlbnQgPSBkZWNvZGVyLmRlY29kZShidWZmZXIuc2xpY2Uob2Zmc2V0LCBvZmZzZXQgKyBldmVudFNpemUpKVxuICAgIG9mZnNldCA9IG9mZnNldCArIGV2ZW50U2l6ZVxuICAgIGxldCBkYXRhID0gYnVmZmVyLnNsaWNlKG9mZnNldCwgYnVmZmVyLmJ5dGVMZW5ndGgpXG4gICAgcmV0dXJuIHtqb2luX3JlZjogam9pblJlZiwgcmVmOiBudWxsLCB0b3BpYzogdG9waWMsIGV2ZW50OiBldmVudCwgcGF5bG9hZDogZGF0YX1cbiAgfSxcblxuICBkZWNvZGVSZXBseShidWZmZXIsIHZpZXcsIGRlY29kZXIpe1xuICAgIGxldCBqb2luUmVmU2l6ZSA9IHZpZXcuZ2V0VWludDgoMSlcbiAgICBsZXQgcmVmU2l6ZSA9IHZpZXcuZ2V0VWludDgoMilcbiAgICBsZXQgdG9waWNTaXplID0gdmlldy5nZXRVaW50OCgzKVxuICAgIGxldCBldmVudFNpemUgPSB2aWV3LmdldFVpbnQ4KDQpXG4gICAgbGV0IG9mZnNldCA9IHRoaXMuSEVBREVSX0xFTkdUSCArIHRoaXMuTUVUQV9MRU5HVEhcbiAgICBsZXQgam9pblJlZiA9IGRlY29kZXIuZGVjb2RlKGJ1ZmZlci5zbGljZShvZmZzZXQsIG9mZnNldCArIGpvaW5SZWZTaXplKSlcbiAgICBvZmZzZXQgPSBvZmZzZXQgKyBqb2luUmVmU2l6ZVxuICAgIGxldCByZWYgPSBkZWNvZGVyLmRlY29kZShidWZmZXIuc2xpY2Uob2Zmc2V0LCBvZmZzZXQgKyByZWZTaXplKSlcbiAgICBvZmZzZXQgPSBvZmZzZXQgKyByZWZTaXplXG4gICAgbGV0IHRvcGljID0gZGVjb2Rlci5kZWNvZGUoYnVmZmVyLnNsaWNlKG9mZnNldCwgb2Zmc2V0ICsgdG9waWNTaXplKSlcbiAgICBvZmZzZXQgPSBvZmZzZXQgKyB0b3BpY1NpemVcbiAgICBsZXQgZXZlbnQgPSBkZWNvZGVyLmRlY29kZShidWZmZXIuc2xpY2Uob2Zmc2V0LCBvZmZzZXQgKyBldmVudFNpemUpKVxuICAgIG9mZnNldCA9IG9mZnNldCArIGV2ZW50U2l6ZVxuICAgIGxldCBkYXRhID0gYnVmZmVyLnNsaWNlKG9mZnNldCwgYnVmZmVyLmJ5dGVMZW5ndGgpXG4gICAgbGV0IHBheWxvYWQgPSB7c3RhdHVzOiBldmVudCwgcmVzcG9uc2U6IGRhdGF9XG4gICAgcmV0dXJuIHtqb2luX3JlZjogam9pblJlZiwgcmVmOiByZWYsIHRvcGljOiB0b3BpYywgZXZlbnQ6IENIQU5ORUxfRVZFTlRTLnJlcGx5LCBwYXlsb2FkOiBwYXlsb2FkfVxuICB9LFxuXG4gIGRlY29kZUJyb2FkY2FzdChidWZmZXIsIHZpZXcsIGRlY29kZXIpe1xuICAgIGxldCB0b3BpY1NpemUgPSB2aWV3LmdldFVpbnQ4KDEpXG4gICAgbGV0IGV2ZW50U2l6ZSA9IHZpZXcuZ2V0VWludDgoMilcbiAgICBsZXQgb2Zmc2V0ID0gdGhpcy5IRUFERVJfTEVOR1RIICsgMlxuICAgIGxldCB0b3BpYyA9IGRlY29kZXIuZGVjb2RlKGJ1ZmZlci5zbGljZShvZmZzZXQsIG9mZnNldCArIHRvcGljU2l6ZSkpXG4gICAgb2Zmc2V0ID0gb2Zmc2V0ICsgdG9waWNTaXplXG4gICAgbGV0IGV2ZW50ID0gZGVjb2Rlci5kZWNvZGUoYnVmZmVyLnNsaWNlKG9mZnNldCwgb2Zmc2V0ICsgZXZlbnRTaXplKSlcbiAgICBvZmZzZXQgPSBvZmZzZXQgKyBldmVudFNpemVcbiAgICBsZXQgZGF0YSA9IGJ1ZmZlci5zbGljZShvZmZzZXQsIGJ1ZmZlci5ieXRlTGVuZ3RoKVxuXG4gICAgcmV0dXJuIHtqb2luX3JlZjogbnVsbCwgcmVmOiBudWxsLCB0b3BpYzogdG9waWMsIGV2ZW50OiBldmVudCwgcGF5bG9hZDogZGF0YX1cbiAgfVxufVxuIiwgImltcG9ydCB7XG4gIGdsb2JhbCxcbiAgcGh4V2luZG93LFxuICBDSEFOTkVMX0VWRU5UUyxcbiAgREVGQVVMVF9USU1FT1VULFxuICBERUZBVUxUX1ZTTixcbiAgU09DS0VUX1NUQVRFUyxcbiAgVFJBTlNQT1JUUyxcbiAgV1NfQ0xPU0VfTk9STUFMLFxuICBBVVRIX1RPS0VOX1BSRUZJWFxufSBmcm9tIFwiLi9jb25zdGFudHNcIlxuXG5pbXBvcnQge1xuICBjbG9zdXJlXG59IGZyb20gXCIuL3V0aWxzXCJcblxuaW1wb3J0IEFqYXggZnJvbSBcIi4vYWpheFwiXG5pbXBvcnQgQ2hhbm5lbCBmcm9tIFwiLi9jaGFubmVsXCJcbmltcG9ydCBMb25nUG9sbCBmcm9tIFwiLi9sb25ncG9sbFwiXG5pbXBvcnQgU2VyaWFsaXplciBmcm9tIFwiLi9zZXJpYWxpemVyXCJcbmltcG9ydCBUaW1lciBmcm9tIFwiLi90aW1lclwiXG5cbi8qKiBJbml0aWFsaXplcyB0aGUgU29ja2V0ICpcbiAqXG4gKiBGb3IgSUU4IHN1cHBvcnQgdXNlIGFuIEVTNS1zaGltIChodHRwczovL2dpdGh1Yi5jb20vZXMtc2hpbXMvZXM1LXNoaW0pXG4gKlxuICogQHBhcmFtIHtzdHJpbmd9IGVuZFBvaW50IC0gVGhlIHN0cmluZyBXZWJTb2NrZXQgZW5kcG9pbnQsIGllLCBgXCJ3czovL2V4YW1wbGUuY29tL3NvY2tldFwiYCxcbiAqICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICBgXCJ3c3M6Ly9leGFtcGxlLmNvbVwiYFxuICogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIGBcIi9zb2NrZXRcImAgKGluaGVyaXRlZCBob3N0ICYgcHJvdG9jb2wpXG4gKiBAcGFyYW0ge09iamVjdH0gW29wdHNdIC0gT3B0aW9uYWwgY29uZmlndXJhdGlvblxuICogQHBhcmFtIHtGdW5jdGlvbn0gW29wdHMudHJhbnNwb3J0XSAtIFRoZSBXZWJzb2NrZXQgVHJhbnNwb3J0LCBmb3IgZXhhbXBsZSBXZWJTb2NrZXQgb3IgUGhvZW5peC5Mb25nUG9sbC5cbiAqXG4gKiBEZWZhdWx0cyB0byBXZWJTb2NrZXQgd2l0aCBhdXRvbWF0aWMgTG9uZ1BvbGwgZmFsbGJhY2sgaWYgV2ViU29ja2V0IGlzIG5vdCBkZWZpbmVkLlxuICogVG8gZmFsbGJhY2sgdG8gTG9uZ1BvbGwgd2hlbiBXZWJTb2NrZXQgYXR0ZW1wdHMgZmFpbCwgdXNlIGBsb25nUG9sbEZhbGxiYWNrTXM6IDI1MDBgLlxuICpcbiAqIEBwYXJhbSB7bnVtYmVyfSBbb3B0cy5sb25nUG9sbEZhbGxiYWNrTXNdIC0gVGhlIG1pbGxpc2Vjb25kIHRpbWUgdG8gYXR0ZW1wdCB0aGUgcHJpbWFyeSB0cmFuc3BvcnRcbiAqIGJlZm9yZSBmYWxsaW5nIGJhY2sgdG8gdGhlIExvbmdQb2xsIHRyYW5zcG9ydC4gRGlzYWJsZWQgYnkgZGVmYXVsdC5cbiAqXG4gKiBAcGFyYW0ge2Jvb2xlYW59IFtvcHRzLmRlYnVnXSAtIFdoZW4gdHJ1ZSwgZW5hYmxlcyBkZWJ1ZyBsb2dnaW5nLiBEZWZhdWx0IGZhbHNlLlxuICpcbiAqIEBwYXJhbSB7RnVuY3Rpb259IFtvcHRzLmVuY29kZV0gLSBUaGUgZnVuY3Rpb24gdG8gZW5jb2RlIG91dGdvaW5nIG1lc3NhZ2VzLlxuICpcbiAqIERlZmF1bHRzIHRvIEpTT04gZW5jb2Rlci5cbiAqXG4gKiBAcGFyYW0ge0Z1bmN0aW9ufSBbb3B0cy5kZWNvZGVdIC0gVGhlIGZ1bmN0aW9uIHRvIGRlY29kZSBpbmNvbWluZyBtZXNzYWdlcy5cbiAqXG4gKiBEZWZhdWx0cyB0byBKU09OOlxuICpcbiAqIGBgYGphdmFzY3JpcHRcbiAqIChwYXlsb2FkLCBjYWxsYmFjaykgPT4gY2FsbGJhY2soSlNPTi5wYXJzZShwYXlsb2FkKSlcbiAqIGBgYFxuICpcbiAqIEBwYXJhbSB7bnVtYmVyfSBbb3B0cy50aW1lb3V0XSAtIFRoZSBkZWZhdWx0IHRpbWVvdXQgaW4gbWlsbGlzZWNvbmRzIHRvIHRyaWdnZXIgcHVzaCB0aW1lb3V0cy5cbiAqXG4gKiBEZWZhdWx0cyBgREVGQVVMVF9USU1FT1VUYFxuICogQHBhcmFtIHtudW1iZXJ9IFtvcHRzLmhlYXJ0YmVhdEludGVydmFsTXNdIC0gVGhlIG1pbGxpc2VjIGludGVydmFsIHRvIHNlbmQgYSBoZWFydGJlYXQgbWVzc2FnZVxuICogQHBhcmFtIHtGdW5jdGlvbn0gW29wdHMucmVjb25uZWN0QWZ0ZXJNc10gLSBUaGUgb3B0aW9uYWwgZnVuY3Rpb24gdGhhdCByZXR1cm5zIHRoZVxuICogc29ja2V0IHJlY29ubmVjdCBpbnRlcnZhbCwgaW4gbWlsbGlzZWNvbmRzLlxuICpcbiAqIERlZmF1bHRzIHRvIHN0ZXBwZWQgYmFja29mZiBvZjpcbiAqXG4gKiBgYGBqYXZhc2NyaXB0XG4gKiBmdW5jdGlvbih0cmllcyl7XG4gKiAgIHJldHVybiBbMTAsIDUwLCAxMDAsIDE1MCwgMjAwLCAyNTAsIDUwMCwgMTAwMCwgMjAwMF1bdHJpZXMgLSAxXSB8fCA1MDAwXG4gKiB9XG4gKiBgYGBgXG4gKlxuICogQHBhcmFtIHtGdW5jdGlvbn0gW29wdHMucmVqb2luQWZ0ZXJNc10gLSBUaGUgb3B0aW9uYWwgZnVuY3Rpb24gdGhhdCByZXR1cm5zIHRoZSBtaWxsaXNlY1xuICogcmVqb2luIGludGVydmFsIGZvciBpbmRpdmlkdWFsIGNoYW5uZWxzLlxuICpcbiAqIGBgYGphdmFzY3JpcHRcbiAqIGZ1bmN0aW9uKHRyaWVzKXtcbiAqICAgcmV0dXJuIFsxMDAwLCAyMDAwLCA1MDAwXVt0cmllcyAtIDFdIHx8IDEwMDAwXG4gKiB9XG4gKiBgYGBgXG4gKlxuICogQHBhcmFtIHtGdW5jdGlvbn0gW29wdHMubG9nZ2VyXSAtIFRoZSBvcHRpb25hbCBmdW5jdGlvbiBmb3Igc3BlY2lhbGl6ZWQgbG9nZ2luZywgaWU6XG4gKlxuICogYGBgamF2YXNjcmlwdFxuICogZnVuY3Rpb24oa2luZCwgbXNnLCBkYXRhKSB7XG4gKiAgIGNvbnNvbGUubG9nKGAke2tpbmR9OiAke21zZ31gLCBkYXRhKVxuICogfVxuICogYGBgXG4gKlxuICogQHBhcmFtIHtudW1iZXJ9IFtvcHRzLmxvbmdwb2xsZXJUaW1lb3V0XSAtIFRoZSBtYXhpbXVtIHRpbWVvdXQgb2YgYSBsb25nIHBvbGwgQUpBWCByZXF1ZXN0LlxuICpcbiAqIERlZmF1bHRzIHRvIDIwcyAoZG91YmxlIHRoZSBzZXJ2ZXIgbG9uZyBwb2xsIHRpbWVyKS5cbiAqXG4gKiBAcGFyYW0geyhPYmplY3R8ZnVuY3Rpb24pfSBbb3B0cy5wYXJhbXNdIC0gVGhlIG9wdGlvbmFsIHBhcmFtcyB0byBwYXNzIHdoZW4gY29ubmVjdGluZ1xuICogQHBhcmFtIHtzdHJpbmd9IFtvcHRzLmF1dGhUb2tlbl0gLSB0aGUgb3B0aW9uYWwgYXV0aGVudGljYXRpb24gdG9rZW4gdG8gYmUgZXhwb3NlZCBvbiB0aGUgc2VydmVyXG4gKiB1bmRlciB0aGUgYDphdXRoX3Rva2VuYCBjb25uZWN0X2luZm8ga2V5LlxuICogQHBhcmFtIHtzdHJpbmd9IFtvcHRzLmJpbmFyeVR5cGVdIC0gVGhlIGJpbmFyeSB0eXBlIHRvIHVzZSBmb3IgYmluYXJ5IFdlYlNvY2tldCBmcmFtZXMuXG4gKlxuICogRGVmYXVsdHMgdG8gXCJhcnJheWJ1ZmZlclwiXG4gKlxuICogQHBhcmFtIHt2c259IFtvcHRzLnZzbl0gLSBUaGUgc2VyaWFsaXplcidzIHByb3RvY29sIHZlcnNpb24gdG8gc2VuZCBvbiBjb25uZWN0LlxuICpcbiAqIERlZmF1bHRzIHRvIERFRkFVTFRfVlNOLlxuICpcbiAqIEBwYXJhbSB7T2JqZWN0fSBbb3B0cy5zZXNzaW9uU3RvcmFnZV0gLSBBbiBvcHRpb25hbCBTdG9yYWdlIGNvbXBhdGlibGUgb2JqZWN0XG4gKiBQaG9lbml4IHVzZXMgc2Vzc2lvblN0b3JhZ2UgZm9yIGxvbmdwb2xsIGZhbGxiYWNrIGhpc3RvcnkuIE92ZXJyaWRpbmcgdGhlIHN0b3JlIGlzXG4gKiB1c2VmdWwgd2hlbiBQaG9lbml4IHdvbid0IGhhdmUgYWNjZXNzIHRvIGBzZXNzaW9uU3RvcmFnZWAuIEZvciBleGFtcGxlLCBUaGlzIGNvdWxkXG4gKiBoYXBwZW4gaWYgYSBzaXRlIGxvYWRzIGEgY3Jvc3MtZG9tYWluIGNoYW5uZWwgaW4gYW4gaWZyYW1lLiBFeGFtcGxlIHVzYWdlOlxuICpcbiAqICAgICBjbGFzcyBJbk1lbW9yeVN0b3JhZ2Uge1xuICogICAgICAgY29uc3RydWN0b3IoKSB7IHRoaXMuc3RvcmFnZSA9IHt9IH1cbiAqICAgICAgIGdldEl0ZW0oa2V5TmFtZSkgeyByZXR1cm4gdGhpcy5zdG9yYWdlW2tleU5hbWVdIHx8IG51bGwgfVxuICogICAgICAgcmVtb3ZlSXRlbShrZXlOYW1lKSB7IGRlbGV0ZSB0aGlzLnN0b3JhZ2Vba2V5TmFtZV0gfVxuICogICAgICAgc2V0SXRlbShrZXlOYW1lLCBrZXlWYWx1ZSkgeyB0aGlzLnN0b3JhZ2Vba2V5TmFtZV0gPSBrZXlWYWx1ZSB9XG4gKiAgICAgfVxuICpcbiovXG5leHBvcnQgZGVmYXVsdCBjbGFzcyBTb2NrZXQge1xuICBjb25zdHJ1Y3RvcihlbmRQb2ludCwgb3B0cyA9IHt9KXtcbiAgICB0aGlzLnN0YXRlQ2hhbmdlQ2FsbGJhY2tzID0ge29wZW46IFtdLCBjbG9zZTogW10sIGVycm9yOiBbXSwgbWVzc2FnZTogW119XG4gICAgdGhpcy5jaGFubmVscyA9IFtdXG4gICAgdGhpcy5zZW5kQnVmZmVyID0gW11cbiAgICB0aGlzLnJlZiA9IDBcbiAgICB0aGlzLnRpbWVvdXQgPSBvcHRzLnRpbWVvdXQgfHwgREVGQVVMVF9USU1FT1VUXG4gICAgdGhpcy50cmFuc3BvcnQgPSBvcHRzLnRyYW5zcG9ydCB8fCBnbG9iYWwuV2ViU29ja2V0IHx8IExvbmdQb2xsXG4gICAgdGhpcy5wcmltYXJ5UGFzc2VkSGVhbHRoQ2hlY2sgPSBmYWxzZVxuICAgIHRoaXMubG9uZ1BvbGxGYWxsYmFja01zID0gb3B0cy5sb25nUG9sbEZhbGxiYWNrTXNcbiAgICB0aGlzLmZhbGxiYWNrVGltZXIgPSBudWxsXG4gICAgdGhpcy5zZXNzaW9uU3RvcmUgPSBvcHRzLnNlc3Npb25TdG9yYWdlIHx8IChnbG9iYWwgJiYgZ2xvYmFsLnNlc3Npb25TdG9yYWdlKVxuICAgIHRoaXMuZXN0YWJsaXNoZWRDb25uZWN0aW9ucyA9IDBcbiAgICB0aGlzLmRlZmF1bHRFbmNvZGVyID0gU2VyaWFsaXplci5lbmNvZGUuYmluZChTZXJpYWxpemVyKVxuICAgIHRoaXMuZGVmYXVsdERlY29kZXIgPSBTZXJpYWxpemVyLmRlY29kZS5iaW5kKFNlcmlhbGl6ZXIpXG4gICAgdGhpcy5jbG9zZVdhc0NsZWFuID0gZmFsc2VcbiAgICB0aGlzLmRpc2Nvbm5lY3RpbmcgPSBmYWxzZVxuICAgIHRoaXMuYmluYXJ5VHlwZSA9IG9wdHMuYmluYXJ5VHlwZSB8fCBcImFycmF5YnVmZmVyXCJcbiAgICB0aGlzLmNvbm5lY3RDbG9jayA9IDFcbiAgICBpZih0aGlzLnRyYW5zcG9ydCAhPT0gTG9uZ1BvbGwpe1xuICAgICAgdGhpcy5lbmNvZGUgPSBvcHRzLmVuY29kZSB8fCB0aGlzLmRlZmF1bHRFbmNvZGVyXG4gICAgICB0aGlzLmRlY29kZSA9IG9wdHMuZGVjb2RlIHx8IHRoaXMuZGVmYXVsdERlY29kZXJcbiAgICB9IGVsc2Uge1xuICAgICAgdGhpcy5lbmNvZGUgPSB0aGlzLmRlZmF1bHRFbmNvZGVyXG4gICAgICB0aGlzLmRlY29kZSA9IHRoaXMuZGVmYXVsdERlY29kZXJcbiAgICB9XG4gICAgbGV0IGF3YWl0aW5nQ29ubmVjdGlvbk9uUGFnZVNob3cgPSBudWxsXG4gICAgaWYocGh4V2luZG93ICYmIHBoeFdpbmRvdy5hZGRFdmVudExpc3RlbmVyKXtcbiAgICAgIHBoeFdpbmRvdy5hZGRFdmVudExpc3RlbmVyKFwicGFnZWhpZGVcIiwgX2UgPT4ge1xuICAgICAgICBpZih0aGlzLmNvbm4pe1xuICAgICAgICAgIHRoaXMuZGlzY29ubmVjdCgpXG4gICAgICAgICAgYXdhaXRpbmdDb25uZWN0aW9uT25QYWdlU2hvdyA9IHRoaXMuY29ubmVjdENsb2NrXG4gICAgICAgIH1cbiAgICAgIH0pXG4gICAgICBwaHhXaW5kb3cuYWRkRXZlbnRMaXN0ZW5lcihcInBhZ2VzaG93XCIsIF9lID0+IHtcbiAgICAgICAgaWYoYXdhaXRpbmdDb25uZWN0aW9uT25QYWdlU2hvdyA9PT0gdGhpcy5jb25uZWN0Q2xvY2spe1xuICAgICAgICAgIGF3YWl0aW5nQ29ubmVjdGlvbk9uUGFnZVNob3cgPSBudWxsXG4gICAgICAgICAgdGhpcy5jb25uZWN0KClcbiAgICAgICAgfVxuICAgICAgfSlcbiAgICB9XG4gICAgdGhpcy5oZWFydGJlYXRJbnRlcnZhbE1zID0gb3B0cy5oZWFydGJlYXRJbnRlcnZhbE1zIHx8IDMwMDAwXG4gICAgdGhpcy5yZWpvaW5BZnRlck1zID0gKHRyaWVzKSA9PiB7XG4gICAgICBpZihvcHRzLnJlam9pbkFmdGVyTXMpe1xuICAgICAgICByZXR1cm4gb3B0cy5yZWpvaW5BZnRlck1zKHRyaWVzKVxuICAgICAgfSBlbHNlIHtcbiAgICAgICAgcmV0dXJuIFsxMDAwLCAyMDAwLCA1MDAwXVt0cmllcyAtIDFdIHx8IDEwMDAwXG4gICAgICB9XG4gICAgfVxuICAgIHRoaXMucmVjb25uZWN0QWZ0ZXJNcyA9ICh0cmllcykgPT4ge1xuICAgICAgaWYob3B0cy5yZWNvbm5lY3RBZnRlck1zKXtcbiAgICAgICAgcmV0dXJuIG9wdHMucmVjb25uZWN0QWZ0ZXJNcyh0cmllcylcbiAgICAgIH0gZWxzZSB7XG4gICAgICAgIHJldHVybiBbMTAsIDUwLCAxMDAsIDE1MCwgMjAwLCAyNTAsIDUwMCwgMTAwMCwgMjAwMF1bdHJpZXMgLSAxXSB8fCA1MDAwXG4gICAgICB9XG4gICAgfVxuICAgIHRoaXMubG9nZ2VyID0gb3B0cy5sb2dnZXIgfHwgbnVsbFxuICAgIGlmKCF0aGlzLmxvZ2dlciAmJiBvcHRzLmRlYnVnKXtcbiAgICAgIHRoaXMubG9nZ2VyID0gKGtpbmQsIG1zZywgZGF0YSkgPT4geyBjb25zb2xlLmxvZyhgJHtraW5kfTogJHttc2d9YCwgZGF0YSkgfVxuICAgIH1cbiAgICB0aGlzLmxvbmdwb2xsZXJUaW1lb3V0ID0gb3B0cy5sb25ncG9sbGVyVGltZW91dCB8fCAyMDAwMFxuICAgIHRoaXMucGFyYW1zID0gY2xvc3VyZShvcHRzLnBhcmFtcyB8fCB7fSlcbiAgICB0aGlzLmVuZFBvaW50ID0gYCR7ZW5kUG9pbnR9LyR7VFJBTlNQT1JUUy53ZWJzb2NrZXR9YFxuICAgIHRoaXMudnNuID0gb3B0cy52c24gfHwgREVGQVVMVF9WU05cbiAgICB0aGlzLmhlYXJ0YmVhdFRpbWVvdXRUaW1lciA9IG51bGxcbiAgICB0aGlzLmhlYXJ0YmVhdFRpbWVyID0gbnVsbFxuICAgIHRoaXMucGVuZGluZ0hlYXJ0YmVhdFJlZiA9IG51bGxcbiAgICB0aGlzLnJlY29ubmVjdFRpbWVyID0gbmV3IFRpbWVyKCgpID0+IHtcbiAgICAgIHRoaXMudGVhcmRvd24oKCkgPT4gdGhpcy5jb25uZWN0KCkpXG4gICAgfSwgdGhpcy5yZWNvbm5lY3RBZnRlck1zKVxuICAgIHRoaXMuYXV0aFRva2VuID0gb3B0cy5hdXRoVG9rZW5cbiAgfVxuXG4gIC8qKlxuICAgKiBSZXR1cm5zIHRoZSBMb25nUG9sbCB0cmFuc3BvcnQgcmVmZXJlbmNlXG4gICAqL1xuICBnZXRMb25nUG9sbFRyYW5zcG9ydCgpeyByZXR1cm4gTG9uZ1BvbGwgfVxuXG4gIC8qKlxuICAgKiBEaXNjb25uZWN0cyBhbmQgcmVwbGFjZXMgdGhlIGFjdGl2ZSB0cmFuc3BvcnRcbiAgICpcbiAgICogQHBhcmFtIHtGdW5jdGlvbn0gbmV3VHJhbnNwb3J0IC0gVGhlIG5ldyB0cmFuc3BvcnQgY2xhc3MgdG8gaW5zdGFudGlhdGVcbiAgICpcbiAgICovXG4gIHJlcGxhY2VUcmFuc3BvcnQobmV3VHJhbnNwb3J0KXtcbiAgICB0aGlzLmNvbm5lY3RDbG9jaysrXG4gICAgdGhpcy5jbG9zZVdhc0NsZWFuID0gdHJ1ZVxuICAgIGNsZWFyVGltZW91dCh0aGlzLmZhbGxiYWNrVGltZXIpXG4gICAgdGhpcy5yZWNvbm5lY3RUaW1lci5yZXNldCgpXG4gICAgaWYodGhpcy5jb25uKXtcbiAgICAgIHRoaXMuY29ubi5jbG9zZSgpXG4gICAgICB0aGlzLmNvbm4gPSBudWxsXG4gICAgfVxuICAgIHRoaXMudHJhbnNwb3J0ID0gbmV3VHJhbnNwb3J0XG4gIH1cblxuICAvKipcbiAgICogUmV0dXJucyB0aGUgc29ja2V0IHByb3RvY29sXG4gICAqXG4gICAqIEByZXR1cm5zIHtzdHJpbmd9XG4gICAqL1xuICBwcm90b2NvbCgpeyByZXR1cm4gbG9jYXRpb24ucHJvdG9jb2wubWF0Y2goL15odHRwcy8pID8gXCJ3c3NcIiA6IFwid3NcIiB9XG5cbiAgLyoqXG4gICAqIFRoZSBmdWxseSBxdWFsaWZpZWQgc29ja2V0IHVybFxuICAgKlxuICAgKiBAcmV0dXJucyB7c3RyaW5nfVxuICAgKi9cbiAgZW5kUG9pbnRVUkwoKXtcbiAgICBsZXQgdXJpID0gQWpheC5hcHBlbmRQYXJhbXMoXG4gICAgICBBamF4LmFwcGVuZFBhcmFtcyh0aGlzLmVuZFBvaW50LCB0aGlzLnBhcmFtcygpKSwge3ZzbjogdGhpcy52c259KVxuICAgIGlmKHVyaS5jaGFyQXQoMCkgIT09IFwiL1wiKXsgcmV0dXJuIHVyaSB9XG4gICAgaWYodXJpLmNoYXJBdCgxKSA9PT0gXCIvXCIpeyByZXR1cm4gYCR7dGhpcy5wcm90b2NvbCgpfToke3VyaX1gIH1cblxuICAgIHJldHVybiBgJHt0aGlzLnByb3RvY29sKCl9Oi8vJHtsb2NhdGlvbi5ob3N0fSR7dXJpfWBcbiAgfVxuXG4gIC8qKlxuICAgKiBEaXNjb25uZWN0cyB0aGUgc29ja2V0XG4gICAqXG4gICAqIFNlZSBodHRwczovL2RldmVsb3Blci5tb3ppbGxhLm9yZy9lbi1VUy9kb2NzL1dlYi9BUEkvQ2xvc2VFdmVudCNTdGF0dXNfY29kZXMgZm9yIHZhbGlkIHN0YXR1cyBjb2Rlcy5cbiAgICpcbiAgICogQHBhcmFtIHtGdW5jdGlvbn0gY2FsbGJhY2sgLSBPcHRpb25hbCBjYWxsYmFjayB3aGljaCBpcyBjYWxsZWQgYWZ0ZXIgc29ja2V0IGlzIGRpc2Nvbm5lY3RlZC5cbiAgICogQHBhcmFtIHtpbnRlZ2VyfSBjb2RlIC0gQSBzdGF0dXMgY29kZSBmb3IgZGlzY29ubmVjdGlvbiAoT3B0aW9uYWwpLlxuICAgKiBAcGFyYW0ge3N0cmluZ30gcmVhc29uIC0gQSB0ZXh0dWFsIGRlc2NyaXB0aW9uIG9mIHRoZSByZWFzb24gdG8gZGlzY29ubmVjdC4gKE9wdGlvbmFsKVxuICAgKi9cbiAgZGlzY29ubmVjdChjYWxsYmFjaywgY29kZSwgcmVhc29uKXtcbiAgICB0aGlzLmNvbm5lY3RDbG9jaysrXG4gICAgdGhpcy5kaXNjb25uZWN0aW5nID0gdHJ1ZVxuICAgIHRoaXMuY2xvc2VXYXNDbGVhbiA9IHRydWVcbiAgICBjbGVhclRpbWVvdXQodGhpcy5mYWxsYmFja1RpbWVyKVxuICAgIHRoaXMucmVjb25uZWN0VGltZXIucmVzZXQoKVxuICAgIHRoaXMudGVhcmRvd24oKCkgPT4ge1xuICAgICAgdGhpcy5kaXNjb25uZWN0aW5nID0gZmFsc2VcbiAgICAgIGNhbGxiYWNrICYmIGNhbGxiYWNrKClcbiAgICB9LCBjb2RlLCByZWFzb24pXG4gIH1cblxuICAvKipcbiAgICpcbiAgICogQHBhcmFtIHtPYmplY3R9IHBhcmFtcyAtIFRoZSBwYXJhbXMgdG8gc2VuZCB3aGVuIGNvbm5lY3RpbmcsIGZvciBleGFtcGxlIGB7dXNlcl9pZDogdXNlclRva2VufWBcbiAgICpcbiAgICogUGFzc2luZyBwYXJhbXMgdG8gY29ubmVjdCBpcyBkZXByZWNhdGVkOyBwYXNzIHRoZW0gaW4gdGhlIFNvY2tldCBjb25zdHJ1Y3RvciBpbnN0ZWFkOlxuICAgKiBgbmV3IFNvY2tldChcIi9zb2NrZXRcIiwge3BhcmFtczoge3VzZXJfaWQ6IHVzZXJUb2tlbn19KWAuXG4gICAqL1xuICBjb25uZWN0KHBhcmFtcyl7XG4gICAgaWYocGFyYW1zKXtcbiAgICAgIGNvbnNvbGUgJiYgY29uc29sZS5sb2coXCJwYXNzaW5nIHBhcmFtcyB0byBjb25uZWN0IGlzIGRlcHJlY2F0ZWQuIEluc3RlYWQgcGFzcyA6cGFyYW1zIHRvIHRoZSBTb2NrZXQgY29uc3RydWN0b3JcIilcbiAgICAgIHRoaXMucGFyYW1zID0gY2xvc3VyZShwYXJhbXMpXG4gICAgfVxuICAgIGlmKHRoaXMuY29ubiAmJiAhdGhpcy5kaXNjb25uZWN0aW5nKXsgcmV0dXJuIH1cbiAgICBpZih0aGlzLmxvbmdQb2xsRmFsbGJhY2tNcyAmJiB0aGlzLnRyYW5zcG9ydCAhPT0gTG9uZ1BvbGwpe1xuICAgICAgdGhpcy5jb25uZWN0V2l0aEZhbGxiYWNrKExvbmdQb2xsLCB0aGlzLmxvbmdQb2xsRmFsbGJhY2tNcylcbiAgICB9IGVsc2Uge1xuICAgICAgdGhpcy50cmFuc3BvcnRDb25uZWN0KClcbiAgICB9XG4gIH1cblxuICAvKipcbiAgICogTG9ncyB0aGUgbWVzc2FnZS4gT3ZlcnJpZGUgYHRoaXMubG9nZ2VyYCBmb3Igc3BlY2lhbGl6ZWQgbG9nZ2luZy4gbm9vcHMgYnkgZGVmYXVsdFxuICAgKiBAcGFyYW0ge3N0cmluZ30ga2luZFxuICAgKiBAcGFyYW0ge3N0cmluZ30gbXNnXG4gICAqIEBwYXJhbSB7T2JqZWN0fSBkYXRhXG4gICAqL1xuICBsb2coa2luZCwgbXNnLCBkYXRhKXsgdGhpcy5sb2dnZXIgJiYgdGhpcy5sb2dnZXIoa2luZCwgbXNnLCBkYXRhKSB9XG5cbiAgLyoqXG4gICAqIFJldHVybnMgdHJ1ZSBpZiBhIGxvZ2dlciBoYXMgYmVlbiBzZXQgb24gdGhpcyBzb2NrZXQuXG4gICAqL1xuICBoYXNMb2dnZXIoKXsgcmV0dXJuIHRoaXMubG9nZ2VyICE9PSBudWxsIH1cblxuICAvKipcbiAgICogUmVnaXN0ZXJzIGNhbGxiYWNrcyBmb3IgY29ubmVjdGlvbiBvcGVuIGV2ZW50c1xuICAgKlxuICAgKiBAZXhhbXBsZSBzb2NrZXQub25PcGVuKGZ1bmN0aW9uKCl7IGNvbnNvbGUuaW5mbyhcInRoZSBzb2NrZXQgd2FzIG9wZW5lZFwiKSB9KVxuICAgKlxuICAgKiBAcGFyYW0ge0Z1bmN0aW9ufSBjYWxsYmFja1xuICAgKi9cbiAgb25PcGVuKGNhbGxiYWNrKXtcbiAgICBsZXQgcmVmID0gdGhpcy5tYWtlUmVmKClcbiAgICB0aGlzLnN0YXRlQ2hhbmdlQ2FsbGJhY2tzLm9wZW4ucHVzaChbcmVmLCBjYWxsYmFja10pXG4gICAgcmV0dXJuIHJlZlxuICB9XG5cbiAgLyoqXG4gICAqIFJlZ2lzdGVycyBjYWxsYmFja3MgZm9yIGNvbm5lY3Rpb24gY2xvc2UgZXZlbnRzXG4gICAqIEBwYXJhbSB7RnVuY3Rpb259IGNhbGxiYWNrXG4gICAqL1xuICBvbkNsb3NlKGNhbGxiYWNrKXtcbiAgICBsZXQgcmVmID0gdGhpcy5tYWtlUmVmKClcbiAgICB0aGlzLnN0YXRlQ2hhbmdlQ2FsbGJhY2tzLmNsb3NlLnB1c2goW3JlZiwgY2FsbGJhY2tdKVxuICAgIHJldHVybiByZWZcbiAgfVxuXG4gIC8qKlxuICAgKiBSZWdpc3RlcnMgY2FsbGJhY2tzIGZvciBjb25uZWN0aW9uIGVycm9yIGV2ZW50c1xuICAgKlxuICAgKiBAZXhhbXBsZSBzb2NrZXQub25FcnJvcihmdW5jdGlvbihlcnJvcil7IGFsZXJ0KFwiQW4gZXJyb3Igb2NjdXJyZWRcIikgfSlcbiAgICpcbiAgICogQHBhcmFtIHtGdW5jdGlvbn0gY2FsbGJhY2tcbiAgICovXG4gIG9uRXJyb3IoY2FsbGJhY2spe1xuICAgIGxldCByZWYgPSB0aGlzLm1ha2VSZWYoKVxuICAgIHRoaXMuc3RhdGVDaGFuZ2VDYWxsYmFja3MuZXJyb3IucHVzaChbcmVmLCBjYWxsYmFja10pXG4gICAgcmV0dXJuIHJlZlxuICB9XG5cbiAgLyoqXG4gICAqIFJlZ2lzdGVycyBjYWxsYmFja3MgZm9yIGNvbm5lY3Rpb24gbWVzc2FnZSBldmVudHNcbiAgICogQHBhcmFtIHtGdW5jdGlvbn0gY2FsbGJhY2tcbiAgICovXG4gIG9uTWVzc2FnZShjYWxsYmFjayl7XG4gICAgbGV0IHJlZiA9IHRoaXMubWFrZVJlZigpXG4gICAgdGhpcy5zdGF0ZUNoYW5nZUNhbGxiYWNrcy5tZXNzYWdlLnB1c2goW3JlZiwgY2FsbGJhY2tdKVxuICAgIHJldHVybiByZWZcbiAgfVxuXG4gIC8qKlxuICAgKiBQaW5ncyB0aGUgc2VydmVyIGFuZCBpbnZva2VzIHRoZSBjYWxsYmFjayB3aXRoIHRoZSBSVFQgaW4gbWlsbGlzZWNvbmRzXG4gICAqIEBwYXJhbSB7RnVuY3Rpb259IGNhbGxiYWNrXG4gICAqXG4gICAqIFJldHVybnMgdHJ1ZSBpZiB0aGUgcGluZyB3YXMgcHVzaGVkIG9yIGZhbHNlIGlmIHVuYWJsZSB0byBiZSBwdXNoZWQuXG4gICAqL1xuICBwaW5nKGNhbGxiYWNrKXtcbiAgICBpZighdGhpcy5pc0Nvbm5lY3RlZCgpKXsgcmV0dXJuIGZhbHNlIH1cbiAgICBsZXQgcmVmID0gdGhpcy5tYWtlUmVmKClcbiAgICBsZXQgc3RhcnRUaW1lID0gRGF0ZS5ub3coKVxuICAgIHRoaXMucHVzaCh7dG9waWM6IFwicGhvZW5peFwiLCBldmVudDogXCJoZWFydGJlYXRcIiwgcGF5bG9hZDoge30sIHJlZjogcmVmfSlcbiAgICBsZXQgb25Nc2dSZWYgPSB0aGlzLm9uTWVzc2FnZShtc2cgPT4ge1xuICAgICAgaWYobXNnLnJlZiA9PT0gcmVmKXtcbiAgICAgICAgdGhpcy5vZmYoW29uTXNnUmVmXSlcbiAgICAgICAgY2FsbGJhY2soRGF0ZS5ub3coKSAtIHN0YXJ0VGltZSlcbiAgICAgIH1cbiAgICB9KVxuICAgIHJldHVybiB0cnVlXG4gIH1cblxuICAvKipcbiAgICogQHByaXZhdGVcbiAgICovXG5cbiAgdHJhbnNwb3J0Q29ubmVjdCgpe1xuICAgIHRoaXMuY29ubmVjdENsb2NrKytcbiAgICB0aGlzLmNsb3NlV2FzQ2xlYW4gPSBmYWxzZVxuICAgIGxldCBwcm90b2NvbHMgPSB1bmRlZmluZWRcbiAgICAvLyBTZWMtV2ViU29ja2V0LVByb3RvY29sIGJhc2VkIHRva2VuXG4gICAgLy8gKGxvbmdwb2xsIHVzZXMgQXV0aG9yaXphdGlvbiBoZWFkZXIgaW5zdGVhZClcbiAgICBpZih0aGlzLmF1dGhUb2tlbil7XG4gICAgICBwcm90b2NvbHMgPSBbXCJwaG9lbml4XCIsIGAke0FVVEhfVE9LRU5fUFJFRklYfSR7YnRvYSh0aGlzLmF1dGhUb2tlbikucmVwbGFjZSgvPS9nLCBcIlwiKX1gXVxuICAgIH1cbiAgICB0aGlzLmNvbm4gPSBuZXcgdGhpcy50cmFuc3BvcnQodGhpcy5lbmRQb2ludFVSTCgpLCBwcm90b2NvbHMpXG4gICAgdGhpcy5jb25uLmJpbmFyeVR5cGUgPSB0aGlzLmJpbmFyeVR5cGVcbiAgICB0aGlzLmNvbm4udGltZW91dCA9IHRoaXMubG9uZ3BvbGxlclRpbWVvdXRcbiAgICB0aGlzLmNvbm4ub25vcGVuID0gKCkgPT4gdGhpcy5vbkNvbm5PcGVuKClcbiAgICB0aGlzLmNvbm4ub25lcnJvciA9IGVycm9yID0+IHRoaXMub25Db25uRXJyb3IoZXJyb3IpXG4gICAgdGhpcy5jb25uLm9ubWVzc2FnZSA9IGV2ZW50ID0+IHRoaXMub25Db25uTWVzc2FnZShldmVudClcbiAgICB0aGlzLmNvbm4ub25jbG9zZSA9IGV2ZW50ID0+IHRoaXMub25Db25uQ2xvc2UoZXZlbnQpXG4gIH1cblxuICBnZXRTZXNzaW9uKGtleSl7IHJldHVybiB0aGlzLnNlc3Npb25TdG9yZSAmJiB0aGlzLnNlc3Npb25TdG9yZS5nZXRJdGVtKGtleSkgfVxuXG4gIHN0b3JlU2Vzc2lvbihrZXksIHZhbCl7IHRoaXMuc2Vzc2lvblN0b3JlICYmIHRoaXMuc2Vzc2lvblN0b3JlLnNldEl0ZW0oa2V5LCB2YWwpIH1cblxuICBjb25uZWN0V2l0aEZhbGxiYWNrKGZhbGxiYWNrVHJhbnNwb3J0LCBmYWxsYmFja1RocmVzaG9sZCA9IDI1MDApe1xuICAgIGNsZWFyVGltZW91dCh0aGlzLmZhbGxiYWNrVGltZXIpXG4gICAgbGV0IGVzdGFibGlzaGVkID0gZmFsc2VcbiAgICBsZXQgcHJpbWFyeVRyYW5zcG9ydCA9IHRydWVcbiAgICBsZXQgb3BlblJlZiwgZXJyb3JSZWZcbiAgICBsZXQgZmFsbGJhY2sgPSAocmVhc29uKSA9PiB7XG4gICAgICB0aGlzLmxvZyhcInRyYW5zcG9ydFwiLCBgZmFsbGluZyBiYWNrIHRvICR7ZmFsbGJhY2tUcmFuc3BvcnQubmFtZX0uLi5gLCByZWFzb24pXG4gICAgICB0aGlzLm9mZihbb3BlblJlZiwgZXJyb3JSZWZdKVxuICAgICAgcHJpbWFyeVRyYW5zcG9ydCA9IGZhbHNlXG4gICAgICB0aGlzLnJlcGxhY2VUcmFuc3BvcnQoZmFsbGJhY2tUcmFuc3BvcnQpXG4gICAgICB0aGlzLnRyYW5zcG9ydENvbm5lY3QoKVxuICAgIH1cbiAgICBpZih0aGlzLmdldFNlc3Npb24oYHBoeDpmYWxsYmFjazoke2ZhbGxiYWNrVHJhbnNwb3J0Lm5hbWV9YCkpeyByZXR1cm4gZmFsbGJhY2soXCJtZW1vcml6ZWRcIikgfVxuXG4gICAgdGhpcy5mYWxsYmFja1RpbWVyID0gc2V0VGltZW91dChmYWxsYmFjaywgZmFsbGJhY2tUaHJlc2hvbGQpXG5cbiAgICBlcnJvclJlZiA9IHRoaXMub25FcnJvcihyZWFzb24gPT4ge1xuICAgICAgdGhpcy5sb2coXCJ0cmFuc3BvcnRcIiwgXCJlcnJvclwiLCByZWFzb24pXG4gICAgICBpZihwcmltYXJ5VHJhbnNwb3J0ICYmICFlc3RhYmxpc2hlZCl7XG4gICAgICAgIGNsZWFyVGltZW91dCh0aGlzLmZhbGxiYWNrVGltZXIpXG4gICAgICAgIGZhbGxiYWNrKHJlYXNvbilcbiAgICAgIH1cbiAgICB9KVxuICAgIHRoaXMub25PcGVuKCgpID0+IHtcbiAgICAgIGVzdGFibGlzaGVkID0gdHJ1ZVxuICAgICAgaWYoIXByaW1hcnlUcmFuc3BvcnQpe1xuICAgICAgICAvLyBvbmx5IG1lbW9yaXplIExQIGlmIHdlIG5ldmVyIGNvbm5lY3RlZCB0byBwcmltYXJ5XG4gICAgICAgIGlmKCF0aGlzLnByaW1hcnlQYXNzZWRIZWFsdGhDaGVjayl7IHRoaXMuc3RvcmVTZXNzaW9uKGBwaHg6ZmFsbGJhY2s6JHtmYWxsYmFja1RyYW5zcG9ydC5uYW1lfWAsIFwidHJ1ZVwiKSB9XG4gICAgICAgIHJldHVybiB0aGlzLmxvZyhcInRyYW5zcG9ydFwiLCBgZXN0YWJsaXNoZWQgJHtmYWxsYmFja1RyYW5zcG9ydC5uYW1lfSBmYWxsYmFja2ApXG4gICAgICB9XG4gICAgICAvLyBpZiB3ZSd2ZSBlc3RhYmxpc2hlZCBwcmltYXJ5LCBnaXZlIHRoZSBmYWxsYmFjayBhIG5ldyBwZXJpb2QgdG8gYXR0ZW1wdCBwaW5nXG4gICAgICBjbGVhclRpbWVvdXQodGhpcy5mYWxsYmFja1RpbWVyKVxuICAgICAgdGhpcy5mYWxsYmFja1RpbWVyID0gc2V0VGltZW91dChmYWxsYmFjaywgZmFsbGJhY2tUaHJlc2hvbGQpXG4gICAgICB0aGlzLnBpbmcocnR0ID0+IHtcbiAgICAgICAgdGhpcy5sb2coXCJ0cmFuc3BvcnRcIiwgXCJjb25uZWN0ZWQgdG8gcHJpbWFyeSBhZnRlclwiLCBydHQpXG4gICAgICAgIHRoaXMucHJpbWFyeVBhc3NlZEhlYWx0aENoZWNrID0gdHJ1ZVxuICAgICAgICBjbGVhclRpbWVvdXQodGhpcy5mYWxsYmFja1RpbWVyKVxuICAgICAgfSlcbiAgICB9KVxuICAgIHRoaXMudHJhbnNwb3J0Q29ubmVjdCgpXG4gIH1cblxuICBjbGVhckhlYXJ0YmVhdHMoKXtcbiAgICBjbGVhclRpbWVvdXQodGhpcy5oZWFydGJlYXRUaW1lcilcbiAgICBjbGVhclRpbWVvdXQodGhpcy5oZWFydGJlYXRUaW1lb3V0VGltZXIpXG4gIH1cblxuICBvbkNvbm5PcGVuKCl7XG4gICAgaWYodGhpcy5oYXNMb2dnZXIoKSkgdGhpcy5sb2coXCJ0cmFuc3BvcnRcIiwgYCR7dGhpcy50cmFuc3BvcnQubmFtZX0gY29ubmVjdGVkIHRvICR7dGhpcy5lbmRQb2ludFVSTCgpfWApXG4gICAgdGhpcy5jbG9zZVdhc0NsZWFuID0gZmFsc2VcbiAgICB0aGlzLmRpc2Nvbm5lY3RpbmcgPSBmYWxzZVxuICAgIHRoaXMuZXN0YWJsaXNoZWRDb25uZWN0aW9ucysrXG4gICAgdGhpcy5mbHVzaFNlbmRCdWZmZXIoKVxuICAgIHRoaXMucmVjb25uZWN0VGltZXIucmVzZXQoKVxuICAgIHRoaXMucmVzZXRIZWFydGJlYXQoKVxuICAgIHRoaXMuc3RhdGVDaGFuZ2VDYWxsYmFja3Mub3Blbi5mb3JFYWNoKChbLCBjYWxsYmFja10pID0+IGNhbGxiYWNrKCkpXG4gIH1cblxuICAvKipcbiAgICogQHByaXZhdGVcbiAgICovXG5cbiAgaGVhcnRiZWF0VGltZW91dCgpe1xuICAgIGlmKHRoaXMucGVuZGluZ0hlYXJ0YmVhdFJlZil7XG4gICAgICB0aGlzLnBlbmRpbmdIZWFydGJlYXRSZWYgPSBudWxsXG4gICAgICBpZih0aGlzLmhhc0xvZ2dlcigpKXsgdGhpcy5sb2coXCJ0cmFuc3BvcnRcIiwgXCJoZWFydGJlYXQgdGltZW91dC4gQXR0ZW1wdGluZyB0byByZS1lc3RhYmxpc2ggY29ubmVjdGlvblwiKSB9XG4gICAgICB0aGlzLnRyaWdnZXJDaGFuRXJyb3IoKVxuICAgICAgdGhpcy5jbG9zZVdhc0NsZWFuID0gZmFsc2VcbiAgICAgIHRoaXMudGVhcmRvd24oKCkgPT4gdGhpcy5yZWNvbm5lY3RUaW1lci5zY2hlZHVsZVRpbWVvdXQoKSwgV1NfQ0xPU0VfTk9STUFMLCBcImhlYXJ0YmVhdCB0aW1lb3V0XCIpXG4gICAgfVxuICB9XG5cbiAgcmVzZXRIZWFydGJlYXQoKXtcbiAgICBpZih0aGlzLmNvbm4gJiYgdGhpcy5jb25uLnNraXBIZWFydGJlYXQpeyByZXR1cm4gfVxuICAgIHRoaXMucGVuZGluZ0hlYXJ0YmVhdFJlZiA9IG51bGxcbiAgICB0aGlzLmNsZWFySGVhcnRiZWF0cygpXG4gICAgdGhpcy5oZWFydGJlYXRUaW1lciA9IHNldFRpbWVvdXQoKCkgPT4gdGhpcy5zZW5kSGVhcnRiZWF0KCksIHRoaXMuaGVhcnRiZWF0SW50ZXJ2YWxNcylcbiAgfVxuXG4gIHRlYXJkb3duKGNhbGxiYWNrLCBjb2RlLCByZWFzb24pe1xuICAgIGlmKCF0aGlzLmNvbm4pe1xuICAgICAgcmV0dXJuIGNhbGxiYWNrICYmIGNhbGxiYWNrKClcbiAgICB9XG4gICAgbGV0IGNvbm5lY3RDbG9jayA9IHRoaXMuY29ubmVjdENsb2NrXG5cbiAgICB0aGlzLndhaXRGb3JCdWZmZXJEb25lKCgpID0+IHtcbiAgICAgIGlmKGNvbm5lY3RDbG9jayAhPT0gdGhpcy5jb25uZWN0Q2xvY2speyByZXR1cm4gfVxuICAgICAgaWYodGhpcy5jb25uKXtcbiAgICAgICAgaWYoY29kZSl7IHRoaXMuY29ubi5jbG9zZShjb2RlLCByZWFzb24gfHwgXCJcIikgfSBlbHNlIHsgdGhpcy5jb25uLmNsb3NlKCkgfVxuICAgICAgfVxuXG4gICAgICB0aGlzLndhaXRGb3JTb2NrZXRDbG9zZWQoKCkgPT4ge1xuICAgICAgICBpZihjb25uZWN0Q2xvY2sgIT09IHRoaXMuY29ubmVjdENsb2NrKXsgcmV0dXJuIH1cbiAgICAgICAgaWYodGhpcy5jb25uKXtcbiAgICAgICAgICB0aGlzLmNvbm4ub25vcGVuID0gZnVuY3Rpb24gKCl7IH0gLy8gbm9vcFxuICAgICAgICAgIHRoaXMuY29ubi5vbmVycm9yID0gZnVuY3Rpb24gKCl7IH0gLy8gbm9vcFxuICAgICAgICAgIHRoaXMuY29ubi5vbm1lc3NhZ2UgPSBmdW5jdGlvbiAoKXsgfSAvLyBub29wXG4gICAgICAgICAgdGhpcy5jb25uLm9uY2xvc2UgPSBmdW5jdGlvbiAoKXsgfSAvLyBub29wXG4gICAgICAgICAgdGhpcy5jb25uID0gbnVsbFxuICAgICAgICB9XG5cbiAgICAgICAgY2FsbGJhY2sgJiYgY2FsbGJhY2soKVxuICAgICAgfSlcbiAgICB9KVxuICB9XG5cbiAgd2FpdEZvckJ1ZmZlckRvbmUoY2FsbGJhY2ssIHRyaWVzID0gMSl7XG4gICAgaWYodHJpZXMgPT09IDUgfHwgIXRoaXMuY29ubiB8fCAhdGhpcy5jb25uLmJ1ZmZlcmVkQW1vdW50KXtcbiAgICAgIGNhbGxiYWNrKClcbiAgICAgIHJldHVyblxuICAgIH1cblxuICAgIHNldFRpbWVvdXQoKCkgPT4ge1xuICAgICAgdGhpcy53YWl0Rm9yQnVmZmVyRG9uZShjYWxsYmFjaywgdHJpZXMgKyAxKVxuICAgIH0sIDE1MCAqIHRyaWVzKVxuICB9XG5cbiAgd2FpdEZvclNvY2tldENsb3NlZChjYWxsYmFjaywgdHJpZXMgPSAxKXtcbiAgICBpZih0cmllcyA9PT0gNSB8fCAhdGhpcy5jb25uIHx8IHRoaXMuY29ubi5yZWFkeVN0YXRlID09PSBTT0NLRVRfU1RBVEVTLmNsb3NlZCl7XG4gICAgICBjYWxsYmFjaygpXG4gICAgICByZXR1cm5cbiAgICB9XG5cbiAgICBzZXRUaW1lb3V0KCgpID0+IHtcbiAgICAgIHRoaXMud2FpdEZvclNvY2tldENsb3NlZChjYWxsYmFjaywgdHJpZXMgKyAxKVxuICAgIH0sIDE1MCAqIHRyaWVzKVxuICB9XG5cbiAgb25Db25uQ2xvc2UoZXZlbnQpe1xuICAgIGxldCBjbG9zZUNvZGUgPSBldmVudCAmJiBldmVudC5jb2RlXG4gICAgaWYodGhpcy5oYXNMb2dnZXIoKSkgdGhpcy5sb2coXCJ0cmFuc3BvcnRcIiwgXCJjbG9zZVwiLCBldmVudClcbiAgICB0aGlzLnRyaWdnZXJDaGFuRXJyb3IoKVxuICAgIHRoaXMuY2xlYXJIZWFydGJlYXRzKClcbiAgICBpZighdGhpcy5jbG9zZVdhc0NsZWFuICYmIGNsb3NlQ29kZSAhPT0gMTAwMCl7XG4gICAgICB0aGlzLnJlY29ubmVjdFRpbWVyLnNjaGVkdWxlVGltZW91dCgpXG4gICAgfVxuICAgIHRoaXMuc3RhdGVDaGFuZ2VDYWxsYmFja3MuY2xvc2UuZm9yRWFjaCgoWywgY2FsbGJhY2tdKSA9PiBjYWxsYmFjayhldmVudCkpXG4gIH1cblxuICAvKipcbiAgICogQHByaXZhdGVcbiAgICovXG4gIG9uQ29ubkVycm9yKGVycm9yKXtcbiAgICBpZih0aGlzLmhhc0xvZ2dlcigpKSB0aGlzLmxvZyhcInRyYW5zcG9ydFwiLCBlcnJvcilcbiAgICBsZXQgdHJhbnNwb3J0QmVmb3JlID0gdGhpcy50cmFuc3BvcnRcbiAgICBsZXQgZXN0YWJsaXNoZWRCZWZvcmUgPSB0aGlzLmVzdGFibGlzaGVkQ29ubmVjdGlvbnNcbiAgICB0aGlzLnN0YXRlQ2hhbmdlQ2FsbGJhY2tzLmVycm9yLmZvckVhY2goKFssIGNhbGxiYWNrXSkgPT4ge1xuICAgICAgY2FsbGJhY2soZXJyb3IsIHRyYW5zcG9ydEJlZm9yZSwgZXN0YWJsaXNoZWRCZWZvcmUpXG4gICAgfSlcbiAgICBpZih0cmFuc3BvcnRCZWZvcmUgPT09IHRoaXMudHJhbnNwb3J0IHx8IGVzdGFibGlzaGVkQmVmb3JlID4gMCl7XG4gICAgICB0aGlzLnRyaWdnZXJDaGFuRXJyb3IoKVxuICAgIH1cbiAgfVxuXG4gIC8qKlxuICAgKiBAcHJpdmF0ZVxuICAgKi9cbiAgdHJpZ2dlckNoYW5FcnJvcigpe1xuICAgIHRoaXMuY2hhbm5lbHMuZm9yRWFjaChjaGFubmVsID0+IHtcbiAgICAgIGlmKCEoY2hhbm5lbC5pc0Vycm9yZWQoKSB8fCBjaGFubmVsLmlzTGVhdmluZygpIHx8IGNoYW5uZWwuaXNDbG9zZWQoKSkpe1xuICAgICAgICBjaGFubmVsLnRyaWdnZXIoQ0hBTk5FTF9FVkVOVFMuZXJyb3IpXG4gICAgICB9XG4gICAgfSlcbiAgfVxuXG4gIC8qKlxuICAgKiBAcmV0dXJucyB7c3RyaW5nfVxuICAgKi9cbiAgY29ubmVjdGlvblN0YXRlKCl7XG4gICAgc3dpdGNoKHRoaXMuY29ubiAmJiB0aGlzLmNvbm4ucmVhZHlTdGF0ZSl7XG4gICAgICBjYXNlIFNPQ0tFVF9TVEFURVMuY29ubmVjdGluZzogcmV0dXJuIFwiY29ubmVjdGluZ1wiXG4gICAgICBjYXNlIFNPQ0tFVF9TVEFURVMub3BlbjogcmV0dXJuIFwib3BlblwiXG4gICAgICBjYXNlIFNPQ0tFVF9TVEFURVMuY2xvc2luZzogcmV0dXJuIFwiY2xvc2luZ1wiXG4gICAgICBkZWZhdWx0OiByZXR1cm4gXCJjbG9zZWRcIlxuICAgIH1cbiAgfVxuXG4gIC8qKlxuICAgKiBAcmV0dXJucyB7Ym9vbGVhbn1cbiAgICovXG4gIGlzQ29ubmVjdGVkKCl7IHJldHVybiB0aGlzLmNvbm5lY3Rpb25TdGF0ZSgpID09PSBcIm9wZW5cIiB9XG5cbiAgLyoqXG4gICAqIEBwcml2YXRlXG4gICAqXG4gICAqIEBwYXJhbSB7Q2hhbm5lbH1cbiAgICovXG4gIHJlbW92ZShjaGFubmVsKXtcbiAgICB0aGlzLm9mZihjaGFubmVsLnN0YXRlQ2hhbmdlUmVmcylcbiAgICB0aGlzLmNoYW5uZWxzID0gdGhpcy5jaGFubmVscy5maWx0ZXIoYyA9PiBjICE9PSBjaGFubmVsKVxuICB9XG5cbiAgLyoqXG4gICAqIFJlbW92ZXMgYG9uT3BlbmAsIGBvbkNsb3NlYCwgYG9uRXJyb3IsYCBhbmQgYG9uTWVzc2FnZWAgcmVnaXN0cmF0aW9ucy5cbiAgICpcbiAgICogQHBhcmFtIHtyZWZzfSAtIGxpc3Qgb2YgcmVmcyByZXR1cm5lZCBieSBjYWxscyB0b1xuICAgKiAgICAgICAgICAgICAgICAgYG9uT3BlbmAsIGBvbkNsb3NlYCwgYG9uRXJyb3IsYCBhbmQgYG9uTWVzc2FnZWBcbiAgICovXG4gIG9mZihyZWZzKXtcbiAgICBmb3IobGV0IGtleSBpbiB0aGlzLnN0YXRlQ2hhbmdlQ2FsbGJhY2tzKXtcbiAgICAgIHRoaXMuc3RhdGVDaGFuZ2VDYWxsYmFja3Nba2V5XSA9IHRoaXMuc3RhdGVDaGFuZ2VDYWxsYmFja3Nba2V5XS5maWx0ZXIoKFtyZWZdKSA9PiB7XG4gICAgICAgIHJldHVybiByZWZzLmluZGV4T2YocmVmKSA9PT0gLTFcbiAgICAgIH0pXG4gICAgfVxuICB9XG5cbiAgLyoqXG4gICAqIEluaXRpYXRlcyBhIG5ldyBjaGFubmVsIGZvciB0aGUgZ2l2ZW4gdG9waWNcbiAgICpcbiAgICogQHBhcmFtIHtzdHJpbmd9IHRvcGljXG4gICAqIEBwYXJhbSB7T2JqZWN0fSBjaGFuUGFyYW1zIC0gUGFyYW1ldGVycyBmb3IgdGhlIGNoYW5uZWxcbiAgICogQHJldHVybnMge0NoYW5uZWx9XG4gICAqL1xuICBjaGFubmVsKHRvcGljLCBjaGFuUGFyYW1zID0ge30pe1xuICAgIGxldCBjaGFuID0gbmV3IENoYW5uZWwodG9waWMsIGNoYW5QYXJhbXMsIHRoaXMpXG4gICAgdGhpcy5jaGFubmVscy5wdXNoKGNoYW4pXG4gICAgcmV0dXJuIGNoYW5cbiAgfVxuXG4gIC8qKlxuICAgKiBAcGFyYW0ge09iamVjdH0gZGF0YVxuICAgKi9cbiAgcHVzaChkYXRhKXtcbiAgICBpZih0aGlzLmhhc0xvZ2dlcigpKXtcbiAgICAgIGxldCB7dG9waWMsIGV2ZW50LCBwYXlsb2FkLCByZWYsIGpvaW5fcmVmfSA9IGRhdGFcbiAgICAgIHRoaXMubG9nKFwicHVzaFwiLCBgJHt0b3BpY30gJHtldmVudH0gKCR7am9pbl9yZWZ9LCAke3JlZn0pYCwgcGF5bG9hZClcbiAgICB9XG5cbiAgICBpZih0aGlzLmlzQ29ubmVjdGVkKCkpe1xuICAgICAgdGhpcy5lbmNvZGUoZGF0YSwgcmVzdWx0ID0+IHRoaXMuY29ubi5zZW5kKHJlc3VsdCkpXG4gICAgfSBlbHNlIHtcbiAgICAgIHRoaXMuc2VuZEJ1ZmZlci5wdXNoKCgpID0+IHRoaXMuZW5jb2RlKGRhdGEsIHJlc3VsdCA9PiB0aGlzLmNvbm4uc2VuZChyZXN1bHQpKSlcbiAgICB9XG4gIH1cblxuICAvKipcbiAgICogUmV0dXJuIHRoZSBuZXh0IG1lc3NhZ2UgcmVmLCBhY2NvdW50aW5nIGZvciBvdmVyZmxvd3NcbiAgICogQHJldHVybnMge3N0cmluZ31cbiAgICovXG4gIG1ha2VSZWYoKXtcbiAgICBsZXQgbmV3UmVmID0gdGhpcy5yZWYgKyAxXG4gICAgaWYobmV3UmVmID09PSB0aGlzLnJlZil7IHRoaXMucmVmID0gMCB9IGVsc2UgeyB0aGlzLnJlZiA9IG5ld1JlZiB9XG5cbiAgICByZXR1cm4gdGhpcy5yZWYudG9TdHJpbmcoKVxuICB9XG5cbiAgc2VuZEhlYXJ0YmVhdCgpe1xuICAgIGlmKHRoaXMucGVuZGluZ0hlYXJ0YmVhdFJlZiAmJiAhdGhpcy5pc0Nvbm5lY3RlZCgpKXsgcmV0dXJuIH1cbiAgICB0aGlzLnBlbmRpbmdIZWFydGJlYXRSZWYgPSB0aGlzLm1ha2VSZWYoKVxuICAgIHRoaXMucHVzaCh7dG9waWM6IFwicGhvZW5peFwiLCBldmVudDogXCJoZWFydGJlYXRcIiwgcGF5bG9hZDoge30sIHJlZjogdGhpcy5wZW5kaW5nSGVhcnRiZWF0UmVmfSlcbiAgICB0aGlzLmhlYXJ0YmVhdFRpbWVvdXRUaW1lciA9IHNldFRpbWVvdXQoKCkgPT4gdGhpcy5oZWFydGJlYXRUaW1lb3V0KCksIHRoaXMuaGVhcnRiZWF0SW50ZXJ2YWxNcylcbiAgfVxuXG4gIGZsdXNoU2VuZEJ1ZmZlcigpe1xuICAgIGlmKHRoaXMuaXNDb25uZWN0ZWQoKSAmJiB0aGlzLnNlbmRCdWZmZXIubGVuZ3RoID4gMCl7XG4gICAgICB0aGlzLnNlbmRCdWZmZXIuZm9yRWFjaChjYWxsYmFjayA9PiBjYWxsYmFjaygpKVxuICAgICAgdGhpcy5zZW5kQnVmZmVyID0gW11cbiAgICB9XG4gIH1cblxuICBvbkNvbm5NZXNzYWdlKHJhd01lc3NhZ2Upe1xuICAgIHRoaXMuZGVjb2RlKHJhd01lc3NhZ2UuZGF0YSwgbXNnID0+IHtcbiAgICAgIGxldCB7dG9waWMsIGV2ZW50LCBwYXlsb2FkLCByZWYsIGpvaW5fcmVmfSA9IG1zZ1xuICAgICAgaWYocmVmICYmIHJlZiA9PT0gdGhpcy5wZW5kaW5nSGVhcnRiZWF0UmVmKXtcbiAgICAgICAgdGhpcy5jbGVhckhlYXJ0YmVhdHMoKVxuICAgICAgICB0aGlzLnBlbmRpbmdIZWFydGJlYXRSZWYgPSBudWxsXG4gICAgICAgIHRoaXMuaGVhcnRiZWF0VGltZXIgPSBzZXRUaW1lb3V0KCgpID0+IHRoaXMuc2VuZEhlYXJ0YmVhdCgpLCB0aGlzLmhlYXJ0YmVhdEludGVydmFsTXMpXG4gICAgICB9XG5cbiAgICAgIGlmKHRoaXMuaGFzTG9nZ2VyKCkpIHRoaXMubG9nKFwicmVjZWl2ZVwiLCBgJHtwYXlsb2FkLnN0YXR1cyB8fCBcIlwifSAke3RvcGljfSAke2V2ZW50fSAke3JlZiAmJiBcIihcIiArIHJlZiArIFwiKVwiIHx8IFwiXCJ9YCwgcGF5bG9hZClcblxuICAgICAgZm9yKGxldCBpID0gMDsgaSA8IHRoaXMuY2hhbm5lbHMubGVuZ3RoOyBpKyspe1xuICAgICAgICBjb25zdCBjaGFubmVsID0gdGhpcy5jaGFubmVsc1tpXVxuICAgICAgICBpZighY2hhbm5lbC5pc01lbWJlcih0b3BpYywgZXZlbnQsIHBheWxvYWQsIGpvaW5fcmVmKSl7IGNvbnRpbnVlIH1cbiAgICAgICAgY2hhbm5lbC50cmlnZ2VyKGV2ZW50LCBwYXlsb2FkLCByZWYsIGpvaW5fcmVmKVxuICAgICAgfVxuXG4gICAgICBmb3IobGV0IGkgPSAwOyBpIDwgdGhpcy5zdGF0ZUNoYW5nZUNhbGxiYWNrcy5tZXNzYWdlLmxlbmd0aDsgaSsrKXtcbiAgICAgICAgbGV0IFssIGNhbGxiYWNrXSA9IHRoaXMuc3RhdGVDaGFuZ2VDYWxsYmFja3MubWVzc2FnZVtpXVxuICAgICAgICBjYWxsYmFjayhtc2cpXG4gICAgICB9XG4gICAgfSlcbiAgfVxuXG4gIGxlYXZlT3BlblRvcGljKHRvcGljKXtcbiAgICBsZXQgZHVwQ2hhbm5lbCA9IHRoaXMuY2hhbm5lbHMuZmluZChjID0+IGMudG9waWMgPT09IHRvcGljICYmIChjLmlzSm9pbmVkKCkgfHwgYy5pc0pvaW5pbmcoKSkpXG4gICAgaWYoZHVwQ2hhbm5lbCl7XG4gICAgICBpZih0aGlzLmhhc0xvZ2dlcigpKSB0aGlzLmxvZyhcInRyYW5zcG9ydFwiLCBgbGVhdmluZyBkdXBsaWNhdGUgdG9waWMgXCIke3RvcGljfVwiYClcbiAgICAgIGR1cENoYW5uZWwubGVhdmUoKVxuICAgIH1cbiAgfVxufVxuIiwgIlxuXG5cbmZ1bmN0aW9uIGlzTmVzdGVkKHgpIHtcbiAgcmV0dXJuIHguQlNfUFJJVkFURV9ORVNURURfU09NRV9OT05FICE9PSB1bmRlZmluZWQ7XG59XG5cbmZ1bmN0aW9uIHNvbWUoeCkge1xuICBpZiAoeCA9PT0gdW5kZWZpbmVkKSB7XG4gICAgcmV0dXJuIHtcbiAgICAgIEJTX1BSSVZBVEVfTkVTVEVEX1NPTUVfTk9ORTogMFxuICAgIH07XG4gIH0gZWxzZSBpZiAoeCAhPT0gbnVsbCAmJiB4LkJTX1BSSVZBVEVfTkVTVEVEX1NPTUVfTk9ORSAhPT0gdW5kZWZpbmVkKSB7XG4gICAgcmV0dXJuIHtcbiAgICAgIEJTX1BSSVZBVEVfTkVTVEVEX1NPTUVfTk9ORTogeC5CU19QUklWQVRFX05FU1RFRF9TT01FX05PTkUgKyAxIHwgMFxuICAgIH07XG4gIH0gZWxzZSB7XG4gICAgcmV0dXJuIHg7XG4gIH1cbn1cblxuZnVuY3Rpb24gZnJvbU51bGxhYmxlKHgpIHtcbiAgaWYgKHggPT0gbnVsbCkge1xuICAgIHJldHVybjtcbiAgfSBlbHNlIHtcbiAgICByZXR1cm4gc29tZSh4KTtcbiAgfVxufVxuXG5mdW5jdGlvbiBmcm9tVW5kZWZpbmVkKHgpIHtcbiAgaWYgKHggPT09IHVuZGVmaW5lZCkge1xuICAgIHJldHVybjtcbiAgfSBlbHNlIHtcbiAgICByZXR1cm4gc29tZSh4KTtcbiAgfVxufVxuXG5mdW5jdGlvbiBmcm9tTnVsbCh4KSB7XG4gIGlmICh4ID09PSBudWxsKSB7XG4gICAgcmV0dXJuO1xuICB9IGVsc2Uge1xuICAgIHJldHVybiBzb21lKHgpO1xuICB9XG59XG5cbmZ1bmN0aW9uIHZhbEZyb21PcHRpb24oeCkge1xuICBpZiAoeCA9PT0gbnVsbCB8fCB4LkJTX1BSSVZBVEVfTkVTVEVEX1NPTUVfTk9ORSA9PT0gdW5kZWZpbmVkKSB7XG4gICAgcmV0dXJuIHg7XG4gIH1cbiAgbGV0IGRlcHRoID0geC5CU19QUklWQVRFX05FU1RFRF9TT01FX05PTkU7XG4gIGlmIChkZXB0aCA9PT0gMCkge1xuICAgIHJldHVybjtcbiAgfSBlbHNlIHtcbiAgICByZXR1cm4ge1xuICAgICAgQlNfUFJJVkFURV9ORVNURURfU09NRV9OT05FOiBkZXB0aCAtIDEgfCAwXG4gICAgfTtcbiAgfVxufVxuXG5mdW5jdGlvbiB0b1VuZGVmaW5lZCh4KSB7XG4gIGlmICh4ID09PSB1bmRlZmluZWQpIHtcbiAgICByZXR1cm47XG4gIH0gZWxzZSB7XG4gICAgcmV0dXJuIHZhbEZyb21PcHRpb24oeCk7XG4gIH1cbn1cblxuZnVuY3Rpb24gdW53cmFwUG9seVZhcih4KSB7XG4gIGlmICh4ICE9PSB1bmRlZmluZWQpIHtcbiAgICByZXR1cm4geC5WQUw7XG4gIH0gZWxzZSB7XG4gICAgcmV0dXJuIHg7XG4gIH1cbn1cblxuZXhwb3J0IHtcbiAgZnJvbU51bGxhYmxlLFxuICBmcm9tVW5kZWZpbmVkLFxuICBmcm9tTnVsbCxcbiAgdmFsRnJvbU9wdGlvbixcbiAgc29tZSxcbiAgaXNOZXN0ZWQsXG4gIHRvVW5kZWZpbmVkLFxuICB1bndyYXBQb2x5VmFyLFxufVxuLyogTm8gc2lkZSBlZmZlY3QgKi9cbiIsICJcblxuaW1wb3J0ICogYXMgU3RkbGliX0pzRXJyb3IgZnJvbSBcIi4vU3RkbGliX0pzRXJyb3IuanNcIjtcbmltcG9ydCAqIGFzIFByaW1pdGl2ZV9vcHRpb24gZnJvbSBcIi4vUHJpbWl0aXZlX29wdGlvbi5qc1wiO1xuXG5mdW5jdGlvbiBmaWx0ZXIob3B0LCBwKSB7XG4gIGlmIChvcHQgIT09IHVuZGVmaW5lZCAmJiBwKFByaW1pdGl2ZV9vcHRpb24udmFsRnJvbU9wdGlvbihvcHQpKSkge1xuICAgIHJldHVybiBvcHQ7XG4gIH1cbn1cblxuZnVuY3Rpb24gZm9yRWFjaChvcHQsIGYpIHtcbiAgaWYgKG9wdCAhPT0gdW5kZWZpbmVkKSB7XG4gICAgcmV0dXJuIGYoUHJpbWl0aXZlX29wdGlvbi52YWxGcm9tT3B0aW9uKG9wdCkpO1xuICB9XG59XG5cbmZ1bmN0aW9uIGdldE9yVGhyb3coeCwgbWVzc2FnZSkge1xuICBpZiAoeCAhPT0gdW5kZWZpbmVkKSB7XG4gICAgcmV0dXJuIFByaW1pdGl2ZV9vcHRpb24udmFsRnJvbU9wdGlvbih4KTtcbiAgfSBlbHNlIHtcbiAgICByZXR1cm4gU3RkbGliX0pzRXJyb3IucGFuaWMobWVzc2FnZSAhPT0gdW5kZWZpbmVkID8gbWVzc2FnZSA6IFwiT3B0aW9uLmdldE9yVGhyb3cgY2FsbGVkIGZvciBOb25lIHZhbHVlXCIpO1xuICB9XG59XG5cbmZ1bmN0aW9uIG1hcE9yKG9wdCwgJCRkZWZhdWx0LCBmKSB7XG4gIGlmIChvcHQgIT09IHVuZGVmaW5lZCkge1xuICAgIHJldHVybiBmKFByaW1pdGl2ZV9vcHRpb24udmFsRnJvbU9wdGlvbihvcHQpKTtcbiAgfSBlbHNlIHtcbiAgICByZXR1cm4gJCRkZWZhdWx0O1xuICB9XG59XG5cbmZ1bmN0aW9uIG1hcChvcHQsIGYpIHtcbiAgaWYgKG9wdCAhPT0gdW5kZWZpbmVkKSB7XG4gICAgcmV0dXJuIFByaW1pdGl2ZV9vcHRpb24uc29tZShmKFByaW1pdGl2ZV9vcHRpb24udmFsRnJvbU9wdGlvbihvcHQpKSk7XG4gIH1cbn1cblxuZnVuY3Rpb24gZmxhdE1hcChvcHQsIGYpIHtcbiAgaWYgKG9wdCAhPT0gdW5kZWZpbmVkKSB7XG4gICAgcmV0dXJuIGYoUHJpbWl0aXZlX29wdGlvbi52YWxGcm9tT3B0aW9uKG9wdCkpO1xuICB9XG59XG5cbmZ1bmN0aW9uIGdldE9yKG9wdCwgJCRkZWZhdWx0KSB7XG4gIGlmIChvcHQgIT09IHVuZGVmaW5lZCkge1xuICAgIHJldHVybiBQcmltaXRpdmVfb3B0aW9uLnZhbEZyb21PcHRpb24ob3B0KTtcbiAgfSBlbHNlIHtcbiAgICByZXR1cm4gJCRkZWZhdWx0O1xuICB9XG59XG5cbmZ1bmN0aW9uIG9yRWxzZShvcHQsIG90aGVyKSB7XG4gIGlmIChvcHQgIT09IHVuZGVmaW5lZCkge1xuICAgIHJldHVybiBvcHQ7XG4gIH0gZWxzZSB7XG4gICAgcmV0dXJuIG90aGVyO1xuICB9XG59XG5cbmZ1bmN0aW9uIGlzU29tZSh4KSB7XG4gIHJldHVybiB4ICE9PSB1bmRlZmluZWQ7XG59XG5cbmZ1bmN0aW9uIGlzTm9uZSh4KSB7XG4gIHJldHVybiB4ID09PSB1bmRlZmluZWQ7XG59XG5cbmZ1bmN0aW9uIGVxdWFsKGEsIGIsIGVxKSB7XG4gIGlmIChhICE9PSB1bmRlZmluZWQpIHtcbiAgICBpZiAoYiAhPT0gdW5kZWZpbmVkKSB7XG4gICAgICByZXR1cm4gZXEoUHJpbWl0aXZlX29wdGlvbi52YWxGcm9tT3B0aW9uKGEpLCBQcmltaXRpdmVfb3B0aW9uLnZhbEZyb21PcHRpb24oYikpO1xuICAgIH0gZWxzZSB7XG4gICAgICByZXR1cm4gZmFsc2U7XG4gICAgfVxuICB9IGVsc2Uge1xuICAgIHJldHVybiBiID09PSB1bmRlZmluZWQ7XG4gIH1cbn1cblxuZnVuY3Rpb24gY29tcGFyZShhLCBiLCBjbXApIHtcbiAgaWYgKGEgIT09IHVuZGVmaW5lZCkge1xuICAgIGlmIChiICE9PSB1bmRlZmluZWQpIHtcbiAgICAgIHJldHVybiBjbXAoUHJpbWl0aXZlX29wdGlvbi52YWxGcm9tT3B0aW9uKGEpLCBQcmltaXRpdmVfb3B0aW9uLnZhbEZyb21PcHRpb24oYikpO1xuICAgIH0gZWxzZSB7XG4gICAgICByZXR1cm4gMTtcbiAgICB9XG4gIH0gZWxzZSBpZiAoYiAhPT0gdW5kZWZpbmVkKSB7XG4gICAgcmV0dXJuIC0xO1xuICB9IGVsc2Uge1xuICAgIHJldHVybiAwO1xuICB9XG59XG5cbmZ1bmN0aW9uIGFsbChvcHRpb25zKSB7XG4gIGxldCBhY2MgPSBbXTtcbiAgbGV0IGhhc05vbmUgPSBmYWxzZTtcbiAgbGV0IGluZGV4ID0gMDtcbiAgd2hpbGUgKGhhc05vbmUgPT09IGZhbHNlICYmIGluZGV4IDwgb3B0aW9ucy5sZW5ndGgpIHtcbiAgICBsZXQgdmFsdWUgPSBvcHRpb25zW2luZGV4XTtcbiAgICBpZiAodmFsdWUgIT09IHVuZGVmaW5lZCkge1xuICAgICAgYWNjLnB1c2goUHJpbWl0aXZlX29wdGlvbi52YWxGcm9tT3B0aW9uKHZhbHVlKSk7XG4gICAgICBpbmRleCA9IGluZGV4ICsgMSB8IDA7XG4gICAgfSBlbHNlIHtcbiAgICAgIGhhc05vbmUgPSB0cnVlO1xuICAgIH1cbiAgfTtcbiAgaWYgKGhhc05vbmUpIHtcbiAgICByZXR1cm47XG4gIH0gZWxzZSB7XG4gICAgcmV0dXJuIGFjYztcbiAgfVxufVxuXG5mdW5jdGlvbiBhbGwyKHBhcmFtKSB7XG4gIGxldCBiID0gcGFyYW1bMV07XG4gIGxldCBhID0gcGFyYW1bMF07XG4gIGlmIChhICE9PSB1bmRlZmluZWQgJiYgYiAhPT0gdW5kZWZpbmVkKSB7XG4gICAgcmV0dXJuIFtcbiAgICAgIFByaW1pdGl2ZV9vcHRpb24udmFsRnJvbU9wdGlvbihhKSxcbiAgICAgIFByaW1pdGl2ZV9vcHRpb24udmFsRnJvbU9wdGlvbihiKVxuICAgIF07XG4gIH1cbn1cblxuZnVuY3Rpb24gYWxsMyhwYXJhbSkge1xuICBsZXQgYyA9IHBhcmFtWzJdO1xuICBsZXQgYiA9IHBhcmFtWzFdO1xuICBsZXQgYSA9IHBhcmFtWzBdO1xuICBpZiAoYSAhPT0gdW5kZWZpbmVkICYmIGIgIT09IHVuZGVmaW5lZCAmJiBjICE9PSB1bmRlZmluZWQpIHtcbiAgICByZXR1cm4gW1xuICAgICAgUHJpbWl0aXZlX29wdGlvbi52YWxGcm9tT3B0aW9uKGEpLFxuICAgICAgUHJpbWl0aXZlX29wdGlvbi52YWxGcm9tT3B0aW9uKGIpLFxuICAgICAgUHJpbWl0aXZlX29wdGlvbi52YWxGcm9tT3B0aW9uKGMpXG4gICAgXTtcbiAgfVxufVxuXG5mdW5jdGlvbiBhbGw0KHBhcmFtKSB7XG4gIGxldCBkID0gcGFyYW1bM107XG4gIGxldCBjID0gcGFyYW1bMl07XG4gIGxldCBiID0gcGFyYW1bMV07XG4gIGxldCBhID0gcGFyYW1bMF07XG4gIGlmIChhICE9PSB1bmRlZmluZWQgJiYgYiAhPT0gdW5kZWZpbmVkICYmIGMgIT09IHVuZGVmaW5lZCAmJiBkICE9PSB1bmRlZmluZWQpIHtcbiAgICByZXR1cm4gW1xuICAgICAgUHJpbWl0aXZlX29wdGlvbi52YWxGcm9tT3B0aW9uKGEpLFxuICAgICAgUHJpbWl0aXZlX29wdGlvbi52YWxGcm9tT3B0aW9uKGIpLFxuICAgICAgUHJpbWl0aXZlX29wdGlvbi52YWxGcm9tT3B0aW9uKGMpLFxuICAgICAgUHJpbWl0aXZlX29wdGlvbi52YWxGcm9tT3B0aW9uKGQpXG4gICAgXTtcbiAgfVxufVxuXG5mdW5jdGlvbiBhbGw1KHBhcmFtKSB7XG4gIGxldCBlID0gcGFyYW1bNF07XG4gIGxldCBkID0gcGFyYW1bM107XG4gIGxldCBjID0gcGFyYW1bMl07XG4gIGxldCBiID0gcGFyYW1bMV07XG4gIGxldCBhID0gcGFyYW1bMF07XG4gIGlmIChhICE9PSB1bmRlZmluZWQgJiYgYiAhPT0gdW5kZWZpbmVkICYmIGMgIT09IHVuZGVmaW5lZCAmJiBkICE9PSB1bmRlZmluZWQgJiYgZSAhPT0gdW5kZWZpbmVkKSB7XG4gICAgcmV0dXJuIFtcbiAgICAgIFByaW1pdGl2ZV9vcHRpb24udmFsRnJvbU9wdGlvbihhKSxcbiAgICAgIFByaW1pdGl2ZV9vcHRpb24udmFsRnJvbU9wdGlvbihiKSxcbiAgICAgIFByaW1pdGl2ZV9vcHRpb24udmFsRnJvbU9wdGlvbihjKSxcbiAgICAgIFByaW1pdGl2ZV9vcHRpb24udmFsRnJvbU9wdGlvbihkKSxcbiAgICAgIFByaW1pdGl2ZV9vcHRpb24udmFsRnJvbU9wdGlvbihlKVxuICAgIF07XG4gIH1cbn1cblxuZnVuY3Rpb24gYWxsNihwYXJhbSkge1xuICBsZXQgZiA9IHBhcmFtWzVdO1xuICBsZXQgZSA9IHBhcmFtWzRdO1xuICBsZXQgZCA9IHBhcmFtWzNdO1xuICBsZXQgYyA9IHBhcmFtWzJdO1xuICBsZXQgYiA9IHBhcmFtWzFdO1xuICBsZXQgYSA9IHBhcmFtWzBdO1xuICBpZiAoYSAhPT0gdW5kZWZpbmVkICYmIGIgIT09IHVuZGVmaW5lZCAmJiBjICE9PSB1bmRlZmluZWQgJiYgZCAhPT0gdW5kZWZpbmVkICYmIGUgIT09IHVuZGVmaW5lZCAmJiBmICE9PSB1bmRlZmluZWQpIHtcbiAgICByZXR1cm4gW1xuICAgICAgUHJpbWl0aXZlX29wdGlvbi52YWxGcm9tT3B0aW9uKGEpLFxuICAgICAgUHJpbWl0aXZlX29wdGlvbi52YWxGcm9tT3B0aW9uKGIpLFxuICAgICAgUHJpbWl0aXZlX29wdGlvbi52YWxGcm9tT3B0aW9uKGMpLFxuICAgICAgUHJpbWl0aXZlX29wdGlvbi52YWxGcm9tT3B0aW9uKGQpLFxuICAgICAgUHJpbWl0aXZlX29wdGlvbi52YWxGcm9tT3B0aW9uKGUpLFxuICAgICAgUHJpbWl0aXZlX29wdGlvbi52YWxGcm9tT3B0aW9uKGYpXG4gICAgXTtcbiAgfVxufVxuXG5sZXQgZ2V0RXhuID0gZ2V0T3JUaHJvdztcblxubGV0IG1hcFdpdGhEZWZhdWx0ID0gbWFwT3I7XG5cbmxldCBnZXRXaXRoRGVmYXVsdCA9IGdldE9yO1xuXG5leHBvcnQge1xuICBmaWx0ZXIsXG4gIGZvckVhY2gsXG4gIGdldEV4bixcbiAgZ2V0T3JUaHJvdyxcbiAgbWFwT3IsXG4gIG1hcFdpdGhEZWZhdWx0LFxuICBtYXAsXG4gIGZsYXRNYXAsXG4gIGdldE9yLFxuICBnZXRXaXRoRGVmYXVsdCxcbiAgb3JFbHNlLFxuICBpc1NvbWUsXG4gIGlzTm9uZSxcbiAgZXF1YWwsXG4gIGNvbXBhcmUsXG4gIGFsbCxcbiAgYWxsMixcbiAgYWxsMyxcbiAgYWxsNCxcbiAgYWxsNSxcbiAgYWxsNixcbn1cbi8qIE5vIHNpZGUgZWZmZWN0ICovXG4iLCAiXG5cbmltcG9ydCAqIGFzIFN0ZGxpYl9Kc0Vycm9yIGZyb20gXCIuL1N0ZGxpYl9Kc0Vycm9yLmpzXCI7XG5cbmZ1bmN0aW9uIGdldE9yVGhyb3coeCwgbWVzc2FnZSkge1xuICBpZiAoeC5UQUcgPT09IFwiT2tcIikge1xuICAgIHJldHVybiB4Ll8wO1xuICB9IGVsc2Uge1xuICAgIHJldHVybiBTdGRsaWJfSnNFcnJvci5wYW5pYyhtZXNzYWdlICE9PSB1bmRlZmluZWQgPyBtZXNzYWdlIDogXCJSZXN1bHQuZ2V0T3JUaHJvdyBjYWxsZWQgZm9yIEVycm9yIHZhbHVlXCIpO1xuICB9XG59XG5cbmZ1bmN0aW9uIG1hcE9yKG9wdCwgJCRkZWZhdWx0LCBmKSB7XG4gIGlmIChvcHQuVEFHID09PSBcIk9rXCIpIHtcbiAgICByZXR1cm4gZihvcHQuXzApO1xuICB9IGVsc2Uge1xuICAgIHJldHVybiAkJGRlZmF1bHQ7XG4gIH1cbn1cblxuZnVuY3Rpb24gbWFwKG9wdCwgZikge1xuICBpZiAob3B0LlRBRyA9PT0gXCJPa1wiKSB7XG4gICAgcmV0dXJuIHtcbiAgICAgIFRBRzogXCJPa1wiLFxuICAgICAgXzA6IGYob3B0Ll8wKVxuICAgIH07XG4gIH0gZWxzZSB7XG4gICAgcmV0dXJuIG9wdDtcbiAgfVxufVxuXG5mdW5jdGlvbiBmbGF0TWFwKG9wdCwgZikge1xuICBpZiAob3B0LlRBRyA9PT0gXCJPa1wiKSB7XG4gICAgcmV0dXJuIGYob3B0Ll8wKTtcbiAgfSBlbHNlIHtcbiAgICByZXR1cm4gb3B0O1xuICB9XG59XG5cbmZ1bmN0aW9uIGdldE9yKG9wdCwgJCRkZWZhdWx0KSB7XG4gIGlmIChvcHQuVEFHID09PSBcIk9rXCIpIHtcbiAgICByZXR1cm4gb3B0Ll8wO1xuICB9IGVsc2Uge1xuICAgIHJldHVybiAkJGRlZmF1bHQ7XG4gIH1cbn1cblxuZnVuY3Rpb24gaXNPayh4KSB7XG4gIHJldHVybiB4LlRBRyA9PT0gXCJPa1wiO1xufVxuXG5mdW5jdGlvbiBpc0Vycm9yKHgpIHtcbiAgcmV0dXJuIHguVEFHICE9PSBcIk9rXCI7XG59XG5cbmZ1bmN0aW9uIGVxdWFsKGEsIGIsIGVxT2ssIGVxRXJyb3IpIHtcbiAgaWYgKGEuVEFHID09PSBcIk9rXCIpIHtcbiAgICBpZiAoYi5UQUcgPT09IFwiT2tcIikge1xuICAgICAgcmV0dXJuIGVxT2soYS5fMCwgYi5fMCk7XG4gICAgfSBlbHNlIHtcbiAgICAgIHJldHVybiBmYWxzZTtcbiAgICB9XG4gIH0gZWxzZSBpZiAoYi5UQUcgPT09IFwiT2tcIikge1xuICAgIHJldHVybiBmYWxzZTtcbiAgfSBlbHNlIHtcbiAgICByZXR1cm4gZXFFcnJvcihhLl8wLCBiLl8wKTtcbiAgfVxufVxuXG5mdW5jdGlvbiBjb21wYXJlKGEsIGIsIGNtcE9rLCBjbXBFcnJvcikge1xuICBpZiAoYS5UQUcgPT09IFwiT2tcIikge1xuICAgIGlmIChiLlRBRyA9PT0gXCJPa1wiKSB7XG4gICAgICByZXR1cm4gY21wT2soYS5fMCwgYi5fMCk7XG4gICAgfSBlbHNlIHtcbiAgICAgIHJldHVybiAxO1xuICAgIH1cbiAgfSBlbHNlIGlmIChiLlRBRyA9PT0gXCJPa1wiKSB7XG4gICAgcmV0dXJuIC0xO1xuICB9IGVsc2Uge1xuICAgIHJldHVybiBjbXBFcnJvcihhLl8wLCBiLl8wKTtcbiAgfVxufVxuXG5mdW5jdGlvbiBmb3JFYWNoKHIsIGYpIHtcbiAgaWYgKHIuVEFHID09PSBcIk9rXCIpIHtcbiAgICByZXR1cm4gZihyLl8wKTtcbiAgfVxufVxuXG5mdW5jdGlvbiBtYXBFcnJvcihyLCBmKSB7XG4gIGlmIChyLlRBRyA9PT0gXCJPa1wiKSB7XG4gICAgcmV0dXJuIHI7XG4gIH0gZWxzZSB7XG4gICAgcmV0dXJuIHtcbiAgICAgIFRBRzogXCJFcnJvclwiLFxuICAgICAgXzA6IGYoci5fMClcbiAgICB9O1xuICB9XG59XG5cbmZ1bmN0aW9uIGFsbChyZXN1bHRzKSB7XG4gIGxldCBhY2MgPSBbXTtcbiAgbGV0IHJldHVyblZhbHVlO1xuICBsZXQgaW5kZXggPSAwO1xuICB3aGlsZSAocmV0dXJuVmFsdWUgPT09IHVuZGVmaW5lZCAmJiBpbmRleCA8IHJlc3VsdHMubGVuZ3RoKSB7XG4gICAgbGV0IGVyciA9IHJlc3VsdHNbaW5kZXhdO1xuICAgIGlmIChlcnIuVEFHID09PSBcIk9rXCIpIHtcbiAgICAgIGFjYy5wdXNoKGVyci5fMCk7XG4gICAgICBpbmRleCA9IGluZGV4ICsgMSB8IDA7XG4gICAgfSBlbHNlIHtcbiAgICAgIHJldHVyblZhbHVlID0gZXJyO1xuICAgIH1cbiAgfTtcbiAgbGV0IGVycm9yID0gcmV0dXJuVmFsdWU7XG4gIGlmIChlcnJvciAhPT0gdW5kZWZpbmVkKSB7XG4gICAgcmV0dXJuIGVycm9yO1xuICB9IGVsc2Uge1xuICAgIHJldHVybiB7XG4gICAgICBUQUc6IFwiT2tcIixcbiAgICAgIF8wOiBhY2NcbiAgICB9O1xuICB9XG59XG5cbmZ1bmN0aW9uIGFsbDIocGFyYW0pIHtcbiAgbGV0IGIgPSBwYXJhbVsxXTtcbiAgbGV0IGEgPSBwYXJhbVswXTtcbiAgaWYgKGEuVEFHID09PSBcIk9rXCIpIHtcbiAgICBpZiAoYi5UQUcgPT09IFwiT2tcIikge1xuICAgICAgcmV0dXJuIHtcbiAgICAgICAgVEFHOiBcIk9rXCIsXG4gICAgICAgIF8wOiBbXG4gICAgICAgICAgYS5fMCxcbiAgICAgICAgICBiLl8wXG4gICAgICAgIF1cbiAgICAgIH07XG4gICAgfSBlbHNlIHtcbiAgICAgIHJldHVybiB7XG4gICAgICAgIFRBRzogXCJFcnJvclwiLFxuICAgICAgICBfMDogYi5fMFxuICAgICAgfTtcbiAgICB9XG4gIH0gZWxzZSB7XG4gICAgcmV0dXJuIHtcbiAgICAgIFRBRzogXCJFcnJvclwiLFxuICAgICAgXzA6IGEuXzBcbiAgICB9O1xuICB9XG59XG5cbmZ1bmN0aW9uIGFsbDMocGFyYW0pIHtcbiAgbGV0IGMgPSBwYXJhbVsyXTtcbiAgbGV0IGIgPSBwYXJhbVsxXTtcbiAgbGV0IGEgPSBwYXJhbVswXTtcbiAgaWYgKGEuVEFHID09PSBcIk9rXCIpIHtcbiAgICBpZiAoYi5UQUcgPT09IFwiT2tcIikge1xuICAgICAgaWYgKGMuVEFHID09PSBcIk9rXCIpIHtcbiAgICAgICAgcmV0dXJuIHtcbiAgICAgICAgICBUQUc6IFwiT2tcIixcbiAgICAgICAgICBfMDogW1xuICAgICAgICAgICAgYS5fMCxcbiAgICAgICAgICAgIGIuXzAsXG4gICAgICAgICAgICBjLl8wXG4gICAgICAgICAgXVxuICAgICAgICB9O1xuICAgICAgfSBlbHNlIHtcbiAgICAgICAgcmV0dXJuIHtcbiAgICAgICAgICBUQUc6IFwiRXJyb3JcIixcbiAgICAgICAgICBfMDogYy5fMFxuICAgICAgICB9O1xuICAgICAgfVxuICAgIH0gZWxzZSB7XG4gICAgICByZXR1cm4ge1xuICAgICAgICBUQUc6IFwiRXJyb3JcIixcbiAgICAgICAgXzA6IGIuXzBcbiAgICAgIH07XG4gICAgfVxuICB9IGVsc2Uge1xuICAgIHJldHVybiB7XG4gICAgICBUQUc6IFwiRXJyb3JcIixcbiAgICAgIF8wOiBhLl8wXG4gICAgfTtcbiAgfVxufVxuXG5mdW5jdGlvbiBhbGw0KHBhcmFtKSB7XG4gIGxldCBkID0gcGFyYW1bM107XG4gIGxldCBjID0gcGFyYW1bMl07XG4gIGxldCBiID0gcGFyYW1bMV07XG4gIGxldCBhID0gcGFyYW1bMF07XG4gIGlmIChhLlRBRyA9PT0gXCJPa1wiKSB7XG4gICAgaWYgKGIuVEFHID09PSBcIk9rXCIpIHtcbiAgICAgIGlmIChjLlRBRyA9PT0gXCJPa1wiKSB7XG4gICAgICAgIGlmIChkLlRBRyA9PT0gXCJPa1wiKSB7XG4gICAgICAgICAgcmV0dXJuIHtcbiAgICAgICAgICAgIFRBRzogXCJPa1wiLFxuICAgICAgICAgICAgXzA6IFtcbiAgICAgICAgICAgICAgYS5fMCxcbiAgICAgICAgICAgICAgYi5fMCxcbiAgICAgICAgICAgICAgYy5fMCxcbiAgICAgICAgICAgICAgZC5fMFxuICAgICAgICAgICAgXVxuICAgICAgICAgIH07XG4gICAgICAgIH0gZWxzZSB7XG4gICAgICAgICAgcmV0dXJuIHtcbiAgICAgICAgICAgIFRBRzogXCJFcnJvclwiLFxuICAgICAgICAgICAgXzA6IGQuXzBcbiAgICAgICAgICB9O1xuICAgICAgICB9XG4gICAgICB9IGVsc2Uge1xuICAgICAgICByZXR1cm4ge1xuICAgICAgICAgIFRBRzogXCJFcnJvclwiLFxuICAgICAgICAgIF8wOiBjLl8wXG4gICAgICAgIH07XG4gICAgICB9XG4gICAgfSBlbHNlIHtcbiAgICAgIHJldHVybiB7XG4gICAgICAgIFRBRzogXCJFcnJvclwiLFxuICAgICAgICBfMDogYi5fMFxuICAgICAgfTtcbiAgICB9XG4gIH0gZWxzZSB7XG4gICAgcmV0dXJuIHtcbiAgICAgIFRBRzogXCJFcnJvclwiLFxuICAgICAgXzA6IGEuXzBcbiAgICB9O1xuICB9XG59XG5cbmZ1bmN0aW9uIGFsbDUocGFyYW0pIHtcbiAgbGV0IGUgPSBwYXJhbVs0XTtcbiAgbGV0IGQgPSBwYXJhbVszXTtcbiAgbGV0IGMgPSBwYXJhbVsyXTtcbiAgbGV0IGIgPSBwYXJhbVsxXTtcbiAgbGV0IGEgPSBwYXJhbVswXTtcbiAgaWYgKGEuVEFHID09PSBcIk9rXCIpIHtcbiAgICBpZiAoYi5UQUcgPT09IFwiT2tcIikge1xuICAgICAgaWYgKGMuVEFHID09PSBcIk9rXCIpIHtcbiAgICAgICAgaWYgKGQuVEFHID09PSBcIk9rXCIpIHtcbiAgICAgICAgICBpZiAoZS5UQUcgPT09IFwiT2tcIikge1xuICAgICAgICAgICAgcmV0dXJuIHtcbiAgICAgICAgICAgICAgVEFHOiBcIk9rXCIsXG4gICAgICAgICAgICAgIF8wOiBbXG4gICAgICAgICAgICAgICAgYS5fMCxcbiAgICAgICAgICAgICAgICBiLl8wLFxuICAgICAgICAgICAgICAgIGMuXzAsXG4gICAgICAgICAgICAgICAgZC5fMCxcbiAgICAgICAgICAgICAgICBlLl8wXG4gICAgICAgICAgICAgIF1cbiAgICAgICAgICAgIH07XG4gICAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICAgIHJldHVybiB7XG4gICAgICAgICAgICAgIFRBRzogXCJFcnJvclwiLFxuICAgICAgICAgICAgICBfMDogZS5fMFxuICAgICAgICAgICAgfTtcbiAgICAgICAgICB9XG4gICAgICAgIH0gZWxzZSB7XG4gICAgICAgICAgcmV0dXJuIHtcbiAgICAgICAgICAgIFRBRzogXCJFcnJvclwiLFxuICAgICAgICAgICAgXzA6IGQuXzBcbiAgICAgICAgICB9O1xuICAgICAgICB9XG4gICAgICB9IGVsc2Uge1xuICAgICAgICByZXR1cm4ge1xuICAgICAgICAgIFRBRzogXCJFcnJvclwiLFxuICAgICAgICAgIF8wOiBjLl8wXG4gICAgICAgIH07XG4gICAgICB9XG4gICAgfSBlbHNlIHtcbiAgICAgIHJldHVybiB7XG4gICAgICAgIFRBRzogXCJFcnJvclwiLFxuICAgICAgICBfMDogYi5fMFxuICAgICAgfTtcbiAgICB9XG4gIH0gZWxzZSB7XG4gICAgcmV0dXJuIHtcbiAgICAgIFRBRzogXCJFcnJvclwiLFxuICAgICAgXzA6IGEuXzBcbiAgICB9O1xuICB9XG59XG5cbmZ1bmN0aW9uIGFsbDYocGFyYW0pIHtcbiAgbGV0IGYgPSBwYXJhbVs1XTtcbiAgbGV0IGUgPSBwYXJhbVs0XTtcbiAgbGV0IGQgPSBwYXJhbVszXTtcbiAgbGV0IGMgPSBwYXJhbVsyXTtcbiAgbGV0IGIgPSBwYXJhbVsxXTtcbiAgbGV0IGEgPSBwYXJhbVswXTtcbiAgaWYgKGEuVEFHID09PSBcIk9rXCIpIHtcbiAgICBpZiAoYi5UQUcgPT09IFwiT2tcIikge1xuICAgICAgaWYgKGMuVEFHID09PSBcIk9rXCIpIHtcbiAgICAgICAgaWYgKGQuVEFHID09PSBcIk9rXCIpIHtcbiAgICAgICAgICBpZiAoZS5UQUcgPT09IFwiT2tcIikge1xuICAgICAgICAgICAgaWYgKGYuVEFHID09PSBcIk9rXCIpIHtcbiAgICAgICAgICAgICAgcmV0dXJuIHtcbiAgICAgICAgICAgICAgICBUQUc6IFwiT2tcIixcbiAgICAgICAgICAgICAgICBfMDogW1xuICAgICAgICAgICAgICAgICAgYS5fMCxcbiAgICAgICAgICAgICAgICAgIGIuXzAsXG4gICAgICAgICAgICAgICAgICBjLl8wLFxuICAgICAgICAgICAgICAgICAgZC5fMCxcbiAgICAgICAgICAgICAgICAgIGUuXzAsXG4gICAgICAgICAgICAgICAgICBmLl8wXG4gICAgICAgICAgICAgICAgXVxuICAgICAgICAgICAgICB9O1xuICAgICAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICAgICAgcmV0dXJuIHtcbiAgICAgICAgICAgICAgICBUQUc6IFwiRXJyb3JcIixcbiAgICAgICAgICAgICAgICBfMDogZi5fMFxuICAgICAgICAgICAgICB9O1xuICAgICAgICAgICAgfVxuICAgICAgICAgIH0gZWxzZSB7XG4gICAgICAgICAgICByZXR1cm4ge1xuICAgICAgICAgICAgICBUQUc6IFwiRXJyb3JcIixcbiAgICAgICAgICAgICAgXzA6IGUuXzBcbiAgICAgICAgICAgIH07XG4gICAgICAgICAgfVxuICAgICAgICB9IGVsc2Uge1xuICAgICAgICAgIHJldHVybiB7XG4gICAgICAgICAgICBUQUc6IFwiRXJyb3JcIixcbiAgICAgICAgICAgIF8wOiBkLl8wXG4gICAgICAgICAgfTtcbiAgICAgICAgfVxuICAgICAgfSBlbHNlIHtcbiAgICAgICAgcmV0dXJuIHtcbiAgICAgICAgICBUQUc6IFwiRXJyb3JcIixcbiAgICAgICAgICBfMDogYy5fMFxuICAgICAgICB9O1xuICAgICAgfVxuICAgIH0gZWxzZSB7XG4gICAgICByZXR1cm4ge1xuICAgICAgICBUQUc6IFwiRXJyb3JcIixcbiAgICAgICAgXzA6IGIuXzBcbiAgICAgIH07XG4gICAgfVxuICB9IGVsc2Uge1xuICAgIHJldHVybiB7XG4gICAgICBUQUc6IFwiRXJyb3JcIixcbiAgICAgIF8wOiBhLl8wXG4gICAgfTtcbiAgfVxufVxuXG5hc3luYyBmdW5jdGlvbiBtYXBPa0FzeW5jKHJlcywgZikge1xuICBsZXQgdmFsdWUgPSBhd2FpdCByZXM7XG4gIGlmICh2YWx1ZS5UQUcgPT09IFwiT2tcIikge1xuICAgIHJldHVybiB7XG4gICAgICBUQUc6IFwiT2tcIixcbiAgICAgIF8wOiBmKHZhbHVlLl8wKVxuICAgIH07XG4gIH0gZWxzZSB7XG4gICAgcmV0dXJuIHtcbiAgICAgIFRBRzogXCJFcnJvclwiLFxuICAgICAgXzA6IHZhbHVlLl8wXG4gICAgfTtcbiAgfVxufVxuXG5hc3luYyBmdW5jdGlvbiBtYXBFcnJvckFzeW5jKHJlcywgZikge1xuICBsZXQgdmFsdWUgPSBhd2FpdCByZXM7XG4gIGlmICh2YWx1ZS5UQUcgPT09IFwiT2tcIikge1xuICAgIHJldHVybiB7XG4gICAgICBUQUc6IFwiT2tcIixcbiAgICAgIF8wOiB2YWx1ZS5fMFxuICAgIH07XG4gIH0gZWxzZSB7XG4gICAgcmV0dXJuIHtcbiAgICAgIFRBRzogXCJFcnJvclwiLFxuICAgICAgXzA6IGYodmFsdWUuXzApXG4gICAgfTtcbiAgfVxufVxuXG5hc3luYyBmdW5jdGlvbiBmbGF0TWFwT2tBc3luYyhyZXMsIGYpIHtcbiAgbGV0IHZhbHVlID0gYXdhaXQgcmVzO1xuICBpZiAodmFsdWUuVEFHID09PSBcIk9rXCIpIHtcbiAgICByZXR1cm4gYXdhaXQgZih2YWx1ZS5fMCk7XG4gIH0gZWxzZSB7XG4gICAgcmV0dXJuIHtcbiAgICAgIFRBRzogXCJFcnJvclwiLFxuICAgICAgXzA6IHZhbHVlLl8wXG4gICAgfTtcbiAgfVxufVxuXG5hc3luYyBmdW5jdGlvbiBmbGF0TWFwRXJyb3JBc3luYyhyZXMsIGYpIHtcbiAgbGV0IHZhbHVlID0gYXdhaXQgcmVzO1xuICBpZiAodmFsdWUuVEFHID09PSBcIk9rXCIpIHtcbiAgICByZXR1cm4ge1xuICAgICAgVEFHOiBcIk9rXCIsXG4gICAgICBfMDogdmFsdWUuXzBcbiAgICB9O1xuICB9IGVsc2Uge1xuICAgIHJldHVybiBhd2FpdCBmKHZhbHVlLl8wKTtcbiAgfVxufVxuXG5sZXQgZ2V0RXhuID0gZ2V0T3JUaHJvdztcblxubGV0IG1hcFdpdGhEZWZhdWx0ID0gbWFwT3I7XG5cbmxldCBnZXRXaXRoRGVmYXVsdCA9IGdldE9yO1xuXG5leHBvcnQge1xuICBnZXRFeG4sXG4gIGdldE9yVGhyb3csXG4gIG1hcE9yLFxuICBtYXBXaXRoRGVmYXVsdCxcbiAgbWFwLFxuICBmbGF0TWFwLFxuICBnZXRPcixcbiAgZ2V0V2l0aERlZmF1bHQsXG4gIGlzT2ssXG4gIGlzRXJyb3IsXG4gIGVxdWFsLFxuICBjb21wYXJlLFxuICBmb3JFYWNoLFxuICBtYXBFcnJvcixcbiAgYWxsLFxuICBhbGwyLFxuICBhbGwzLFxuICBhbGw0LFxuICBhbGw1LFxuICBhbGw2LFxuICBtYXBPa0FzeW5jLFxuICBtYXBFcnJvckFzeW5jLFxuICBmbGF0TWFwT2tBc3luYyxcbiAgZmxhdE1hcEVycm9yQXN5bmMsXG59XG4vKiBObyBzaWRlIGVmZmVjdCAqL1xuIiwgIlxuXG5cbmZ1bmN0aW9uIGlzRXh0ZW5zaW9uKGUpIHtcbiAgaWYgKGUgPT0gbnVsbCkge1xuICAgIHJldHVybiBmYWxzZTtcbiAgfSBlbHNlIHtcbiAgICByZXR1cm4gdHlwZW9mIGUuUkVfRVhOX0lEID09PSBcInN0cmluZ1wiO1xuICB9XG59XG5cbmZ1bmN0aW9uIGludGVybmFsVG9FeGNlcHRpb24oZSkge1xuICBpZiAoaXNFeHRlbnNpb24oZSkpIHtcbiAgICByZXR1cm4gZTtcbiAgfSBlbHNlIHtcbiAgICByZXR1cm4ge1xuICAgICAgUkVfRVhOX0lEOiBcIkpzRXhuXCIsXG4gICAgICBfMTogZVxuICAgIH07XG4gIH1cbn1cblxubGV0IGlkTWFwID0ge307XG5cbmZ1bmN0aW9uIGNyZWF0ZShzdHIpIHtcbiAgbGV0IHYgPSBpZE1hcFtzdHJdO1xuICBpZiAodiAhPT0gdW5kZWZpbmVkKSB7XG4gICAgbGV0IGlkID0gdiArIDEgfCAwO1xuICAgIGlkTWFwW3N0cl0gPSBpZDtcbiAgICByZXR1cm4gc3RyICsgKFwiL1wiICsgaWQpO1xuICB9XG4gIGlkTWFwW3N0cl0gPSAxO1xuICByZXR1cm4gc3RyO1xufVxuXG5sZXQgJCRFcnJvciA9IFwiSnNFeG5cIjtcblxuZXhwb3J0IHtcbiAgJCRFcnJvcixcbiAgY3JlYXRlLFxuICBpbnRlcm5hbFRvRXhjZXB0aW9uLFxufVxuLyogTm8gc2lkZSBlZmZlY3QgKi9cbiIsICIvLyBHZW5lcmF0ZWQgYnkgUmVTY3JpcHQsIFBMRUFTRSBFRElUIFdJVEggQ0FSRVxuXG5pbXBvcnQgKiBhcyBCZWx0X0xpc3QgZnJvbSBcIkByZXNjcmlwdC9ydW50aW1lL2xpYi9lczYvQmVsdF9MaXN0LmpzXCI7XG5pbXBvcnQgKiBhcyBKU09OU2NoZW1hIGZyb20gXCIuL0pTT05TY2hlbWEucmVzLm1qc1wiO1xuaW1wb3J0ICogYXMgUHJpbWl0aXZlX29wdGlvbiBmcm9tIFwiQHJlc2NyaXB0L3J1bnRpbWUvbGliL2VzNi9QcmltaXRpdmVfb3B0aW9uLmpzXCI7XG5pbXBvcnQgKiBhcyBQcmltaXRpdmVfZXhjZXB0aW9ucyBmcm9tIFwiQHJlc2NyaXB0L3J1bnRpbWUvbGliL2VzNi9QcmltaXRpdmVfZXhjZXB0aW9ucy5qc1wiO1xuXG5sZXQgaW1tdXRhYmxlRW1wdHkgPSB7fTtcblxubGV0IGltbXV0YWJsZUVtcHR5JDEgPSBbXTtcblxuZnVuY3Rpb24gY2FwaXRhbGl6ZShzdHJpbmcpIHtcbiAgcmV0dXJuIHN0cmluZy5zbGljZSgwLCAxKS50b1VwcGVyQ2FzZSgpICsgc3RyaW5nLnNsaWNlKDEpO1xufVxuXG5sZXQgY29weSA9ICgoZCkgPT4gKHsuLi5kfSkpO1xuXG5mdW5jdGlvbiBmcm9tU3RyaW5nKHN0cmluZykge1xuICBsZXQgX2lkeCA9IDA7XG4gIHdoaWxlICh0cnVlKSB7XG4gICAgbGV0IGlkeCA9IF9pZHg7XG4gICAgbGV0IG1hdGNoID0gc3RyaW5nW2lkeF07XG4gICAgaWYgKG1hdGNoID09PSB1bmRlZmluZWQpIHtcbiAgICAgIHJldHVybiBgXCJgICsgc3RyaW5nICsgYFwiYDtcbiAgICB9XG4gICAgc3dpdGNoIChtYXRjaCkge1xuICAgICAgY2FzZSBcIlxcXCJcIiA6XG4gICAgICBjYXNlIFwiXFxuXCIgOlxuICAgICAgICByZXR1cm4gSlNPTi5zdHJpbmdpZnkoc3RyaW5nKTtcbiAgICAgIGRlZmF1bHQ6XG4gICAgICAgIF9pZHggPSBpZHggKyAxIHwgMDtcbiAgICAgICAgY29udGludWU7XG4gICAgfVxuICB9O1xufVxuXG5mdW5jdGlvbiB0b0FycmF5KHBhdGgpIHtcbiAgaWYgKHBhdGggPT09IFwiXCIpIHtcbiAgICByZXR1cm4gW107XG4gIH0gZWxzZSB7XG4gICAgcmV0dXJuIEpTT04ucGFyc2UocGF0aC5zcGxpdChgXCJdW1wiYCkuam9pbihgXCIsXCJgKSk7XG4gIH1cbn1cblxuZnVuY3Rpb24gZnJvbUxvY2F0aW9uKGxvY2F0aW9uKSB7XG4gIHJldHVybiBgW2AgKyBmcm9tU3RyaW5nKGxvY2F0aW9uKSArIGBdYDtcbn1cblxuZnVuY3Rpb24gZnJvbUFycmF5KGFycmF5KSB7XG4gIGxldCBsZW4gPSBhcnJheS5sZW5ndGg7XG4gIGlmIChsZW4gIT09IDEpIHtcbiAgICBpZiAobGVuICE9PSAwKSB7XG4gICAgICByZXR1cm4gXCJbXCIgKyBhcnJheS5tYXAoZnJvbVN0cmluZykuam9pbihcIl1bXCIpICsgXCJdXCI7XG4gICAgfSBlbHNlIHtcbiAgICAgIHJldHVybiBcIlwiO1xuICAgIH1cbiAgfSBlbHNlIHtcbiAgICByZXR1cm4gYFtgICsgZnJvbVN0cmluZyhhcnJheVswXSkgKyBgXWA7XG4gIH1cbn1cblxuZnVuY3Rpb24gY29uY2F0KHBhdGgsIGNvbmNhdGVkUGF0aCkge1xuICByZXR1cm4gcGF0aCArIGNvbmNhdGVkUGF0aDtcbn1cblxubGV0IHZlbmRvciA9IFwic3VyeVwiO1xuXG5sZXQgcyA9IFN5bWJvbCh2ZW5kb3IpO1xuXG5sZXQgaXRlbVN5bWJvbCA9IFN5bWJvbCh2ZW5kb3IgKyBcIjppdGVtXCIpO1xuXG5sZXQgJCRFcnJvciA9IC8qIEBfX1BVUkVfXyAqL1ByaW1pdGl2ZV9leGNlcHRpb25zLmNyZWF0ZShcIlN1cnkuRXJyb3JcIik7XG5cbmxldCBjb25zdEZpZWxkID0gXCJjb25zdFwiO1xuXG5mdW5jdGlvbiBpc09wdGlvbmFsKHNjaGVtYSkge1xuICBsZXQgbWF0Y2ggPSBzY2hlbWEudHlwZTtcbiAgc3dpdGNoIChtYXRjaCkge1xuICAgIGNhc2UgXCJ1bmRlZmluZWRcIiA6XG4gICAgICByZXR1cm4gdHJ1ZTtcbiAgICBjYXNlIFwidW5pb25cIiA6XG4gICAgICByZXR1cm4gXCJ1bmRlZmluZWRcIiBpbiBzY2hlbWEuaGFzO1xuICAgIGRlZmF1bHQ6XG4gICAgICByZXR1cm4gZmFsc2U7XG4gIH1cbn1cblxuZnVuY3Rpb24gaGFzKGFjYywgZmxhZykge1xuICByZXR1cm4gKGFjYyAmIGZsYWcpICE9PSAwO1xufVxuXG5sZXQgZmxhZ3MgPSB7XG4gICAgdW5rbm93bjogMSxcbiAgICBzdHJpbmc6IDIsXG4gICAgbnVtYmVyOiA0LFxuICAgIGJvb2xlYW46IDgsXG4gICAgdW5kZWZpbmVkOiAxNixcbiAgICBudWxsOiAzMixcbiAgICBvYmplY3Q6IDY0LFxuICAgIGFycmF5OiAxMjgsXG4gICAgdW5pb246IDI1NixcbiAgICByZWY6IDUxMixcbiAgICBiaWdpbnQ6IDEwMjQsXG4gICAgbmFuOiAyMDQ4LFxuICAgIFwiZnVuY3Rpb25cIjogNDA5NixcbiAgICBpbnN0YW5jZTogODE5MixcbiAgICBuZXZlcjogMTYzODQsXG4gICAgc3ltYm9sOiAzMjc2OCxcbiAgfTtcblxuZnVuY3Rpb24gc3RyaW5naWZ5KHVua25vd24pIHtcbiAgbGV0IHRhZ0ZsYWcgPSBmbGFnc1t0eXBlb2YgdW5rbm93bl07XG4gIGlmICh0YWdGbGFnICYgMTYpIHtcbiAgICByZXR1cm4gXCJ1bmRlZmluZWRcIjtcbiAgfVxuICBpZiAoISh0YWdGbGFnICYgNjQpKSB7XG4gICAgaWYgKHRhZ0ZsYWcgJiAyKSB7XG4gICAgICByZXR1cm4gYFwiYCArIHVua25vd24gKyBgXCJgO1xuICAgIH0gZWxzZSBpZiAodGFnRmxhZyAmIDEwMjQpIHtcbiAgICAgIHJldHVybiB1bmtub3duICsgYG5gO1xuICAgIH0gZWxzZSB7XG4gICAgICByZXR1cm4gdW5rbm93bi50b1N0cmluZygpO1xuICAgIH1cbiAgfVxuICBpZiAodW5rbm93biA9PT0gbnVsbCkge1xuICAgIHJldHVybiBcIm51bGxcIjtcbiAgfVxuICBpZiAoQXJyYXkuaXNBcnJheSh1bmtub3duKSkge1xuICAgIGxldCBzdHJpbmcgPSBcIltcIjtcbiAgICBmb3IgKGxldCBpID0gMCwgaV9maW5pc2ggPSB1bmtub3duLmxlbmd0aDsgaSA8IGlfZmluaXNoOyArK2kpIHtcbiAgICAgIGlmIChpICE9PSAwKSB7XG4gICAgICAgIHN0cmluZyA9IHN0cmluZyArIFwiLCBcIjtcbiAgICAgIH1cbiAgICAgIHN0cmluZyA9IHN0cmluZyArIHN0cmluZ2lmeSh1bmtub3duW2ldKTtcbiAgICB9XG4gICAgcmV0dXJuIHN0cmluZyArIFwiXVwiO1xuICB9XG4gIGlmICh1bmtub3duLmNvbnN0cnVjdG9yICE9PSBPYmplY3QpIHtcbiAgICByZXR1cm4gT2JqZWN0LnByb3RvdHlwZS50b1N0cmluZy5jYWxsKHVua25vd24pO1xuICB9XG4gIGxldCBrZXlzID0gT2JqZWN0LmtleXModW5rbm93bik7XG4gIGxldCBzdHJpbmckMSA9IFwieyBcIjtcbiAgZm9yIChsZXQgaSQxID0gMCwgaV9maW5pc2gkMSA9IGtleXMubGVuZ3RoOyBpJDEgPCBpX2ZpbmlzaCQxOyArK2kkMSkge1xuICAgIGxldCBrZXkgPSBrZXlzW2kkMV07XG4gICAgbGV0IHZhbHVlID0gdW5rbm93bltrZXldO1xuICAgIHN0cmluZyQxID0gc3RyaW5nJDEgKyBrZXkgKyBgOiBgICsgc3RyaW5naWZ5KHZhbHVlKSArIGA7IGA7XG4gIH1cbiAgcmV0dXJuIHN0cmluZyQxICsgXCJ9XCI7XG59XG5cbmZ1bmN0aW9uIHRvRXhwcmVzc2lvbihzY2hlbWEpIHtcbiAgbGV0IHRhZyA9IHNjaGVtYS50eXBlO1xuICBsZXQgJCRjb25zdCA9IHNjaGVtYS5jb25zdDtcbiAgbGV0IG5hbWUgPSBzY2hlbWEubmFtZTtcbiAgaWYgKG5hbWUgIT09IHVuZGVmaW5lZCkge1xuICAgIHJldHVybiBuYW1lO1xuICB9XG4gIGlmICgkJGNvbnN0ICE9PSB1bmRlZmluZWQpIHtcbiAgICByZXR1cm4gc3RyaW5naWZ5KCQkY29uc3QpO1xuICB9XG4gIGxldCBmb3JtYXQgPSBzY2hlbWEuZm9ybWF0O1xuICBsZXQgYW55T2YgPSBzY2hlbWEuYW55T2Y7XG4gIGlmIChhbnlPZiAhPT0gdW5kZWZpbmVkKSB7XG4gICAgcmV0dXJuIGFueU9mLm1hcCh0b0V4cHJlc3Npb24pLmpvaW4oXCIgfCBcIik7XG4gIH1cbiAgaWYgKGZvcm1hdCAhPT0gdW5kZWZpbmVkKSB7XG4gICAgcmV0dXJuIGZvcm1hdDtcbiAgfVxuICBzd2l0Y2ggKHRhZykge1xuICAgIGNhc2UgXCJuYW5cIiA6XG4gICAgICByZXR1cm4gXCJOYU5cIjtcbiAgICBjYXNlIFwib2JqZWN0XCIgOlxuICAgICAgbGV0IGFkZGl0aW9uYWxJdGVtcyA9IHNjaGVtYS5hZGRpdGlvbmFsSXRlbXM7XG4gICAgICBsZXQgcHJvcGVydGllcyA9IHNjaGVtYS5wcm9wZXJ0aWVzO1xuICAgICAgbGV0IGxvY2F0aW9ucyA9IE9iamVjdC5rZXlzKHByb3BlcnRpZXMpO1xuICAgICAgaWYgKGxvY2F0aW9ucy5sZW5ndGggPT09IDApIHtcbiAgICAgICAgaWYgKHR5cGVvZiBhZGRpdGlvbmFsSXRlbXMgPT09IFwib2JqZWN0XCIpIHtcbiAgICAgICAgICByZXR1cm4gYHsgW2tleTogc3RyaW5nXTogYCArIHRvRXhwcmVzc2lvbihhZGRpdGlvbmFsSXRlbXMpICsgYDsgfWA7XG4gICAgICAgIH0gZWxzZSB7XG4gICAgICAgICAgcmV0dXJuIGB7fWA7XG4gICAgICAgIH1cbiAgICAgIH0gZWxzZSB7XG4gICAgICAgIHJldHVybiBgeyBgICsgbG9jYXRpb25zLm1hcChsb2NhdGlvbiA9PiBsb2NhdGlvbiArIGA6IGAgKyB0b0V4cHJlc3Npb24ocHJvcGVydGllc1tsb2NhdGlvbl0pICsgYDtgKS5qb2luKFwiIFwiKSArIGAgfWA7XG4gICAgICB9XG4gICAgZGVmYXVsdDpcbiAgICAgIGlmIChzY2hlbWEuYikge1xuICAgICAgICByZXR1cm4gdGFnO1xuICAgICAgfVxuICAgICAgc3dpdGNoICh0YWcpIHtcbiAgICAgICAgY2FzZSBcImluc3RhbmNlXCIgOlxuICAgICAgICAgIHJldHVybiBzY2hlbWEuY2xhc3MubmFtZTtcbiAgICAgICAgY2FzZSBcImFycmF5XCIgOlxuICAgICAgICAgIGxldCBhZGRpdGlvbmFsSXRlbXMkMSA9IHNjaGVtYS5hZGRpdGlvbmFsSXRlbXM7XG4gICAgICAgICAgbGV0IGl0ZW1zID0gc2NoZW1hLml0ZW1zO1xuICAgICAgICAgIGlmICh0eXBlb2YgYWRkaXRpb25hbEl0ZW1zJDEgIT09IFwib2JqZWN0XCIpIHtcbiAgICAgICAgICAgIHJldHVybiBgW2AgKyBpdGVtcy5tYXAoaXRlbSA9PiB0b0V4cHJlc3Npb24oaXRlbS5zY2hlbWEpKS5qb2luKFwiLCBcIikgKyBgXWA7XG4gICAgICAgICAgfVxuICAgICAgICAgIGxldCBpdGVtTmFtZSA9IHRvRXhwcmVzc2lvbihhZGRpdGlvbmFsSXRlbXMkMSk7XG4gICAgICAgICAgcmV0dXJuIChcbiAgICAgICAgICAgIGFkZGl0aW9uYWxJdGVtcyQxLnR5cGUgPT09IFwidW5pb25cIiA/IGAoYCArIGl0ZW1OYW1lICsgYClgIDogaXRlbU5hbWVcbiAgICAgICAgICApICsgXCJbXVwiO1xuICAgICAgICBkZWZhdWx0OlxuICAgICAgICAgIHJldHVybiB0YWc7XG4gICAgICB9XG4gIH1cbn1cblxuY2xhc3MgU3VyeUVycm9yIGV4dGVuZHMgRXJyb3Ige1xuICBjb25zdHJ1Y3Rvcihjb2RlLCBmbGFnLCBwYXRoKSB7XG4gICAgc3VwZXIoKTtcbiAgICB0aGlzLmZsYWcgPSBmbGFnO1xuICAgIHRoaXMuY29kZSA9IGNvZGU7XG4gICAgdGhpcy5wYXRoID0gcGF0aDtcbiAgfVxufVxuXG52YXIgZCA9IE9iamVjdC5kZWZpbmVQcm9wZXJ0eSwgcCA9IFN1cnlFcnJvci5wcm90b3R5cGU7XG5kKHAsICdtZXNzYWdlJywge1xuICBnZXQoKSB7XG4gICAgICByZXR1cm4gbWVzc2FnZSh0aGlzKTtcbiAgfSxcbn0pXG5kKHAsICdyZWFzb24nLCB7XG4gIGdldCgpIHtcbiAgICAgIHJldHVybiByZWFzb24odGhpcyk7XG4gIH1cbn0pXG5kKHAsICduYW1lJywge3ZhbHVlOiAnU3VyeUVycm9yJ30pXG5kKHAsICdzJywge3ZhbHVlOiBzfSlcbmQocCwgJ18xJywge1xuICBnZXQoKSB7XG4gICAgcmV0dXJuIHRoaXNcbiAgfSxcbn0pO1xuZChwLCAnUkVfRVhOX0lEJywge1xuICB2YWx1ZTogJCRFcnJvcixcbn0pO1xuXG52YXIgU2NoZW1hID0gZnVuY3Rpb24odHlwZSkge3RoaXMudHlwZT10eXBlfSwgc3AgPSBPYmplY3QuY3JlYXRlKG51bGwpO1xuZChzcCwgJ3dpdGgnLCB7XG4gIGdldCgpIHtcbiAgICByZXR1cm4gKGZuLCAuLi5hcmdzKSA9PiBmbih0aGlzLCAuLi5hcmdzKVxuICB9LFxufSk7XG4vLyBBbHNvIGhhcyB+c3RhbmRhcmQgYmVsb3dcblNjaGVtYS5wcm90b3R5cGUgPSBzcDtcbjtcblxuZnVuY3Rpb24gZ2V0T3JSZXRocm93KGV4bikge1xuICBpZiAoKGV4biYmZXhuLnM9PT1zKSkge1xuICAgIHJldHVybiBleG47XG4gIH1cbiAgdGhyb3cgZXhuO1xufVxuXG5mdW5jdGlvbiByZWFzb24oZXJyb3IsIG5lc3RlZExldmVsT3B0KSB7XG4gIGxldCBuZXN0ZWRMZXZlbCA9IG5lc3RlZExldmVsT3B0ICE9PSB1bmRlZmluZWQgPyBuZXN0ZWRMZXZlbE9wdCA6IDA7XG4gIGxldCByZWFzb24kMSA9IGVycm9yLmNvZGU7XG4gIGlmICh0eXBlb2YgcmVhc29uJDEgIT09IFwib2JqZWN0XCIpIHtcbiAgICByZXR1cm4gXCJFbmNvdW50ZXJlZCB1bmV4cGVjdGVkIGFzeW5jIHRyYW5zZm9ybSBvciByZWZpbmUuIFVzZSBwYXJzZUFzeW5jT3JUaHJvdyBvcGVyYXRpb24gaW5zdGVhZFwiO1xuICB9XG4gIHN3aXRjaCAocmVhc29uJDEuVEFHKSB7XG4gICAgY2FzZSBcIk9wZXJhdGlvbkZhaWxlZFwiIDpcbiAgICAgIHJldHVybiByZWFzb24kMS5fMDtcbiAgICBjYXNlIFwiSW52YWxpZE9wZXJhdGlvblwiIDpcbiAgICAgIHJldHVybiByZWFzb24kMS5kZXNjcmlwdGlvbjtcbiAgICBjYXNlIFwiSW52YWxpZFR5cGVcIiA6XG4gICAgICBsZXQgdW5pb25FcnJvcnMgPSByZWFzb24kMS51bmlvbkVycm9ycztcbiAgICAgIGxldCBtID0gYEV4cGVjdGVkIGAgKyB0b0V4cHJlc3Npb24ocmVhc29uJDEuZXhwZWN0ZWQpICsgYCwgcmVjZWl2ZWQgYCArIHN0cmluZ2lmeShyZWFzb24kMS5yZWNlaXZlZCk7XG4gICAgICBpZiAodW5pb25FcnJvcnMgIT09IHVuZGVmaW5lZCkge1xuICAgICAgICBsZXQgbGluZUJyZWFrID0gYFxcbmAgKyBcIiBcIi5yZXBlYXQoKG5lc3RlZExldmVsIDw8IDEpKTtcbiAgICAgICAgbGV0IHJlYXNvbnNEaWN0ID0ge307XG4gICAgICAgIGZvciAobGV0IGlkeCA9IDAsIGlkeF9maW5pc2ggPSB1bmlvbkVycm9ycy5sZW5ndGg7IGlkeCA8IGlkeF9maW5pc2g7ICsraWR4KSB7XG4gICAgICAgICAgbGV0IGVycm9yJDEgPSB1bmlvbkVycm9yc1tpZHhdO1xuICAgICAgICAgIGxldCByZWFzb24kMiA9IHJlYXNvbihlcnJvciQxLCBuZXN0ZWRMZXZlbCArIDEpO1xuICAgICAgICAgIGxldCBub25FbXB0eVBhdGggPSBlcnJvciQxLnBhdGg7XG4gICAgICAgICAgbGV0IGxvY2F0aW9uID0gbm9uRW1wdHlQYXRoID09PSBcIlwiID8gXCJcIiA6IGBBdCBgICsgbm9uRW1wdHlQYXRoICsgYDogYDtcbiAgICAgICAgICBsZXQgbGluZSA9IGAtIGAgKyBsb2NhdGlvbiArIHJlYXNvbiQyO1xuICAgICAgICAgIGlmICghcmVhc29uc0RpY3RbbGluZV0pIHtcbiAgICAgICAgICAgIHJlYXNvbnNEaWN0W2xpbmVdID0gMTtcbiAgICAgICAgICAgIG0gPSBtICsgbGluZUJyZWFrICsgbGluZTtcbiAgICAgICAgICB9XG4gICAgICAgIH1cbiAgICAgIH1cbiAgICAgIHJldHVybiBtO1xuICAgIGNhc2UgXCJVbnN1cHBvcnRlZFRyYW5zZm9ybWF0aW9uXCIgOlxuICAgICAgcmV0dXJuIGBVbnN1cHBvcnRlZCB0cmFuc2Zvcm1hdGlvbiBmcm9tIGAgKyB0b0V4cHJlc3Npb24ocmVhc29uJDEuZnJvbSkgKyBgIHRvIGAgKyB0b0V4cHJlc3Npb24ocmVhc29uJDEudG8pO1xuICAgIGNhc2UgXCJFeGNlc3NGaWVsZFwiIDpcbiAgICAgIHJldHVybiBgVW5yZWNvZ25pemVkIGtleSBcImAgKyByZWFzb24kMS5fMCArIGBcImA7XG4gICAgY2FzZSBcIkludmFsaWRKc29uU2NoZW1hXCIgOlxuICAgICAgcmV0dXJuIHRvRXhwcmVzc2lvbihyZWFzb24kMS5fMCkgKyBgIGlzIG5vdCB2YWxpZCBKU09OYDtcbiAgfVxufVxuXG5mdW5jdGlvbiBtZXNzYWdlKGVycm9yKSB7XG4gIGxldCBvcCA9IGVycm9yLmZsYWc7XG4gIGxldCB0ZXh0ID0gXCJGYWlsZWQgXCI7XG4gIGlmIChvcCAmIDIpIHtcbiAgICB0ZXh0ID0gdGV4dCArIFwiYXN5bmMgXCI7XG4gIH1cbiAgdGV4dCA9IHRleHQgKyAoXG4gICAgb3AgJiAxID8gKFxuICAgICAgICBvcCAmIDQgPyBcImFzc2VydGluZ1wiIDogXCJwYXJzaW5nXCJcbiAgICAgICkgOiBcImNvbnZlcnRpbmdcIlxuICApO1xuICBpZiAob3AgJiA4KSB7XG4gICAgdGV4dCA9IHRleHQgKyBcIiB0byBKU09OXCIgKyAoXG4gICAgICBvcCAmIDE2ID8gXCIgc3RyaW5nXCIgOiBcIlwiXG4gICAgKTtcbiAgfVxuICBsZXQgbm9uRW1wdHlQYXRoID0gZXJyb3IucGF0aDtcbiAgbGV0IHRtcCA9IG5vbkVtcHR5UGF0aCA9PT0gXCJcIiA/IFwiXCIgOiBgIGF0IGAgKyBub25FbXB0eVBhdGg7XG4gIHJldHVybiB0ZXh0ICsgdG1wICsgYDogYCArIHJlYXNvbihlcnJvciwgdW5kZWZpbmVkKTtcbn1cblxubGV0IGdsb2JhbENvbmZpZyA9IHtcbiAgbTogbWVzc2FnZSxcbiAgZDogdW5kZWZpbmVkLFxuICBhOiBcInN0cmlwXCIsXG4gIG46IGZhbHNlXG59O1xuXG5sZXQgc2hha2VuUmVmID0gXCJhc1wiO1xuXG5sZXQgc2hha2VuVHJhcHMgPSB7XG4gIGdldDogKHRhcmdldCwgcHJvcCkgPT4ge1xuICAgIGxldCBsID0gdGFyZ2V0W3NoYWtlblJlZl07XG4gICAgaWYgKGwgPT09IHVuZGVmaW5lZCkge1xuICAgICAgcmV0dXJuIHRhcmdldFtwcm9wXTtcbiAgICB9XG4gICAgaWYgKHByb3AgPT09IHNoYWtlblJlZikge1xuICAgICAgcmV0dXJuIHRhcmdldFtwcm9wXTtcbiAgICB9XG4gICAgbGV0IGwkMSA9IFByaW1pdGl2ZV9vcHRpb24udmFsRnJvbU9wdGlvbihsKTtcbiAgICBsZXQgbWVzc2FnZSA9IGBTY2hlbWEgUy5gICsgbCQxICsgYCBpcyBub3QgZW5hYmxlZC4gVG8gc3RhcnQgdXNpbmcgaXQsIGFkZCBTLmVuYWJsZWAgKyBjYXBpdGFsaXplKGwkMSkgKyBgKCkgYXQgdGhlIHByb2plY3Qgcm9vdC5gO1xuICAgIHRocm93IG5ldyBFcnJvcihgW1N1cnldIGAgKyBtZXNzYWdlKTtcbiAgfVxufTtcblxuZnVuY3Rpb24gc2hha2VuKGFwaU5hbWUpIHtcbiAgbGV0IG11dCA9IG5ldyBTY2hlbWEoXCJuZXZlclwiKTtcbiAgbXV0W3NoYWtlblJlZl0gPSBhcGlOYW1lO1xuICByZXR1cm4gbmV3IFByb3h5KG11dCwgc2hha2VuVHJhcHMpO1xufVxuXG5sZXQgdW5rbm93biA9IG5ldyBTY2hlbWEoXCJ1bmtub3duXCIpO1xuXG5sZXQgYm9vbCA9IG5ldyBTY2hlbWEoXCJib29sZWFuXCIpO1xuXG5sZXQgc3ltYm9sID0gbmV3IFNjaGVtYShcInN5bWJvbFwiKTtcblxubGV0IHN0cmluZyA9IG5ldyBTY2hlbWEoXCJzdHJpbmdcIik7XG5cbmxldCBpbnQgPSBuZXcgU2NoZW1hKFwibnVtYmVyXCIpO1xuXG5pbnQuZm9ybWF0ID0gXCJpbnQzMlwiO1xuXG5sZXQgZmxvYXQgPSBuZXcgU2NoZW1hKFwibnVtYmVyXCIpO1xuXG5sZXQgYmlnaW50ID0gbmV3IFNjaGVtYShcImJpZ2ludFwiKTtcblxubGV0IHVuaXQgPSBuZXcgU2NoZW1hKFwidW5kZWZpbmVkXCIpO1xuXG51bml0LmNvbnN0ID0gKHZvaWQgMCk7XG5cbmxldCBjb3B5V2l0aG91dENhY2hlID0gKChzY2hlbWEpID0+IHtcbiAgbGV0IGMgPSBuZXcgU2NoZW1hKHNjaGVtYS50eXBlKVxuICBmb3IgKGxldCBrIGluIHNjaGVtYSkge1xuICAgIGlmIChrID4gXCJhXCIgfHwgayA9PT0gXCIkcmVmXCIgfHwgayA9PT0gXCIkZGVmc1wiKSB7XG4gICAgICBjW2tdID0gc2NoZW1hW2tdXG4gICAgfVxuICB9XG4gIHJldHVybiBjXG59KTtcblxuZnVuY3Rpb24gdXBkYXRlT3V0cHV0KHNjaGVtYSwgZm4pIHtcbiAgbGV0IHJvb3QgPSBjb3B5V2l0aG91dENhY2hlKHNjaGVtYSk7XG4gIGxldCBtdXQgPSByb290O1xuICB3aGlsZSAobXV0LnRvKSB7XG4gICAgbGV0IG5leHQgPSBjb3B5V2l0aG91dENhY2hlKG11dC50byk7XG4gICAgbXV0LnRvID0gbmV4dDtcbiAgICBtdXQgPSBuZXh0O1xuICB9O1xuICBmbihtdXQpO1xuICByZXR1cm4gcm9vdDtcbn1cblxubGV0IHJlc2V0Q2FjaGVJblBsYWNlID0gKChzY2hlbWEpID0+IHtcbiAgZm9yIChsZXQgayBpbiBzY2hlbWEpIHtcbiAgICBpZiAoTnVtYmVyKGtbMF0pKSB7XG4gICAgICBkZWxldGUgc2NoZW1hW2tdO1xuICAgIH1cbiAgfVxufSk7XG5cbmxldCB2YWx1ZSA9IFN1cnlFcnJvcjtcblxuZnVuY3Rpb24gY29uc3RydWN0b3IocHJpbTAsIHByaW0xLCBwcmltMikge1xuICByZXR1cm4gbmV3IFN1cnlFcnJvcihwcmltMCwgcHJpbTEsIHByaW0yKTtcbn1cblxubGV0IEVycm9yQ2xhc3MgPSB7XG4gIHZhbHVlOiB2YWx1ZSxcbiAgY29uc3RydWN0b3I6IGNvbnN0cnVjdG9yXG59O1xuXG5mdW5jdGlvbiBlbWJlZChiLCB2YWx1ZSkge1xuICBsZXQgZSA9IGIuZy5lO1xuICBsZXQgbCA9IGUubGVuZ3RoO1xuICBlW2xdID0gdmFsdWU7XG4gIHJldHVybiBgZVtgICsgbCArIGBdYDtcbn1cblxuZnVuY3Rpb24gaW5saW5lQ29uc3QoYiwgc2NoZW1hKSB7XG4gIGxldCB0YWdGbGFnID0gZmxhZ3Nbc2NoZW1hLnR5cGVdO1xuICBsZXQgJCRjb25zdCA9IHNjaGVtYS5jb25zdDtcbiAgaWYgKHRhZ0ZsYWcgJiAxNikge1xuICAgIHJldHVybiBcInZvaWQgMFwiO1xuICB9IGVsc2UgaWYgKHRhZ0ZsYWcgJiAyKSB7XG4gICAgcmV0dXJuIGZyb21TdHJpbmcoJCRjb25zdCk7XG4gIH0gZWxzZSBpZiAodGFnRmxhZyAmIDEwMjQpIHtcbiAgICByZXR1cm4gJCRjb25zdCArIFwiblwiO1xuICB9IGVsc2UgaWYgKHRhZ0ZsYWcgJiA0NTA1Nikge1xuICAgIHJldHVybiBlbWJlZChiLCBzY2hlbWEuY29uc3QpO1xuICB9IGVsc2Uge1xuICAgIHJldHVybiAkJGNvbnN0O1xuICB9XG59XG5cbmZ1bmN0aW9uIGlubGluZUxvY2F0aW9uKGIsIGxvY2F0aW9uKSB7XG4gIGxldCBrZXkgPSBgXCJgICsgbG9jYXRpb24gKyBgXCJgO1xuICBsZXQgaSA9IGIuZ1trZXldO1xuICBpZiAoaSAhPT0gdW5kZWZpbmVkKSB7XG4gICAgcmV0dXJuIGk7XG4gIH1cbiAgbGV0IGlubGluZWRMb2NhdGlvbiA9IGZyb21TdHJpbmcobG9jYXRpb24pO1xuICBiLmdba2V5XSA9IGlubGluZWRMb2NhdGlvbjtcbiAgcmV0dXJuIGlubGluZWRMb2NhdGlvbjtcbn1cblxuZnVuY3Rpb24gc2Vjb25kQWxsb2NhdGUodikge1xuICBsZXQgYiA9IHRoaXM7XG4gIGIubCA9IGIubCArIFwiLFwiICsgdjtcbn1cblxuZnVuY3Rpb24gaW5pdGlhbEFsbG9jYXRlKHYpIHtcbiAgbGV0IGIgPSB0aGlzO1xuICBiLmwgPSB2O1xuICBiLmEgPSBzZWNvbmRBbGxvY2F0ZTtcbn1cblxuZnVuY3Rpb24gcm9vdFNjb3BlKGZsYWcsIGRlZnMpIHtcbiAgbGV0IGdsb2JhbCA9IHtcbiAgICBjOiBcIlwiLFxuICAgIGw6IFwiXCIsXG4gICAgYTogaW5pdGlhbEFsbG9jYXRlLFxuICAgIHY6IC0xLFxuICAgIG86IGZsYWcsXG4gICAgZjogXCJcIixcbiAgICBlOiBbXSxcbiAgICBkOiBkZWZzXG4gIH07XG4gIGdsb2JhbC5nID0gZ2xvYmFsO1xuICByZXR1cm4gZ2xvYmFsO1xufVxuXG5mdW5jdGlvbiBhbGxvY2F0ZVNjb3BlKGIpIHtcbiAgKChkZWxldGUgYi5hKSk7XG4gIGxldCB2YXJzQWxsb2NhdGlvbiA9IGIubDtcbiAgaWYgKHZhcnNBbGxvY2F0aW9uID09PSBcIlwiKSB7XG4gICAgcmV0dXJuIGIuZiArIGIuYztcbiAgfSBlbHNlIHtcbiAgICByZXR1cm4gYi5mICsgYGxldCBgICsgdmFyc0FsbG9jYXRpb24gKyBgO2AgKyBiLmM7XG4gIH1cbn1cblxuZnVuY3Rpb24gdmFyV2l0aG91dEFsbG9jYXRpb24oZ2xvYmFsKSB7XG4gIGxldCBuZXdDb3VudGVyID0gZ2xvYmFsLnYgKyAxO1xuICBnbG9iYWwudiA9IG5ld0NvdW50ZXI7XG4gIHJldHVybiBgdmAgKyBuZXdDb3VudGVyO1xufVxuXG5mdW5jdGlvbiBfdmFyKF9iKSB7XG4gIHJldHVybiB0aGlzLmk7XG59XG5cbmZ1bmN0aW9uIF9ub3RWYXIoYikge1xuICBsZXQgdmFsID0gdGhpcztcbiAgbGV0IHYgPSB2YXJXaXRob3V0QWxsb2NhdGlvbihiLmcpO1xuICBsZXQgaSA9IHZhbC5pO1xuICBpZiAoaSA9PT0gXCJcIikge1xuICAgIHZhbC5iLmEodik7XG4gIH0gZWxzZSBpZiAoYi5hICE9PSAodm9pZCAwKSkge1xuICAgIGIuYSh2ICsgYD1gICsgaSk7XG4gIH0gZWxzZSB7XG4gICAgYi5jID0gYi5jICsgKHYgKyBgPWAgKyBpICsgYDtgKTtcbiAgICBiLmcuYSh2KTtcbiAgfVxuICB2YWwudiA9IF92YXI7XG4gIHZhbC5pID0gdjtcbiAgcmV0dXJuIHY7XG59XG5cbmZ1bmN0aW9uIGFsbG9jYXRlVmFsKGIsIHNjaGVtYSkge1xuICBsZXQgdiA9IHZhcldpdGhvdXRBbGxvY2F0aW9uKGIuZyk7XG4gIGIuYSh2KTtcbiAgcmV0dXJuIHtcbiAgICBiOiBiLFxuICAgIHY6IF92YXIsXG4gICAgaTogdixcbiAgICBmOiAwLFxuICAgIHR5cGU6IHNjaGVtYS50eXBlXG4gIH07XG59XG5cbmZ1bmN0aW9uIHZhbChiLCBpbml0aWFsLCBzY2hlbWEpIHtcbiAgcmV0dXJuIHtcbiAgICBiOiBiLFxuICAgIHY6IF9ub3RWYXIsXG4gICAgaTogaW5pdGlhbCxcbiAgICBmOiAwLFxuICAgIHR5cGU6IHNjaGVtYS50eXBlXG4gIH07XG59XG5cbmZ1bmN0aW9uIGNvbnN0VmFsKGIsIHNjaGVtYSkge1xuICByZXR1cm4ge1xuICAgIGI6IGIsXG4gICAgdjogX25vdFZhcixcbiAgICBpOiBpbmxpbmVDb25zdChiLCBzY2hlbWEpLFxuICAgIGY6IDAsXG4gICAgdHlwZTogc2NoZW1hLnR5cGUsXG4gICAgY29uc3Q6IHNjaGVtYS5jb25zdFxuICB9O1xufVxuXG5mdW5jdGlvbiBhc3luY1ZhbChiLCBpbml0aWFsKSB7XG4gIHJldHVybiB7XG4gICAgYjogYixcbiAgICB2OiBfbm90VmFyLFxuICAgIGk6IGluaXRpYWwsXG4gICAgZjogMixcbiAgICB0eXBlOiBcInVua25vd25cIlxuICB9O1xufVxuXG5mdW5jdGlvbiBvYmplY3RKb2luKGlubGluZWRMb2NhdGlvbiwgdmFsdWUpIHtcbiAgcmV0dXJuIGlubGluZWRMb2NhdGlvbiArIGA6YCArIHZhbHVlICsgYCxgO1xufVxuXG5mdW5jdGlvbiBhcnJheUpvaW4oX2lubGluZWRMb2NhdGlvbiwgdmFsdWUpIHtcbiAgcmV0dXJuIHZhbHVlICsgXCIsXCI7XG59XG5cbmZ1bmN0aW9uIG1ha2UoYiwgaXNBcnJheSkge1xuICByZXR1cm4ge1xuICAgIGI6IGIsXG4gICAgdjogX25vdFZhcixcbiAgICBpOiBcIlwiLFxuICAgIGY6IDAsXG4gICAgdHlwZTogaXNBcnJheSA/IFwiYXJyYXlcIiA6IFwib2JqZWN0XCIsXG4gICAgcHJvcGVydGllczoge30sXG4gICAgYWRkaXRpb25hbEl0ZW1zOiBcInN0cmljdFwiLFxuICAgIGo6IGlzQXJyYXkgPyBhcnJheUpvaW4gOiBvYmplY3RKb2luLFxuICAgIGM6IDAsXG4gICAgcjogXCJcIlxuICB9O1xufVxuXG5mdW5jdGlvbiBhZGQob2JqZWN0VmFsLCBsb2NhdGlvbiwgdmFsKSB7XG4gIGxldCBpbmxpbmVkTG9jYXRpb24gPSBpbmxpbmVMb2NhdGlvbihvYmplY3RWYWwuYiwgbG9jYXRpb24pO1xuICBvYmplY3RWYWwucHJvcGVydGllc1tsb2NhdGlvbl0gPSB2YWw7XG4gIGlmICh2YWwuZiAmIDIpIHtcbiAgICBvYmplY3RWYWwuciA9IG9iamVjdFZhbC5yICsgdmFsLmkgKyBcIixcIjtcbiAgICBvYmplY3RWYWwuaSA9IG9iamVjdFZhbC5pICsgb2JqZWN0VmFsLmooaW5saW5lZExvY2F0aW9uLCBgYVtgICsgKG9iamVjdFZhbC5jKyspICsgYF1gKTtcbiAgfSBlbHNlIHtcbiAgICBvYmplY3RWYWwuaSA9IG9iamVjdFZhbC5pICsgb2JqZWN0VmFsLmooaW5saW5lZExvY2F0aW9uLCB2YWwuaSk7XG4gIH1cbn1cblxuZnVuY3Rpb24gbWVyZ2UodGFyZ2V0LCBzdWJPYmplY3RWYWwpIHtcbiAgbGV0IGxvY2F0aW9ucyA9IE9iamVjdC5rZXlzKHN1Yk9iamVjdFZhbC5wcm9wZXJ0aWVzKTtcbiAgZm9yIChsZXQgaWR4ID0gMCwgaWR4X2ZpbmlzaCA9IGxvY2F0aW9ucy5sZW5ndGg7IGlkeCA8IGlkeF9maW5pc2g7ICsraWR4KSB7XG4gICAgbGV0IGxvY2F0aW9uID0gbG9jYXRpb25zW2lkeF07XG4gICAgYWRkKHRhcmdldCwgbG9jYXRpb24sIHN1Yk9iamVjdFZhbC5wcm9wZXJ0aWVzW2xvY2F0aW9uXSk7XG4gIH1cbn1cblxuZnVuY3Rpb24gY29tcGxldGUob2JqZWN0VmFsLCBpc0FycmF5KSB7XG4gIG9iamVjdFZhbC5pID0gaXNBcnJheSA/IFwiW1wiICsgb2JqZWN0VmFsLmkgKyBcIl1cIiA6IFwie1wiICsgb2JqZWN0VmFsLmkgKyBcIn1cIjtcbiAgaWYgKG9iamVjdFZhbC5jKSB7XG4gICAgb2JqZWN0VmFsLmYgPSBvYmplY3RWYWwuZiB8IDI7XG4gICAgb2JqZWN0VmFsLmkgPSBgUHJvbWlzZS5hbGwoW2AgKyBvYmplY3RWYWwuciArIGBdKS50aGVuKGE9PihgICsgb2JqZWN0VmFsLmkgKyBgKSlgO1xuICB9XG4gIG9iamVjdFZhbC5hZGRpdGlvbmFsSXRlbXMgPSBcInN0cmljdFwiO1xuICByZXR1cm4gb2JqZWN0VmFsO1xufVxuXG5mdW5jdGlvbiBhZGRLZXkoYiwgaW5wdXQsIGtleSwgdmFsKSB7XG4gIHJldHVybiBpbnB1dC52KGIpICsgYFtgICsga2V5ICsgYF09YCArIHZhbC5pO1xufVxuXG5mdW5jdGlvbiBzZXQoYiwgaW5wdXQsIHZhbCkge1xuICBpZiAoaW5wdXQgPT09IHZhbCkge1xuICAgIHJldHVybiBcIlwiO1xuICB9XG4gIGxldCBpbnB1dFZhciA9IGlucHV0LnYoYik7XG4gIGxldCBtYXRjaCA9IGlucHV0LmYgJiAyO1xuICBsZXQgbWF0Y2gkMSA9IHZhbC5mICYgMjtcbiAgaWYgKG1hdGNoKSB7XG4gICAgaWYgKCFtYXRjaCQxKSB7XG4gICAgICByZXR1cm4gaW5wdXRWYXIgKyBgPVByb21pc2UucmVzb2x2ZShgICsgdmFsLmkgKyBgKWA7XG4gICAgfVxuICB9IGVsc2UgaWYgKG1hdGNoJDEpIHtcbiAgICBpbnB1dC5mID0gaW5wdXQuZiB8IDI7XG4gICAgcmV0dXJuIGlucHV0VmFyICsgYD1gICsgdmFsLmk7XG4gIH1cbiAgcmV0dXJuIGlucHV0VmFyICsgYD1gICsgdmFsLmk7XG59XG5cbmZ1bmN0aW9uIGdldChiLCB0YXJnZXRWYWwsIGxvY2F0aW9uKSB7XG4gIGxldCBwcm9wZXJ0aWVzID0gdGFyZ2V0VmFsLnByb3BlcnRpZXM7XG4gIGxldCB2YWwgPSBwcm9wZXJ0aWVzW2xvY2F0aW9uXTtcbiAgaWYgKHZhbCAhPT0gdW5kZWZpbmVkKSB7XG4gICAgcmV0dXJuIHZhbDtcbiAgfVxuICBsZXQgc2NoZW1hID0gdGFyZ2V0VmFsLmFkZGl0aW9uYWxJdGVtcztcbiAgbGV0IHNjaGVtYSQxO1xuICBpZiAoc2NoZW1hID09PSBcInN0cmlwXCIgfHwgc2NoZW1hID09PSBcInN0cmljdFwiKSB7XG4gICAgaWYgKHNjaGVtYSA9PT0gXCJzdHJpcFwiKSB7XG4gICAgICB0aHJvdyBuZXcgRXJyb3IoYFtTdXJ5XSBgICsgXCJUaGUgc2NoZW1hIGRvZXNuJ3QgaGF2ZSBhZGRpdGlvbmFsIGl0ZW1zXCIpO1xuICAgIH1cbiAgICB0aHJvdyBuZXcgRXJyb3IoYFtTdXJ5XSBgICsgXCJUaGUgc2NoZW1hIGRvZXNuJ3QgaGF2ZSBhZGRpdGlvbmFsIGl0ZW1zXCIpO1xuICB9IGVsc2Uge1xuICAgIHNjaGVtYSQxID0gc2NoZW1hO1xuICB9XG4gIGxldCB2YWwkMSA9IHtcbiAgICBiOiBiLFxuICAgIHY6IF9ub3RWYXIsXG4gICAgaTogdGFyZ2V0VmFsLnYoYikgKyAoYFtgICsgZnJvbVN0cmluZyhsb2NhdGlvbikgKyBgXWApLFxuICAgIGY6IDAsXG4gICAgdHlwZTogc2NoZW1hJDEudHlwZVxuICB9O1xuICBwcm9wZXJ0aWVzW2xvY2F0aW9uXSA9IHZhbCQxO1xuICByZXR1cm4gdmFsJDE7XG59XG5cbmZ1bmN0aW9uIHNldElubGluZWQoYiwgaW5wdXQsIGlubGluZWQpIHtcbiAgcmV0dXJuIGlucHV0LnYoYikgKyBgPWAgKyBpbmxpbmVkO1xufVxuXG5mdW5jdGlvbiBtYXAoaW5saW5lZEZuLCBpbnB1dCkge1xuICByZXR1cm4ge1xuICAgIGI6IGlucHV0LmIsXG4gICAgdjogX25vdFZhcixcbiAgICBpOiBpbmxpbmVkRm4gKyBgKGAgKyBpbnB1dC5pICsgYClgLFxuICAgIGY6IDAsXG4gICAgdHlwZTogXCJ1bmtub3duXCJcbiAgfTtcbn1cblxuZnVuY3Rpb24gJCR0aHJvdyhiLCBjb2RlLCBwYXRoKSB7XG4gIHRocm93IG5ldyBTdXJ5RXJyb3IoY29kZSwgYi5nLm8sIHBhdGgpO1xufVxuXG5mdW5jdGlvbiBlbWJlZFN5bmNPcGVyYXRpb24oYiwgaW5wdXQsIGZuKSB7XG4gIGlmIChpbnB1dC5mICYgMikge1xuICAgIHJldHVybiBhc3luY1ZhbChpbnB1dC5iLCBpbnB1dC5pICsgYC50aGVuKGAgKyBlbWJlZChiLCBmbikgKyBgKWApO1xuICB9IGVsc2Uge1xuICAgIHJldHVybiBtYXAoZW1iZWQoYiwgZm4pLCBpbnB1dCk7XG4gIH1cbn1cblxuZnVuY3Rpb24gZmFpbFdpdGhBcmcoYiwgcGF0aCwgZm4sIGFyZykge1xuICByZXR1cm4gZW1iZWQoYiwgYXJnID0+ICQkdGhyb3coYiwgZm4oYXJnKSwgcGF0aCkpICsgYChgICsgYXJnICsgYClgO1xufVxuXG5mdW5jdGlvbiBmYWlsKGIsIG1lc3NhZ2UsIHBhdGgpIHtcbiAgcmV0dXJuIGVtYmVkKGIsICgpID0+ICQkdGhyb3coYiwge1xuICAgIFRBRzogXCJPcGVyYXRpb25GYWlsZWRcIixcbiAgICBfMDogbWVzc2FnZVxuICB9LCBwYXRoKSkgKyBgKClgO1xufVxuXG5mdW5jdGlvbiBlZmZlY3RDdHgoYiwgc2VsZlNjaGVtYSwgcGF0aCkge1xuICByZXR1cm4ge1xuICAgIHNjaGVtYTogc2VsZlNjaGVtYSxcbiAgICBmYWlsOiAobWVzc2FnZSwgY3VzdG9tUGF0aE9wdCkgPT4ge1xuICAgICAgbGV0IGN1c3RvbVBhdGggPSBjdXN0b21QYXRoT3B0ICE9PSB1bmRlZmluZWQgPyBjdXN0b21QYXRoT3B0IDogXCJcIjtcbiAgICAgIHJldHVybiAkJHRocm93KGIsIHtcbiAgICAgICAgVEFHOiBcIk9wZXJhdGlvbkZhaWxlZFwiLFxuICAgICAgICBfMDogbWVzc2FnZVxuICAgICAgfSwgcGF0aCArIGN1c3RvbVBhdGgpO1xuICAgIH1cbiAgfTtcbn1cblxuZnVuY3Rpb24gaW52YWxpZE9wZXJhdGlvbihiLCBwYXRoLCBkZXNjcmlwdGlvbikge1xuICByZXR1cm4gJCR0aHJvdyhiLCB7XG4gICAgVEFHOiBcIkludmFsaWRPcGVyYXRpb25cIixcbiAgICBkZXNjcmlwdGlvbjogZGVzY3JpcHRpb25cbiAgfSwgcGF0aCk7XG59XG5cbmZ1bmN0aW9uIHdpdGhQYXRoUHJlcGVuZChiLCBpbnB1dCwgcGF0aCwgbWF5YmVEeW5hbWljTG9jYXRpb25WYXIsIGFwcGVuZFNhZmUsIGZuKSB7XG4gIGlmIChwYXRoID09PSBcIlwiICYmIG1heWJlRHluYW1pY0xvY2F0aW9uVmFyID09PSB1bmRlZmluZWQpIHtcbiAgICByZXR1cm4gZm4oYiwgaW5wdXQsIHBhdGgpO1xuICB9XG4gIHRyeSB7XG4gICAgbGV0ICQkY2F0Y2ggPSAoYiwgZXJyb3JWYXIpID0+IHtcbiAgICAgIGIuYyA9IGVycm9yVmFyICsgYC5wYXRoPWAgKyBmcm9tU3RyaW5nKHBhdGgpICsgYCtgICsgKFxuICAgICAgICBtYXliZUR5bmFtaWNMb2NhdGlvblZhciAhPT0gdW5kZWZpbmVkID8gYCdbXCInK2AgKyBtYXliZUR5bmFtaWNMb2NhdGlvblZhciArIGArJ1wiXScrYCA6IFwiXCJcbiAgICAgICkgKyBlcnJvclZhciArIGAucGF0aGA7XG4gICAgfTtcbiAgICBsZXQgZm4kMSA9IGIgPT4gZm4oYiwgaW5wdXQsIFwiXCIpO1xuICAgIGxldCBwcmV2Q29kZSA9IGIuYztcbiAgICBiLmMgPSBcIlwiO1xuICAgIGxldCBlcnJvclZhciA9IHZhcldpdGhvdXRBbGxvY2F0aW9uKGIuZyk7XG4gICAgbGV0IG1heWJlUmVzb2x2ZVZhbCA9ICQkY2F0Y2goYiwgZXJyb3JWYXIpO1xuICAgIGxldCBjYXRjaENvZGUgPSBgaWYoYCArIChlcnJvclZhciArIGAmJmAgKyBlcnJvclZhciArIGAucz09PXNgKSArIGApe2AgKyBiLmM7XG4gICAgYi5jID0gXCJcIjtcbiAgICBsZXQgYmIgPSB7XG4gICAgICBjOiBcIlwiLFxuICAgICAgbDogXCJcIixcbiAgICAgIGE6IGluaXRpYWxBbGxvY2F0ZSxcbiAgICAgIGY6IFwiXCIsXG4gICAgICBnOiBiLmdcbiAgICB9O1xuICAgIGxldCBmbk91dHB1dCA9IGZuJDEoYmIpO1xuICAgIGIuYyA9IGIuYyArIGFsbG9jYXRlU2NvcGUoYmIpO1xuICAgIGxldCBpc05vb3AgPSBmbk91dHB1dC5pID09PSBpbnB1dC5pICYmIGIuYyA9PT0gXCJcIjtcbiAgICBpZiAoYXBwZW5kU2FmZSAhPT0gdW5kZWZpbmVkKSB7XG4gICAgICBhcHBlbmRTYWZlKGIsIGZuT3V0cHV0KTtcbiAgICB9XG4gICAgaWYgKGlzTm9vcCkge1xuICAgICAgcmV0dXJuIGZuT3V0cHV0O1xuICAgIH1cbiAgICBsZXQgaXNBc3luYyA9IGZuT3V0cHV0LmYgJiAyO1xuICAgIGxldCBvdXRwdXQgPSBpbnB1dCA9PT0gZm5PdXRwdXQgPyBpbnB1dCA6IChcbiAgICAgICAgYXBwZW5kU2FmZSAhPT0gdW5kZWZpbmVkID8gZm5PdXRwdXQgOiAoe1xuICAgICAgICAgICAgYjogYixcbiAgICAgICAgICAgIHY6IF9ub3RWYXIsXG4gICAgICAgICAgICBpOiBcIlwiLFxuICAgICAgICAgICAgZjogaXNBc3luYyA/IDIgOiAwLFxuICAgICAgICAgICAgdHlwZTogXCJ1bmtub3duXCJcbiAgICAgICAgICB9KVxuICAgICAgKTtcbiAgICBsZXQgY2F0Y2hDb2RlJDEgPSBtYXliZVJlc29sdmVWYWwgIT09IHVuZGVmaW5lZCA/IGNhdGNoTG9jYXRpb24gPT4gY2F0Y2hDb2RlICsgKFxuICAgICAgICBjYXRjaExvY2F0aW9uID09PSAxID8gYHJldHVybiBgICsgbWF5YmVSZXNvbHZlVmFsLmkgOiBzZXQoYiwgb3V0cHV0LCBtYXliZVJlc29sdmVWYWwpXG4gICAgICApICsgKGB9ZWxzZXt0aHJvdyBgICsgZXJyb3JWYXIgKyBgfWApIDogcGFyYW0gPT4gY2F0Y2hDb2RlICsgYH10aHJvdyBgICsgZXJyb3JWYXI7XG4gICAgYi5jID0gcHJldkNvZGUgKyAoYHRyeXtgICsgYi5jICsgKFxuICAgICAgaXNBc3luYyA/IHNldElubGluZWQoYiwgb3V0cHV0LCBmbk91dHB1dC5pICsgYC5jYXRjaChgICsgZXJyb3JWYXIgKyBgPT57YCArIGNhdGNoQ29kZSQxKDEpICsgYH0pYCkgOiBzZXQoYiwgb3V0cHV0LCBmbk91dHB1dClcbiAgICApICsgYH1jYXRjaChgICsgZXJyb3JWYXIgKyBgKXtgICsgY2F0Y2hDb2RlJDEoMCkgKyBgfWApO1xuICAgIHJldHVybiBvdXRwdXQ7XG4gIH0gY2F0Y2ggKGV4bikge1xuICAgIGxldCBlcnJvciA9IGdldE9yUmV0aHJvdyhleG4pO1xuICAgIHRocm93IG5ldyBTdXJ5RXJyb3IoZXJyb3IuY29kZSwgZXJyb3IuZmxhZywgcGF0aCArIFwiW11cIiArIGVycm9yLnBhdGgpO1xuICB9XG59XG5cbmZ1bmN0aW9uIHZhbGlkYXRpb24oYiwgaW5wdXRWYXIsIHNjaGVtYSwgbmVnYXRpdmUpIHtcbiAgbGV0IGVxID0gbmVnYXRpdmUgPyBcIiE9PVwiIDogXCI9PT1cIjtcbiAgbGV0IGFuZF8gPSBuZWdhdGl2ZSA/IFwifHxcIiA6IFwiJiZcIjtcbiAgbGV0IGV4cCA9IG5lZ2F0aXZlID8gXCIhXCIgOiBcIlwiO1xuICBsZXQgdGFnID0gc2NoZW1hLnR5cGU7XG4gIGxldCB0YWdGbGFnID0gZmxhZ3NbdGFnXTtcbiAgaWYgKHRhZ0ZsYWcgJiAyMDQ4KSB7XG4gICAgcmV0dXJuIGV4cCArIChgTnVtYmVyLmlzTmFOKGAgKyBpbnB1dFZhciArIGApYCk7XG4gIH1cbiAgaWYgKGNvbnN0RmllbGQgaW4gc2NoZW1hKSB7XG4gICAgcmV0dXJuIGlucHV0VmFyICsgZXEgKyBpbmxpbmVDb25zdChiLCBzY2hlbWEpO1xuICB9XG4gIGlmICh0YWdGbGFnICYgNCkge1xuICAgIHJldHVybiBgdHlwZW9mIGAgKyBpbnB1dFZhciArIGVxICsgYFwiYCArIHRhZyArIGBcImA7XG4gIH1cbiAgaWYgKHRhZ0ZsYWcgJiA2NCkge1xuICAgIHJldHVybiBgdHlwZW9mIGAgKyBpbnB1dFZhciArIGVxICsgYFwiYCArIHRhZyArIGBcImAgKyBhbmRfICsgZXhwICsgaW5wdXRWYXI7XG4gIH1cbiAgaWYgKHRhZ0ZsYWcgJiAxMjgpIHtcbiAgICByZXR1cm4gZXhwICsgYEFycmF5LmlzQXJyYXkoYCArIGlucHV0VmFyICsgYClgO1xuICB9XG4gIGlmICghKHRhZ0ZsYWcgJiA4MTkyKSkge1xuICAgIHJldHVybiBgdHlwZW9mIGAgKyBpbnB1dFZhciArIGVxICsgYFwiYCArIHRhZyArIGBcImA7XG4gIH1cbiAgbGV0IGMgPSBpbnB1dFZhciArIGAgaW5zdGFuY2VvZiBgICsgZW1iZWQoYiwgc2NoZW1hLmNsYXNzKTtcbiAgaWYgKG5lZ2F0aXZlKSB7XG4gICAgcmV0dXJuIGAhKGAgKyBjICsgYClgO1xuICB9IGVsc2Uge1xuICAgIHJldHVybiBjO1xuICB9XG59XG5cbmZ1bmN0aW9uIHJlZmluZW1lbnQoYiwgaW5wdXRWYXIsIHNjaGVtYSwgbmVnYXRpdmUpIHtcbiAgbGV0IGVxID0gbmVnYXRpdmUgPyBcIiE9PVwiIDogXCI9PT1cIjtcbiAgbGV0IGFuZF8gPSBuZWdhdGl2ZSA/IFwifHxcIiA6IFwiJiZcIjtcbiAgbGV0IG5vdF8gPSBuZWdhdGl2ZSA/IFwiXCIgOiBcIiFcIjtcbiAgbGV0IGx0ID0gbmVnYXRpdmUgPyBcIj5cIiA6IFwiPFwiO1xuICBsZXQgZ3QgPSBuZWdhdGl2ZSA/IFwiPFwiIDogXCI+XCI7XG4gIGxldCBtYXRjaCA9IHNjaGVtYS50eXBlO1xuICBsZXQgdGFnO1xuICBsZXQgZXhpdCA9IDA7XG4gIGxldCBtYXRjaCQxID0gc2NoZW1hLmNvbnN0O1xuICBpZiAobWF0Y2gkMSAhPT0gdW5kZWZpbmVkKSB7XG4gICAgcmV0dXJuIFwiXCI7XG4gIH1cbiAgbGV0IG1hdGNoJDIgPSBzY2hlbWEuZm9ybWF0O1xuICBpZiAobWF0Y2gkMiAhPT0gdW5kZWZpbmVkKSB7XG4gICAgc3dpdGNoIChtYXRjaCQyKSB7XG4gICAgICBjYXNlIFwiaW50MzJcIiA6XG4gICAgICAgIHJldHVybiBhbmRfICsgaW5wdXRWYXIgKyBsdCArIGAyMTQ3NDgzNjQ3YCArIGFuZF8gKyBpbnB1dFZhciArIGd0ICsgYC0yMTQ3NDgzNjQ4YCArIGFuZF8gKyBpbnB1dFZhciArIGAlMWAgKyBlcSArIGAwYDtcbiAgICAgIGNhc2UgXCJwb3J0XCIgOlxuICAgICAgY2FzZSBcImpzb25cIiA6XG4gICAgICAgIGV4aXQgPSAyO1xuICAgICAgICBicmVhaztcbiAgICB9XG4gIH0gZWxzZSB7XG4gICAgZXhpdCA9IDI7XG4gIH1cbiAgaWYgKGV4aXQgPT09IDIpIHtcbiAgICBzd2l0Y2ggKG1hdGNoKSB7XG4gICAgICBjYXNlIFwibnVtYmVyXCIgOlxuICAgICAgICBpZiAoZ2xvYmFsQ29uZmlnLm4pIHtcbiAgICAgICAgICByZXR1cm4gXCJcIjtcbiAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICByZXR1cm4gYW5kXyArIG5vdF8gKyBgTnVtYmVyLmlzTmFOKGAgKyBpbnB1dFZhciArIGApYDtcbiAgICAgICAgfVxuICAgICAgY2FzZSBcImFycmF5XCIgOlxuICAgICAgY2FzZSBcIm9iamVjdFwiIDpcbiAgICAgICAgdGFnID0gbWF0Y2g7XG4gICAgICAgIGJyZWFrO1xuICAgICAgZGVmYXVsdDpcbiAgICAgICAgcmV0dXJuIFwiXCI7XG4gICAgfVxuICB9XG4gIGxldCBhZGRpdGlvbmFsSXRlbXMgPSBzY2hlbWEuYWRkaXRpb25hbEl0ZW1zO1xuICBsZXQgaXRlbXMgPSBzY2hlbWEuaXRlbXM7XG4gIGxldCBsZW5ndGggPSBpdGVtcy5sZW5ndGg7XG4gIGxldCBjb2RlID0gdGFnID09PSBcImFycmF5XCIgPyAoXG4gICAgICBhZGRpdGlvbmFsSXRlbXMgPT09IFwic3RyaXBcIiB8fCBhZGRpdGlvbmFsSXRlbXMgPT09IFwic3RyaWN0XCIgPyAoXG4gICAgICAgICAgYWRkaXRpb25hbEl0ZW1zID09PSBcInN0cmlwXCIgPyBhbmRfICsgaW5wdXRWYXIgKyBgLmxlbmd0aGAgKyBndCArIGxlbmd0aCA6IGFuZF8gKyBpbnB1dFZhciArIGAubGVuZ3RoYCArIGVxICsgbGVuZ3RoXG4gICAgICAgICkgOiBcIlwiXG4gICAgKSA6IChcbiAgICAgIGFkZGl0aW9uYWxJdGVtcyA9PT0gXCJzdHJpcFwiID8gXCJcIiA6IGFuZF8gKyBub3RfICsgYEFycmF5LmlzQXJyYXkoYCArIGlucHV0VmFyICsgYClgXG4gICAgKTtcbiAgZm9yIChsZXQgaWR4ID0gMCwgaWR4X2ZpbmlzaCA9IGl0ZW1zLmxlbmd0aDsgaWR4IDwgaWR4X2ZpbmlzaDsgKytpZHgpIHtcbiAgICBsZXQgbWF0Y2gkMyA9IGl0ZW1zW2lkeF07XG4gICAgbGV0IGxvY2F0aW9uID0gbWF0Y2gkMy5sb2NhdGlvbjtcbiAgICBsZXQgaXRlbSA9IG1hdGNoJDMuc2NoZW1hO1xuICAgIGxldCBpdGVtQ29kZTtcbiAgICBpZiAoY29uc3RGaWVsZCBpbiBpdGVtIHx8IHNjaGVtYS51bm5lc3QpIHtcbiAgICAgIGxldCBpbmxpbmVkTG9jYXRpb24gPSBpbmxpbmVMb2NhdGlvbihiLCBsb2NhdGlvbik7XG4gICAgICBpdGVtQ29kZSA9IHZhbGlkYXRpb24oYiwgaW5wdXRWYXIgKyAoYFtgICsgaW5saW5lZExvY2F0aW9uICsgYF1gKSwgaXRlbSwgbmVnYXRpdmUpO1xuICAgIH0gZWxzZSBpZiAoaXRlbS5pdGVtcykge1xuICAgICAgbGV0IGlubGluZWRMb2NhdGlvbiQxID0gaW5saW5lTG9jYXRpb24oYiwgbG9jYXRpb24pO1xuICAgICAgbGV0IGlucHV0VmFyJDEgPSBpbnB1dFZhciArIChgW2AgKyBpbmxpbmVkTG9jYXRpb24kMSArIGBdYCk7XG4gICAgICBpdGVtQ29kZSA9IHZhbGlkYXRpb24oYiwgaW5wdXRWYXIkMSwgaXRlbSwgbmVnYXRpdmUpICsgcmVmaW5lbWVudChiLCBpbnB1dFZhciQxLCBpdGVtLCBuZWdhdGl2ZSk7XG4gICAgfSBlbHNlIHtcbiAgICAgIGl0ZW1Db2RlID0gXCJcIjtcbiAgICB9XG4gICAgaWYgKGl0ZW1Db2RlICE9PSBcIlwiKSB7XG4gICAgICBjb2RlID0gY29kZSArIGFuZF8gKyBpdGVtQ29kZTtcbiAgICB9XG4gIH1cbiAgcmV0dXJuIGNvZGU7XG59XG5cbmZ1bmN0aW9uIG1ha2VSZWZpbmVkT2YoYiwgaW5wdXQsIHNjaGVtYSkge1xuICBsZXQgbXV0ID0ge1xuICAgIGI6IGIsXG4gICAgdjogaW5wdXQudixcbiAgICBpOiBpbnB1dC5pLFxuICAgIGY6IGlucHV0LmYsXG4gICAgdHlwZTogc2NoZW1hLnR5cGVcbiAgfTtcbiAgbGV0IGxvb3AgPSAobXV0LCBzY2hlbWEpID0+IHtcbiAgICBpZiAoY29uc3RGaWVsZCBpbiBzY2hlbWEpIHtcbiAgICAgIG11dC5jb25zdCA9IHNjaGVtYS5jb25zdDtcbiAgICB9XG4gICAgbGV0IGl0ZW1zID0gc2NoZW1hLml0ZW1zO1xuICAgIGlmIChpdGVtcyA9PT0gdW5kZWZpbmVkKSB7XG4gICAgICByZXR1cm47XG4gICAgfVxuICAgIGxldCBwcm9wZXJ0aWVzID0ge307XG4gICAgaXRlbXMuZm9yRWFjaChpdGVtID0+IHtcbiAgICAgIGxldCBzY2hlbWEgPSBpdGVtLnNjaGVtYTtcbiAgICAgIGxldCBpc0NvbnN0ID0gY29uc3RGaWVsZCBpbiBzY2hlbWE7XG4gICAgICBpZiAoIShpc0NvbnN0IHx8IHNjaGVtYS5pdGVtcykpIHtcbiAgICAgICAgcmV0dXJuO1xuICAgICAgfVxuICAgICAgbGV0IHRtcDtcbiAgICAgIGlmIChpc0NvbnN0KSB7XG4gICAgICAgIHRtcCA9IGlubGluZUNvbnN0KGIsIHNjaGVtYSk7XG4gICAgICB9IGVsc2Uge1xuICAgICAgICBsZXQgaW5saW5lZExvY2F0aW9uID0gaW5saW5lTG9jYXRpb24oYiwgaXRlbS5sb2NhdGlvbik7XG4gICAgICAgIHRtcCA9IG11dC52KGIpICsgKGBbYCArIGlubGluZWRMb2NhdGlvbiArIGBdYCk7XG4gICAgICB9XG4gICAgICBsZXQgbXV0JDEgPSB7XG4gICAgICAgIGI6IG11dC5iLFxuICAgICAgICB2OiBfbm90VmFyLFxuICAgICAgICBpOiB0bXAsXG4gICAgICAgIGY6IDAsXG4gICAgICAgIHR5cGU6IHNjaGVtYS50eXBlXG4gICAgICB9O1xuICAgICAgbG9vcChtdXQkMSwgc2NoZW1hKTtcbiAgICAgIHByb3BlcnRpZXNbaXRlbS5sb2NhdGlvbl0gPSBtdXQkMTtcbiAgICB9KTtcbiAgICBtdXQucHJvcGVydGllcyA9IHByb3BlcnRpZXM7XG4gICAgbXV0LmFkZGl0aW9uYWxJdGVtcyA9IHVua25vd247XG4gIH07XG4gIGxvb3AobXV0LCBzY2hlbWEpO1xuICByZXR1cm4gbXV0O1xufVxuXG5mdW5jdGlvbiB0eXBlRmlsdGVyQ29kZShiLCBzY2hlbWEsIGlucHV0LCBwYXRoKSB7XG4gIGlmIChzY2hlbWEubm9WYWxpZGF0aW9uIHx8IGZsYWdzW3NjaGVtYS50eXBlXSAmIDE3MTUzKSB7XG4gICAgcmV0dXJuIFwiXCI7XG4gIH1cbiAgbGV0IGlucHV0VmFyID0gaW5wdXQudihiKTtcbiAgcmV0dXJuIGBpZihgICsgdmFsaWRhdGlvbihiLCBpbnB1dFZhciwgc2NoZW1hLCB0cnVlKSArIHJlZmluZW1lbnQoYiwgaW5wdXRWYXIsIHNjaGVtYSwgdHJ1ZSkgKyBgKXtgICsgZmFpbFdpdGhBcmcoYiwgcGF0aCwgaW5wdXQgPT4gKHtcbiAgICBUQUc6IFwiSW52YWxpZFR5cGVcIixcbiAgICBleHBlY3RlZDogc2NoZW1hLFxuICAgIHJlY2VpdmVkOiBpbnB1dFxuICB9KSwgaW5wdXRWYXIpICsgYH1gO1xufVxuXG5mdW5jdGlvbiB1bnN1cHBvcnRlZFRyYW5zZm9ybShiLCBmcm9tLCB0YXJnZXQsIHBhdGgpIHtcbiAgcmV0dXJuICQkdGhyb3coYiwge1xuICAgIFRBRzogXCJVbnN1cHBvcnRlZFRyYW5zZm9ybWF0aW9uXCIsXG4gICAgZnJvbTogZnJvbSxcbiAgICB0bzogdGFyZ2V0XG4gIH0sIHBhdGgpO1xufVxuXG5mdW5jdGlvbiBub29wT3BlcmF0aW9uKGkpIHtcbiAgcmV0dXJuIGk7XG59XG5cbmZ1bmN0aW9uIHNldEhhcyhoYXMsIHRhZykge1xuICBoYXNbdGFnID09PSBcInVuaW9uXCIgfHwgdGFnID09PSBcInJlZlwiID8gXCJ1bmtub3duXCIgOiB0YWddID0gdHJ1ZTtcbn1cblxubGV0IGpzb25OYW1lID0gYEpTT05gO1xuXG5sZXQganNvblN0cmluZyA9IHNoYWtlbihcImpzb25TdHJpbmdcIik7XG5cbmZ1bmN0aW9uIGlucHV0VG9TdHJpbmcoYiwgaW5wdXQpIHtcbiAgcmV0dXJuIHZhbChiLCBgXCJcIitgICsgaW5wdXQuaSwgc3RyaW5nKTtcbn1cblxuZnVuY3Rpb24gcGFyc2UocHJldkIsIHNjaGVtYSwgaW5wdXRBcmcsIHBhdGgpIHtcbiAgbGV0IGIgPSB7XG4gICAgYzogXCJcIixcbiAgICBsOiBcIlwiLFxuICAgIGE6IGluaXRpYWxBbGxvY2F0ZSxcbiAgICBmOiBcIlwiLFxuICAgIGc6IHByZXZCLmdcbiAgfTtcbiAgaWYgKHNjaGVtYS4kZGVmcykge1xuICAgIGIuZy5kID0gc2NoZW1hLiRkZWZzO1xuICB9XG4gIGxldCBpbnB1dCA9IGlucHV0QXJnO1xuICBsZXQgaXNGcm9tTGl0ZXJhbCA9IGNvbnN0RmllbGQgaW4gaW5wdXQ7XG4gIGxldCBpc1NjaGVtYUxpdGVyYWwgPSBjb25zdEZpZWxkIGluIHNjaGVtYTtcbiAgbGV0IGlzU2FtZVRhZyA9IGlucHV0LnR5cGUgPT09IHNjaGVtYS50eXBlO1xuICBsZXQgc2NoZW1hVGFnRmxhZyA9IGZsYWdzW3NjaGVtYS50eXBlXTtcbiAgbGV0IGlucHV0VGFnRmxhZyA9IGZsYWdzW2lucHV0LnR5cGVdO1xuICBsZXQgaXNVbnN1cHBvcnRlZCA9IGZhbHNlO1xuICBpZiAoIShzY2hlbWFUYWdGbGFnICYgMjU3IHx8IHNjaGVtYS5mb3JtYXQgPT09IFwianNvblwiKSkge1xuICAgIGlmIChzY2hlbWEubmFtZSA9PT0ganNvbk5hbWUgJiYgIShpbnB1dFRhZ0ZsYWcgJiAxKSkge1xuICAgICAgaWYgKCEoaW5wdXRUYWdGbGFnICYgMTQpKSB7XG4gICAgICAgIGlmIChpbnB1dFRhZ0ZsYWcgJiAxMDI0KSB7XG4gICAgICAgICAgaW5wdXQgPSBpbnB1dFRvU3RyaW5nKGIsIGlucHV0KTtcbiAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICBpc1Vuc3VwcG9ydGVkID0gdHJ1ZTtcbiAgICAgICAgfVxuICAgICAgfVxuICAgIH0gZWxzZSBpZiAoaXNTY2hlbWFMaXRlcmFsKSB7XG4gICAgICBpZiAoaXNGcm9tTGl0ZXJhbCkge1xuICAgICAgICBpZiAoaW5wdXQuY29uc3QgIT09IHNjaGVtYS5jb25zdCkge1xuICAgICAgICAgIGlucHV0ID0gY29uc3RWYWwoYiwgc2NoZW1hKTtcbiAgICAgICAgfVxuICAgICAgfSBlbHNlIGlmIChpbnB1dFRhZ0ZsYWcgJiAyICYmIHNjaGVtYVRhZ0ZsYWcgJiAzMTMyKSB7XG4gICAgICAgIGxldCBpbnB1dFZhciA9IGlucHV0LnYoYik7XG4gICAgICAgIGIuZiA9IHNjaGVtYS5ub1ZhbGlkYXRpb24gPyBcIlwiIDogaW5wdXQuaSArIGA9PT1cImAgKyBzY2hlbWEuY29uc3QgKyBgXCJ8fGAgKyBmYWlsV2l0aEFyZyhiLCBwYXRoLCBpbnB1dCA9PiAoe1xuICAgICAgICAgICAgVEFHOiBcIkludmFsaWRUeXBlXCIsXG4gICAgICAgICAgICBleHBlY3RlZDogc2NoZW1hLFxuICAgICAgICAgICAgcmVjZWl2ZWQ6IGlucHV0XG4gICAgICAgICAgfSksIGlucHV0VmFyKSArIGA7YDtcbiAgICAgICAgaW5wdXQgPSBjb25zdFZhbChiLCBzY2hlbWEpO1xuICAgICAgfSBlbHNlIGlmIChzY2hlbWEubm9WYWxpZGF0aW9uKSB7XG4gICAgICAgIGlucHV0ID0gY29uc3RWYWwoYiwgc2NoZW1hKTtcbiAgICAgIH0gZWxzZSB7XG4gICAgICAgIGIuZiA9IHR5cGVGaWx0ZXJDb2RlKHByZXZCLCBzY2hlbWEsIGlucHV0LCBwYXRoKTtcbiAgICAgICAgaW5wdXQudHlwZSA9IHNjaGVtYS50eXBlO1xuICAgICAgICBpbnB1dC5jb25zdCA9IHNjaGVtYS5jb25zdDtcbiAgICAgIH1cbiAgICB9IGVsc2UgaWYgKGlzRnJvbUxpdGVyYWwgJiYgIWlzU2NoZW1hTGl0ZXJhbCkge1xuICAgICAgaWYgKCFpc1NhbWVUYWcpIHtcbiAgICAgICAgaWYgKHNjaGVtYVRhZ0ZsYWcgJiAyICYmIGlucHV0VGFnRmxhZyAmIDMxMzIpIHtcbiAgICAgICAgICBsZXQgJCRjb25zdCA9IChcIlwiK2lucHV0LmNvbnN0KTtcbiAgICAgICAgICBpbnB1dCA9IHtcbiAgICAgICAgICAgIGI6IGIsXG4gICAgICAgICAgICB2OiBfbm90VmFyLFxuICAgICAgICAgICAgaTogYFwiYCArICQkY29uc3QgKyBgXCJgLFxuICAgICAgICAgICAgZjogMCxcbiAgICAgICAgICAgIHR5cGU6IFwic3RyaW5nXCIsXG4gICAgICAgICAgICBjb25zdDogJCRjb25zdFxuICAgICAgICAgIH07XG4gICAgICAgIH0gZWxzZSB7XG4gICAgICAgICAgaXNVbnN1cHBvcnRlZCA9IHRydWU7XG4gICAgICAgIH1cbiAgICAgIH1cbiAgICB9IGVsc2UgaWYgKGlucHV0VGFnRmxhZyAmIDEpIHtcbiAgICAgIGxldCByZWYgPSBzY2hlbWEuJHJlZjtcbiAgICAgIGlmIChyZWYgIT09IHVuZGVmaW5lZCkge1xuICAgICAgICBsZXQgZGVmcyA9IGIuZy5kO1xuICAgICAgICBsZXQgaWRlbnRpZmllciA9IHJlZi5zbGljZSg4KTtcbiAgICAgICAgbGV0IGRlZiA9IGRlZnNbaWRlbnRpZmllcl07XG4gICAgICAgIGxldCBmbGFnID0gc2NoZW1hLm5vVmFsaWRhdGlvbiA/IChiLmcubyB8IDEpIF4gMSA6IGIuZy5vO1xuICAgICAgICBsZXQgZm4gPSBkZWZbZmxhZ107XG4gICAgICAgIGxldCByZWNPcGVyYXRpb247XG4gICAgICAgIGlmIChmbiAhPT0gdW5kZWZpbmVkKSB7XG4gICAgICAgICAgbGV0IGZuJDEgPSBQcmltaXRpdmVfb3B0aW9uLnZhbEZyb21PcHRpb24oZm4pO1xuICAgICAgICAgIHJlY09wZXJhdGlvbiA9IGZuJDEgPT09IDAgPyBlbWJlZChiLCBkZWYpICsgKGBbYCArIGZsYWcgKyBgXWApIDogZW1iZWQoYiwgZm4kMSk7XG4gICAgICAgIH0gZWxzZSB7XG4gICAgICAgICAgZGVmW2ZsYWddID0gMDtcbiAgICAgICAgICBsZXQgZm4kMiA9IGludGVybmFsQ29tcGlsZShkZWYsIGZsYWcsIGIuZy5kKTtcbiAgICAgICAgICBkZWZbZmxhZ10gPSBmbiQyO1xuICAgICAgICAgIHJlY09wZXJhdGlvbiA9IGVtYmVkKGIsIGZuJDIpO1xuICAgICAgICB9XG4gICAgICAgIGlucHV0ID0gd2l0aFBhdGhQcmVwZW5kKGIsIGlucHV0LCBwYXRoLCB1bmRlZmluZWQsIHVuZGVmaW5lZCwgKHBhcmFtLCBpbnB1dCwgcGFyYW0kMSkgPT4ge1xuICAgICAgICAgIGxldCBvdXRwdXQgPSBtYXAocmVjT3BlcmF0aW9uLCBpbnB1dCk7XG4gICAgICAgICAgaWYgKGRlZi5pc0FzeW5jID09PSB1bmRlZmluZWQpIHtcbiAgICAgICAgICAgIGxldCBkZWZzTXV0ID0gY29weShkZWZzKTtcbiAgICAgICAgICAgIGRlZnNNdXRbaWRlbnRpZmllcl0gPSB1bmtub3duO1xuICAgICAgICAgICAgaXNBc3luY0ludGVybmFsKGRlZiwgZGVmc011dCk7XG4gICAgICAgICAgfVxuICAgICAgICAgIGlmIChkZWYuaXNBc3luYykge1xuICAgICAgICAgICAgb3V0cHV0LmYgPSBvdXRwdXQuZiB8IDI7XG4gICAgICAgICAgfVxuICAgICAgICAgIHJldHVybiBvdXRwdXQ7XG4gICAgICAgIH0pO1xuICAgICAgICBpbnB1dC52KGIpO1xuICAgICAgfSBlbHNlIHtcbiAgICAgICAgaWYgKGIuZy5vICYgMSkge1xuICAgICAgICAgIGIuZiA9IHR5cGVGaWx0ZXJDb2RlKHByZXZCLCBzY2hlbWEsIGlucHV0LCBwYXRoKTtcbiAgICAgICAgfVxuICAgICAgICBsZXQgcmVmaW5lZCA9IG1ha2VSZWZpbmVkT2YoYiwgaW5wdXQsIHNjaGVtYSk7XG4gICAgICAgIGlucHV0LnR5cGUgPSByZWZpbmVkLnR5cGU7XG4gICAgICAgIGlucHV0LmkgPSByZWZpbmVkLmk7XG4gICAgICAgIGlucHV0LnYgPSByZWZpbmVkLnY7XG4gICAgICAgIGlucHV0LmFkZGl0aW9uYWxJdGVtcyA9IHJlZmluZWQuYWRkaXRpb25hbEl0ZW1zO1xuICAgICAgICBpbnB1dC5wcm9wZXJ0aWVzID0gcmVmaW5lZC5wcm9wZXJ0aWVzO1xuICAgICAgICBpZiAoY29uc3RGaWVsZCBpbiByZWZpbmVkKSB7XG4gICAgICAgICAgaW5wdXQuY29uc3QgPSByZWZpbmVkLmNvbnN0O1xuICAgICAgICB9XG4gICAgICB9XG4gICAgfSBlbHNlIGlmIChzY2hlbWFUYWdGbGFnICYgMiAmJiBpbnB1dFRhZ0ZsYWcgJiAxMDM2KSB7XG4gICAgICBpbnB1dCA9IGlucHV0VG9TdHJpbmcoYiwgaW5wdXQpO1xuICAgIH0gZWxzZSBpZiAoIWlzU2FtZVRhZykge1xuICAgICAgaWYgKGlucHV0VGFnRmxhZyAmIDIpIHtcbiAgICAgICAgbGV0IGlucHV0VmFyJDEgPSBpbnB1dC52KGIpO1xuICAgICAgICBpZiAoc2NoZW1hVGFnRmxhZyAmIDgpIHtcbiAgICAgICAgICBsZXQgb3V0cHV0ID0gYWxsb2NhdGVWYWwoYiwgc2NoZW1hKTtcbiAgICAgICAgICBiLmMgPSBiLmMgKyAoYChgICsgb3V0cHV0LmkgKyBgPWAgKyBpbnB1dFZhciQxICsgYD09PVwidHJ1ZVwiKXx8YCArIGlucHV0VmFyJDEgKyBgPT09XCJmYWxzZVwifHxgICsgZmFpbFdpdGhBcmcoYiwgcGF0aCwgaW5wdXQgPT4gKHtcbiAgICAgICAgICAgIFRBRzogXCJJbnZhbGlkVHlwZVwiLFxuICAgICAgICAgICAgZXhwZWN0ZWQ6IHNjaGVtYSxcbiAgICAgICAgICAgIHJlY2VpdmVkOiBpbnB1dFxuICAgICAgICAgIH0pLCBpbnB1dFZhciQxKSArIGA7YCk7XG4gICAgICAgICAgaW5wdXQgPSBvdXRwdXQ7XG4gICAgICAgIH0gZWxzZSBpZiAoc2NoZW1hVGFnRmxhZyAmIDQpIHtcbiAgICAgICAgICBsZXQgb3V0cHV0JDEgPSB2YWwoYiwgYCtgICsgaW5wdXRWYXIkMSwgc2NoZW1hKTtcbiAgICAgICAgICBsZXQgb3V0cHV0VmFyID0gb3V0cHV0JDEudihiKTtcbiAgICAgICAgICBsZXQgbWF0Y2ggPSBzY2hlbWEuZm9ybWF0O1xuICAgICAgICAgIGIuYyA9IGIuYyArIChcbiAgICAgICAgICAgIG1hdGNoICE9PSB1bmRlZmluZWQgPyBgKGAgKyByZWZpbmVtZW50KGIsIG91dHB1dFZhciwgc2NoZW1hLCB0cnVlKS5zbGljZSgyKSArIGApYCA6IGBOdW1iZXIuaXNOYU4oYCArIG91dHB1dFZhciArIGApYFxuICAgICAgICAgICkgKyAoYCYmYCArIGZhaWxXaXRoQXJnKGIsIHBhdGgsIGlucHV0ID0+ICh7XG4gICAgICAgICAgICBUQUc6IFwiSW52YWxpZFR5cGVcIixcbiAgICAgICAgICAgIGV4cGVjdGVkOiBzY2hlbWEsXG4gICAgICAgICAgICByZWNlaXZlZDogaW5wdXRcbiAgICAgICAgICB9KSwgaW5wdXRWYXIkMSkgKyBgO2ApO1xuICAgICAgICAgIGlucHV0ID0gb3V0cHV0JDE7XG4gICAgICAgIH0gZWxzZSBpZiAoc2NoZW1hVGFnRmxhZyAmIDEwMjQpIHtcbiAgICAgICAgICBsZXQgb3V0cHV0JDIgPSBhbGxvY2F0ZVZhbChiLCBzY2hlbWEpO1xuICAgICAgICAgIGIuYyA9IGIuYyArIChgdHJ5e2AgKyBvdXRwdXQkMi5pICsgYD1CaWdJbnQoYCArIGlucHV0VmFyJDEgKyBgKX1jYXRjaChfKXtgICsgZmFpbFdpdGhBcmcoYiwgcGF0aCwgaW5wdXQgPT4gKHtcbiAgICAgICAgICAgIFRBRzogXCJJbnZhbGlkVHlwZVwiLFxuICAgICAgICAgICAgZXhwZWN0ZWQ6IHNjaGVtYSxcbiAgICAgICAgICAgIHJlY2VpdmVkOiBpbnB1dFxuICAgICAgICAgIH0pLCBpbnB1dFZhciQxKSArIGB9YCk7XG4gICAgICAgICAgaW5wdXQgPSBvdXRwdXQkMjtcbiAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICBpc1Vuc3VwcG9ydGVkID0gdHJ1ZTtcbiAgICAgICAgfVxuICAgICAgfSBlbHNlIGlmIChpbnB1dFRhZ0ZsYWcgJiA0ICYmIHNjaGVtYVRhZ0ZsYWcgJiAxMDI0KSB7XG4gICAgICAgIGlucHV0ID0gdmFsKGIsIGBCaWdJbnQoYCArIGlucHV0LmkgKyBgKWAsIHNjaGVtYSk7XG4gICAgICB9IGVsc2Uge1xuICAgICAgICBpc1Vuc3VwcG9ydGVkID0gdHJ1ZTtcbiAgICAgIH1cbiAgICB9XG4gIH1cbiAgaWYgKGlzVW5zdXBwb3J0ZWQpIHtcbiAgICB1bnN1cHBvcnRlZFRyYW5zZm9ybShiLCBpbnB1dCwgc2NoZW1hLCBwYXRoKTtcbiAgfVxuICBsZXQgY29tcGlsZXIgPSBzY2hlbWEuY29tcGlsZXI7XG4gIGlmIChjb21waWxlciAhPT0gdW5kZWZpbmVkKSB7XG4gICAgaW5wdXQgPSBjb21waWxlcihiLCBpbnB1dCwgc2NoZW1hLCBwYXRoKTtcbiAgfVxuICBpZiAoaW5wdXQudCAhPT0gdHJ1ZSkge1xuICAgIGxldCByZWZpbmVyID0gc2NoZW1hLnJlZmluZXI7XG4gICAgaWYgKHJlZmluZXIgIT09IHVuZGVmaW5lZCkge1xuICAgICAgYi5jID0gYi5jICsgcmVmaW5lcihiLCBpbnB1dC52KGIpLCBzY2hlbWEsIHBhdGgpO1xuICAgIH1cbiAgfVxuICBsZXQgdG8gPSBzY2hlbWEudG87XG4gIGlmICh0byAhPT0gdW5kZWZpbmVkKSB7XG4gICAgbGV0IHBhcnNlciA9IHNjaGVtYS5wYXJzZXI7XG4gICAgaWYgKHBhcnNlciAhPT0gdW5kZWZpbmVkKSB7XG4gICAgICBpbnB1dCA9IHBhcnNlcihiLCBpbnB1dCwgc2NoZW1hLCBwYXRoKTtcbiAgICB9XG4gICAgaWYgKGlucHV0LnQgIT09IHRydWUpIHtcbiAgICAgIGlucHV0ID0gcGFyc2UoYiwgdG8sIGlucHV0LCBwYXRoKTtcbiAgICB9XG4gIH1cbiAgcHJldkIuYyA9IHByZXZCLmMgKyBhbGxvY2F0ZVNjb3BlKGIpO1xuICByZXR1cm4gaW5wdXQ7XG59XG5cbmZ1bmN0aW9uIGlzQXN5bmNJbnRlcm5hbChzY2hlbWEsIGRlZnMpIHtcbiAgdHJ5IHtcbiAgICBsZXQgYiA9IHJvb3RTY29wZSgyLCBkZWZzKTtcbiAgICBsZXQgaW5wdXQgPSB7XG4gICAgICBiOiBiLFxuICAgICAgdjogX3ZhcixcbiAgICAgIGk6IFwiaVwiLFxuICAgICAgZjogMCxcbiAgICAgIHR5cGU6IFwidW5rbm93blwiXG4gICAgfTtcbiAgICBsZXQgb3V0cHV0ID0gcGFyc2UoYiwgc2NoZW1hLCBpbnB1dCwgXCJcIik7XG4gICAgbGV0IGlzQXN5bmMgPSBoYXMob3V0cHV0LmYsIDIpO1xuICAgIHNjaGVtYS5pc0FzeW5jID0gaXNBc3luYztcbiAgICByZXR1cm4gaXNBc3luYztcbiAgfSBjYXRjaCAoZXhuKSB7XG4gICAgZ2V0T3JSZXRocm93KGV4bik7XG4gICAgcmV0dXJuIGZhbHNlO1xuICB9XG59XG5cbmZ1bmN0aW9uIGludGVybmFsQ29tcGlsZShzY2hlbWEsIGZsYWcsIGRlZnMpIHtcbiAgbGV0IGIgPSByb290U2NvcGUoZmxhZywgZGVmcyk7XG4gIGlmIChmbGFnICYgOCkge1xuICAgIGxldCBvdXRwdXQgPSByZXZlcnNlKHNjaGVtYSk7XG4gICAganNvbmFibGVWYWxpZGF0aW9uKG91dHB1dCwgb3V0cHV0LCBcIlwiLCBmbGFnKTtcbiAgfVxuICBsZXQgaW5wdXQgPSB7XG4gICAgYjogYixcbiAgICB2OiBfdmFyLFxuICAgIGk6IFwiaVwiLFxuICAgIGY6IDAsXG4gICAgdHlwZTogXCJ1bmtub3duXCJcbiAgfTtcbiAgbGV0IHNjaGVtYSQxID0gZmxhZyAmIDQgPyB1cGRhdGVPdXRwdXQoc2NoZW1hLCBtdXQgPT4ge1xuICAgICAgbGV0IHQgPSBuZXcgU2NoZW1hKHVuaXQudHlwZSk7XG4gICAgICB0LmNvbnN0ID0gdW5pdC5jb25zdDtcbiAgICAgIHQubm9WYWxpZGF0aW9uID0gdHJ1ZTtcbiAgICAgIG11dC50byA9IHQ7XG4gICAgfSkgOiAoXG4gICAgICBmbGFnICYgMTYgPyB1cGRhdGVPdXRwdXQoc2NoZW1hLCBtdXQgPT4ge1xuICAgICAgICAgIG11dC50byA9IGpzb25TdHJpbmc7XG4gICAgICAgIH0pIDogc2NoZW1hXG4gICAgKTtcbiAgbGV0IG91dHB1dCQxID0gcGFyc2UoYiwgc2NoZW1hJDEsIGlucHV0LCBcIlwiKTtcbiAgbGV0IGNvZGUgPSBhbGxvY2F0ZVNjb3BlKGIpO1xuICBsZXQgaXNBc3luYyA9IGhhcyhvdXRwdXQkMS5mLCAyKTtcbiAgc2NoZW1hJDEuaXNBc3luYyA9IGlzQXN5bmM7XG4gIGlmIChjb2RlID09PSBcIlwiICYmIG91dHB1dCQxID09PSBpbnB1dCAmJiAhKGZsYWcgJiAyKSkge1xuICAgIHJldHVybiBub29wT3BlcmF0aW9uO1xuICB9XG4gIGxldCBpbmxpbmVkT3V0cHV0ID0gb3V0cHV0JDEuaTtcbiAgaWYgKGZsYWcgJiAyICYmICFpc0FzeW5jICYmICFkZWZzKSB7XG4gICAgaW5saW5lZE91dHB1dCA9IGBQcm9taXNlLnJlc29sdmUoYCArIGlubGluZWRPdXRwdXQgKyBgKWA7XG4gIH1cbiAgbGV0IGlubGluZWRGdW5jdGlvbiA9IFwiaVwiICsgYD0+e2AgKyBjb2RlICsgYHJldHVybiBgICsgaW5saW5lZE91dHB1dCArIGB9YDtcbiAgbGV0IGN0eFZhclZhbHVlMSA9IGIuZy5lO1xuICByZXR1cm4gbmV3IEZ1bmN0aW9uKFwiZVwiLCBcInNcIiwgYHJldHVybiBgICsgaW5saW5lZEZ1bmN0aW9uKShjdHhWYXJWYWx1ZTEsIHMpO1xufVxuXG5mdW5jdGlvbiByZXZlcnNlKHNjaGVtYSkge1xuICBsZXQgcmV2ZXJzZWRIZWFkO1xuICBsZXQgY3VycmVudCA9IHNjaGVtYTtcbiAgd2hpbGUgKGN1cnJlbnQpIHtcbiAgICBsZXQgbXV0ID0gY29weVdpdGhvdXRDYWNoZShjdXJyZW50KTtcbiAgICBsZXQgbmV4dCA9IG11dC50bztcbiAgICBsZXQgdG8gPSByZXZlcnNlZEhlYWQ7XG4gICAgaWYgKHRvICE9PSB1bmRlZmluZWQpIHtcbiAgICAgIG11dC50byA9IHRvO1xuICAgIH0gZWxzZSB7XG4gICAgICAoKGRlbGV0ZSBtdXQudG8pKTtcbiAgICB9XG4gICAgbGV0IHBhcnNlciA9IG11dC5wYXJzZXI7XG4gICAgbGV0IHNlcmlhbGl6ZXIgPSBtdXQuc2VyaWFsaXplcjtcbiAgICBpZiAoc2VyaWFsaXplciAhPT0gdW5kZWZpbmVkKSB7XG4gICAgICBtdXQucGFyc2VyID0gc2VyaWFsaXplcjtcbiAgICB9IGVsc2Uge1xuICAgICAgKChkZWxldGUgbXV0LnBhcnNlcikpO1xuICAgIH1cbiAgICBpZiAocGFyc2VyICE9PSB1bmRlZmluZWQpIHtcbiAgICAgIG11dC5zZXJpYWxpemVyID0gcGFyc2VyO1xuICAgIH0gZWxzZSB7XG4gICAgICAoKGRlbGV0ZSBtdXQuc2VyaWFsaXplcikpO1xuICAgIH1cbiAgICBsZXQgZnJvbURlZmF1bHQgPSBtdXQuZnJvbURlZmF1bHQ7XG4gICAgbGV0ICQkZGVmYXVsdCA9IG11dC5kZWZhdWx0O1xuICAgIGlmICgkJGRlZmF1bHQgIT09IHVuZGVmaW5lZCkge1xuICAgICAgbXV0LmZyb21EZWZhdWx0ID0gJCRkZWZhdWx0O1xuICAgIH0gZWxzZSB7XG4gICAgICAoKGRlbGV0ZSBtdXQuZnJvbURlZmF1bHQpKTtcbiAgICB9XG4gICAgaWYgKGZyb21EZWZhdWx0ICE9PSB1bmRlZmluZWQpIHtcbiAgICAgIG11dC5kZWZhdWx0ID0gZnJvbURlZmF1bHQ7XG4gICAgfSBlbHNlIHtcbiAgICAgICgoZGVsZXRlIG11dC5kZWZhdWx0KSk7XG4gICAgfVxuICAgIGxldCBpdGVtcyA9IG11dC5pdGVtcztcbiAgICBpZiAoaXRlbXMgIT09IHVuZGVmaW5lZCkge1xuICAgICAgbGV0IHByb3BlcnRpZXMgPSB7fTtcbiAgICAgIGxldCBuZXdJdGVtcyA9IG5ldyBBcnJheShpdGVtcy5sZW5ndGgpO1xuICAgICAgZm9yIChsZXQgaWR4ID0gMCwgaWR4X2ZpbmlzaCA9IGl0ZW1zLmxlbmd0aDsgaWR4IDwgaWR4X2ZpbmlzaDsgKytpZHgpIHtcbiAgICAgICAgbGV0IGl0ZW0gPSBpdGVtc1tpZHhdO1xuICAgICAgICBsZXQgcmV2ZXJzZWRfc2NoZW1hID0gcmV2ZXJzZShpdGVtLnNjaGVtYSk7XG4gICAgICAgIGxldCByZXZlcnNlZF9sb2NhdGlvbiA9IGl0ZW0ubG9jYXRpb247XG4gICAgICAgIGxldCByZXZlcnNlZCA9IHtcbiAgICAgICAgICBzY2hlbWE6IHJldmVyc2VkX3NjaGVtYSxcbiAgICAgICAgICBsb2NhdGlvbjogcmV2ZXJzZWRfbG9jYXRpb25cbiAgICAgICAgfTtcbiAgICAgICAgaWYgKGl0ZW0ucikge1xuICAgICAgICAgIHJldmVyc2VkLnIgPSBpdGVtLnI7XG4gICAgICAgIH1cbiAgICAgICAgcHJvcGVydGllc1tpdGVtLmxvY2F0aW9uXSA9IHJldmVyc2VkX3NjaGVtYTtcbiAgICAgICAgbmV3SXRlbXNbaWR4XSA9IHJldmVyc2VkO1xuICAgICAgfVxuICAgICAgbXV0Lml0ZW1zID0gbmV3SXRlbXM7XG4gICAgICBsZXQgbWF0Y2ggPSBtdXQucHJvcGVydGllcztcbiAgICAgIGlmIChtYXRjaCAhPT0gdW5kZWZpbmVkKSB7XG4gICAgICAgIG11dC5wcm9wZXJ0aWVzID0gcHJvcGVydGllcztcbiAgICAgIH1cbiAgICB9XG4gICAgaWYgKHR5cGVvZiBtdXQuYWRkaXRpb25hbEl0ZW1zID09PSBcIm9iamVjdFwiKSB7XG4gICAgICBtdXQuYWRkaXRpb25hbEl0ZW1zID0gcmV2ZXJzZShtdXQuYWRkaXRpb25hbEl0ZW1zKTtcbiAgICB9XG4gICAgbGV0IGFueU9mID0gbXV0LmFueU9mO1xuICAgIGlmIChhbnlPZiAhPT0gdW5kZWZpbmVkKSB7XG4gICAgICBsZXQgaGFzID0ge307XG4gICAgICBsZXQgbmV3QW55T2YgPSBbXTtcbiAgICAgIGZvciAobGV0IGlkeCQxID0gMCwgaWR4X2ZpbmlzaCQxID0gYW55T2YubGVuZ3RoOyBpZHgkMSA8IGlkeF9maW5pc2gkMTsgKytpZHgkMSkge1xuICAgICAgICBsZXQgcyA9IGFueU9mW2lkeCQxXTtcbiAgICAgICAgbGV0IHJldmVyc2VkJDEgPSByZXZlcnNlKHMpO1xuICAgICAgICBuZXdBbnlPZi5wdXNoKHJldmVyc2VkJDEpO1xuICAgICAgICBzZXRIYXMoaGFzLCByZXZlcnNlZCQxLnR5cGUpO1xuICAgICAgfVxuICAgICAgbXV0LmhhcyA9IGhhcztcbiAgICAgIG11dC5hbnlPZiA9IG5ld0FueU9mO1xuICAgIH1cbiAgICBsZXQgZGVmcyA9IG11dC4kZGVmcztcbiAgICBpZiAoZGVmcyAhPT0gdW5kZWZpbmVkKSB7XG4gICAgICBsZXQgcmV2ZXJzZWREZWZzID0ge307XG4gICAgICBmb3IgKGxldCBpZHgkMiA9IDAsIGlkeF9maW5pc2gkMiA9IE9iamVjdC5rZXlzKGRlZnMpLmxlbmd0aDsgaWR4JDIgPCBpZHhfZmluaXNoJDI7ICsraWR4JDIpIHtcbiAgICAgICAgbGV0IGtleSA9IE9iamVjdC5rZXlzKGRlZnMpW2lkeCQyXTtcbiAgICAgICAgcmV2ZXJzZWREZWZzW2tleV0gPSByZXZlcnNlKGRlZnNba2V5XSk7XG4gICAgICB9XG4gICAgICBtdXQuJGRlZnMgPSByZXZlcnNlZERlZnM7XG4gICAgfVxuICAgIHJldmVyc2VkSGVhZCA9IG11dDtcbiAgICBjdXJyZW50ID0gbmV4dDtcbiAgfTtcbiAgcmV0dXJuIHJldmVyc2VkSGVhZDtcbn1cblxuZnVuY3Rpb24ganNvbmFibGVWYWxpZGF0aW9uKG91dHB1dCwgcGFyZW50LCBwYXRoLCBmbGFnKSB7XG4gIGxldCB0YWdGbGFnID0gZmxhZ3Nbb3V0cHV0LnR5cGVdO1xuICBpZiAodGFnRmxhZyAmIDQ4MTI5IHx8IHRhZ0ZsYWcgJiAxNiAmJiBwYXJlbnQudHlwZSAhPT0gXCJvYmplY3RcIikge1xuICAgIHRocm93IG5ldyBTdXJ5RXJyb3Ioe1xuICAgICAgVEFHOiBcIkludmFsaWRKc29uU2NoZW1hXCIsXG4gICAgICBfMDogcGFyZW50XG4gICAgfSwgZmxhZywgcGF0aCk7XG4gIH1cbiAgaWYgKHRhZ0ZsYWcgJiAyNTYpIHtcbiAgICBvdXRwdXQuYW55T2YuZm9yRWFjaChzID0+IGpzb25hYmxlVmFsaWRhdGlvbihzLCBwYXJlbnQsIHBhdGgsIGZsYWcpKTtcbiAgICByZXR1cm47XG4gIH1cbiAgaWYgKCEodGFnRmxhZyAmIDE5MikpIHtcbiAgICByZXR1cm47XG4gIH1cbiAgbGV0IGFkZGl0aW9uYWxJdGVtcyA9IG91dHB1dC5hZGRpdGlvbmFsSXRlbXM7XG4gIGlmIChhZGRpdGlvbmFsSXRlbXMgPT09IFwic3RyaXBcIiB8fCBhZGRpdGlvbmFsSXRlbXMgPT09IFwic3RyaWN0XCIpIHtcbiAgICBhZGRpdGlvbmFsSXRlbXMgPT09IFwic3RyaXBcIjtcbiAgfSBlbHNlIHtcbiAgICBqc29uYWJsZVZhbGlkYXRpb24oYWRkaXRpb25hbEl0ZW1zLCBwYXJlbnQsIHBhdGgsIGZsYWcpO1xuICB9XG4gIGxldCBwID0gb3V0cHV0LnByb3BlcnRpZXM7XG4gIGlmIChwICE9PSB1bmRlZmluZWQpIHtcbiAgICBsZXQga2V5cyA9IE9iamVjdC5rZXlzKHApO1xuICAgIGZvciAobGV0IGlkeCA9IDAsIGlkeF9maW5pc2ggPSBrZXlzLmxlbmd0aDsgaWR4IDwgaWR4X2ZpbmlzaDsgKytpZHgpIHtcbiAgICAgIGxldCBrZXkgPSBrZXlzW2lkeF07XG4gICAgICBqc29uYWJsZVZhbGlkYXRpb24ocFtrZXldLCBwYXJlbnQsIHBhdGgsIGZsYWcpO1xuICAgIH1cbiAgICByZXR1cm47XG4gIH1cbiAgb3V0cHV0Lml0ZW1zLmZvckVhY2goaXRlbSA9PiBqc29uYWJsZVZhbGlkYXRpb24oaXRlbS5zY2hlbWEsIG91dHB1dCwgcGF0aCArIChgW2AgKyBmcm9tU3RyaW5nKGl0ZW0ubG9jYXRpb24pICsgYF1gKSwgZmxhZykpO1xufVxuXG5mdW5jdGlvbiBnZXRPdXRwdXRTY2hlbWEoX3NjaGVtYSkge1xuICB3aGlsZSAodHJ1ZSkge1xuICAgIGxldCBzY2hlbWEgPSBfc2NoZW1hO1xuICAgIGxldCB0byA9IHNjaGVtYS50bztcbiAgICBpZiAodG8gPT09IHVuZGVmaW5lZCkge1xuICAgICAgcmV0dXJuIHNjaGVtYTtcbiAgICB9XG4gICAgX3NjaGVtYSA9IHRvO1xuICAgIGNvbnRpbnVlO1xuICB9O1xufVxuXG5mdW5jdGlvbiBvcGVyYXRpb25GbihzLCBvKSB7XG4gIGlmICgobyBpbiBzKSkge1xuICAgIHJldHVybiAoc1tvXSk7XG4gIH1cbiAgbGV0IGYgPSBpbnRlcm5hbENvbXBpbGUobyAmIDMyID8gcmV2ZXJzZShzKSA6IHMsIG8sIDApO1xuICAoKHNbb10gPSBmKSk7XG4gIHJldHVybiBmO1xufVxuXG5kKHNwLCBcIn5zdGFuZGFyZFwiLCB7XG4gIGdldDogZnVuY3Rpb24gKCkge1xuICAgIGxldCBzY2hlbWEgPSB0aGlzO1xuICAgIHJldHVybiB7XG4gICAgICB2ZXJzaW9uOiAxLFxuICAgICAgdmVuZG9yOiB2ZW5kb3IsXG4gICAgICB2YWxpZGF0ZTogaW5wdXQgPT4ge1xuICAgICAgICB0cnkge1xuICAgICAgICAgIHJldHVybiB7XG4gICAgICAgICAgICB2YWx1ZTogb3BlcmF0aW9uRm4oc2NoZW1hLCAxKShpbnB1dClcbiAgICAgICAgICB9O1xuICAgICAgICB9IGNhdGNoIChleG4pIHtcbiAgICAgICAgICBsZXQgZXJyb3IgPSBnZXRPclJldGhyb3coZXhuKTtcbiAgICAgICAgICByZXR1cm4ge1xuICAgICAgICAgICAgaXNzdWVzOiBbe1xuICAgICAgICAgICAgICAgIG1lc3NhZ2U6IHJlYXNvbihlcnJvciwgdW5kZWZpbmVkKSxcbiAgICAgICAgICAgICAgICBwYXRoOiBlcnJvci5wYXRoID09PSBcIlwiID8gdW5kZWZpbmVkIDogdG9BcnJheShlcnJvci5wYXRoKVxuICAgICAgICAgICAgICB9XVxuICAgICAgICAgIH07XG4gICAgICAgIH1cbiAgICAgIH1cbiAgICB9O1xuICB9XG59KTtcblxuZnVuY3Rpb24gY29tcGlsZShzY2hlbWEsIGlucHV0LCBvdXRwdXQsIG1vZGUsIHR5cGVWYWxpZGF0aW9uT3B0KSB7XG4gIGxldCB0eXBlVmFsaWRhdGlvbiA9IHR5cGVWYWxpZGF0aW9uT3B0ICE9PSB1bmRlZmluZWQgPyB0eXBlVmFsaWRhdGlvbk9wdCA6IHRydWU7XG4gIGxldCBmbGFnID0gMDtcbiAgbGV0IGV4aXQgPSAwO1xuICBzd2l0Y2ggKG91dHB1dCkge1xuICAgIGNhc2UgXCJPdXRwdXRcIiA6XG4gICAgY2FzZSBcIklucHV0XCIgOlxuICAgICAgZXhpdCA9IDE7XG4gICAgICBicmVhaztcbiAgICBjYXNlIFwiQXNzZXJ0XCIgOlxuICAgICAgZmxhZyA9IGZsYWcgfCA0O1xuICAgICAgYnJlYWs7XG4gICAgY2FzZSBcIkpzb25cIiA6XG4gICAgICBmbGFnID0gZmxhZyB8IDg7XG4gICAgICBicmVhaztcbiAgICBjYXNlIFwiSnNvblN0cmluZ1wiIDpcbiAgICAgIGZsYWcgPSBmbGFnIHwgMjQ7XG4gICAgICBicmVhaztcbiAgfVxuICBpZiAoZXhpdCA9PT0gMSAmJiBvdXRwdXQgPT09IGlucHV0KSB7XG4gICAgdGhyb3cgbmV3IEVycm9yKGBbU3VyeV0gQ2FuJ3QgY29tcGlsZSBvcGVyYXRpb24gdG8gY29udmVydGluZyB2YWx1ZSB0byBzZWxmYCk7XG4gIH1cbiAgaWYgKG1vZGUgIT09IFwiU3luY1wiKSB7XG4gICAgZmxhZyA9IGZsYWcgfCAyO1xuICB9XG4gIGlmICh0eXBlVmFsaWRhdGlvbikge1xuICAgIGZsYWcgPSBmbGFnIHwgMTtcbiAgfVxuICBpZiAoaW5wdXQgPT09IFwiT3V0cHV0XCIpIHtcbiAgICBmbGFnID0gZmxhZyB8IDMyO1xuICB9XG4gIGxldCBmbiA9IG9wZXJhdGlvbkZuKHNjaGVtYSwgZmxhZyk7XG4gIGlmIChpbnB1dCAhPT0gXCJKc29uU3RyaW5nXCIpIHtcbiAgICByZXR1cm4gZm47XG4gIH1cbiAgbGV0IGZsYWckMSA9IGZsYWc7XG4gIHJldHVybiBqc29uU3RyaW5nID0+IHtcbiAgICB0cnkge1xuICAgICAgcmV0dXJuIGZuKEpTT04ucGFyc2UoanNvblN0cmluZykpO1xuICAgIH0gY2F0Y2ggKGV4bikge1xuICAgICAgdGhyb3cgbmV3IFN1cnlFcnJvcih7XG4gICAgICAgIFRBRzogXCJPcGVyYXRpb25GYWlsZWRcIixcbiAgICAgICAgXzA6IGV4bi5tZXNzYWdlXG4gICAgICB9LCBmbGFnJDEsIFwiXCIpO1xuICAgIH1cbiAgfTtcbn1cblxuZnVuY3Rpb24gcGFyc2VPclRocm93KGFueSwgc2NoZW1hKSB7XG4gIHJldHVybiBvcGVyYXRpb25GbihzY2hlbWEsIDEpKGFueSk7XG59XG5cbmZ1bmN0aW9uIHBhcnNlSnNvblN0cmluZ09yVGhyb3coanNvblN0cmluZywgc2NoZW1hKSB7XG4gIGxldCB0bXA7XG4gIHRyeSB7XG4gICAgdG1wID0gSlNPTi5wYXJzZShqc29uU3RyaW5nKTtcbiAgfSBjYXRjaCAoZXhuKSB7XG4gICAgdGhyb3cgbmV3IFN1cnlFcnJvcih7XG4gICAgICBUQUc6IFwiT3BlcmF0aW9uRmFpbGVkXCIsXG4gICAgICBfMDogZXhuLm1lc3NhZ2VcbiAgICB9LCAxLCBcIlwiKTtcbiAgfVxuICByZXR1cm4gcGFyc2VPclRocm93KHRtcCwgc2NoZW1hKTtcbn1cblxuZnVuY3Rpb24gcGFyc2VBc3luY09yVGhyb3coYW55LCBzY2hlbWEpIHtcbiAgcmV0dXJuIG9wZXJhdGlvbkZuKHNjaGVtYSwgMykoYW55KTtcbn1cblxuZnVuY3Rpb24gY29udmVydE9yVGhyb3coaW5wdXQsIHNjaGVtYSkge1xuICByZXR1cm4gb3BlcmF0aW9uRm4oc2NoZW1hLCAwKShpbnB1dCk7XG59XG5cbmZ1bmN0aW9uIGNvbnZlcnRUb0pzb25PclRocm93KGFueSwgc2NoZW1hKSB7XG4gIHJldHVybiBvcGVyYXRpb25GbihzY2hlbWEsIDgpKGFueSk7XG59XG5cbmZ1bmN0aW9uIGNvbnZlcnRUb0pzb25TdHJpbmdPclRocm93KGlucHV0LCBzY2hlbWEpIHtcbiAgcmV0dXJuIG9wZXJhdGlvbkZuKHNjaGVtYSwgMjQpKGlucHV0KTtcbn1cblxuZnVuY3Rpb24gY29udmVydEFzeW5jT3JUaHJvdyhhbnksIHNjaGVtYSkge1xuICByZXR1cm4gb3BlcmF0aW9uRm4oc2NoZW1hLCAyKShhbnkpO1xufVxuXG5mdW5jdGlvbiByZXZlcnNlQ29udmVydE9yVGhyb3codmFsdWUsIHNjaGVtYSkge1xuICByZXR1cm4gb3BlcmF0aW9uRm4oc2NoZW1hLCAzMikodmFsdWUpO1xufVxuXG5mdW5jdGlvbiByZXZlcnNlQ29udmVydFRvSnNvbk9yVGhyb3codmFsdWUsIHNjaGVtYSkge1xuICByZXR1cm4gb3BlcmF0aW9uRm4oc2NoZW1hLCA0MCkodmFsdWUpO1xufVxuXG5mdW5jdGlvbiByZXZlcnNlQ29udmVydFRvSnNvblN0cmluZ09yVGhyb3codmFsdWUsIHNjaGVtYSwgc3BhY2VPcHQpIHtcbiAgbGV0IHNwYWNlID0gc3BhY2VPcHQgIT09IHVuZGVmaW5lZCA/IHNwYWNlT3B0IDogMDtcbiAgcmV0dXJuIEpTT04uc3RyaW5naWZ5KHJldmVyc2VDb252ZXJ0VG9Kc29uT3JUaHJvdyh2YWx1ZSwgc2NoZW1hKSwgbnVsbCwgc3BhY2UpO1xufVxuXG5mdW5jdGlvbiBhc3NlcnRPclRocm93KGFueSwgc2NoZW1hKSB7XG4gIHJldHVybiBvcGVyYXRpb25GbihzY2hlbWEsIDUpKGFueSk7XG59XG5cbmxldCAkJG51bGwgPSBuZXcgU2NoZW1hKFwibnVsbFwiKTtcblxuJCRudWxsLmNvbnN0ID0gbnVsbDtcblxuZnVuY3Rpb24gcGFyc2UkMSh2YWx1ZSkge1xuICBpZiAodmFsdWUgPT09IG51bGwpIHtcbiAgICByZXR1cm4gJCRudWxsO1xuICB9XG4gIGxldCAkJHR5cGVvZiA9IHR5cGVvZiB2YWx1ZTtcbiAgbGV0IHNjaGVtYTtcbiAgaWYgKCQkdHlwZW9mID09PSBcIm9iamVjdFwiKSB7XG4gICAgbGV0IGkgPSBuZXcgU2NoZW1hKFwiaW5zdGFuY2VcIik7XG4gICAgaS5jbGFzcyA9IHZhbHVlLmNvbnN0cnVjdG9yO1xuICAgIHNjaGVtYSA9IGk7XG4gIH0gZWxzZSB7XG4gICAgc2NoZW1hID0gJCR0eXBlb2YgPT09IFwidW5kZWZpbmVkXCIgPyB1bml0IDogKFxuICAgICAgICAkJHR5cGVvZiA9PT0gXCJudW1iZXJcIiA/IChcbiAgICAgICAgICAgIE51bWJlci5pc05hTih2YWx1ZSkgPyBuZXcgU2NoZW1hKFwibmFuXCIpIDogbmV3IFNjaGVtYSgkJHR5cGVvZilcbiAgICAgICAgICApIDogbmV3IFNjaGVtYSgkJHR5cGVvZilcbiAgICAgICk7XG4gIH1cbiAgc2NoZW1hLmNvbnN0ID0gdmFsdWU7XG4gIHJldHVybiBzY2hlbWE7XG59XG5cbmZ1bmN0aW9uIGlzQXN5bmMoc2NoZW1hKSB7XG4gIGxldCB2ID0gc2NoZW1hLmlzQXN5bmM7XG4gIGlmICh2ICE9PSB1bmRlZmluZWQpIHtcbiAgICByZXR1cm4gdjtcbiAgfSBlbHNlIHtcbiAgICByZXR1cm4gaXNBc3luY0ludGVybmFsKHNjaGVtYSwgMCk7XG4gIH1cbn1cblxuZnVuY3Rpb24gd3JhcEV4blRvRmFpbHVyZShleG4pIHtcbiAgaWYgKChleG4mJmV4bi5zPT09cykpIHtcbiAgICByZXR1cm4ge1xuICAgICAgc3VjY2VzczogZmFsc2UsXG4gICAgICBlcnJvcjogZXhuXG4gICAgfTtcbiAgfVxuICB0aHJvdyBleG47XG59XG5cbmZ1bmN0aW9uIGpzX3NhZmUoZm4pIHtcbiAgdHJ5IHtcbiAgICByZXR1cm4ge1xuICAgICAgc3VjY2VzczogdHJ1ZSxcbiAgICAgIHZhbHVlOiBmbigpXG4gICAgfTtcbiAgfSBjYXRjaCAoZXhuKSB7XG4gICAgcmV0dXJuIHdyYXBFeG5Ub0ZhaWx1cmUoZXhuKTtcbiAgfVxufVxuXG5mdW5jdGlvbiBqc19zYWZlQXN5bmMoZm4pIHtcbiAgdHJ5IHtcbiAgICByZXR1cm4gZm4oKS50aGVuKHZhbHVlID0+ICh7XG4gICAgICBzdWNjZXNzOiB0cnVlLFxuICAgICAgdmFsdWU6IHZhbHVlXG4gICAgfSksIHdyYXBFeG5Ub0ZhaWx1cmUpO1xuICB9IGNhdGNoIChleG4pIHtcbiAgICByZXR1cm4gUHJvbWlzZS5yZXNvbHZlKHdyYXBFeG5Ub0ZhaWx1cmUoZXhuKSk7XG4gIH1cbn1cblxuZnVuY3Rpb24gbWFrZSQxKG5hbWVzcGFjZSwgbmFtZSkge1xuICByZXR1cm4gYG06YCArIG5hbWVzcGFjZSArIGA6YCArIG5hbWU7XG59XG5cbmZ1bmN0aW9uIGludGVybmFsKG5hbWUpIHtcbiAgcmV0dXJuIGBtOmAgKyBuYW1lO1xufVxuXG5sZXQgSWQgPSB7XG4gIG1ha2U6IG1ha2UkMSxcbiAgaW50ZXJuYWw6IGludGVybmFsXG59O1xuXG5mdW5jdGlvbiBnZXQkMShzY2hlbWEsIGlkKSB7XG4gIHJldHVybiBzY2hlbWFbaWRdO1xufVxuXG5mdW5jdGlvbiBzZXQkMShzY2hlbWEsIGlkLCBtZXRhZGF0YSkge1xuICBsZXQgbXV0ID0gY29weVdpdGhvdXRDYWNoZShzY2hlbWEpO1xuICBtdXRbaWRdID0gbWV0YWRhdGE7XG4gIHJldHVybiBtdXQ7XG59XG5cbmxldCBkZWZzUGF0aCA9IGAjLyRkZWZzL2A7XG5cbmZ1bmN0aW9uIHJlY3Vyc2l2ZShuYW1lLCBmbikge1xuICBsZXQgcmVmID0gZGVmc1BhdGggKyBuYW1lO1xuICBsZXQgcmVmU2NoZW1hID0gbmV3IFNjaGVtYShcInJlZlwiKTtcbiAgcmVmU2NoZW1hLiRyZWYgPSByZWY7XG4gIHJlZlNjaGVtYS5uYW1lID0gbmFtZTtcbiAgbGV0IGlzTmVzdGVkUmVjID0gZ2xvYmFsQ29uZmlnLmQ7XG4gIGlmICghaXNOZXN0ZWRSZWMpIHtcbiAgICBnbG9iYWxDb25maWcuZCA9IHt9O1xuICB9XG4gIGxldCBkZWYgPSBmbihyZWZTY2hlbWEpO1xuICBpZiAoZGVmLm5hbWUpIHtcbiAgICByZWZTY2hlbWEubmFtZSA9IGRlZi5uYW1lO1xuICB9IGVsc2Uge1xuICAgIGRlZi5uYW1lID0gbmFtZTtcbiAgfVxuICBnbG9iYWxDb25maWcuZFtuYW1lXSA9IGRlZjtcbiAgaWYgKGlzTmVzdGVkUmVjKSB7XG4gICAgcmV0dXJuIHJlZlNjaGVtYTtcbiAgfVxuICBsZXQgc2NoZW1hID0gbmV3IFNjaGVtYShcInJlZlwiKTtcbiAgc2NoZW1hLm5hbWUgPSBkZWYubmFtZTtcbiAgc2NoZW1hLiRyZWYgPSByZWY7XG4gIHNjaGVtYS4kZGVmcyA9IGdsb2JhbENvbmZpZy5kO1xuICBnbG9iYWxDb25maWcuZCA9IHVuZGVmaW5lZDtcbiAgcmV0dXJuIHNjaGVtYTtcbn1cblxuZnVuY3Rpb24gbm9WYWxpZGF0aW9uKHNjaGVtYSwgdmFsdWUpIHtcbiAgbGV0IG11dCA9IGNvcHlXaXRob3V0Q2FjaGUoc2NoZW1hKTtcbiAgbXV0Lm5vVmFsaWRhdGlvbiA9IHZhbHVlO1xuICByZXR1cm4gbXV0O1xufVxuXG5mdW5jdGlvbiBhcHBlbmRSZWZpbmVyKG1heWJlRXhpc3RpbmdSZWZpbmVyLCByZWZpbmVyKSB7XG4gIGlmIChtYXliZUV4aXN0aW5nUmVmaW5lciAhPT0gdW5kZWZpbmVkKSB7XG4gICAgcmV0dXJuIChiLCBpbnB1dFZhciwgc2VsZlNjaGVtYSwgcGF0aCkgPT4gbWF5YmVFeGlzdGluZ1JlZmluZXIoYiwgaW5wdXRWYXIsIHNlbGZTY2hlbWEsIHBhdGgpICsgcmVmaW5lcihiLCBpbnB1dFZhciwgc2VsZlNjaGVtYSwgcGF0aCk7XG4gIH0gZWxzZSB7XG4gICAgcmV0dXJuIHJlZmluZXI7XG4gIH1cbn1cblxuZnVuY3Rpb24gaW50ZXJuYWxSZWZpbmUoc2NoZW1hLCByZWZpbmVyKSB7XG4gIHJldHVybiB1cGRhdGVPdXRwdXQoc2NoZW1hLCBtdXQgPT4ge1xuICAgIG11dC5yZWZpbmVyID0gYXBwZW5kUmVmaW5lcihtdXQucmVmaW5lciwgcmVmaW5lcik7XG4gIH0pO1xufVxuXG5mdW5jdGlvbiByZWZpbmUoc2NoZW1hLCByZWZpbmVyKSB7XG4gIHJldHVybiBpbnRlcm5hbFJlZmluZShzY2hlbWEsIChiLCBpbnB1dFZhciwgc2VsZlNjaGVtYSwgcGF0aCkgPT4gZW1iZWQoYiwgcmVmaW5lcihlZmZlY3RDdHgoYiwgc2VsZlNjaGVtYSwgcGF0aCkpKSArIGAoYCArIGlucHV0VmFyICsgYCk7YCk7XG59XG5cbmZ1bmN0aW9uIGFkZFJlZmluZW1lbnQoc2NoZW1hLCBtZXRhZGF0YUlkLCByZWZpbmVtZW50LCByZWZpbmVyKSB7XG4gIGxldCByZWZpbmVtZW50cyA9IHNjaGVtYVttZXRhZGF0YUlkXTtcbiAgcmV0dXJuIGludGVybmFsUmVmaW5lKHNldCQxKHNjaGVtYSwgbWV0YWRhdGFJZCwgcmVmaW5lbWVudHMgIT09IHVuZGVmaW5lZCA/IHJlZmluZW1lbnRzLmNvbmNhdChyZWZpbmVtZW50KSA6IFtyZWZpbmVtZW50XSksIHJlZmluZXIpO1xufVxuXG5mdW5jdGlvbiB0cmFuc2Zvcm0oc2NoZW1hLCB0cmFuc2Zvcm1lcikge1xuICByZXR1cm4gdXBkYXRlT3V0cHV0KHNjaGVtYSwgbXV0ID0+IHtcbiAgICBtdXQucGFyc2VyID0gKGIsIGlucHV0LCBzZWxmU2NoZW1hLCBwYXRoKSA9PiB7XG4gICAgICBsZXQgbWF0Y2ggPSB0cmFuc2Zvcm1lcihlZmZlY3RDdHgoYiwgc2VsZlNjaGVtYSwgcGF0aCkpO1xuICAgICAgbGV0IHBhcnNlciA9IG1hdGNoLnA7XG4gICAgICBpZiAocGFyc2VyICE9PSB1bmRlZmluZWQpIHtcbiAgICAgICAgaWYgKG1hdGNoLmEgIT09IHVuZGVmaW5lZCkge1xuICAgICAgICAgIHJldHVybiBpbnZhbGlkT3BlcmF0aW9uKGIsIHBhdGgsIGBUaGUgUy50cmFuc2Zvcm0gZG9lc24ndCBhbGxvdyBwYXJzZXIgYW5kIGFzeW5jUGFyc2VyIGF0IHRoZSBzYW1lIHRpbWUuIFJlbW92ZSBwYXJzZXIgaW4gZmF2b3Igb2YgYXN5bmNQYXJzZXJgKTtcbiAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICByZXR1cm4gZW1iZWRTeW5jT3BlcmF0aW9uKGIsIGlucHV0LCBwYXJzZXIpO1xuICAgICAgICB9XG4gICAgICB9XG4gICAgICBsZXQgYXN5bmNQYXJzZXIgPSBtYXRjaC5hO1xuICAgICAgaWYgKGFzeW5jUGFyc2VyICE9PSB1bmRlZmluZWQpIHtcbiAgICAgICAgaWYgKCEoYi5nLm8gJiAyKSkge1xuICAgICAgICAgICQkdGhyb3coYiwgXCJVbmV4cGVjdGVkQXN5bmNcIiwgXCJcIik7XG4gICAgICAgIH1cbiAgICAgICAgbGV0IHZhbCA9IGVtYmVkU3luY09wZXJhdGlvbihiLCBpbnB1dCwgYXN5bmNQYXJzZXIpO1xuICAgICAgICB2YWwuZiA9IHZhbC5mIHwgMjtcbiAgICAgICAgcmV0dXJuIHZhbDtcbiAgICAgIH0gZWxzZSBpZiAobWF0Y2gucyAhPT0gdW5kZWZpbmVkKSB7XG4gICAgICAgIHJldHVybiBpbnZhbGlkT3BlcmF0aW9uKGIsIHBhdGgsIGBUaGUgUy50cmFuc2Zvcm0gcGFyc2VyIGlzIG1pc3NpbmdgKTtcbiAgICAgIH0gZWxzZSB7XG4gICAgICAgIHJldHVybiBpbnB1dDtcbiAgICAgIH1cbiAgICB9O1xuICAgIGxldCB0byA9IG5ldyBTY2hlbWEoXCJ1bmtub3duXCIpO1xuICAgIG11dC50byA9ICh0by5zZXJpYWxpemVyID0gKGIsIGlucHV0LCBzZWxmU2NoZW1hLCBwYXRoKSA9PiB7XG4gICAgICBsZXQgbWF0Y2ggPSB0cmFuc2Zvcm1lcihlZmZlY3RDdHgoYiwgc2VsZlNjaGVtYSwgcGF0aCkpO1xuICAgICAgbGV0IHNlcmlhbGl6ZXIgPSBtYXRjaC5zO1xuICAgICAgaWYgKHNlcmlhbGl6ZXIgIT09IHVuZGVmaW5lZCkge1xuICAgICAgICByZXR1cm4gZW1iZWRTeW5jT3BlcmF0aW9uKGIsIGlucHV0LCBzZXJpYWxpemVyKTtcbiAgICAgIH0gZWxzZSBpZiAobWF0Y2guYSAhPT0gdW5kZWZpbmVkIHx8IG1hdGNoLnAgIT09IHVuZGVmaW5lZCkge1xuICAgICAgICByZXR1cm4gaW52YWxpZE9wZXJhdGlvbihiLCBwYXRoLCBgVGhlIFMudHJhbnNmb3JtIHNlcmlhbGl6ZXIgaXMgbWlzc2luZ2ApO1xuICAgICAgfSBlbHNlIHtcbiAgICAgICAgcmV0dXJuIGlucHV0O1xuICAgICAgfVxuICAgIH0sIHRvKTtcbiAgICAoKGRlbGV0ZSBtdXQuaXNBc3luYykpO1xuICB9KTtcbn1cblxubGV0IG51bGxBc1VuaXQgPSBuZXcgU2NoZW1hKFwibnVsbFwiKTtcblxubnVsbEFzVW5pdC5jb25zdCA9IG51bGw7XG5cbm51bGxBc1VuaXQudG8gPSB1bml0O1xuXG5mdW5jdGlvbiBuZXZlckJ1aWxkZXIoYiwgaW5wdXQsIHNlbGZTY2hlbWEsIHBhdGgpIHtcbiAgYi5jID0gYi5jICsgZmFpbFdpdGhBcmcoYiwgcGF0aCwgaW5wdXQgPT4gKHtcbiAgICBUQUc6IFwiSW52YWxpZFR5cGVcIixcbiAgICBleHBlY3RlZDogc2VsZlNjaGVtYSxcbiAgICByZWNlaXZlZDogaW5wdXRcbiAgfSksIGlucHV0LmkpICsgXCI7XCI7XG4gIHJldHVybiBpbnB1dDtcbn1cblxubGV0IG5ldmVyID0gbmV3IFNjaGVtYShcIm5ldmVyXCIpO1xuXG5uZXZlci5jb21waWxlciA9IG5ldmVyQnVpbGRlcjtcblxubGV0IG5lc3RlZExvYyA9IFwiQlNfUFJJVkFURV9ORVNURURfU09NRV9OT05FXCI7XG5cbmZ1bmN0aW9uIGdldEl0ZW1Db2RlKGIsIHNjaGVtYSwgaW5wdXQsIG91dHB1dCwgZGVvcHQsIHBhdGgpIHtcbiAgdHJ5IHtcbiAgICBsZXQgZ2xvYmFsRmxhZyA9IGIuZy5vO1xuICAgIGlmIChkZW9wdCkge1xuICAgICAgYi5nLm8gPSBnbG9iYWxGbGFnIHwgMTtcbiAgICB9XG4gICAgbGV0IGJiID0ge1xuICAgICAgYzogXCJcIixcbiAgICAgIGw6IFwiXCIsXG4gICAgICBhOiBpbml0aWFsQWxsb2NhdGUsXG4gICAgICBmOiBcIlwiLFxuICAgICAgZzogYi5nXG4gICAgfTtcbiAgICBsZXQgaW5wdXQkMSA9IGRlb3B0ID8gY29weShpbnB1dCkgOiBtYWtlUmVmaW5lZE9mKGJiLCBpbnB1dCwgc2NoZW1hKTtcbiAgICBsZXQgaXRlbU91dHB1dCA9IHBhcnNlKGJiLCBzY2hlbWEsIGlucHV0JDEsIHBhdGgpO1xuICAgIGlmIChpdGVtT3V0cHV0ICE9PSBpbnB1dCQxKSB7XG4gICAgICBpdGVtT3V0cHV0LmIgPSBiYjtcbiAgICAgIGlmIChpdGVtT3V0cHV0LmYgJiAyKSB7XG4gICAgICAgIG91dHB1dC5mID0gb3V0cHV0LmYgfCAyO1xuICAgICAgfVxuICAgICAgYmIuYyA9IGJiLmMgKyAob3V0cHV0LnYoYikgKyBgPWAgKyBpdGVtT3V0cHV0LmkpO1xuICAgIH1cbiAgICBiLmcubyA9IGdsb2JhbEZsYWc7XG4gICAgcmV0dXJuIGFsbG9jYXRlU2NvcGUoYmIpO1xuICB9IGNhdGNoIChleG4pIHtcbiAgICByZXR1cm4gXCJ0aHJvdyBcIiArIGVtYmVkKGIsIGdldE9yUmV0aHJvdyhleG4pKTtcbiAgfVxufVxuXG5mdW5jdGlvbiBpc1ByaW9yaXR5KHRhZ0ZsYWcsIGJ5S2V5KSB7XG4gIGlmICh0YWdGbGFnICYgODMyMCAmJiBcIm9iamVjdFwiIGluIGJ5S2V5KSB7XG4gICAgcmV0dXJuIHRydWU7XG4gIH0gZWxzZSBpZiAodGFnRmxhZyAmIDIwNDgpIHtcbiAgICByZXR1cm4gXCJudW1iZXJcIiBpbiBieUtleTtcbiAgfSBlbHNlIHtcbiAgICByZXR1cm4gZmFsc2U7XG4gIH1cbn1cblxuZnVuY3Rpb24gaXNXaWRlclVuaW9uU2NoZW1hKHNjaGVtYUFueU9mLCBpbnB1dEFueU9mKSB7XG4gIHJldHVybiBpbnB1dEFueU9mLmV2ZXJ5KChpbnB1dFNjaGVtYSwgaWR4KSA9PiB7XG4gICAgbGV0IHNjaGVtYSA9IHNjaGVtYUFueU9mW2lkeF07XG4gICAgaWYgKHNjaGVtYSAhPT0gdW5kZWZpbmVkICYmICEoZmxhZ3NbaW5wdXRTY2hlbWEudHlwZV0gJiA5MTUyKSAmJiBpbnB1dFNjaGVtYS50eXBlID09PSBzY2hlbWEudHlwZSkge1xuICAgICAgcmV0dXJuIGlucHV0U2NoZW1hLmNvbnN0ID09PSBzY2hlbWEuY29uc3Q7XG4gICAgfSBlbHNlIHtcbiAgICAgIHJldHVybiBmYWxzZTtcbiAgICB9XG4gIH0pO1xufVxuXG5mdW5jdGlvbiBjb21waWxlcihiLCBpbnB1dCwgc2VsZlNjaGVtYSwgcGF0aCkge1xuICBsZXQgc2NoZW1hcyA9IHNlbGZTY2hlbWEuYW55T2Y7XG4gIGxldCBpbnB1dEFueU9mID0gaW5wdXQuYW55T2Y7XG4gIGlmIChpbnB1dEFueU9mICE9PSB1bmRlZmluZWQpIHtcbiAgICBpZiAoaXNXaWRlclVuaW9uU2NoZW1hKHNjaGVtYXMsIGlucHV0QW55T2YpKSB7XG4gICAgICByZXR1cm4gaW5wdXQ7XG4gICAgfSBlbHNlIHtcbiAgICAgIHJldHVybiB1bnN1cHBvcnRlZFRyYW5zZm9ybShiLCBpbnB1dCwgc2VsZlNjaGVtYSwgcGF0aCk7XG4gICAgfVxuICB9XG4gIGxldCBmYWlsID0gY2F1Z2h0ID0+IGVtYmVkKGIsIGZ1bmN0aW9uICgpIHtcbiAgICBsZXQgYXJncyA9IGFyZ3VtZW50cztcbiAgICByZXR1cm4gJCR0aHJvdyhiLCB7XG4gICAgICBUQUc6IFwiSW52YWxpZFR5cGVcIixcbiAgICAgIGV4cGVjdGVkOiBzZWxmU2NoZW1hLFxuICAgICAgcmVjZWl2ZWQ6IGFyZ3NbMF0sXG4gICAgICB1bmlvbkVycm9yczogYXJncy5sZW5ndGggPiAxID8gQXJyYXkuZnJvbShhcmdzKS5zbGljZSgxKSA6IHVuZGVmaW5lZFxuICAgIH0sIHBhdGgpO1xuICB9KSArIGAoYCArIGlucHV0LnYoYikgKyBjYXVnaHQgKyBgKWA7XG4gIGxldCB0eXBlVmFsaWRhdGlvbiA9IGIuZy5vICYgMTtcbiAgbGV0IGluaXRpYWxJbmxpbmUgPSBpbnB1dC5pO1xuICBsZXQgZGVvcHRJZHggPSAtMTtcbiAgbGV0IGxhc3RJZHggPSBzY2hlbWFzLmxlbmd0aCAtIDEgfCAwO1xuICBsZXQgYnlLZXkgPSB7fTtcbiAgbGV0IGtleXMgPSBbXTtcbiAgZm9yIChsZXQgaWR4ID0gMDsgaWR4IDw9IGxhc3RJZHg7ICsraWR4KSB7XG4gICAgbGV0IHRhcmdldCA9IHNlbGZTY2hlbWEudG87XG4gICAgbGV0IHNjaGVtYSA9IHRhcmdldCAhPT0gdW5kZWZpbmVkICYmICFzZWxmU2NoZW1hLnBhcnNlciAmJiB0YXJnZXQudHlwZSAhPT0gXCJ1bmlvblwiID8gdXBkYXRlT3V0cHV0KHNjaGVtYXNbaWR4XSwgbXV0ID0+IHtcbiAgICAgICAgbGV0IHJlZmluZXIgPSBzZWxmU2NoZW1hLnJlZmluZXI7XG4gICAgICAgIGlmIChyZWZpbmVyICE9PSB1bmRlZmluZWQpIHtcbiAgICAgICAgICBtdXQucmVmaW5lciA9IGFwcGVuZFJlZmluZXIobXV0LnJlZmluZXIsIHJlZmluZXIpO1xuICAgICAgICB9XG4gICAgICAgIG11dC50byA9IHRhcmdldDtcbiAgICAgIH0pIDogc2NoZW1hc1tpZHhdO1xuICAgIGxldCB0YWcgPSBzY2hlbWEudHlwZTtcbiAgICBsZXQgdGFnRmxhZyA9IGZsYWdzW3RhZ107XG4gICAgaWYgKCEodGFnRmxhZyAmIDE2ICYmIFwiZnJvbURlZmF1bHRcIiBpbiBzZWxmU2NoZW1hKSkge1xuICAgICAgaWYgKHRhZ0ZsYWcgJiAxNzE1MyB8fCAhKGZsYWdzW2lucHV0LnR5cGVdICYgMSkgJiYgaW5wdXQudHlwZSAhPT0gdGFnKSB7XG4gICAgICAgIGRlb3B0SWR4ID0gaWR4O1xuICAgICAgICBieUtleSA9IHt9O1xuICAgICAgICBrZXlzID0gW107XG4gICAgICB9IGVsc2Uge1xuICAgICAgICBsZXQga2V5ID0gdGFnRmxhZyAmIDgxOTIgPyBzY2hlbWEuY2xhc3MubmFtZSA6IHRhZztcbiAgICAgICAgbGV0IGFyciA9IGJ5S2V5W2tleV07XG4gICAgICAgIGlmIChhcnIgIT09IHVuZGVmaW5lZCkge1xuICAgICAgICAgIGlmICh0YWdGbGFnICYgNjQgJiYgbmVzdGVkTG9jIGluIHNjaGVtYS5wcm9wZXJ0aWVzKSB7XG4gICAgICAgICAgICBhcnIudW5zaGlmdChzY2hlbWEpO1xuICAgICAgICAgIH0gZWxzZSBpZiAoISh0YWdGbGFnICYgMjA5NikpIHtcbiAgICAgICAgICAgIGFyci5wdXNoKHNjaGVtYSk7XG4gICAgICAgICAgfVxuICAgICAgICB9IGVsc2Uge1xuICAgICAgICAgIGlmIChpc1ByaW9yaXR5KHRhZ0ZsYWcsIGJ5S2V5KSkge1xuICAgICAgICAgICAga2V5cy51bnNoaWZ0KGtleSk7XG4gICAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICAgIGtleXMucHVzaChrZXkpO1xuICAgICAgICAgIH1cbiAgICAgICAgICBieUtleVtrZXldID0gW3NjaGVtYV07XG4gICAgICAgIH1cbiAgICAgIH1cbiAgICB9XG4gIH1cbiAgbGV0IGRlb3B0SWR4JDEgPSBkZW9wdElkeDtcbiAgbGV0IGJ5S2V5JDEgPSBieUtleTtcbiAgbGV0IGtleXMkMSA9IGtleXM7XG4gIGxldCBzdGFydCA9IFwiXCI7XG4gIGxldCBlbmQgPSBcIlwiO1xuICBsZXQgY2F1Z2h0ID0gXCJcIjtcbiAgbGV0IGV4aXQgPSBmYWxzZTtcbiAgaWYgKGRlb3B0SWR4JDEgIT09IC0xKSB7XG4gICAgZm9yIChsZXQgaWR4JDEgPSAwOyBpZHgkMSA8PSBkZW9wdElkeCQxOyArK2lkeCQxKSB7XG4gICAgICBpZiAoIWV4aXQpIHtcbiAgICAgICAgbGV0IHNjaGVtYSQxID0gc2NoZW1hc1tpZHgkMV07XG4gICAgICAgIGxldCBpdGVtQ29kZSA9IGdldEl0ZW1Db2RlKGIsIHNjaGVtYSQxLCBpbnB1dCwgaW5wdXQsIHRydWUsIHBhdGgpO1xuICAgICAgICBpZiAoaXRlbUNvZGUpIHtcbiAgICAgICAgICBsZXQgZXJyb3JWYXIgPSBgZWAgKyBpZHgkMTtcbiAgICAgICAgICBzdGFydCA9IHN0YXJ0ICsgKGB0cnl7YCArIGl0ZW1Db2RlICsgYH1jYXRjaChgICsgZXJyb3JWYXIgKyBgKXtgKTtcbiAgICAgICAgICBlbmQgPSBcIn1cIiArIGVuZDtcbiAgICAgICAgICBjYXVnaHQgPSBjYXVnaHQgKyBgLGAgKyBlcnJvclZhcjtcbiAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICBleGl0ID0gdHJ1ZTtcbiAgICAgICAgfVxuICAgICAgfVxuICAgIH1cbiAgfVxuICBpZiAoIWV4aXQpIHtcbiAgICBsZXQgbmV4dEVsc2UgPSBmYWxzZTtcbiAgICBsZXQgbm9vcCA9IFwiXCI7XG4gICAgZm9yIChsZXQgaWR4JDIgPSAwLCBpZHhfZmluaXNoID0ga2V5cyQxLmxlbmd0aDsgaWR4JDIgPCBpZHhfZmluaXNoOyArK2lkeCQyKSB7XG4gICAgICBsZXQgc2NoZW1hcyQxID0gYnlLZXkkMVtrZXlzJDFbaWR4JDJdXTtcbiAgICAgIGxldCBpc011bHRpcGxlID0gc2NoZW1hcyQxLmxlbmd0aCA+IDE7XG4gICAgICBsZXQgZmlyc3RTY2hlbWEgPSBzY2hlbWFzJDFbMF07XG4gICAgICBsZXQgY29uZCA9IDA7XG4gICAgICBsZXQgYm9keTtcbiAgICAgIGlmIChpc011bHRpcGxlKSB7XG4gICAgICAgIGxldCBpbnB1dFZhciA9IGlucHV0LnYoYik7XG4gICAgICAgIGxldCBpdGVtU3RhcnQgPSBcIlwiO1xuICAgICAgICBsZXQgaXRlbUVuZCA9IFwiXCI7XG4gICAgICAgIGxldCBpdGVtTmV4dEVsc2UgPSBmYWxzZTtcbiAgICAgICAgbGV0IGl0ZW1Ob29wID0ge1xuICAgICAgICAgIGNvbnRlbnRzOiBcIlwiXG4gICAgICAgIH07XG4gICAgICAgIGxldCBjYXVnaHQkMSA9IFwiXCI7XG4gICAgICAgIGxldCBieURpc2NyaW1pbmFudCA9IHt9O1xuICAgICAgICBsZXQgaXRlbUlkeCA9IDA7XG4gICAgICAgIGxldCBsYXN0SWR4JDEgPSBzY2hlbWFzJDEubGVuZ3RoIC0gMSB8IDA7XG4gICAgICAgIHdoaWxlIChpdGVtSWR4IDw9IGxhc3RJZHgkMSkge1xuICAgICAgICAgIGxldCBzY2hlbWEkMiA9IHNjaGVtYXMkMVtpdGVtSWR4XTtcbiAgICAgICAgICBsZXQgaXRlbUNvbmQgPSAoXG4gICAgICAgICAgICBjb25zdEZpZWxkIGluIHNjaGVtYSQyID8gdmFsaWRhdGlvbihiLCBpbnB1dFZhciwgc2NoZW1hJDIsIGZhbHNlKSA6IFwiXCJcbiAgICAgICAgICApICsgcmVmaW5lbWVudChiLCBpbnB1dFZhciwgc2NoZW1hJDIsIGZhbHNlKS5zbGljZSgyKTtcbiAgICAgICAgICBsZXQgaXRlbUNvZGUkMSA9IGdldEl0ZW1Db2RlKGIsIHNjaGVtYSQyLCBpbnB1dCwgaW5wdXQsIGZhbHNlLCBwYXRoKTtcbiAgICAgICAgICBpZiAoaXRlbUNvbmQpIHtcbiAgICAgICAgICAgIGlmIChpdGVtQ29kZSQxKSB7XG4gICAgICAgICAgICAgIGxldCBtYXRjaCA9IGJ5RGlzY3JpbWluYW50W2l0ZW1Db25kXTtcbiAgICAgICAgICAgICAgaWYgKG1hdGNoICE9PSB1bmRlZmluZWQpIHtcbiAgICAgICAgICAgICAgICBpZiAodHlwZW9mIG1hdGNoID09PSBcInN0cmluZ1wiKSB7XG4gICAgICAgICAgICAgICAgICBieURpc2NyaW1pbmFudFtpdGVtQ29uZF0gPSBbXG4gICAgICAgICAgICAgICAgICAgIG1hdGNoLFxuICAgICAgICAgICAgICAgICAgICBpdGVtQ29kZSQxXG4gICAgICAgICAgICAgICAgICBdO1xuICAgICAgICAgICAgICAgIH0gZWxzZSB7XG4gICAgICAgICAgICAgICAgICBtYXRjaC5wdXNoKGl0ZW1Db2RlJDEpO1xuICAgICAgICAgICAgICAgIH1cbiAgICAgICAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICAgICAgICBieURpc2NyaW1pbmFudFtpdGVtQ29uZF0gPSBpdGVtQ29kZSQxO1xuICAgICAgICAgICAgICB9XG4gICAgICAgICAgICB9IGVsc2Uge1xuICAgICAgICAgICAgICBpdGVtTm9vcC5jb250ZW50cyA9IGl0ZW1Ob29wLmNvbnRlbnRzID8gaXRlbU5vb3AuY29udGVudHMgKyBgfHxgICsgaXRlbUNvbmQgOiBpdGVtQ29uZDtcbiAgICAgICAgICAgIH1cbiAgICAgICAgICB9XG4gICAgICAgICAgaWYgKCFpdGVtQ29uZCB8fCBpdGVtSWR4ID09PSBsYXN0SWR4JDEpIHtcbiAgICAgICAgICAgIGxldCBhY2NlZERpc2NyaW1pbmFudHMgPSBPYmplY3Qua2V5cyhieURpc2NyaW1pbmFudCk7XG4gICAgICAgICAgICBmb3IgKGxldCBpZHgkMyA9IDAsIGlkeF9maW5pc2gkMSA9IGFjY2VkRGlzY3JpbWluYW50cy5sZW5ndGg7IGlkeCQzIDwgaWR4X2ZpbmlzaCQxOyArK2lkeCQzKSB7XG4gICAgICAgICAgICAgIGxldCBkaXNjcmltID0gYWNjZWREaXNjcmltaW5hbnRzW2lkeCQzXTtcbiAgICAgICAgICAgICAgbGV0IGlmXyA9IGl0ZW1OZXh0RWxzZSA/IFwiZWxzZSBpZlwiIDogXCJpZlwiO1xuICAgICAgICAgICAgICBpdGVtU3RhcnQgPSBpdGVtU3RhcnQgKyBpZl8gKyAoYChgICsgZGlzY3JpbSArIGApe2ApO1xuICAgICAgICAgICAgICBsZXQgY29kZSA9IGJ5RGlzY3JpbWluYW50W2Rpc2NyaW1dO1xuICAgICAgICAgICAgICBpZiAodHlwZW9mIGNvZGUgPT09IFwic3RyaW5nXCIpIHtcbiAgICAgICAgICAgICAgICBpdGVtU3RhcnQgPSBpdGVtU3RhcnQgKyBjb2RlICsgXCJ9XCI7XG4gICAgICAgICAgICAgIH0gZWxzZSB7XG4gICAgICAgICAgICAgICAgbGV0IGNhdWdodCQyID0gXCJcIjtcbiAgICAgICAgICAgICAgICBmb3IgKGxldCBpZHgkNCA9IDAsIGlkeF9maW5pc2gkMiA9IGNvZGUubGVuZ3RoOyBpZHgkNCA8IGlkeF9maW5pc2gkMjsgKytpZHgkNCkge1xuICAgICAgICAgICAgICAgICAgbGV0IGNvZGUkMSA9IGNvZGVbaWR4JDRdO1xuICAgICAgICAgICAgICAgICAgbGV0IGVycm9yVmFyJDEgPSBgZWAgKyBpZHgkNDtcbiAgICAgICAgICAgICAgICAgIGl0ZW1TdGFydCA9IGl0ZW1TdGFydCArIChgdHJ5e2AgKyBjb2RlJDEgKyBgfWNhdGNoKGAgKyBlcnJvclZhciQxICsgYCl7YCk7XG4gICAgICAgICAgICAgICAgICBjYXVnaHQkMiA9IGNhdWdodCQyICsgYCxgICsgZXJyb3JWYXIkMTtcbiAgICAgICAgICAgICAgICB9XG4gICAgICAgICAgICAgICAgaXRlbVN0YXJ0ID0gaXRlbVN0YXJ0ICsgZmFpbChjYXVnaHQkMikgKyBcIn1cIi5yZXBlYXQoY29kZS5sZW5ndGgpICsgXCJ9XCI7XG4gICAgICAgICAgICAgIH1cbiAgICAgICAgICAgICAgaXRlbU5leHRFbHNlID0gdHJ1ZTtcbiAgICAgICAgICAgIH1cbiAgICAgICAgICAgIGJ5RGlzY3JpbWluYW50ID0ge307XG4gICAgICAgICAgfVxuICAgICAgICAgIGlmICghaXRlbUNvbmQpIHtcbiAgICAgICAgICAgIGlmIChpdGVtQ29kZSQxKSB7XG4gICAgICAgICAgICAgIGlmIChpdGVtTm9vcC5jb250ZW50cykge1xuICAgICAgICAgICAgICAgIGxldCBpZl8kMSA9IGl0ZW1OZXh0RWxzZSA/IFwiZWxzZSBpZlwiIDogXCJpZlwiO1xuICAgICAgICAgICAgICAgIGl0ZW1TdGFydCA9IGl0ZW1TdGFydCArIGlmXyQxICsgKGAoIShgICsgaXRlbU5vb3AuY29udGVudHMgKyBgKSl7YCk7XG4gICAgICAgICAgICAgICAgaXRlbUVuZCA9IFwifVwiICsgaXRlbUVuZDtcbiAgICAgICAgICAgICAgICBpdGVtTm9vcC5jb250ZW50cyA9IFwiXCI7XG4gICAgICAgICAgICAgICAgaXRlbU5leHRFbHNlID0gZmFsc2U7XG4gICAgICAgICAgICAgIH1cbiAgICAgICAgICAgICAgbGV0IGVycm9yVmFyJDIgPSBgZWAgKyBpdGVtSWR4O1xuICAgICAgICAgICAgICBpdGVtU3RhcnQgPSBpdGVtU3RhcnQgKyAoKFxuICAgICAgICAgICAgICAgIGl0ZW1OZXh0RWxzZSA/IFwiZWxzZXtcIiA6IFwiXCJcbiAgICAgICAgICAgICAgKSArIGB0cnl7YCArIGl0ZW1Db2RlJDEgKyBgfWNhdGNoKGAgKyBlcnJvclZhciQyICsgYCl7YCk7XG4gICAgICAgICAgICAgIGl0ZW1FbmQgPSAoXG4gICAgICAgICAgICAgICAgaXRlbU5leHRFbHNlID8gXCJ9XCIgOiBcIlwiXG4gICAgICAgICAgICAgICkgKyBcIn1cIiArIGl0ZW1FbmQ7XG4gICAgICAgICAgICAgIGNhdWdodCQxID0gY2F1Z2h0JDEgKyBgLGAgKyBlcnJvclZhciQyO1xuICAgICAgICAgICAgICBpdGVtTmV4dEVsc2UgPSBmYWxzZTtcbiAgICAgICAgICAgIH0gZWxzZSB7XG4gICAgICAgICAgICAgIGl0ZW1Ob29wLmNvbnRlbnRzID0gXCJcIjtcbiAgICAgICAgICAgICAgaXRlbUlkeCA9IGxhc3RJZHgkMTtcbiAgICAgICAgICAgIH1cbiAgICAgICAgICB9XG4gICAgICAgICAgaXRlbUlkeCA9IGl0ZW1JZHggKyAxO1xuICAgICAgICB9O1xuICAgICAgICBjb25kID0gaW5wdXRWYXIgPT4gdmFsaWRhdGlvbihiLCBpbnB1dFZhciwge1xuICAgICAgICAgIHR5cGU6IGZpcnN0U2NoZW1hLnR5cGUsXG4gICAgICAgICAgcGFyc2VyOiAwXG4gICAgICAgIH0sIGZhbHNlKTtcbiAgICAgICAgaWYgKGl0ZW1Ob29wLmNvbnRlbnRzKSB7XG4gICAgICAgICAgaWYgKGl0ZW1TdGFydCkge1xuICAgICAgICAgICAgaWYgKHR5cGVWYWxpZGF0aW9uKSB7XG4gICAgICAgICAgICAgIGxldCBpZl8kMiA9IGl0ZW1OZXh0RWxzZSA/IFwiZWxzZSBpZlwiIDogXCJpZlwiO1xuICAgICAgICAgICAgICBpdGVtU3RhcnQgPSBpdGVtU3RhcnQgKyBpZl8kMiArIChgKCEoYCArIGl0ZW1Ob29wLmNvbnRlbnRzICsgYCkpe2AgKyBmYWlsKGNhdWdodCQxKSArIGB9YCk7XG4gICAgICAgICAgICB9XG4gICAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICAgIGxldCBjb25kQmVmb3JlID0gY29uZDtcbiAgICAgICAgICAgIGNvbmQgPSBpbnB1dFZhciA9PiBjb25kQmVmb3JlKGlucHV0VmFyKSArIChgJiYoYCArIGl0ZW1Ob29wLmNvbnRlbnRzICsgYClgKTtcbiAgICAgICAgICB9XG4gICAgICAgIH0gZWxzZSBpZiAodHlwZVZhbGlkYXRpb24gJiYgaXRlbVN0YXJ0KSB7XG4gICAgICAgICAgbGV0IGVycm9yQ29kZSA9IGZhaWwoY2F1Z2h0JDEpO1xuICAgICAgICAgIGl0ZW1TdGFydCA9IGl0ZW1TdGFydCArIChcbiAgICAgICAgICAgIGl0ZW1OZXh0RWxzZSA/IGBlbHNle2AgKyBlcnJvckNvZGUgKyBgfWAgOiBlcnJvckNvZGVcbiAgICAgICAgICApO1xuICAgICAgICB9XG4gICAgICAgIGJvZHkgPSBpdGVtU3RhcnQgKyBpdGVtRW5kO1xuICAgICAgfSBlbHNlIHtcbiAgICAgICAgY29uZCA9IGlucHV0VmFyID0+IHZhbGlkYXRpb24oYiwgaW5wdXRWYXIsIGZpcnN0U2NoZW1hLCBmYWxzZSkgKyByZWZpbmVtZW50KGIsIGlucHV0VmFyLCBmaXJzdFNjaGVtYSwgZmFsc2UpO1xuICAgICAgICBib2R5ID0gZ2V0SXRlbUNvZGUoYiwgZmlyc3RTY2hlbWEsIGlucHV0LCBpbnB1dCwgZmFsc2UsIHBhdGgpO1xuICAgICAgfVxuICAgICAgaWYgKGJvZHkgfHwgaXNQcmlvcml0eShmbGFnc1tmaXJzdFNjaGVtYS50eXBlXSwgYnlLZXkkMSkpIHtcbiAgICAgICAgbGV0IGlmXyQzID0gbmV4dEVsc2UgPyBcImVsc2UgaWZcIiA6IFwiaWZcIjtcbiAgICAgICAgc3RhcnQgPSBzdGFydCArIGlmXyQzICsgKGAoYCArIGNvbmQoaW5wdXQudihiKSkgKyBgKXtgICsgYm9keSArIGB9YCk7XG4gICAgICAgIG5leHRFbHNlID0gdHJ1ZTtcbiAgICAgIH0gZWxzZSBpZiAodHlwZVZhbGlkYXRpb24pIHtcbiAgICAgICAgbGV0IGNvbmQkMSA9IGNvbmQoaW5wdXQudihiKSk7XG4gICAgICAgIG5vb3AgPSBub29wID8gbm9vcCArIGB8fGAgKyBjb25kJDEgOiBjb25kJDE7XG4gICAgICB9XG4gICAgfVxuICAgIGlmICh0eXBlVmFsaWRhdGlvbiB8fCBkZW9wdElkeCQxID09PSBsYXN0SWR4KSB7XG4gICAgICBsZXQgZXJyb3JDb2RlJDEgPSBmYWlsKGNhdWdodCk7XG4gICAgICBsZXQgdG1wO1xuICAgICAgaWYgKG5vb3ApIHtcbiAgICAgICAgbGV0IGlmXyQ0ID0gbmV4dEVsc2UgPyBcImVsc2UgaWZcIiA6IFwiaWZcIjtcbiAgICAgICAgdG1wID0gaWZfJDQgKyAoYCghKGAgKyBub29wICsgYCkpe2AgKyBlcnJvckNvZGUkMSArIGB9YCk7XG4gICAgICB9IGVsc2Uge1xuICAgICAgICB0bXAgPSBuZXh0RWxzZSA/IGBlbHNle2AgKyBlcnJvckNvZGUkMSArIGB9YCA6IGVycm9yQ29kZSQxO1xuICAgICAgfVxuICAgICAgc3RhcnQgPSBzdGFydCArIHRtcDtcbiAgICB9XG4gIH1cbiAgYi5jID0gYi5jICsgc3RhcnQgKyBlbmQ7XG4gIGxldCBvID0gaW5wdXQuZiAmIDIgPyBhc3luY1ZhbChiLCBgUHJvbWlzZS5yZXNvbHZlKGAgKyBpbnB1dC5pICsgYClgKSA6IChcbiAgICAgIGlucHV0LnYgPT09IF92YXIgPyAoXG4gICAgICAgICAgYi5jID09PSBcIlwiICYmIGlucHV0LmIuYyA9PT0gXCJcIiAmJiAoaW5wdXQuYi5sID09PSBpbnB1dC5pICsgYD1gICsgaW5pdGlhbElubGluZSB8fCBpbml0aWFsSW5saW5lID09PSBcImlcIikgPyAoaW5wdXQuYi5sID0gXCJcIiwgaW5wdXQuYi5hID0gaW5pdGlhbEFsbG9jYXRlLCBpbnB1dC52ID0gX25vdFZhciwgaW5wdXQuaSA9IGluaXRpYWxJbmxpbmUsIGlucHV0KSA6IGNvcHkoaW5wdXQpXG4gICAgICAgICkgOiBpbnB1dFxuICAgICk7XG4gIG8uYW55T2YgPSBzZWxmU2NoZW1hLmFueU9mO1xuICBsZXQgdG8gPSBzZWxmU2NoZW1hLnRvO1xuICBvLnR5cGUgPSB0byAhPT0gdW5kZWZpbmVkICYmIHRvLnR5cGUgIT09IFwidW5pb25cIiA/IChvLnQgPSB0cnVlLCBnZXRPdXRwdXRTY2hlbWEodG8pLnR5cGUpIDogXCJ1bmlvblwiO1xuICByZXR1cm4gbztcbn1cblxuZnVuY3Rpb24gZmFjdG9yeShzY2hlbWFzKSB7XG4gIGxldCBsZW4gPSBzY2hlbWFzLmxlbmd0aDtcbiAgaWYgKGxlbiA9PT0gMSkge1xuICAgIHJldHVybiBzY2hlbWFzWzBdO1xuICB9XG4gIGlmIChsZW4gIT09IDApIHtcbiAgICBsZXQgaGFzID0ge307XG4gICAgbGV0IGFueU9mID0gbmV3IFNldCgpO1xuICAgIGZvciAobGV0IGlkeCA9IDAsIGlkeF9maW5pc2ggPSBzY2hlbWFzLmxlbmd0aDsgaWR4IDwgaWR4X2ZpbmlzaDsgKytpZHgpIHtcbiAgICAgIGxldCBzY2hlbWEgPSBzY2hlbWFzW2lkeF07XG4gICAgICBpZiAoc2NoZW1hLnR5cGUgPT09IFwidW5pb25cIiAmJiBzY2hlbWEudG8gPT09IHVuZGVmaW5lZCkge1xuICAgICAgICBzY2hlbWEuYW55T2YuZm9yRWFjaChpdGVtID0+IHtcbiAgICAgICAgICBhbnlPZi5hZGQoaXRlbSk7XG4gICAgICAgIH0pO1xuICAgICAgICBPYmplY3QuYXNzaWduKGhhcywgc2NoZW1hLmhhcyk7XG4gICAgICB9IGVsc2Uge1xuICAgICAgICBhbnlPZi5hZGQoc2NoZW1hKTtcbiAgICAgICAgc2V0SGFzKGhhcywgc2NoZW1hLnR5cGUpO1xuICAgICAgfVxuICAgIH1cbiAgICBsZXQgbXV0ID0gbmV3IFNjaGVtYShcInVuaW9uXCIpO1xuICAgIG11dC5hbnlPZiA9IEFycmF5LmZyb20oYW55T2YpO1xuICAgIG11dC5jb21waWxlciA9IGNvbXBpbGVyO1xuICAgIG11dC5oYXMgPSBoYXM7XG4gICAgcmV0dXJuIG11dDtcbiAgfVxuICB0aHJvdyBuZXcgRXJyb3IoYFtTdXJ5XSBgICsgXCJTLnVuaW9uIHJlcXVpcmVzIGF0IGxlYXN0IG9uZSBpdGVtXCIpO1xufVxuXG5mdW5jdGlvbiBuZXN0ZWROb25lKCkge1xuICBsZXQgaXRlbVNjaGVtYSA9IHBhcnNlJDEoMCk7XG4gIGxldCBpdGVtID0ge1xuICAgIHNjaGVtYTogaXRlbVNjaGVtYSxcbiAgICBsb2NhdGlvbjogbmVzdGVkTG9jXG4gIH07XG4gIGxldCBwcm9wZXJ0aWVzID0ge307XG4gIHByb3BlcnRpZXNbbmVzdGVkTG9jXSA9IGl0ZW1TY2hlbWE7XG4gIHJldHVybiB7XG4gICAgdHlwZTogXCJvYmplY3RcIixcbiAgICBzZXJpYWxpemVyOiAoYiwgcGFyYW0sIHNlbGZTY2hlbWEsIHBhcmFtJDEpID0+IGNvbnN0VmFsKGIsIHNlbGZTY2hlbWEudG8pLFxuICAgIGFkZGl0aW9uYWxJdGVtczogXCJzdHJpcFwiLFxuICAgIGl0ZW1zOiBbaXRlbV0sXG4gICAgcHJvcGVydGllczogcHJvcGVydGllc1xuICB9O1xufVxuXG5mdW5jdGlvbiBwYXJzZXIoYiwgcGFyYW0sIHNlbGZTY2hlbWEsIHBhcmFtJDEpIHtcbiAgcmV0dXJuIHZhbChiLCBge2AgKyBuZXN0ZWRMb2MgKyBgOmAgKyBnZXRPdXRwdXRTY2hlbWEoc2VsZlNjaGVtYSkuaXRlbXNbMF0uc2NoZW1hLmNvbnN0ICsgYH1gLCBzZWxmU2NoZW1hLnRvKTtcbn1cblxuZnVuY3Rpb24gbmVzdGVkT3B0aW9uKGl0ZW0pIHtcbiAgcmV0dXJuIHVwZGF0ZU91dHB1dChpdGVtLCBtdXQgPT4ge1xuICAgIG11dC50byA9IG5lc3RlZE5vbmUoKTtcbiAgICBtdXQucGFyc2VyID0gcGFyc2VyO1xuICB9KTtcbn1cblxuZnVuY3Rpb24gZmFjdG9yeSQxKGl0ZW0sIHVuaXRPcHQpIHtcbiAgbGV0IHVuaXQkMSA9IHVuaXRPcHQgIT09IHVuZGVmaW5lZCA/IHVuaXRPcHQgOiB1bml0O1xuICBsZXQgbWF0Y2ggPSBnZXRPdXRwdXRTY2hlbWEoaXRlbSk7XG4gIGxldCBtYXRjaCQxID0gbWF0Y2gudHlwZTtcbiAgc3dpdGNoIChtYXRjaCQxKSB7XG4gICAgY2FzZSBcInVuZGVmaW5lZFwiIDpcbiAgICAgIHJldHVybiBmYWN0b3J5KFtcbiAgICAgICAgdW5pdCQxLFxuICAgICAgICBuZXN0ZWRPcHRpb24oaXRlbSlcbiAgICAgIF0pO1xuICAgIGNhc2UgXCJ1bmlvblwiIDpcbiAgICAgIGxldCBoYXMgPSBtYXRjaC5oYXM7XG4gICAgICBsZXQgYW55T2YgPSBtYXRjaC5hbnlPZjtcbiAgICAgIHJldHVybiB1cGRhdGVPdXRwdXQoaXRlbSwgbXV0ID0+IHtcbiAgICAgICAgbGV0IG11dEhhcyA9IGNvcHkoaGFzKTtcbiAgICAgICAgbGV0IG5ld0FueU9mID0gW107XG4gICAgICAgIGZvciAobGV0IGlkeCA9IDAsIGlkeF9maW5pc2ggPSBhbnlPZi5sZW5ndGg7IGlkeCA8IGlkeF9maW5pc2g7ICsraWR4KSB7XG4gICAgICAgICAgbGV0IHNjaGVtYSA9IGFueU9mW2lkeF07XG4gICAgICAgICAgbGV0IG1hdGNoID0gZ2V0T3V0cHV0U2NoZW1hKHNjaGVtYSk7XG4gICAgICAgICAgbGV0IG1hdGNoJDEgPSBtYXRjaC50eXBlO1xuICAgICAgICAgIGxldCB0bXA7XG4gICAgICAgICAgaWYgKG1hdGNoJDEgPT09IFwidW5kZWZpbmVkXCIpIHtcbiAgICAgICAgICAgIG11dEhhc1t1bml0JDEudHlwZV0gPSB0cnVlO1xuICAgICAgICAgICAgbmV3QW55T2YucHVzaCh1bml0JDEpO1xuICAgICAgICAgICAgdG1wID0gbmVzdGVkT3B0aW9uKHNjaGVtYSk7XG4gICAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICAgIGxldCBwcm9wZXJ0aWVzID0gbWF0Y2gucHJvcGVydGllcztcbiAgICAgICAgICAgIGlmIChwcm9wZXJ0aWVzICE9PSB1bmRlZmluZWQpIHtcbiAgICAgICAgICAgICAgbGV0IG5lc3RlZFNjaGVtYSA9IHByb3BlcnRpZXNbbmVzdGVkTG9jXTtcbiAgICAgICAgICAgICAgdG1wID0gbmVzdGVkU2NoZW1hICE9PSB1bmRlZmluZWQgPyB1cGRhdGVPdXRwdXQoc2NoZW1hLCBtdXQgPT4ge1xuICAgICAgICAgICAgICAgICAgbGV0IG5ld0l0ZW1fc2NoZW1hID0ge1xuICAgICAgICAgICAgICAgICAgICB0eXBlOiBuZXN0ZWRTY2hlbWEudHlwZSxcbiAgICAgICAgICAgICAgICAgICAgcGFyc2VyOiBuZXN0ZWRTY2hlbWEucGFyc2VyLFxuICAgICAgICAgICAgICAgICAgICBjb25zdDogbmVzdGVkU2NoZW1hLmNvbnN0ICsgMVxuICAgICAgICAgICAgICAgICAgfTtcbiAgICAgICAgICAgICAgICAgIGxldCBuZXdJdGVtID0ge1xuICAgICAgICAgICAgICAgICAgICBzY2hlbWE6IG5ld0l0ZW1fc2NoZW1hLFxuICAgICAgICAgICAgICAgICAgICBsb2NhdGlvbjogbmVzdGVkTG9jXG4gICAgICAgICAgICAgICAgICB9O1xuICAgICAgICAgICAgICAgICAgbGV0IHByb3BlcnRpZXMgPSB7fTtcbiAgICAgICAgICAgICAgICAgIHByb3BlcnRpZXNbbmVzdGVkTG9jXSA9IG5ld0l0ZW1fc2NoZW1hO1xuICAgICAgICAgICAgICAgICAgbXV0Lml0ZW1zID0gW25ld0l0ZW1dO1xuICAgICAgICAgICAgICAgICAgbXV0LnByb3BlcnRpZXMgPSBwcm9wZXJ0aWVzO1xuICAgICAgICAgICAgICAgIH0pIDogc2NoZW1hO1xuICAgICAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICAgICAgdG1wID0gc2NoZW1hO1xuICAgICAgICAgICAgfVxuICAgICAgICAgIH1cbiAgICAgICAgICBuZXdBbnlPZi5wdXNoKHRtcCk7XG4gICAgICAgIH1cbiAgICAgICAgaWYgKG5ld0FueU9mLmxlbmd0aCA9PT0gYW55T2YubGVuZ3RoKSB7XG4gICAgICAgICAgbXV0SGFzW3VuaXQkMS50eXBlXSA9IHRydWU7XG4gICAgICAgICAgbmV3QW55T2YucHVzaCh1bml0JDEpO1xuICAgICAgICB9XG4gICAgICAgIG11dC5hbnlPZiA9IG5ld0FueU9mO1xuICAgICAgICBtdXQuaGFzID0gbXV0SGFzO1xuICAgICAgfSk7XG4gICAgZGVmYXVsdDpcbiAgICAgIHJldHVybiBmYWN0b3J5KFtcbiAgICAgICAgaXRlbSxcbiAgICAgICAgdW5pdCQxXG4gICAgICBdKTtcbiAgfVxufVxuXG5mdW5jdGlvbiBnZXRXaXRoRGVmYXVsdChzY2hlbWEsICQkZGVmYXVsdCkge1xuICByZXR1cm4gdXBkYXRlT3V0cHV0KHNjaGVtYSwgbXV0ID0+IHtcbiAgICBsZXQgYW55T2YgPSBtdXQuYW55T2Y7XG4gICAgaWYgKGFueU9mICE9PSB1bmRlZmluZWQpIHtcbiAgICAgIGxldCBpdGVtO1xuICAgICAgbGV0IGl0ZW1PdXRwdXRTY2hlbWE7XG4gICAgICBmb3IgKGxldCBpZHggPSAwLCBpZHhfZmluaXNoID0gYW55T2YubGVuZ3RoOyBpZHggPCBpZHhfZmluaXNoOyArK2lkeCkge1xuICAgICAgICBsZXQgc2NoZW1hID0gYW55T2ZbaWR4XTtcbiAgICAgICAgbGV0IG91dHB1dFNjaGVtYSA9IGdldE91dHB1dFNjaGVtYShzY2hlbWEpO1xuICAgICAgICBsZXQgbWF0Y2ggPSBvdXRwdXRTY2hlbWEudHlwZTtcbiAgICAgICAgaWYgKG1hdGNoICE9PSBcInVuZGVmaW5lZFwiKSB7XG4gICAgICAgICAgbGV0IG1hdGNoJDEgPSBpdGVtO1xuICAgICAgICAgIGlmIChtYXRjaCQxICE9PSB1bmRlZmluZWQpIHtcbiAgICAgICAgICAgIGxldCBtZXNzYWdlID0gYENhbid0IHNldCBkZWZhdWx0IGZvciBgICsgdG9FeHByZXNzaW9uKG11dCk7XG4gICAgICAgICAgICB0aHJvdyBuZXcgRXJyb3IoYFtTdXJ5XSBgICsgbWVzc2FnZSk7XG4gICAgICAgICAgfVxuICAgICAgICAgIGl0ZW0gPSBzY2hlbWE7XG4gICAgICAgICAgaXRlbU91dHB1dFNjaGVtYSA9IG91dHB1dFNjaGVtYTtcbiAgICAgICAgfVxuICAgICAgfVxuICAgICAgbGV0IHMgPSBpdGVtO1xuICAgICAgbGV0IGl0ZW0kMTtcbiAgICAgIGlmIChzICE9PSB1bmRlZmluZWQpIHtcbiAgICAgICAgaXRlbSQxID0gcztcbiAgICAgIH0gZWxzZSB7XG4gICAgICAgIGxldCBtZXNzYWdlJDEgPSBgQ2FuJ3Qgc2V0IGRlZmF1bHQgZm9yIGAgKyB0b0V4cHJlc3Npb24obXV0KTtcbiAgICAgICAgdGhyb3cgbmV3IEVycm9yKGBbU3VyeV0gYCArIG1lc3NhZ2UkMSk7XG4gICAgICB9XG4gICAgICBtdXQucGFyc2VyID0gKGIsIGlucHV0LCBzZWxmU2NoZW1hLCBwYXJhbSkgPT4ge1xuICAgICAgICBsZXQgb3BlcmF0aW9uID0gKGIsIGlucHV0KSA9PiB7XG4gICAgICAgICAgbGV0IGlucHV0VmFyID0gaW5wdXQudihiKTtcbiAgICAgICAgICBsZXQgdG1wO1xuICAgICAgICAgIHRtcCA9ICQkZGVmYXVsdC5UQUcgPT09IFwiVmFsdWVcIiA/IGlubGluZUNvbnN0KGIsIHBhcnNlJDEoJCRkZWZhdWx0Ll8wKSkgOiBlbWJlZChiLCAkJGRlZmF1bHQuXzApICsgYCgpYDtcbiAgICAgICAgICByZXR1cm4gdmFsKGIsIGlucHV0VmFyICsgYD09PXZvaWQgMD9gICsgdG1wICsgYDpgICsgaW5wdXRWYXIsIHNlbGZTY2hlbWEudG8pO1xuICAgICAgICB9O1xuICAgICAgICBpZiAoIShpbnB1dC5mICYgMikpIHtcbiAgICAgICAgICByZXR1cm4gb3BlcmF0aW9uKGIsIGlucHV0KTtcbiAgICAgICAgfVxuICAgICAgICBsZXQgYmIgPSB7XG4gICAgICAgICAgYzogXCJcIixcbiAgICAgICAgICBsOiBcIlwiLFxuICAgICAgICAgIGE6IGluaXRpYWxBbGxvY2F0ZSxcbiAgICAgICAgICBmOiBcIlwiLFxuICAgICAgICAgIGc6IGIuZ1xuICAgICAgICB9O1xuICAgICAgICBsZXQgb3BlcmF0aW9uSW5wdXQgPSB7XG4gICAgICAgICAgYjogYixcbiAgICAgICAgICB2OiBfdmFyLFxuICAgICAgICAgIGk6IHZhcldpdGhvdXRBbGxvY2F0aW9uKGJiLmcpLFxuICAgICAgICAgIGY6IDAsXG4gICAgICAgICAgdHlwZTogXCJ1bmtub3duXCJcbiAgICAgICAgfTtcbiAgICAgICAgbGV0IG9wZXJhdGlvbk91dHB1dFZhbCA9IG9wZXJhdGlvbihiYiwgb3BlcmF0aW9uSW5wdXQpO1xuICAgICAgICBsZXQgb3BlcmF0aW9uQ29kZSA9IGFsbG9jYXRlU2NvcGUoYmIpO1xuICAgICAgICByZXR1cm4gYXN5bmNWYWwoaW5wdXQuYiwgaW5wdXQuaSArIGAudGhlbihgICsgb3BlcmF0aW9uSW5wdXQudihiKSArIGA9PntgICsgb3BlcmF0aW9uQ29kZSArIGByZXR1cm4gYCArIG9wZXJhdGlvbk91dHB1dFZhbC5pICsgYH0pYCk7XG4gICAgICB9O1xuICAgICAgbGV0IHRvID0gY29weVdpdGhvdXRDYWNoZShpdGVtT3V0cHV0U2NoZW1hKTtcbiAgICAgIGxldCBjb21waWxlciA9IHRvLmNvbXBpbGVyO1xuICAgICAgaWYgKGNvbXBpbGVyICE9PSB1bmRlZmluZWQpIHtcbiAgICAgICAgdG8uc2VyaWFsaXplciA9IGNvbXBpbGVyO1xuICAgICAgICAoKGRlbGV0ZSB0by5jb21waWxlcikpO1xuICAgICAgfSBlbHNlIHtcbiAgICAgICAgdG8uc2VyaWFsaXplciA9IChfYiwgaW5wdXQsIHBhcmFtLCBwYXJhbSQxKSA9PiBpbnB1dDtcbiAgICAgIH1cbiAgICAgIG11dC50byA9IHRvO1xuICAgICAgaWYgKCQkZGVmYXVsdC5UQUcgIT09IFwiVmFsdWVcIikge1xuICAgICAgICByZXR1cm47XG4gICAgICB9XG4gICAgICB0cnkge1xuICAgICAgICBtdXQuZGVmYXVsdCA9IG9wZXJhdGlvbkZuKGl0ZW0kMSwgMzIpKCQkZGVmYXVsdC5fMCk7XG4gICAgICAgIHJldHVybjtcbiAgICAgIH0gY2F0Y2ggKGV4bikge1xuICAgICAgICByZXR1cm47XG4gICAgICB9XG4gICAgfSBlbHNlIHtcbiAgICAgIGxldCBtZXNzYWdlJDIgPSBgQ2FuJ3Qgc2V0IGRlZmF1bHQgZm9yIGAgKyB0b0V4cHJlc3Npb24obXV0KTtcbiAgICAgIHRocm93IG5ldyBFcnJvcihgW1N1cnldIGAgKyBtZXNzYWdlJDIpO1xuICAgIH1cbiAgfSk7XG59XG5cbmZ1bmN0aW9uIGdldE9yKHNjaGVtYSwgZGVmYWx1dFZhbHVlKSB7XG4gIHJldHVybiBnZXRXaXRoRGVmYXVsdChzY2hlbWEsIHtcbiAgICBUQUc6IFwiVmFsdWVcIixcbiAgICBfMDogZGVmYWx1dFZhbHVlXG4gIH0pO1xufVxuXG5mdW5jdGlvbiBnZXRPcldpdGgoc2NoZW1hLCBkZWZhbHV0Q2IpIHtcbiAgcmV0dXJuIGdldFdpdGhEZWZhdWx0KHNjaGVtYSwge1xuICAgIFRBRzogXCJDYWxsYmFja1wiLFxuICAgIF8wOiBkZWZhbHV0Q2JcbiAgfSk7XG59XG5cbmxldCBtZXRhZGF0YUlkID0gYG06YCArIFwiQXJyYXkucmVmaW5lbWVudHNcIjtcblxuZnVuY3Rpb24gcmVmaW5lbWVudHMoc2NoZW1hKSB7XG4gIGxldCBtID0gc2NoZW1hW21ldGFkYXRhSWRdO1xuICBpZiAobSAhPT0gdW5kZWZpbmVkKSB7XG4gICAgcmV0dXJuIG07XG4gIH0gZWxzZSB7XG4gICAgcmV0dXJuIFtdO1xuICB9XG59XG5cbmZ1bmN0aW9uIGFycmF5Q29tcGlsZXIoYiwgaW5wdXQsIHNlbGZTY2hlbWEsIHBhdGgpIHtcbiAgbGV0IGl0ZW0gPSBzZWxmU2NoZW1hLmFkZGl0aW9uYWxJdGVtcztcbiAgbGV0IGlucHV0VmFyID0gaW5wdXQudihiKTtcbiAgbGV0IGl0ZXJhdG9yVmFyID0gdmFyV2l0aG91dEFsbG9jYXRpb24oYi5nKTtcbiAgbGV0IGJiID0ge1xuICAgIGM6IFwiXCIsXG4gICAgbDogXCJcIixcbiAgICBhOiBpbml0aWFsQWxsb2NhdGUsXG4gICAgZjogXCJcIixcbiAgICBnOiBiLmdcbiAgfTtcbiAgbGV0IGl0ZW1JbnB1dCA9IHZhbChiYiwgaW5wdXRWYXIgKyBgW2AgKyBpdGVyYXRvclZhciArIGBdYCwgdW5rbm93bik7XG4gIGxldCBpdGVtT3V0cHV0ID0gd2l0aFBhdGhQcmVwZW5kKGJiLCBpdGVtSW5wdXQsIHBhdGgsIGl0ZXJhdG9yVmFyLCB1bmRlZmluZWQsIChiLCBpbnB1dCwgcGF0aCkgPT4gcGFyc2UoYiwgaXRlbSwgaW5wdXQsIHBhdGgpKTtcbiAgbGV0IGl0ZW1Db2RlID0gYWxsb2NhdGVTY29wZShiYik7XG4gIGxldCBpc1RyYW5zZm9ybWVkID0gaXRlbUlucHV0ICE9PSBpdGVtT3V0cHV0O1xuICBsZXQgb3V0cHV0ID0gaXNUcmFuc2Zvcm1lZCA/IHZhbChiLCBgbmV3IEFycmF5KGAgKyBpbnB1dFZhciArIGAubGVuZ3RoKWAsIHNlbGZTY2hlbWEpIDogaW5wdXQ7XG4gIG91dHB1dC50eXBlID0gc2VsZlNjaGVtYS50eXBlO1xuICBvdXRwdXQuYWRkaXRpb25hbEl0ZW1zID0gc2VsZlNjaGVtYS5hZGRpdGlvbmFsSXRlbXM7XG4gIGlmIChpc1RyYW5zZm9ybWVkIHx8IGl0ZW1Db2RlICE9PSBcIlwiKSB7XG4gICAgYi5jID0gYi5jICsgKGBmb3IobGV0IGAgKyBpdGVyYXRvclZhciArIGA9MDtgICsgaXRlcmF0b3JWYXIgKyBgPGAgKyBpbnB1dFZhciArIGAubGVuZ3RoOysrYCArIGl0ZXJhdG9yVmFyICsgYCl7YCArIGl0ZW1Db2RlICsgKFxuICAgICAgaXNUcmFuc2Zvcm1lZCA/IGFkZEtleShiLCBvdXRwdXQsIGl0ZXJhdG9yVmFyLCBpdGVtT3V0cHV0KSA6IFwiXCJcbiAgICApICsgYH1gKTtcbiAgfVxuICBpZiAoaXRlbU91dHB1dC5mICYgMikge1xuICAgIHJldHVybiBhc3luY1ZhbChvdXRwdXQuYiwgYFByb21pc2UuYWxsKGAgKyBvdXRwdXQuaSArIGApYCk7XG4gIH0gZWxzZSB7XG4gICAgcmV0dXJuIG91dHB1dDtcbiAgfVxufVxuXG5mdW5jdGlvbiBmYWN0b3J5JDIoaXRlbSkge1xuICBsZXQgbXV0ID0gbmV3IFNjaGVtYShcImFycmF5XCIpO1xuICBtdXQuYWRkaXRpb25hbEl0ZW1zID0gaXRlbTtcbiAgbXV0Lml0ZW1zID0gaW1tdXRhYmxlRW1wdHkkMTtcbiAgbXV0LmNvbXBpbGVyID0gYXJyYXlDb21waWxlcjtcbiAgcmV0dXJuIG11dDtcbn1cblxuZnVuY3Rpb24gc2V0QWRkaXRpb25hbEl0ZW1zKHNjaGVtYSwgYWRkaXRpb25hbEl0ZW1zLCBkZWVwKSB7XG4gIGxldCBjdXJyZW50QWRkaXRpb25hbEl0ZW1zID0gc2NoZW1hLmFkZGl0aW9uYWxJdGVtcztcbiAgaWYgKGN1cnJlbnRBZGRpdGlvbmFsSXRlbXMgPT09IHVuZGVmaW5lZCkge1xuICAgIHJldHVybiBzY2hlbWE7XG4gIH1cbiAgbGV0IGl0ZW1zID0gc2NoZW1hLml0ZW1zO1xuICBpZiAoY3VycmVudEFkZGl0aW9uYWxJdGVtcyA9PT0gYWRkaXRpb25hbEl0ZW1zIHx8IHR5cGVvZiBjdXJyZW50QWRkaXRpb25hbEl0ZW1zID09PSBcIm9iamVjdFwiKSB7XG4gICAgcmV0dXJuIHNjaGVtYTtcbiAgfVxuICBsZXQgbXV0ID0gY29weVdpdGhvdXRDYWNoZShzY2hlbWEpO1xuICBtdXQuYWRkaXRpb25hbEl0ZW1zID0gYWRkaXRpb25hbEl0ZW1zO1xuICBpZiAoZGVlcCkge1xuICAgIGxldCBuZXdJdGVtcyA9IFtdO1xuICAgIGxldCBuZXdQcm9wZXJ0aWVzID0ge307XG4gICAgZm9yIChsZXQgaWR4ID0gMCwgaWR4X2ZpbmlzaCA9IGl0ZW1zLmxlbmd0aDsgaWR4IDwgaWR4X2ZpbmlzaDsgKytpZHgpIHtcbiAgICAgIGxldCBpdGVtID0gaXRlbXNbaWR4XTtcbiAgICAgIGxldCBuZXdTY2hlbWEgPSBzZXRBZGRpdGlvbmFsSXRlbXMoaXRlbS5zY2hlbWEsIGFkZGl0aW9uYWxJdGVtcywgZGVlcCk7XG4gICAgICBsZXQgbmV3SXRlbSA9IG5ld1NjaGVtYSA9PT0gaXRlbS5zY2hlbWEgPyBpdGVtIDogKHtcbiAgICAgICAgICBzY2hlbWE6IG5ld1NjaGVtYSxcbiAgICAgICAgICBsb2NhdGlvbjogaXRlbS5sb2NhdGlvblxuICAgICAgICB9KTtcbiAgICAgIG5ld1Byb3BlcnRpZXNbaXRlbS5sb2NhdGlvbl0gPSBuZXdTY2hlbWE7XG4gICAgICBuZXdJdGVtcy5wdXNoKG5ld0l0ZW0pO1xuICAgIH1cbiAgICBtdXQuaXRlbXMgPSBuZXdJdGVtcztcbiAgICBtdXQucHJvcGVydGllcyA9IG5ld1Byb3BlcnRpZXM7XG4gIH1cbiAgcmV0dXJuIG11dDtcbn1cblxuZnVuY3Rpb24gc3RyaXAoc2NoZW1hKSB7XG4gIHJldHVybiBzZXRBZGRpdGlvbmFsSXRlbXMoc2NoZW1hLCBcInN0cmlwXCIsIGZhbHNlKTtcbn1cblxuZnVuY3Rpb24gZGVlcFN0cmlwKHNjaGVtYSkge1xuICByZXR1cm4gc2V0QWRkaXRpb25hbEl0ZW1zKHNjaGVtYSwgXCJzdHJpcFwiLCB0cnVlKTtcbn1cblxuZnVuY3Rpb24gc3RyaWN0KHNjaGVtYSkge1xuICByZXR1cm4gc2V0QWRkaXRpb25hbEl0ZW1zKHNjaGVtYSwgXCJzdHJpY3RcIiwgZmFsc2UpO1xufVxuXG5mdW5jdGlvbiBkZWVwU3RyaWN0KHNjaGVtYSkge1xuICByZXR1cm4gc2V0QWRkaXRpb25hbEl0ZW1zKHNjaGVtYSwgXCJzdHJpY3RcIiwgdHJ1ZSk7XG59XG5cbmZ1bmN0aW9uIGRpY3RDb21waWxlcihiLCBpbnB1dCwgc2VsZlNjaGVtYSwgcGF0aCkge1xuICBsZXQgaXRlbSA9IHNlbGZTY2hlbWEuYWRkaXRpb25hbEl0ZW1zO1xuICBsZXQgaW5wdXRWYXIgPSBpbnB1dC52KGIpO1xuICBsZXQga2V5VmFyID0gdmFyV2l0aG91dEFsbG9jYXRpb24oYi5nKTtcbiAgbGV0IGJiID0ge1xuICAgIGM6IFwiXCIsXG4gICAgbDogXCJcIixcbiAgICBhOiBpbml0aWFsQWxsb2NhdGUsXG4gICAgZjogXCJcIixcbiAgICBnOiBiLmdcbiAgfTtcbiAgbGV0IGl0ZW1JbnB1dCA9IHZhbChiYiwgaW5wdXRWYXIgKyBgW2AgKyBrZXlWYXIgKyBgXWAsIHVua25vd24pO1xuICBsZXQgaXRlbU91dHB1dCA9IHdpdGhQYXRoUHJlcGVuZChiYiwgaXRlbUlucHV0LCBwYXRoLCBrZXlWYXIsIHVuZGVmaW5lZCwgKGIsIGlucHV0LCBwYXRoKSA9PiBwYXJzZShiLCBpdGVtLCBpbnB1dCwgcGF0aCkpO1xuICBsZXQgaXRlbUNvZGUgPSBhbGxvY2F0ZVNjb3BlKGJiKTtcbiAgbGV0IGlzVHJhbnNmb3JtZWQgPSBpdGVtSW5wdXQgIT09IGl0ZW1PdXRwdXQ7XG4gIGxldCBvdXRwdXQgPSBpc1RyYW5zZm9ybWVkID8gdmFsKGIsIFwie31cIiwgc2VsZlNjaGVtYSkgOiBpbnB1dDtcbiAgb3V0cHV0LnR5cGUgPSBzZWxmU2NoZW1hLnR5cGU7XG4gIG91dHB1dC5hZGRpdGlvbmFsSXRlbXMgPSBzZWxmU2NoZW1hLmFkZGl0aW9uYWxJdGVtcztcbiAgaWYgKGlzVHJhbnNmb3JtZWQgfHwgaXRlbUNvZGUgIT09IFwiXCIpIHtcbiAgICBiLmMgPSBiLmMgKyAoYGZvcihsZXQgYCArIGtleVZhciArIGAgaW4gYCArIGlucHV0VmFyICsgYCl7YCArIGl0ZW1Db2RlICsgKFxuICAgICAgaXNUcmFuc2Zvcm1lZCA/IGFkZEtleShiLCBvdXRwdXQsIGtleVZhciwgaXRlbU91dHB1dCkgOiBcIlwiXG4gICAgKSArIGB9YCk7XG4gIH1cbiAgaWYgKCEoaXRlbU91dHB1dC5mICYgMikpIHtcbiAgICByZXR1cm4gb3V0cHV0O1xuICB9XG4gIGxldCByZXNvbHZlVmFyID0gdmFyV2l0aG91dEFsbG9jYXRpb24oYi5nKTtcbiAgbGV0IHJlamVjdFZhciA9IHZhcldpdGhvdXRBbGxvY2F0aW9uKGIuZyk7XG4gIGxldCBhc3luY1BhcnNlUmVzdWx0VmFyID0gdmFyV2l0aG91dEFsbG9jYXRpb24oYi5nKTtcbiAgbGV0IGNvdW50ZXJWYXIgPSB2YXJXaXRob3V0QWxsb2NhdGlvbihiLmcpO1xuICBsZXQgb3V0cHV0VmFyID0gb3V0cHV0LnYoYik7XG4gIHJldHVybiBhc3luY1ZhbChiLCBgbmV3IFByb21pc2UoKGAgKyByZXNvbHZlVmFyICsgYCxgICsgcmVqZWN0VmFyICsgYCk9PntsZXQgYCArIGNvdW50ZXJWYXIgKyBgPU9iamVjdC5rZXlzKGAgKyBvdXRwdXRWYXIgKyBgKS5sZW5ndGg7Zm9yKGxldCBgICsga2V5VmFyICsgYCBpbiBgICsgb3V0cHV0VmFyICsgYCl7YCArIG91dHB1dFZhciArIGBbYCArIGtleVZhciArIGBdLnRoZW4oYCArIGFzeW5jUGFyc2VSZXN1bHRWYXIgKyBgPT57YCArIG91dHB1dFZhciArIGBbYCArIGtleVZhciArIGBdPWAgKyBhc3luY1BhcnNlUmVzdWx0VmFyICsgYDtpZihgICsgY291bnRlclZhciArIGAtLT09PTEpe2AgKyByZXNvbHZlVmFyICsgYChgICsgb3V0cHV0VmFyICsgYCl9fSxgICsgcmVqZWN0VmFyICsgYCl9fSlgKTtcbn1cblxuZnVuY3Rpb24gZmFjdG9yeSQzKGl0ZW0pIHtcbiAgbGV0IG11dCA9IG5ldyBTY2hlbWEoXCJvYmplY3RcIik7XG4gIG11dC5wcm9wZXJ0aWVzID0gaW1tdXRhYmxlRW1wdHk7XG4gIG11dC5pdGVtcyA9IGltbXV0YWJsZUVtcHR5JDE7XG4gIG11dC5hZGRpdGlvbmFsSXRlbXMgPSBpdGVtO1xuICBtdXQuY29tcGlsZXIgPSBkaWN0Q29tcGlsZXI7XG4gIHJldHVybiBtdXQ7XG59XG5cbmxldCBUdXBsZSA9IHt9O1xuXG5sZXQgbWV0YWRhdGFJZCQxID0gYG06YCArIFwiU3RyaW5nLnJlZmluZW1lbnRzXCI7XG5cbmZ1bmN0aW9uIHJlZmluZW1lbnRzJDEoc2NoZW1hKSB7XG4gIGxldCBtID0gc2NoZW1hW21ldGFkYXRhSWQkMV07XG4gIGlmIChtICE9PSB1bmRlZmluZWQpIHtcbiAgICByZXR1cm4gbTtcbiAgfSBlbHNlIHtcbiAgICByZXR1cm4gW107XG4gIH1cbn1cblxubGV0IGN1aWRSZWdleCA9IC9eY1teXFxzLV17OCx9JC9pO1xuXG5sZXQgdXVpZFJlZ2V4ID0gL15bMC05YS1mQS1GXXs4fVxcYi1bMC05YS1mQS1GXXs0fVxcYi1bMC05YS1mQS1GXXs0fVxcYi1bMC05YS1mQS1GXXs0fVxcYi1bMC05YS1mQS1GXXsxMn0kL2k7XG5cbmxldCBlbWFpbFJlZ2V4ID0gL14oPyFcXC4pKD8hLipcXC5cXC4pKFtBLVowLTlfJytcXC1cXC5dKilbQS1aMC05XystXUAoW0EtWjAtOV1bQS1aMC05XFwtXSpcXC4pK1tBLVpdezIsfSQvaTtcblxubGV0IGRhdGV0aW1lUmUgPSAvXlxcZHs0fS1cXGR7Mn0tXFxkezJ9VFxcZHsyfTpcXGR7Mn06XFxkezJ9KFxcLlxcZCspP1okLztcblxubGV0IGpzb24gPSBzaGFrZW4oXCJqc29uXCIpO1xuXG5mdW5jdGlvbiBlbmFibGVKc29uKCkge1xuICBpZiAoIWpzb25bc2hha2VuUmVmXSkge1xuICAgIHJldHVybjtcbiAgfVxuICAoKGRlbGV0ZSBqc29uLmFzKSk7XG4gIGxldCBqc29uUmVmID0gbmV3IFNjaGVtYShcInJlZlwiKTtcbiAganNvblJlZi4kcmVmID0gZGVmc1BhdGggKyBqc29uTmFtZTtcbiAganNvblJlZi5uYW1lID0ganNvbk5hbWU7XG4gIGpzb24udHlwZSA9IGpzb25SZWYudHlwZTtcbiAganNvbi4kcmVmID0ganNvblJlZi4kcmVmO1xuICBqc29uLm5hbWUgPSBqc29uTmFtZTtcbiAgbGV0IGRlZnMgPSB7fTtcbiAgZGVmc1tqc29uTmFtZV0gPSB7XG4gICAgdHlwZTogXCJ1bmlvblwiLFxuICAgIGNvbXBpbGVyOiBjb21waWxlcixcbiAgICBuYW1lOiBqc29uTmFtZSxcbiAgICBoYXM6IHtcbiAgICAgIHN0cmluZzogdHJ1ZSxcbiAgICAgIGJvb2xlYW46IHRydWUsXG4gICAgICBudW1iZXI6IHRydWUsXG4gICAgICBudWxsOiB0cnVlLFxuICAgICAgb2JqZWN0OiB0cnVlLFxuICAgICAgYXJyYXk6IHRydWVcbiAgICB9LFxuICAgIGFueU9mOiBbXG4gICAgICBzdHJpbmcsXG4gICAgICBib29sLFxuICAgICAgZmxvYXQsXG4gICAgICAkJG51bGwsXG4gICAgICBmYWN0b3J5JDMoanNvblJlZiksXG4gICAgICBmYWN0b3J5JDIoanNvblJlZilcbiAgICBdXG4gIH07XG4gIGpzb24uJGRlZnMgPSBkZWZzO1xufVxuXG5mdW5jdGlvbiBpbmxpbmVKc29uU3RyaW5nKGIsIHNjaGVtYSwgc2VsZlNjaGVtYSwgcGF0aCkge1xuICBsZXQgdGFnRmxhZyA9IGZsYWdzW3NjaGVtYS50eXBlXTtcbiAgbGV0ICQkY29uc3QgPSBzY2hlbWEuY29uc3Q7XG4gIGlmICh0YWdGbGFnICYgNDgpIHtcbiAgICByZXR1cm4gYFwibnVsbFwiYDtcbiAgfSBlbHNlIGlmICh0YWdGbGFnICYgMikge1xuICAgIHJldHVybiBKU09OLnN0cmluZ2lmeShmcm9tU3RyaW5nKCQkY29uc3QpKTtcbiAgfSBlbHNlIGlmICh0YWdGbGFnICYgMTAyNCkge1xuICAgIHJldHVybiBgXCJcXFxcXCJgICsgJCRjb25zdCArIGBcXFxcXCJcImA7XG4gIH0gZWxzZSBpZiAodGFnRmxhZyAmIDEyKSB7XG4gICAgcmV0dXJuIGBcImAgKyAkJGNvbnN0ICsgYFwiYDtcbiAgfSBlbHNlIHtcbiAgICByZXR1cm4gdW5zdXBwb3J0ZWRUcmFuc2Zvcm0oYiwgc2NoZW1hLCBzZWxmU2NoZW1hLCBwYXRoKTtcbiAgfVxufVxuXG5mdW5jdGlvbiBlbmFibGVKc29uU3RyaW5nKCkge1xuICBpZiAoanNvblN0cmluZ1tzaGFrZW5SZWZdKSB7XG4gICAgKChkZWxldGUganNvblN0cmluZy5hcykpO1xuICAgIGpzb25TdHJpbmcudHlwZSA9IFwic3RyaW5nXCI7XG4gICAganNvblN0cmluZy5mb3JtYXQgPSBcImpzb25cIjtcbiAgICBqc29uU3RyaW5nLm5hbWUgPSBqc29uTmFtZSArIGAgc3RyaW5nYDtcbiAgICBqc29uU3RyaW5nLmNvbXBpbGVyID0gKGIsIGlucHV0QXJnLCBzZWxmU2NoZW1hLCBwYXRoKSA9PiB7XG4gICAgICBsZXQgaW5wdXRUYWdGbGFnID0gZmxhZ3NbaW5wdXRBcmcudHlwZV07XG4gICAgICBsZXQgaW5wdXQgPSBpbnB1dEFyZztcbiAgICAgIGlmIChpbnB1dFRhZ0ZsYWcgJiAxKSB7XG4gICAgICAgIGxldCB0byA9IHNlbGZTY2hlbWEudG87XG4gICAgICAgIGlmICh0byAmJiBjb25zdEZpZWxkIGluIHRvKSB7XG4gICAgICAgICAgbGV0IGlucHV0VmFyID0gaW5wdXQudihiKTtcbiAgICAgICAgICBiLmYgPSBpbnB1dFZhciArIGA9PT1gICsgaW5saW5lSnNvblN0cmluZyhiLCB0bywgc2VsZlNjaGVtYSwgcGF0aCkgKyBgfHxgICsgZmFpbFdpdGhBcmcoYiwgcGF0aCwgaW5wdXQgPT4gKHtcbiAgICAgICAgICAgIFRBRzogXCJJbnZhbGlkVHlwZVwiLFxuICAgICAgICAgICAgZXhwZWN0ZWQ6IHRvLFxuICAgICAgICAgICAgcmVjZWl2ZWQ6IGlucHV0XG4gICAgICAgICAgfSksIGlucHV0VmFyKSArIGA7YDtcbiAgICAgICAgICBpbnB1dCA9IGNvbnN0VmFsKGIsIHRvKTtcbiAgICAgICAgfSBlbHNlIGlmICghKHRvICYmIHRvLmZvcm1hdCA9PT0gXCJqc29uXCIpKSB7XG4gICAgICAgICAgbGV0IGlucHV0VmFyJDEgPSBpbnB1dC52KGIpO1xuICAgICAgICAgIGxldCB3aXRoVHlwZVZhbGlkYXRpb24gPSBiLmcubyAmIDE7XG4gICAgICAgICAgaWYgKHdpdGhUeXBlVmFsaWRhdGlvbikge1xuICAgICAgICAgICAgYi5mID0gdHlwZUZpbHRlckNvZGUoYiwgc3RyaW5nLCBpbnB1dCwgcGF0aCk7XG4gICAgICAgICAgfVxuICAgICAgICAgIGlmICh0byB8fCB3aXRoVHlwZVZhbGlkYXRpb24pIHtcbiAgICAgICAgICAgIGxldCB0bXA7XG4gICAgICAgICAgICBpZiAodG8pIHtcbiAgICAgICAgICAgICAganNvbmFibGVWYWxpZGF0aW9uKHRvLCB0bywgcGF0aCwgYi5nLm8pO1xuICAgICAgICAgICAgICBsZXQgdGFyZ2V0VmFsID0gYWxsb2NhdGVWYWwoYiwgdW5rbm93bik7XG4gICAgICAgICAgICAgIGlucHV0ID0gdGFyZ2V0VmFsO1xuICAgICAgICAgICAgICB0bXAgPSB0YXJnZXRWYWwuaSArIFwiPVwiO1xuICAgICAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICAgICAgdG1wID0gXCJcIjtcbiAgICAgICAgICAgIH1cbiAgICAgICAgICAgIGIuYyA9IGIuYyArIChgdHJ5e2AgKyB0bXAgKyBgSlNPTi5wYXJzZShgICsgaW5wdXRWYXIkMSArIGApfWNhdGNoKHQpe2AgKyBmYWlsV2l0aEFyZyhiLCBwYXRoLCBpbnB1dCA9PiAoe1xuICAgICAgICAgICAgICBUQUc6IFwiSW52YWxpZFR5cGVcIixcbiAgICAgICAgICAgICAgZXhwZWN0ZWQ6IHNlbGZTY2hlbWEsXG4gICAgICAgICAgICAgIHJlY2VpdmVkOiBpbnB1dFxuICAgICAgICAgICAgfSksIGlucHV0VmFyJDEpICsgYH1gKTtcbiAgICAgICAgICB9XG4gICAgICAgIH1cbiAgICAgIH0gZWxzZSB7XG4gICAgICAgIGlmIChjb25zdEZpZWxkIGluIGlucHV0KSB7XG4gICAgICAgICAgaW5wdXQgPSB2YWwoYiwgaW5saW5lSnNvblN0cmluZyhiLCBpbnB1dCwgc2VsZlNjaGVtYSwgcGF0aCksIHN0cmluZyk7XG4gICAgICAgIH0gZWxzZSBpZiAoaW5wdXRUYWdGbGFnICYgMikge1xuICAgICAgICAgIGlmIChpbnB1dC5mb3JtYXQgIT09IFwianNvblwiKSB7XG4gICAgICAgICAgICBpbnB1dCA9IHZhbChiLCBgSlNPTi5zdHJpbmdpZnkoYCArIGlucHV0LmkgKyBgKWAsIHN0cmluZyk7XG4gICAgICAgICAgfVxuICAgICAgICB9IGVsc2UgaWYgKGlucHV0VGFnRmxhZyAmIDEyKSB7XG4gICAgICAgICAgaW5wdXQgPSBpbnB1dFRvU3RyaW5nKGIsIGlucHV0KTtcbiAgICAgICAgfSBlbHNlIGlmIChpbnB1dFRhZ0ZsYWcgJiAxMDI0KSB7XG4gICAgICAgICAgaW5wdXQgPSB2YWwoYiwgYFwiXFxcXFwiXCIrYCArIGlucHV0LmkgKyBgK1wiXFxcXFwiXCJgLCBzdHJpbmcpO1xuICAgICAgICB9IGVsc2UgaWYgKGlucHV0VGFnRmxhZyAmIDE5Mikge1xuICAgICAgICAgIGpzb25hYmxlVmFsaWRhdGlvbihpbnB1dCwgaW5wdXQsIHBhdGgsIGIuZy5vKTtcbiAgICAgICAgICBsZXQgdiA9IHNlbGZTY2hlbWEuc3BhY2U7XG4gICAgICAgICAgaW5wdXQgPSB2YWwoYiwgYEpTT04uc3RyaW5naWZ5KGAgKyBpbnB1dC5pICsgKFxuICAgICAgICAgICAgdiAhPT0gdW5kZWZpbmVkICYmIHYgIT09IDAgPyBgLG51bGwsYCArIHYgOiBcIlwiXG4gICAgICAgICAgKSArIGApYCwgc3RyaW5nKTtcbiAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICB1bnN1cHBvcnRlZFRyYW5zZm9ybShiLCBpbnB1dCwgc2VsZlNjaGVtYSwgcGF0aCk7XG4gICAgICAgIH1cbiAgICAgICAgaW5wdXQuZm9ybWF0ID0gXCJqc29uXCI7XG4gICAgICB9XG4gICAgICByZXR1cm4gaW5wdXQ7XG4gICAgfTtcbiAgICByZXR1cm47XG4gIH1cbn1cblxuZnVuY3Rpb24ganNvblN0cmluZ1dpdGhTcGFjZShzcGFjZSkge1xuICBsZXQgbXV0ID0gY29weVdpdGhvdXRDYWNoZShqc29uU3RyaW5nKTtcbiAgbXV0LnNwYWNlID0gc3BhY2U7XG4gIHJldHVybiBtdXQ7XG59XG5cbmxldCBtZXRhZGF0YUlkJDIgPSBgbTpgICsgXCJJbnQucmVmaW5lbWVudHNcIjtcblxuZnVuY3Rpb24gcmVmaW5lbWVudHMkMihzY2hlbWEpIHtcbiAgbGV0IG0gPSBzY2hlbWFbbWV0YWRhdGFJZCQyXTtcbiAgaWYgKG0gIT09IHVuZGVmaW5lZCkge1xuICAgIHJldHVybiBtO1xuICB9IGVsc2Uge1xuICAgIHJldHVybiBbXTtcbiAgfVxufVxuXG5sZXQgbWV0YWRhdGFJZCQzID0gYG06YCArIFwiRmxvYXQucmVmaW5lbWVudHNcIjtcblxuZnVuY3Rpb24gcmVmaW5lbWVudHMkMyhzY2hlbWEpIHtcbiAgbGV0IG0gPSBzY2hlbWFbbWV0YWRhdGFJZCQzXTtcbiAgaWYgKG0gIT09IHVuZGVmaW5lZCkge1xuICAgIHJldHVybiBtO1xuICB9IGVsc2Uge1xuICAgIHJldHVybiBbXTtcbiAgfVxufVxuXG5mdW5jdGlvbiB0byhmcm9tLCB0YXJnZXQpIHtcbiAgaWYgKGZyb20gPT09IHRhcmdldCkge1xuICAgIHJldHVybiBmcm9tO1xuICB9IGVsc2Uge1xuICAgIHJldHVybiB1cGRhdGVPdXRwdXQoZnJvbSwgbXV0ID0+IHtcbiAgICAgIG11dC50byA9IHRhcmdldDtcbiAgICB9KTtcbiAgfVxufVxuXG5mdW5jdGlvbiBsaXN0KHNjaGVtYSkge1xuICByZXR1cm4gdHJhbnNmb3JtKGZhY3RvcnkkMihzY2hlbWEpLCBwYXJhbSA9PiAoe1xuICAgIHA6IEJlbHRfTGlzdC5mcm9tQXJyYXksXG4gICAgczogQmVsdF9MaXN0LnRvQXJyYXlcbiAgfSkpO1xufVxuXG5mdW5jdGlvbiBpbnN0YW5jZShjbGFzc18pIHtcbiAgbGV0IG11dCA9IG5ldyBTY2hlbWEoXCJpbnN0YW5jZVwiKTtcbiAgbXV0LmNsYXNzID0gY2xhc3NfO1xuICByZXR1cm4gbXV0O1xufVxuXG5mdW5jdGlvbiBtZXRhKHNjaGVtYSwgZGF0YSkge1xuICBsZXQgbXV0ID0gY29weVdpdGhvdXRDYWNoZShzY2hlbWEpO1xuICBsZXQgbmFtZSA9IGRhdGEubmFtZTtcbiAgaWYgKG5hbWUgIT09IHVuZGVmaW5lZCkge1xuICAgIGlmIChuYW1lID09PSBcIlwiKSB7XG4gICAgICBtdXQubmFtZSA9IHVuZGVmaW5lZDtcbiAgICB9IGVsc2Uge1xuICAgICAgbXV0Lm5hbWUgPSBuYW1lO1xuICAgIH1cbiAgfVxuICBsZXQgdGl0bGUgPSBkYXRhLnRpdGxlO1xuICBpZiAodGl0bGUgIT09IHVuZGVmaW5lZCkge1xuICAgIGlmICh0aXRsZSA9PT0gXCJcIikge1xuICAgICAgbXV0LnRpdGxlID0gdW5kZWZpbmVkO1xuICAgIH0gZWxzZSB7XG4gICAgICBtdXQudGl0bGUgPSB0aXRsZTtcbiAgICB9XG4gIH1cbiAgbGV0IGRlc2NyaXB0aW9uID0gZGF0YS5kZXNjcmlwdGlvbjtcbiAgaWYgKGRlc2NyaXB0aW9uICE9PSB1bmRlZmluZWQpIHtcbiAgICBpZiAoZGVzY3JpcHRpb24gPT09IFwiXCIpIHtcbiAgICAgIG11dC5kZXNjcmlwdGlvbiA9IHVuZGVmaW5lZDtcbiAgICB9IGVsc2Uge1xuICAgICAgbXV0LmRlc2NyaXB0aW9uID0gZGVzY3JpcHRpb247XG4gICAgfVxuICB9XG4gIGxldCBkZXByZWNhdGVkID0gZGF0YS5kZXByZWNhdGVkO1xuICBpZiAoZGVwcmVjYXRlZCAhPT0gdW5kZWZpbmVkKSB7XG4gICAgbXV0LmRlcHJlY2F0ZWQgPSBkZXByZWNhdGVkO1xuICB9XG4gIGxldCBleGFtcGxlcyA9IGRhdGEuZXhhbXBsZXM7XG4gIGlmIChleGFtcGxlcyAhPT0gdW5kZWZpbmVkKSB7XG4gICAgaWYgKGV4YW1wbGVzLmxlbmd0aCAhPT0gMCkge1xuICAgICAgbXV0LmV4YW1wbGVzID0gZXhhbXBsZXMubWFwKG9wZXJhdGlvbkZuKHNjaGVtYSwgMzIpKTtcbiAgICB9IGVsc2Uge1xuICAgICAgbXV0LmV4YW1wbGVzID0gdW5kZWZpbmVkO1xuICAgIH1cbiAgfVxuICByZXR1cm4gbXV0O1xufVxuXG5mdW5jdGlvbiBicmFuZChzY2hlbWEsIGlkKSB7XG4gIGxldCBtdXQgPSBjb3B5V2l0aG91dENhY2hlKHNjaGVtYSk7XG4gIG11dC5uYW1lID0gaWQ7XG4gIHJldHVybiBtdXQ7XG59XG5cbmZ1bmN0aW9uIGdldEZ1bGxEaXRlbVBhdGgoZGl0ZW0pIHtcbiAgc3dpdGNoIChkaXRlbS5rKSB7XG4gICAgY2FzZSAwIDpcbiAgICAgIHJldHVybiBgW2AgKyBmcm9tU3RyaW5nKGRpdGVtLmxvY2F0aW9uKSArIGBdYDtcbiAgICBjYXNlIDEgOlxuICAgICAgcmV0dXJuIGdldEZ1bGxEaXRlbVBhdGgoZGl0ZW0ub2YpICsgZGl0ZW0ucDtcbiAgICBjYXNlIDIgOlxuICAgICAgcmV0dXJuIGRpdGVtLnA7XG4gIH1cbn1cblxuZnVuY3Rpb24gZGVmaW5pdGlvblRvT3V0cHV0KGIsIGRlZmluaXRpb24sIGdldEl0ZW1PdXRwdXQsIG91dHB1dFNjaGVtYSkge1xuICBpZiAoY29uc3RGaWVsZCBpbiBvdXRwdXRTY2hlbWEpIHtcbiAgICByZXR1cm4gY29uc3RWYWwoYiwgb3V0cHV0U2NoZW1hKTtcbiAgfVxuICBsZXQgaXRlbSA9IGRlZmluaXRpb25baXRlbVN5bWJvbF07XG4gIGlmIChpdGVtICE9PSB1bmRlZmluZWQpIHtcbiAgICByZXR1cm4gZ2V0SXRlbU91dHB1dChpdGVtKTtcbiAgfVxuICBsZXQgaXNBcnJheSA9IGZsYWdzW291dHB1dFNjaGVtYS50eXBlXSAmIDEyODtcbiAgbGV0IG9iamVjdFZhbCA9IG1ha2UoYiwgaXNBcnJheSk7XG4gIG91dHB1dFNjaGVtYS5pdGVtcy5mb3JFYWNoKGl0ZW0gPT4gYWRkKG9iamVjdFZhbCwgaXRlbS5sb2NhdGlvbiwgZGVmaW5pdGlvblRvT3V0cHV0KGIsIGRlZmluaXRpb25baXRlbS5sb2NhdGlvbl0sIGdldEl0ZW1PdXRwdXQsIGl0ZW0uc2NoZW1hKSkpO1xuICByZXR1cm4gY29tcGxldGUob2JqZWN0VmFsLCBpc0FycmF5KTtcbn1cblxuZnVuY3Rpb24gb2JqZWN0U3RyaWN0TW9kZUNoZWNrKGIsIGlucHV0LCBpdGVtcywgc2VsZlNjaGVtYSwgcGF0aCkge1xuICBpZiAoIShzZWxmU2NoZW1hLnR5cGUgPT09IFwib2JqZWN0XCIgJiYgc2VsZlNjaGVtYS5hZGRpdGlvbmFsSXRlbXMgPT09IFwic3RyaWN0XCIgJiYgYi5nLm8gJiAxKSkge1xuICAgIHJldHVybjtcbiAgfVxuICBsZXQga2V5ID0gYWxsb2NhdGVWYWwoYiwgdW5rbm93bik7XG4gIGxldCBrZXlWYXIgPSBrZXkuaTtcbiAgYi5jID0gYi5jICsgKGBmb3IoYCArIGtleVZhciArIGAgaW4gYCArIGlucHV0LnYoYikgKyBgKXtpZihgKTtcbiAgaWYgKGl0ZW1zLmxlbmd0aCAhPT0gMCkge1xuICAgIGZvciAobGV0IGlkeCA9IDAsIGlkeF9maW5pc2ggPSBpdGVtcy5sZW5ndGg7IGlkeCA8IGlkeF9maW5pc2g7ICsraWR4KSB7XG4gICAgICBsZXQgbWF0Y2ggPSBpdGVtc1tpZHhdO1xuICAgICAgaWYgKGlkeCAhPT0gMCkge1xuICAgICAgICBiLmMgPSBiLmMgKyBcIiYmXCI7XG4gICAgICB9XG4gICAgICBiLmMgPSBiLmMgKyAoa2V5VmFyICsgYCE9PWAgKyBpbmxpbmVMb2NhdGlvbihiLCBtYXRjaC5sb2NhdGlvbikpO1xuICAgIH1cbiAgfSBlbHNlIHtcbiAgICBiLmMgPSBiLmMgKyBcInRydWVcIjtcbiAgfVxuICBiLmMgPSBiLmMgKyAoYCl7YCArIGZhaWxXaXRoQXJnKGIsIHBhdGgsIGV4Y2Nlc3NGaWVsZE5hbWUgPT4gKHtcbiAgICBUQUc6IFwiRXhjZXNzRmllbGRcIixcbiAgICBfMDogZXhjY2Vzc0ZpZWxkTmFtZVxuICB9KSwga2V5VmFyKSArIGB9fWApO1xufVxuXG5mdW5jdGlvbiBwcm94aWZ5KGl0ZW0pIHtcbiAgcmV0dXJuIG5ldyBQcm94eShpbW11dGFibGVFbXB0eSwge1xuICAgIGdldDogKHBhcmFtLCBwcm9wKSA9PiB7XG4gICAgICBpZiAocHJvcCA9PT0gaXRlbVN5bWJvbCkge1xuICAgICAgICByZXR1cm4gaXRlbTtcbiAgICAgIH1cbiAgICAgIGxldCBpbmxpbmVkTG9jYXRpb24gPSBmcm9tU3RyaW5nKHByb3ApO1xuICAgICAgbGV0IHRhcmdldFJldmVyc2VkID0gZ2V0T3V0cHV0U2NoZW1hKGl0ZW0uc2NoZW1hKTtcbiAgICAgIGxldCBpdGVtcyA9IHRhcmdldFJldmVyc2VkLml0ZW1zO1xuICAgICAgbGV0IHByb3BlcnRpZXMgPSB0YXJnZXRSZXZlcnNlZC5wcm9wZXJ0aWVzO1xuICAgICAgbGV0IG1heWJlRmllbGQ7XG4gICAgICBpZiAocHJvcGVydGllcyAhPT0gdW5kZWZpbmVkKSB7XG4gICAgICAgIG1heWJlRmllbGQgPSBwcm9wZXJ0aWVzW3Byb3BdO1xuICAgICAgfSBlbHNlIGlmIChpdGVtcyAhPT0gdW5kZWZpbmVkKSB7XG4gICAgICAgIGxldCBpID0gaXRlbXNbcHJvcF07XG4gICAgICAgIG1heWJlRmllbGQgPSBpICE9PSB1bmRlZmluZWQgPyBpLnNjaGVtYSA6IHVuZGVmaW5lZDtcbiAgICAgIH0gZWxzZSB7XG4gICAgICAgIG1heWJlRmllbGQgPSB1bmRlZmluZWQ7XG4gICAgICB9XG4gICAgICBpZiAobWF5YmVGaWVsZCA9PT0gdW5kZWZpbmVkKSB7XG4gICAgICAgIGxldCBtZXNzYWdlID0gYENhbm5vdCByZWFkIHByb3BlcnR5IGAgKyBpbmxpbmVkTG9jYXRpb24gKyBgIG9mIGAgKyB0b0V4cHJlc3Npb24odGFyZ2V0UmV2ZXJzZWQpO1xuICAgICAgICB0aHJvdyBuZXcgRXJyb3IoYFtTdXJ5XSBgICsgbWVzc2FnZSk7XG4gICAgICB9XG4gICAgICByZXR1cm4gcHJveGlmeSh7XG4gICAgICAgIGs6IDEsXG4gICAgICAgIGxvY2F0aW9uOiBwcm9wLFxuICAgICAgICBzY2hlbWE6IG1heWJlRmllbGQsXG4gICAgICAgIG9mOiBpdGVtLFxuICAgICAgICBwOiBgW2AgKyBpbmxpbmVkTG9jYXRpb24gKyBgXWBcbiAgICAgIH0pO1xuICAgIH1cbiAgfSk7XG59XG5cbmZ1bmN0aW9uIHNjaGVtYUNvbXBpbGVyKGIsIGlucHV0LCBzZWxmU2NoZW1hLCBwYXRoKSB7XG4gIGxldCBhZGRpdGlvbmFsSXRlbXMgPSBzZWxmU2NoZW1hLmFkZGl0aW9uYWxJdGVtcztcbiAgbGV0IGl0ZW1zID0gc2VsZlNjaGVtYS5pdGVtcztcbiAgbGV0IGlzQXJyYXkgPSBmbGFnc1tzZWxmU2NoZW1hLnR5cGVdICYgMTI4O1xuICBpZiAoYi5nLm8gJiA2NCkge1xuICAgIGxldCBvYmplY3RWYWwgPSBtYWtlKGIsIGlzQXJyYXkpO1xuICAgIGZvciAobGV0IGlkeCA9IDAsIGlkeF9maW5pc2ggPSBpdGVtcy5sZW5ndGg7IGlkeCA8IGlkeF9maW5pc2g7ICsraWR4KSB7XG4gICAgICBsZXQgbWF0Y2ggPSBpdGVtc1tpZHhdO1xuICAgICAgbGV0IGxvY2F0aW9uID0gbWF0Y2gubG9jYXRpb247XG4gICAgICBhZGQob2JqZWN0VmFsLCBsb2NhdGlvbiwgaW5wdXQucHJvcGVydGllc1tsb2NhdGlvbl0pO1xuICAgIH1cbiAgICByZXR1cm4gY29tcGxldGUob2JqZWN0VmFsLCBpc0FycmF5KTtcbiAgfVxuICBsZXQgb2JqZWN0VmFsJDEgPSBtYWtlKGIsIGlzQXJyYXkpO1xuICBmb3IgKGxldCBpZHgkMSA9IDAsIGlkeF9maW5pc2gkMSA9IGl0ZW1zLmxlbmd0aDsgaWR4JDEgPCBpZHhfZmluaXNoJDE7ICsraWR4JDEpIHtcbiAgICBsZXQgbWF0Y2gkMSA9IGl0ZW1zW2lkeCQxXTtcbiAgICBsZXQgbG9jYXRpb24kMSA9IG1hdGNoJDEubG9jYXRpb247XG4gICAgbGV0IGl0ZW1JbnB1dCA9IGdldChiLCBpbnB1dCwgbG9jYXRpb24kMSk7XG4gICAgbGV0IGlubGluZWRMb2NhdGlvbiA9IGlubGluZUxvY2F0aW9uKGIsIGxvY2F0aW9uJDEpO1xuICAgIGxldCBwYXRoJDEgPSBwYXRoICsgKGBbYCArIGlubGluZWRMb2NhdGlvbiArIGBdYCk7XG4gICAgYWRkKG9iamVjdFZhbCQxLCBsb2NhdGlvbiQxLCBwYXJzZShiLCBtYXRjaCQxLnNjaGVtYSwgaXRlbUlucHV0LCBwYXRoJDEpKTtcbiAgfVxuICBvYmplY3RTdHJpY3RNb2RlQ2hlY2soYiwgaW5wdXQsIGl0ZW1zLCBzZWxmU2NoZW1hLCBwYXRoKTtcbiAgaWYgKChhZGRpdGlvbmFsSXRlbXMgIT09IFwic3RyaXBcIiB8fCBiLmcubyAmIDMyKSAmJiBpdGVtcy5ldmVyeShpdGVtID0+IG9iamVjdFZhbCQxLnByb3BlcnRpZXNbaXRlbS5sb2NhdGlvbl0gPT09IGlucHV0LnByb3BlcnRpZXNbaXRlbS5sb2NhdGlvbl0pKSB7XG4gICAgaW5wdXQuYWRkaXRpb25hbEl0ZW1zID0gXCJzdHJpcFwiO1xuICAgIHJldHVybiBpbnB1dDtcbiAgfSBlbHNlIHtcbiAgICByZXR1cm4gY29tcGxldGUob2JqZWN0VmFsJDEsIGlzQXJyYXkpO1xuICB9XG59XG5cbmZ1bmN0aW9uIGRlZmluaXRpb25Ub1NjaGVtYShkZWZpbml0aW9uKSB7XG4gIGlmICh0eXBlb2YgZGVmaW5pdGlvbiAhPT0gXCJvYmplY3RcIiB8fCBkZWZpbml0aW9uID09PSBudWxsKSB7XG4gICAgcmV0dXJuIHBhcnNlJDEoZGVmaW5pdGlvbik7XG4gIH1cbiAgaWYgKGRlZmluaXRpb25bXCJ+c3RhbmRhcmRcIl0pIHtcbiAgICByZXR1cm4gZGVmaW5pdGlvbjtcbiAgfVxuICBpZiAoQXJyYXkuaXNBcnJheShkZWZpbml0aW9uKSkge1xuICAgIGZvciAobGV0IGlkeCA9IDAsIGlkeF9maW5pc2ggPSBkZWZpbml0aW9uLmxlbmd0aDsgaWR4IDwgaWR4X2ZpbmlzaDsgKytpZHgpIHtcbiAgICAgIGxldCBzY2hlbWEgPSBkZWZpbml0aW9uVG9TY2hlbWEoZGVmaW5pdGlvbltpZHhdKTtcbiAgICAgIGxldCBsb2NhdGlvbiA9IGlkeC50b1N0cmluZygpO1xuICAgICAgZGVmaW5pdGlvbltpZHhdID0ge1xuICAgICAgICBzY2hlbWE6IHNjaGVtYSxcbiAgICAgICAgbG9jYXRpb246IGxvY2F0aW9uXG4gICAgICB9O1xuICAgIH1cbiAgICBsZXQgbXV0ID0gbmV3IFNjaGVtYShcImFycmF5XCIpO1xuICAgIG11dC5pdGVtcyA9IGRlZmluaXRpb247XG4gICAgbXV0LmFkZGl0aW9uYWxJdGVtcyA9IFwic3RyaWN0XCI7XG4gICAgbXV0LmNvbXBpbGVyID0gc2NoZW1hQ29tcGlsZXI7XG4gICAgcmV0dXJuIG11dDtcbiAgfVxuICBsZXQgY25zdHIgPSBkZWZpbml0aW9uLmNvbnN0cnVjdG9yO1xuICBpZiAoY25zdHIgJiYgY25zdHIgIT09IE9iamVjdCkge1xuICAgIHJldHVybiB7XG4gICAgICB0eXBlOiBcImluc3RhbmNlXCIsXG4gICAgICBjb25zdDogZGVmaW5pdGlvbixcbiAgICAgIGNsYXNzOiBjbnN0clxuICAgIH07XG4gIH1cbiAgbGV0IGZpZWxkTmFtZXMgPSBPYmplY3Qua2V5cyhkZWZpbml0aW9uKTtcbiAgbGV0IGxlbmd0aCA9IGZpZWxkTmFtZXMubGVuZ3RoO1xuICBsZXQgaXRlbXMgPSBbXTtcbiAgZm9yIChsZXQgaWR4JDEgPSAwOyBpZHgkMSA8IGxlbmd0aDsgKytpZHgkMSkge1xuICAgIGxldCBsb2NhdGlvbiQxID0gZmllbGROYW1lc1tpZHgkMV07XG4gICAgbGV0IHNjaGVtYSQxID0gZGVmaW5pdGlvblRvU2NoZW1hKGRlZmluaXRpb25bbG9jYXRpb24kMV0pO1xuICAgIGxldCBpdGVtID0ge1xuICAgICAgc2NoZW1hOiBzY2hlbWEkMSxcbiAgICAgIGxvY2F0aW9uOiBsb2NhdGlvbiQxXG4gICAgfTtcbiAgICBkZWZpbml0aW9uW2xvY2F0aW9uJDFdID0gc2NoZW1hJDE7XG4gICAgaXRlbXNbaWR4JDFdID0gaXRlbTtcbiAgfVxuICBsZXQgbXV0JDEgPSBuZXcgU2NoZW1hKFwib2JqZWN0XCIpO1xuICBtdXQkMS5pdGVtcyA9IGl0ZW1zO1xuICBtdXQkMS5wcm9wZXJ0aWVzID0gZGVmaW5pdGlvbjtcbiAgbXV0JDEuYWRkaXRpb25hbEl0ZW1zID0gZ2xvYmFsQ29uZmlnLmE7XG4gIG11dCQxLmNvbXBpbGVyID0gc2NoZW1hQ29tcGlsZXI7XG4gIHJldHVybiBtdXQkMTtcbn1cblxuZnVuY3Rpb24gbmVzdGVkKGZpZWxkTmFtZSkge1xuICBsZXQgcGFyZW50Q3R4ID0gdGhpcztcbiAgbGV0IGNhY2hlSWQgPSBgfmAgKyBmaWVsZE5hbWU7XG4gIGxldCBjdHggPSBwYXJlbnRDdHhbY2FjaGVJZF07XG4gIGlmIChjdHggIT09IHVuZGVmaW5lZCkge1xuICAgIHJldHVybiBQcmltaXRpdmVfb3B0aW9uLnZhbEZyb21PcHRpb24oY3R4KTtcbiAgfVxuICBsZXQgc2NoZW1hcyA9IFtdO1xuICBsZXQgcHJvcGVydGllcyA9IHt9O1xuICBsZXQgaXRlbXMgPSBbXTtcbiAgbGV0IHNjaGVtYSA9IG5ldyBTY2hlbWEoXCJvYmplY3RcIik7XG4gIHNjaGVtYS5pdGVtcyA9IGl0ZW1zO1xuICBzY2hlbWEucHJvcGVydGllcyA9IHByb3BlcnRpZXM7XG4gIHNjaGVtYS5hZGRpdGlvbmFsSXRlbXMgPSBnbG9iYWxDb25maWcuYTtcbiAgc2NoZW1hLmNvbXBpbGVyID0gc2NoZW1hQ29tcGlsZXI7XG4gIGxldCB0YXJnZXQgPSBwYXJlbnRDdHguZihmaWVsZE5hbWUsIHNjaGVtYSlbaXRlbVN5bWJvbF07XG4gIGxldCBmaWVsZCA9IChmaWVsZE5hbWUsIHNjaGVtYSkgPT4ge1xuICAgIGxldCBpbmxpbmVkTG9jYXRpb24gPSBmcm9tU3RyaW5nKGZpZWxkTmFtZSk7XG4gICAgaWYgKGZpZWxkTmFtZSBpbiBwcm9wZXJ0aWVzKSB7XG4gICAgICB0aHJvdyBuZXcgRXJyb3IoYFtTdXJ5XSBgICsgKGBUaGUgZmllbGQgYCArIGlubGluZWRMb2NhdGlvbiArIGAgZGVmaW5lZCB0d2ljZWApKTtcbiAgICB9XG4gICAgbGV0IGRpdGVtXzMgPSBgW2AgKyBpbmxpbmVkTG9jYXRpb24gKyBgXWA7XG4gICAgbGV0IGRpdGVtID0ge1xuICAgICAgazogMSxcbiAgICAgIGxvY2F0aW9uOiBmaWVsZE5hbWUsXG4gICAgICBzY2hlbWE6IHNjaGVtYSxcbiAgICAgIG9mOiB0YXJnZXQsXG4gICAgICBwOiBkaXRlbV8zXG4gICAgfTtcbiAgICBwcm9wZXJ0aWVzW2ZpZWxkTmFtZV0gPSBzY2hlbWE7XG4gICAgaXRlbXMucHVzaChkaXRlbSk7XG4gICAgc2NoZW1hcy5wdXNoKHNjaGVtYSk7XG4gICAgcmV0dXJuIHByb3hpZnkoZGl0ZW0pO1xuICB9O1xuICBsZXQgdGFnID0gKHRhZyQxLCBhc1ZhbHVlKSA9PiB7XG4gICAgZmllbGQodGFnJDEsIGRlZmluaXRpb25Ub1NjaGVtYShhc1ZhbHVlKSk7XG4gIH07XG4gIGxldCBmaWVsZE9yID0gKGZpZWxkTmFtZSwgc2NoZW1hLCBvcikgPT4ge1xuICAgIGxldCBzY2hlbWEkMSA9IGZhY3RvcnkkMShzY2hlbWEsIHVuZGVmaW5lZCk7XG4gICAgcmV0dXJuIGZpZWxkKGZpZWxkTmFtZSwgZ2V0V2l0aERlZmF1bHQoc2NoZW1hJDEsIHtcbiAgICAgIFRBRzogXCJWYWx1ZVwiLFxuICAgICAgXzA6IG9yXG4gICAgfSkpO1xuICB9O1xuICBsZXQgZmxhdHRlbiA9IHNjaGVtYSA9PiB7XG4gICAgbGV0IG1hdGNoID0gc2NoZW1hLnR5cGU7XG4gICAgaWYgKG1hdGNoID09PSBcIm9iamVjdFwiKSB7XG4gICAgICBsZXQgdG8gPSBzY2hlbWEudG87XG4gICAgICBsZXQgZmxhdHRlbmVkSXRlbXMgPSBzY2hlbWEuaXRlbXM7XG4gICAgICBpZiAodG8pIHtcbiAgICAgICAgbGV0IG1lc3NhZ2UgPSBgVW5zdXBwb3J0ZWQgbmVzdGVkIGZsYXR0ZW4gZm9yIHRyYW5zZm9ybWVkIG9iamVjdCBzY2hlbWEgYCArIHRvRXhwcmVzc2lvbihzY2hlbWEpO1xuICAgICAgICB0aHJvdyBuZXcgRXJyb3IoYFtTdXJ5XSBgICsgbWVzc2FnZSk7XG4gICAgICB9XG4gICAgICBsZXQgcmVzdWx0ID0ge307XG4gICAgICBmb3IgKGxldCBpZHggPSAwLCBpZHhfZmluaXNoID0gZmxhdHRlbmVkSXRlbXMubGVuZ3RoOyBpZHggPCBpZHhfZmluaXNoOyArK2lkeCkge1xuICAgICAgICBsZXQgaXRlbSA9IGZsYXR0ZW5lZEl0ZW1zW2lkeF07XG4gICAgICAgIHJlc3VsdFtpdGVtLmxvY2F0aW9uXSA9IGZpZWxkKGl0ZW0ubG9jYXRpb24sIGl0ZW0uc2NoZW1hKTtcbiAgICAgIH1cbiAgICAgIHJldHVybiByZXN1bHQ7XG4gICAgfVxuICAgIGxldCBtZXNzYWdlJDEgPSBgQ2FuJ3QgZmxhdHRlbiBgICsgdG9FeHByZXNzaW9uKHNjaGVtYSkgKyBgIHNjaGVtYWA7XG4gICAgdGhyb3cgbmV3IEVycm9yKGBbU3VyeV0gYCArIG1lc3NhZ2UkMSk7XG4gIH07XG4gIGxldCBjdHgkMSA9IHtcbiAgICBmaWVsZDogZmllbGQsXG4gICAgZjogZmllbGQsXG4gICAgZmllbGRPcjogZmllbGRPcixcbiAgICB0YWc6IHRhZyxcbiAgICBuZXN0ZWQ6IG5lc3RlZCxcbiAgICBmbGF0dGVuOiBmbGF0dGVuXG4gIH07XG4gIHBhcmVudEN0eFtjYWNoZUlkXSA9IGN0eCQxO1xuICByZXR1cm4gY3R4JDE7XG59XG5cbmZ1bmN0aW9uIGRlZmluaXRpb25Ub1JpdGVtKGRlZmluaXRpb24sIHBhdGgsIHJpdGVtc0J5SXRlbVBhdGgpIHtcbiAgaWYgKHR5cGVvZiBkZWZpbml0aW9uICE9PSBcIm9iamVjdFwiIHx8IGRlZmluaXRpb24gPT09IG51bGwpIHtcbiAgICByZXR1cm4ge1xuICAgICAgazogMSxcbiAgICAgIHA6IHBhdGgsXG4gICAgICBzOiBjb3B5V2l0aG91dENhY2hlKHBhcnNlJDEoZGVmaW5pdGlvbikpXG4gICAgfTtcbiAgfVxuICBsZXQgaXRlbSA9IGRlZmluaXRpb25baXRlbVN5bWJvbF07XG4gIGlmIChpdGVtICE9PSB1bmRlZmluZWQpIHtcbiAgICBsZXQgcml0ZW1TY2hlbWEgPSBjb3B5V2l0aG91dENhY2hlKGdldE91dHB1dFNjaGVtYShpdGVtLnNjaGVtYSkpO1xuICAgICgoZGVsZXRlIHJpdGVtU2NoZW1hLnNlcmlhbGl6ZXIpKTtcbiAgICBsZXQgcml0ZW0gPSB7XG4gICAgICBrOiAwLFxuICAgICAgcDogcGF0aCxcbiAgICAgIHM6IHJpdGVtU2NoZW1hXG4gICAgfTtcbiAgICBpdGVtLnIgPSByaXRlbTtcbiAgICByaXRlbXNCeUl0ZW1QYXRoW2dldEZ1bGxEaXRlbVBhdGgoaXRlbSldID0gcml0ZW07XG4gICAgcmV0dXJuIHJpdGVtO1xuICB9XG4gIGlmIChBcnJheS5pc0FycmF5KGRlZmluaXRpb24pKSB7XG4gICAgbGV0IGl0ZW1zID0gW107XG4gICAgZm9yIChsZXQgaWR4ID0gMCwgaWR4X2ZpbmlzaCA9IGRlZmluaXRpb24ubGVuZ3RoOyBpZHggPCBpZHhfZmluaXNoOyArK2lkeCkge1xuICAgICAgbGV0IGxvY2F0aW9uID0gaWR4LnRvU3RyaW5nKCk7XG4gICAgICBsZXQgaW5saW5lZExvY2F0aW9uID0gYFwiYCArIGxvY2F0aW9uICsgYFwiYDtcbiAgICAgIGxldCByaXRlbSQxID0gZGVmaW5pdGlvblRvUml0ZW0oZGVmaW5pdGlvbltpZHhdLCBwYXRoICsgKGBbYCArIGlubGluZWRMb2NhdGlvbiArIGBdYCksIHJpdGVtc0J5SXRlbVBhdGgpO1xuICAgICAgbGV0IGl0ZW1fc2NoZW1hID0gcml0ZW0kMS5zO1xuICAgICAgbGV0IGl0ZW0kMSA9IHtcbiAgICAgICAgc2NoZW1hOiBpdGVtX3NjaGVtYSxcbiAgICAgICAgbG9jYXRpb246IGxvY2F0aW9uXG4gICAgICB9O1xuICAgICAgaXRlbXNbaWR4XSA9IGl0ZW0kMTtcbiAgICB9XG4gICAgbGV0IG11dCA9IG5ldyBTY2hlbWEoXCJhcnJheVwiKTtcbiAgICByZXR1cm4ge1xuICAgICAgazogMixcbiAgICAgIHA6IHBhdGgsXG4gICAgICBzOiAobXV0Lml0ZW1zID0gaXRlbXMsIG11dC5hZGRpdGlvbmFsSXRlbXMgPSBcInN0cmljdFwiLCBtdXQuc2VyaWFsaXplciA9IG5ldmVyQnVpbGRlciwgbXV0KVxuICAgIH07XG4gIH1cbiAgbGV0IGZpZWxkTmFtZXMgPSBPYmplY3Qua2V5cyhkZWZpbml0aW9uKTtcbiAgbGV0IHByb3BlcnRpZXMgPSB7fTtcbiAgbGV0IGl0ZW1zJDEgPSBbXTtcbiAgZm9yIChsZXQgaWR4JDEgPSAwLCBpZHhfZmluaXNoJDEgPSBmaWVsZE5hbWVzLmxlbmd0aDsgaWR4JDEgPCBpZHhfZmluaXNoJDE7ICsraWR4JDEpIHtcbiAgICBsZXQgbG9jYXRpb24kMSA9IGZpZWxkTmFtZXNbaWR4JDFdO1xuICAgIGxldCBpbmxpbmVkTG9jYXRpb24kMSA9IGZyb21TdHJpbmcobG9jYXRpb24kMSk7XG4gICAgbGV0IHJpdGVtJDIgPSBkZWZpbml0aW9uVG9SaXRlbShkZWZpbml0aW9uW2xvY2F0aW9uJDFdLCBwYXRoICsgKGBbYCArIGlubGluZWRMb2NhdGlvbiQxICsgYF1gKSwgcml0ZW1zQnlJdGVtUGF0aCk7XG4gICAgbGV0IGl0ZW1fc2NoZW1hJDEgPSByaXRlbSQyLnM7XG4gICAgbGV0IGl0ZW0kMiA9IHtcbiAgICAgIHNjaGVtYTogaXRlbV9zY2hlbWEkMSxcbiAgICAgIGxvY2F0aW9uOiBsb2NhdGlvbiQxXG4gICAgfTtcbiAgICBpdGVtcyQxW2lkeCQxXSA9IGl0ZW0kMjtcbiAgICBwcm9wZXJ0aWVzW2xvY2F0aW9uJDFdID0gaXRlbV9zY2hlbWEkMTtcbiAgfVxuICBsZXQgbXV0JDEgPSBuZXcgU2NoZW1hKFwib2JqZWN0XCIpO1xuICByZXR1cm4ge1xuICAgIGs6IDIsXG4gICAgcDogcGF0aCxcbiAgICBzOiAobXV0JDEuaXRlbXMgPSBpdGVtcyQxLCBtdXQkMS5wcm9wZXJ0aWVzID0gcHJvcGVydGllcywgbXV0JDEuYWRkaXRpb25hbEl0ZW1zID0gZ2xvYmFsQ29uZmlnLmEsIG11dCQxLnNlcmlhbGl6ZXIgPSBuZXZlckJ1aWxkZXIsIG11dCQxKVxuICB9O1xufVxuXG5mdW5jdGlvbiBkZWZpbml0aW9uVG9UYXJnZXQoZGVmaW5pdGlvbiwgdG8sIGZsYXR0ZW5lZCkge1xuICBsZXQgcml0ZW1zQnlJdGVtUGF0aCA9IHt9O1xuICBsZXQgcml0ZW0gPSBkZWZpbml0aW9uVG9SaXRlbShkZWZpbml0aW9uLCBcIlwiLCByaXRlbXNCeUl0ZW1QYXRoKTtcbiAgbGV0IG11dCA9IHJpdGVtLnM7XG4gICgoZGVsZXRlIG11dC5yZWZpbmVyKSk7XG4gICgoZGVsZXRlIG11dC5jb21waWxlcikpO1xuICBtdXQuc2VyaWFsaXplciA9IChiLCBpbnB1dCwgc2VsZlNjaGVtYSwgcGF0aCkgPT4ge1xuICAgIGxldCBnZXRSaXRlbUlucHV0ID0gcml0ZW0gPT4ge1xuICAgICAgbGV0IHJpdGVtUGF0aCA9IHJpdGVtLnA7XG4gICAgICBpZiAocml0ZW1QYXRoID09PSBcIlwiKSB7XG4gICAgICAgIHJldHVybiBpbnB1dDtcbiAgICAgIH1cbiAgICAgIGxldCBfaW5wdXQgPSBpbnB1dDtcbiAgICAgIGxldCBfbG9jYXRpb25zID0gdG9BcnJheShyaXRlbVBhdGgpO1xuICAgICAgd2hpbGUgKHRydWUpIHtcbiAgICAgICAgbGV0IGxvY2F0aW9ucyA9IF9sb2NhdGlvbnM7XG4gICAgICAgIGxldCBpbnB1dCQxID0gX2lucHV0O1xuICAgICAgICBpZiAobG9jYXRpb25zLmxlbmd0aCA9PT0gMCkge1xuICAgICAgICAgIHJldHVybiBpbnB1dCQxO1xuICAgICAgICB9XG4gICAgICAgIGxldCBsb2NhdGlvbiA9IGxvY2F0aW9uc1swXTtcbiAgICAgICAgX2xvY2F0aW9ucyA9IGxvY2F0aW9ucy5zbGljZSgxKTtcbiAgICAgICAgX2lucHV0ID0gZ2V0KGIsIGlucHV0JDEsIGxvY2F0aW9uKTtcbiAgICAgICAgY29udGludWU7XG4gICAgICB9O1xuICAgIH07XG4gICAgbGV0IHNjaGVtYVRvT3V0cHV0ID0gKHNjaGVtYSwgb3JpZ2luYWxQYXRoKSA9PiB7XG4gICAgICBsZXQgb3V0cHV0U2NoZW1hID0gZ2V0T3V0cHV0U2NoZW1hKHNjaGVtYSk7XG4gICAgICBpZiAoY29uc3RGaWVsZCBpbiBvdXRwdXRTY2hlbWEpIHtcbiAgICAgICAgcmV0dXJuIGNvbnN0VmFsKGIsIG91dHB1dFNjaGVtYSk7XG4gICAgICB9XG4gICAgICBpZiAoY29uc3RGaWVsZCBpbiBzY2hlbWEpIHtcbiAgICAgICAgcmV0dXJuIHBhcnNlKGIsIHNjaGVtYSwgY29uc3RWYWwoYiwgc2NoZW1hKSwgcGF0aCk7XG4gICAgICB9XG4gICAgICBsZXQgdGFnID0gb3V0cHV0U2NoZW1hLnR5cGU7XG4gICAgICBsZXQgYWRkaXRpb25hbEl0ZW1zID0gb3V0cHV0U2NoZW1hLmFkZGl0aW9uYWxJdGVtcztcbiAgICAgIGxldCBpdGVtcyA9IG91dHB1dFNjaGVtYS5pdGVtcztcbiAgICAgIGlmIChpdGVtcyAhPT0gdW5kZWZpbmVkICYmIHR5cGVvZiBhZGRpdGlvbmFsSXRlbXMgPT09IFwic3RyaW5nXCIpIHtcbiAgICAgICAgbGV0IGlzQXJyYXkgPSBmbGFnc1t0YWddICYgMTI4O1xuICAgICAgICBsZXQgb2JqZWN0VmFsID0gbWFrZShiLCBpc0FycmF5KTtcbiAgICAgICAgZm9yIChsZXQgaWR4ID0gMCwgaWR4X2ZpbmlzaCA9IGl0ZW1zLmxlbmd0aDsgaWR4IDwgaWR4X2ZpbmlzaDsgKytpZHgpIHtcbiAgICAgICAgICBsZXQgaXRlbSA9IGl0ZW1zW2lkeF07XG4gICAgICAgICAgbGV0IGlubGluZWRMb2NhdGlvbiA9IGlubGluZUxvY2F0aW9uKGIsIGl0ZW0ubG9jYXRpb24pO1xuICAgICAgICAgIGxldCBpdGVtUGF0aCA9IG9yaWdpbmFsUGF0aCArIChgW2AgKyBpbmxpbmVkTG9jYXRpb24gKyBgXWApO1xuICAgICAgICAgIGxldCByaXRlbSA9IHJpdGVtc0J5SXRlbVBhdGhbaXRlbVBhdGhdO1xuICAgICAgICAgIGxldCBpdGVtSW5wdXQgPSByaXRlbSAhPT0gdW5kZWZpbmVkID8gcGFyc2UoYiwgaXRlbS5zY2hlbWEsIGdldFJpdGVtSW5wdXQocml0ZW0pLCByaXRlbS5wKSA6IHNjaGVtYVRvT3V0cHV0KGl0ZW0uc2NoZW1hLCBpdGVtUGF0aCk7XG4gICAgICAgICAgYWRkKG9iamVjdFZhbCwgaXRlbS5sb2NhdGlvbiwgaXRlbUlucHV0KTtcbiAgICAgICAgfVxuICAgICAgICByZXR1cm4gY29tcGxldGUob2JqZWN0VmFsLCBpc0FycmF5KTtcbiAgICAgIH1cbiAgICAgIGxldCB0bXAgPSBvcmlnaW5hbFBhdGggPT09IFwiXCIgPyBgU2NoZW1hIGlzbid0IHJlZ2lzdGVyZWRgIDogYFNjaGVtYSBmb3IgYCArIG9yaWdpbmFsUGF0aCArIGAgaXNuJ3QgcmVnaXN0ZXJlZGA7XG4gICAgICByZXR1cm4gaW52YWxpZE9wZXJhdGlvbihiLCBwYXRoLCB0bXApO1xuICAgIH07XG4gICAgbGV0IGdldEl0ZW1PdXRwdXQgPSAoaXRlbSwgaXRlbVBhdGgsIHNob3VsZFJldmVyc2UpID0+IHtcbiAgICAgIGxldCByaXRlbSA9IGl0ZW0ucjtcbiAgICAgIGlmIChyaXRlbSA9PT0gdW5kZWZpbmVkKSB7XG4gICAgICAgIHJldHVybiBzY2hlbWFUb091dHB1dChpdGVtLnNjaGVtYSwgaXRlbVBhdGgpO1xuICAgICAgfVxuICAgICAgbGV0IHRhcmdldFNjaGVtYSA9IHNob3VsZFJldmVyc2UgPyByZXZlcnNlKGl0ZW0uc2NoZW1hKSA6IChcbiAgICAgICAgICBpdGVtUGF0aCA9PT0gXCJcIiA/IGdldE91dHB1dFNjaGVtYShpdGVtLnNjaGVtYSkgOiBpdGVtLnNjaGVtYVxuICAgICAgICApO1xuICAgICAgbGV0IGl0ZW1JbnB1dCA9IGdldFJpdGVtSW5wdXQocml0ZW0pO1xuICAgICAgbGV0IHBhdGgkMSA9IHBhdGggKyByaXRlbS5wO1xuICAgICAgcmV0dXJuIHBhcnNlKGIsIHRhcmdldFNjaGVtYSwgaXRlbUlucHV0LCBwYXRoJDEpO1xuICAgIH07XG4gICAgaWYgKHRvICE9PSB1bmRlZmluZWQpIHtcbiAgICAgIHJldHVybiBnZXRJdGVtT3V0cHV0KHRvLCBcIlwiLCBmYWxzZSk7XG4gICAgfVxuICAgIGxldCBvcmlnaW5hbFNjaGVtYSA9IHNlbGZTY2hlbWEudG87XG4gICAgb2JqZWN0U3RyaWN0TW9kZUNoZWNrKGIsIGlucHV0LCBzZWxmU2NoZW1hLml0ZW1zLCBzZWxmU2NoZW1hLCBwYXRoKTtcbiAgICBsZXQgaXNBcnJheSA9IG9yaWdpbmFsU2NoZW1hLnR5cGUgPT09IFwiYXJyYXlcIjtcbiAgICBsZXQgaXRlbXMgPSBvcmlnaW5hbFNjaGVtYS5pdGVtcztcbiAgICBsZXQgb2JqZWN0VmFsID0gbWFrZShiLCBpc0FycmF5KTtcbiAgICBpZiAoZmxhdHRlbmVkICE9PSB1bmRlZmluZWQpIHtcbiAgICAgIGZvciAobGV0IGlkeCA9IDAsIGlkeF9maW5pc2ggPSBmbGF0dGVuZWQubGVuZ3RoOyBpZHggPCBpZHhfZmluaXNoOyArK2lkeCkge1xuICAgICAgICBtZXJnZShvYmplY3RWYWwsIGdldEl0ZW1PdXRwdXQoZmxhdHRlbmVkW2lkeF0sIFwiXCIsIHRydWUpKTtcbiAgICAgIH1cbiAgICB9XG4gICAgZm9yIChsZXQgaWR4JDEgPSAwLCBpZHhfZmluaXNoJDEgPSBpdGVtcy5sZW5ndGg7IGlkeCQxIDwgaWR4X2ZpbmlzaCQxOyArK2lkeCQxKSB7XG4gICAgICBsZXQgaXRlbSA9IGl0ZW1zW2lkeCQxXTtcbiAgICAgIGlmICghKGl0ZW0ubG9jYXRpb24gaW4gb2JqZWN0VmFsLnByb3BlcnRpZXMpKSB7XG4gICAgICAgIGxldCBpbmxpbmVkTG9jYXRpb24gPSBpbmxpbmVMb2NhdGlvbihiLCBpdGVtLmxvY2F0aW9uKTtcbiAgICAgICAgYWRkKG9iamVjdFZhbCwgaXRlbS5sb2NhdGlvbiwgZ2V0SXRlbU91dHB1dChpdGVtLCBgW2AgKyBpbmxpbmVkTG9jYXRpb24gKyBgXWAsIGZhbHNlKSk7XG4gICAgICB9XG4gICAgfVxuICAgIHJldHVybiBjb21wbGV0ZShvYmplY3RWYWwsIGlzQXJyYXkpO1xuICB9O1xuICByZXR1cm4gbXV0O1xufVxuXG5mdW5jdGlvbiBhZHZhbmNlZEJ1aWxkZXIoZGVmaW5pdGlvbiwgZmxhdHRlbmVkKSB7XG4gIHJldHVybiAoYiwgaW5wdXQsIHNlbGZTY2hlbWEsIHBhdGgpID0+IHtcbiAgICBsZXQgaXNGbGF0dGVuID0gYi5nLm8gJiA2NDtcbiAgICBsZXQgb3V0cHV0cyA9IGlzRmxhdHRlbiA/IGlucHV0LnByb3BlcnRpZXMgOiAoe30pO1xuICAgIGlmICghaXNGbGF0dGVuKSB7XG4gICAgICBsZXQgaXRlbXMgPSBzZWxmU2NoZW1hLml0ZW1zO1xuICAgICAgZm9yIChsZXQgaWR4ID0gMCwgaWR4X2ZpbmlzaCA9IGl0ZW1zLmxlbmd0aDsgaWR4IDwgaWR4X2ZpbmlzaDsgKytpZHgpIHtcbiAgICAgICAgbGV0IG1hdGNoID0gaXRlbXNbaWR4XTtcbiAgICAgICAgbGV0IGxvY2F0aW9uID0gbWF0Y2gubG9jYXRpb247XG4gICAgICAgIGxldCBpdGVtSW5wdXQgPSBnZXQoYiwgaW5wdXQsIGxvY2F0aW9uKTtcbiAgICAgICAgbGV0IGlubGluZWRMb2NhdGlvbiA9IGlubGluZUxvY2F0aW9uKGIsIGxvY2F0aW9uKTtcbiAgICAgICAgbGV0IHBhdGgkMSA9IHBhdGggKyAoYFtgICsgaW5saW5lZExvY2F0aW9uICsgYF1gKTtcbiAgICAgICAgb3V0cHV0c1tsb2NhdGlvbl0gPSBwYXJzZShiLCBtYXRjaC5zY2hlbWEsIGl0ZW1JbnB1dCwgcGF0aCQxKTtcbiAgICAgIH1cbiAgICAgIG9iamVjdFN0cmljdE1vZGVDaGVjayhiLCBpbnB1dCwgaXRlbXMsIHNlbGZTY2hlbWEsIHBhdGgpO1xuICAgIH1cbiAgICBpZiAoZmxhdHRlbmVkICE9PSB1bmRlZmluZWQpIHtcbiAgICAgIGxldCBwcmV2RmxhZyA9IGIuZy5vO1xuICAgICAgYi5nLm8gPSBwcmV2RmxhZyB8IDY0O1xuICAgICAgZm9yIChsZXQgaWR4JDEgPSAwLCBpZHhfZmluaXNoJDEgPSBmbGF0dGVuZWQubGVuZ3RoOyBpZHgkMSA8IGlkeF9maW5pc2gkMTsgKytpZHgkMSkge1xuICAgICAgICBsZXQgaXRlbSA9IGZsYXR0ZW5lZFtpZHgkMV07XG4gICAgICAgIG91dHB1dHNbaXRlbS5pXSA9IHBhcnNlKGIsIGl0ZW0uc2NoZW1hLCBpbnB1dCwgcGF0aCk7XG4gICAgICB9XG4gICAgICBiLmcubyA9IHByZXZGbGFnO1xuICAgIH1cbiAgICBsZXQgZ2V0SXRlbU91dHB1dCA9IGl0ZW0gPT4ge1xuICAgICAgc3dpdGNoIChpdGVtLmspIHtcbiAgICAgICAgY2FzZSAwIDpcbiAgICAgICAgICByZXR1cm4gb3V0cHV0c1tpdGVtLmxvY2F0aW9uXTtcbiAgICAgICAgY2FzZSAxIDpcbiAgICAgICAgICByZXR1cm4gZ2V0KGIsIGdldEl0ZW1PdXRwdXQoaXRlbS5vZiksIGl0ZW0ubG9jYXRpb24pO1xuICAgICAgICBjYXNlIDIgOlxuICAgICAgICAgIHJldHVybiBvdXRwdXRzW2l0ZW0uaV07XG4gICAgICB9XG4gICAgfTtcbiAgICByZXR1cm4gZGVmaW5pdGlvblRvT3V0cHV0KGIsIGRlZmluaXRpb24sIGdldEl0ZW1PdXRwdXQsIHNlbGZTY2hlbWEudG8pO1xuICB9O1xufVxuXG5mdW5jdGlvbiBzaGFwZShzY2hlbWEsIGRlZmluZXIpIHtcbiAgcmV0dXJuIHVwZGF0ZU91dHB1dChzY2hlbWEsIG11dCA9PiB7XG4gICAgbGV0IGRpdGVtID0ge1xuICAgICAgazogMixcbiAgICAgIHNjaGVtYTogc2NoZW1hLFxuICAgICAgcDogXCJcIixcbiAgICAgIGk6IDBcbiAgICB9O1xuICAgIGxldCBkZWZpbml0aW9uID0gZGVmaW5lcihwcm94aWZ5KGRpdGVtKSk7XG4gICAgbXV0LnBhcnNlciA9IChiLCBpbnB1dCwgc2VsZlNjaGVtYSwgcGFyYW0pID0+IHtcbiAgICAgIGxldCBnZXRJdGVtT3V0cHV0ID0gaXRlbSA9PiB7XG4gICAgICAgIHN3aXRjaCAoaXRlbS5rKSB7XG4gICAgICAgICAgY2FzZSAxIDpcbiAgICAgICAgICAgIHJldHVybiBnZXQoYiwgZ2V0SXRlbU91dHB1dChpdGVtLm9mKSwgaXRlbS5sb2NhdGlvbik7XG4gICAgICAgICAgY2FzZSAwIDpcbiAgICAgICAgICBjYXNlIDIgOlxuICAgICAgICAgICAgcmV0dXJuIGlucHV0O1xuICAgICAgICB9XG4gICAgICB9O1xuICAgICAgcmV0dXJuIGRlZmluaXRpb25Ub091dHB1dChiLCBkZWZpbml0aW9uLCBnZXRJdGVtT3V0cHV0LCBzZWxmU2NoZW1hLnRvKTtcbiAgICB9O1xuICAgIG11dC50byA9IGRlZmluaXRpb25Ub1RhcmdldChkZWZpbml0aW9uLCBkaXRlbSwgdW5kZWZpbmVkKTtcbiAgfSk7XG59XG5cbmZ1bmN0aW9uIG9iamVjdChkZWZpbmVyKSB7XG4gIGxldCBmbGF0dGVuZWQgPSAodm9pZCAwKTtcbiAgbGV0IGl0ZW1zID0gW107XG4gIGxldCBwcm9wZXJ0aWVzID0ge307XG4gIGxldCBmbGF0dGVuID0gc2NoZW1hID0+IHtcbiAgICBsZXQgbWF0Y2ggPSBzY2hlbWEudHlwZTtcbiAgICBpZiAobWF0Y2ggPT09IFwib2JqZWN0XCIpIHtcbiAgICAgIGxldCBmbGF0dGVuZWRJdGVtcyA9IHNjaGVtYS5pdGVtcztcbiAgICAgIGZvciAobGV0IGlkeCA9IDAsIGlkeF9maW5pc2ggPSBmbGF0dGVuZWRJdGVtcy5sZW5ndGg7IGlkeCA8IGlkeF9maW5pc2g7ICsraWR4KSB7XG4gICAgICAgIGxldCBtYXRjaCQxID0gZmxhdHRlbmVkSXRlbXNbaWR4XTtcbiAgICAgICAgbGV0IGxvY2F0aW9uID0gbWF0Y2gkMS5sb2NhdGlvbjtcbiAgICAgICAgbGV0IGZsYXR0ZW5lZFNjaGVtYSA9IG1hdGNoJDEuc2NoZW1hO1xuICAgICAgICBsZXQgc2NoZW1hJDEgPSBwcm9wZXJ0aWVzW2xvY2F0aW9uXTtcbiAgICAgICAgaWYgKHNjaGVtYSQxICE9PSB1bmRlZmluZWQpIHtcbiAgICAgICAgICBpZiAoc2NoZW1hJDEgIT09IGZsYXR0ZW5lZFNjaGVtYSkge1xuICAgICAgICAgICAgdGhyb3cgbmV3IEVycm9yKGBbU3VyeV0gYCArIChgVGhlIGZpZWxkIFwiYCArIGxvY2F0aW9uICsgYFwiIGRlZmluZWQgdHdpY2Ugd2l0aCBpbmNvbXBhdGlibGUgc2NoZW1hc2ApKTtcbiAgICAgICAgICB9XG4gICAgICAgIH0gZWxzZSB7XG4gICAgICAgICAgbGV0IGl0ZW0gPSB7XG4gICAgICAgICAgICBrOiAwLFxuICAgICAgICAgICAgc2NoZW1hOiBmbGF0dGVuZWRTY2hlbWEsXG4gICAgICAgICAgICBsb2NhdGlvbjogbG9jYXRpb25cbiAgICAgICAgICB9O1xuICAgICAgICAgIGl0ZW1zLnB1c2goaXRlbSk7XG4gICAgICAgICAgcHJvcGVydGllc1tsb2NhdGlvbl0gPSBmbGF0dGVuZWRTY2hlbWE7XG4gICAgICAgIH1cbiAgICAgIH1cbiAgICAgIGxldCBmID0gKGZsYXR0ZW5lZCB8fCAoZmxhdHRlbmVkID0gW10pKTtcbiAgICAgIGxldCBpdGVtXzIgPSBmLmxlbmd0aDtcbiAgICAgIGxldCBpdGVtJDEgPSB7XG4gICAgICAgIGs6IDIsXG4gICAgICAgIHNjaGVtYTogc2NoZW1hLFxuICAgICAgICBwOiBcIlwiLFxuICAgICAgICBpOiBpdGVtXzJcbiAgICAgIH07XG4gICAgICBmLnB1c2goaXRlbSQxKTtcbiAgICAgIHJldHVybiBwcm94aWZ5KGl0ZW0kMSk7XG4gICAgfVxuICAgIGxldCBtZXNzYWdlID0gYFRoZSAnYCArIHRvRXhwcmVzc2lvbihzY2hlbWEpICsgYCcgc2NoZW1hIGNhbid0IGJlIGZsYXR0ZW5lZGA7XG4gICAgdGhyb3cgbmV3IEVycm9yKGBbU3VyeV0gYCArIG1lc3NhZ2UpO1xuICB9O1xuICBsZXQgZmllbGQgPSAoZmllbGROYW1lLCBzY2hlbWEpID0+IHtcbiAgICBpZiAoZmllbGROYW1lIGluIHByb3BlcnRpZXMpIHtcbiAgICAgIHRocm93IG5ldyBFcnJvcihgW1N1cnldIGAgKyAoYFRoZSBmaWVsZCBcImAgKyBmaWVsZE5hbWUgKyBgXCIgZGVmaW5lZCB0d2ljZSB3aXRoIGluY29tcGF0aWJsZSBzY2hlbWFzYCkpO1xuICAgIH1cbiAgICBsZXQgZGl0ZW0gPSB7XG4gICAgICBrOiAwLFxuICAgICAgc2NoZW1hOiBzY2hlbWEsXG4gICAgICBsb2NhdGlvbjogZmllbGROYW1lXG4gICAgfTtcbiAgICBwcm9wZXJ0aWVzW2ZpZWxkTmFtZV0gPSBzY2hlbWE7XG4gICAgaXRlbXMucHVzaChkaXRlbSk7XG4gICAgcmV0dXJuIHByb3hpZnkoZGl0ZW0pO1xuICB9O1xuICBsZXQgdGFnID0gKHRhZyQxLCBhc1ZhbHVlKSA9PiB7XG4gICAgZmllbGQodGFnJDEsIGRlZmluaXRpb25Ub1NjaGVtYShhc1ZhbHVlKSk7XG4gIH07XG4gIGxldCBmaWVsZE9yID0gKGZpZWxkTmFtZSwgc2NoZW1hLCBvcikgPT4ge1xuICAgIGxldCBzY2hlbWEkMSA9IGZhY3RvcnkkMShzY2hlbWEsIHVuZGVmaW5lZCk7XG4gICAgcmV0dXJuIGZpZWxkKGZpZWxkTmFtZSwgZ2V0V2l0aERlZmF1bHQoc2NoZW1hJDEsIHtcbiAgICAgIFRBRzogXCJWYWx1ZVwiLFxuICAgICAgXzA6IG9yXG4gICAgfSkpO1xuICB9O1xuICBsZXQgY3R4ID0ge1xuICAgIGZpZWxkOiBmaWVsZCxcbiAgICBmOiBmaWVsZCxcbiAgICBmaWVsZE9yOiBmaWVsZE9yLFxuICAgIHRhZzogdGFnLFxuICAgIG5lc3RlZDogbmVzdGVkLFxuICAgIGZsYXR0ZW46IGZsYXR0ZW5cbiAgfTtcbiAgbGV0IGRlZmluaXRpb24gPSBkZWZpbmVyKGN0eCk7XG4gIGxldCBtdXQgPSBuZXcgU2NoZW1hKFwib2JqZWN0XCIpO1xuICBtdXQuaXRlbXMgPSBpdGVtcztcbiAgbXV0LnByb3BlcnRpZXMgPSBwcm9wZXJ0aWVzO1xuICBtdXQuYWRkaXRpb25hbEl0ZW1zID0gZ2xvYmFsQ29uZmlnLmE7XG4gIG11dC5wYXJzZXIgPSBhZHZhbmNlZEJ1aWxkZXIoZGVmaW5pdGlvbiwgZmxhdHRlbmVkKTtcbiAgbXV0LnRvID0gZGVmaW5pdGlvblRvVGFyZ2V0KGRlZmluaXRpb24sIHVuZGVmaW5lZCwgZmxhdHRlbmVkKTtcbiAgcmV0dXJuIG11dDtcbn1cblxuZnVuY3Rpb24gdHVwbGUoZGVmaW5lcikge1xuICBsZXQgaXRlbXMgPSBbXTtcbiAgbGV0IGl0ZW0gPSAoaWR4LCBzY2hlbWEpID0+IHtcbiAgICBsZXQgbG9jYXRpb24gPSBpZHgudG9TdHJpbmcoKTtcbiAgICBpZiAoaXRlbXNbaWR4XSkge1xuICAgICAgdGhyb3cgbmV3IEVycm9yKGBbU3VyeV0gYCArIChgVGhlIGl0ZW0gW2AgKyBsb2NhdGlvbiArIGBdIGlzIGRlZmluZWQgbXVsdGlwbGUgdGltZXNgKSk7XG4gICAgfVxuICAgIGxldCBkaXRlbSA9IHtcbiAgICAgIGs6IDAsXG4gICAgICBzY2hlbWE6IHNjaGVtYSxcbiAgICAgIGxvY2F0aW9uOiBsb2NhdGlvblxuICAgIH07XG4gICAgaXRlbXNbaWR4XSA9IGRpdGVtO1xuICAgIHJldHVybiBwcm94aWZ5KGRpdGVtKTtcbiAgfTtcbiAgbGV0IHRhZyA9IChpZHgsIGFzVmFsdWUpID0+IHtcbiAgICBpdGVtKGlkeCwgZGVmaW5pdGlvblRvU2NoZW1hKGFzVmFsdWUpKTtcbiAgfTtcbiAgbGV0IGN0eCA9IHtcbiAgICBpdGVtOiBpdGVtLFxuICAgIHRhZzogdGFnXG4gIH07XG4gIGxldCBkZWZpbml0aW9uID0gZGVmaW5lcihjdHgpO1xuICBmb3IgKGxldCBpZHggPSAwLCBpZHhfZmluaXNoID0gaXRlbXMubGVuZ3RoOyBpZHggPCBpZHhfZmluaXNoOyArK2lkeCkge1xuICAgIGlmICghaXRlbXNbaWR4XSkge1xuICAgICAgbGV0IGxvY2F0aW9uID0gaWR4LnRvU3RyaW5nKCk7XG4gICAgICBsZXQgZGl0ZW0gPSB7XG4gICAgICAgIHNjaGVtYTogdW5pdCxcbiAgICAgICAgbG9jYXRpb246IGxvY2F0aW9uXG4gICAgICB9O1xuICAgICAgaXRlbXNbaWR4XSA9IGRpdGVtO1xuICAgIH1cbiAgfVxuICBsZXQgbXV0ID0gbmV3IFNjaGVtYShcImFycmF5XCIpO1xuICBtdXQuaXRlbXMgPSBpdGVtcztcbiAgbXV0LmFkZGl0aW9uYWxJdGVtcyA9IFwic3RyaWN0XCI7XG4gIG11dC5wYXJzZXIgPSBhZHZhbmNlZEJ1aWxkZXIoZGVmaW5pdGlvbiwgdW5kZWZpbmVkKTtcbiAgbXV0LnRvID0gZGVmaW5pdGlvblRvVGFyZ2V0KGRlZmluaXRpb24sIHVuZGVmaW5lZCwgdW5kZWZpbmVkKTtcbiAgcmV0dXJuIG11dDtcbn1cblxuZnVuY3Rpb24gbWF0Y2hlcyhzY2hlbWEpIHtcbiAgcmV0dXJuIHNjaGVtYTtcbn1cblxubGV0IGN0eCA9IHtcbiAgbTogbWF0Y2hlc1xufTtcblxuZnVuY3Rpb24gZmFjdG9yeSQ0KGRlZmluZXIpIHtcbiAgcmV0dXJuIGRlZmluaXRpb25Ub1NjaGVtYShkZWZpbmVyKGN0eCkpO1xufVxuXG5mdW5jdGlvbiBmYWN0b3J5JDUoaXRlbSkge1xuICByZXR1cm4gZmFjdG9yeSQxKGl0ZW0sIG51bGxBc1VuaXQpO1xufVxuXG5sZXQganNfc2NoZW1hID0gZGVmaW5pdGlvblRvU2NoZW1hO1xuXG5mdW5jdGlvbiAkJGVudW0odmFsdWVzKSB7XG4gIHJldHVybiBmYWN0b3J5KHZhbHVlcy5tYXAoanNfc2NoZW1hKSk7XG59XG5cbmZ1bmN0aW9uIHVubmVzdFNlcmlhbGl6ZXIoYiwgaW5wdXQsIHNlbGZTY2hlbWEsIHBhdGgpIHtcbiAgbGV0IHNjaGVtYSA9IHNlbGZTY2hlbWEuYWRkaXRpb25hbEl0ZW1zO1xuICBsZXQgaXRlbXMgPSBzY2hlbWEuaXRlbXM7XG4gIGxldCBpbnB1dFZhciA9IGlucHV0LnYoYik7XG4gIGxldCBpdGVyYXRvclZhciA9IHZhcldpdGhvdXRBbGxvY2F0aW9uKGIuZyk7XG4gIGxldCBvdXRwdXRWYXIgPSB2YXJXaXRob3V0QWxsb2NhdGlvbihiLmcpO1xuICBsZXQgYmIgPSB7XG4gICAgYzogXCJcIixcbiAgICBsOiBcIlwiLFxuICAgIGE6IGluaXRpYWxBbGxvY2F0ZSxcbiAgICBmOiBcIlwiLFxuICAgIGc6IGIuZ1xuICB9O1xuICBsZXQgaXRlbUlucHV0ID0ge1xuICAgIGI6IGJiLFxuICAgIHY6IF92YXIsXG4gICAgaTogaW5wdXRWYXIgKyBgW2AgKyBpdGVyYXRvclZhciArIGBdYCxcbiAgICBmOiAwLFxuICAgIHR5cGU6IFwidW5rbm93blwiXG4gIH07XG4gIGxldCBpdGVtT3V0cHV0ID0gd2l0aFBhdGhQcmVwZW5kKGJiLCBpdGVtSW5wdXQsIHBhdGgsIGl0ZXJhdG9yVmFyLCAoYmIsIG91dHB1dCkgPT4ge1xuICAgIGxldCBpbml0aWFsQXJyYXlzQ29kZSA9IFwiXCI7XG4gICAgbGV0IHNldHRpbmdDb2RlID0gXCJcIjtcbiAgICBmb3IgKGxldCBpZHggPSAwLCBpZHhfZmluaXNoID0gaXRlbXMubGVuZ3RoOyBpZHggPCBpZHhfZmluaXNoOyArK2lkeCkge1xuICAgICAgbGV0IHRvSXRlbSA9IGl0ZW1zW2lkeF07XG4gICAgICBpbml0aWFsQXJyYXlzQ29kZSA9IGluaXRpYWxBcnJheXNDb2RlICsgKGBuZXcgQXJyYXkoYCArIGlucHV0VmFyICsgYC5sZW5ndGgpLGApO1xuICAgICAgc2V0dGluZ0NvZGUgPSBzZXR0aW5nQ29kZSArIChvdXRwdXRWYXIgKyBgW2AgKyBpZHggKyBgXVtgICsgaXRlcmF0b3JWYXIgKyBgXT1gICsgZ2V0KGIsIG91dHB1dCwgdG9JdGVtLmxvY2F0aW9uKS5pICsgYDtgKTtcbiAgICB9XG4gICAgYi5hKG91dHB1dFZhciArIGA9W2AgKyBpbml0aWFsQXJyYXlzQ29kZSArIGBdYCk7XG4gICAgYmIuYyA9IGJiLmMgKyBzZXR0aW5nQ29kZTtcbiAgfSwgKGIsIGlucHV0LCBwYXRoKSA9PiBwYXJzZShiLCBzY2hlbWEsIGlucHV0LCBwYXRoKSk7XG4gIGxldCBpdGVtQ29kZSA9IGFsbG9jYXRlU2NvcGUoYmIpO1xuICBiLmMgPSBiLmMgKyAoYGZvcihsZXQgYCArIGl0ZXJhdG9yVmFyICsgYD0wO2AgKyBpdGVyYXRvclZhciArIGA8YCArIGlucHV0VmFyICsgYC5sZW5ndGg7KytgICsgaXRlcmF0b3JWYXIgKyBgKXtgICsgaXRlbUNvZGUgKyBgfWApO1xuICBpZiAoaXRlbU91dHB1dC5mICYgMikge1xuICAgIHJldHVybiB7XG4gICAgICBiOiBiLFxuICAgICAgdjogX25vdFZhcixcbiAgICAgIGk6IGBQcm9taXNlLmFsbChgICsgb3V0cHV0VmFyICsgYClgLFxuICAgICAgZjogMixcbiAgICAgIHR5cGU6IFwiYXJyYXlcIlxuICAgIH07XG4gIH0gZWxzZSB7XG4gICAgcmV0dXJuIHtcbiAgICAgIGI6IGIsXG4gICAgICB2OiBfdmFyLFxuICAgICAgaTogb3V0cHV0VmFyLFxuICAgICAgZjogMCxcbiAgICAgIHR5cGU6IFwiYXJyYXlcIlxuICAgIH07XG4gIH1cbn1cblxuZnVuY3Rpb24gdW5uZXN0KHNjaGVtYSkge1xuICBpZiAoc2NoZW1hLnR5cGUgPT09IFwib2JqZWN0XCIpIHtcbiAgICBsZXQgaXRlbXMgPSBzY2hlbWEuaXRlbXM7XG4gICAgaWYgKGl0ZW1zLmxlbmd0aCA9PT0gMCkge1xuICAgICAgdGhyb3cgbmV3IEVycm9yKGBbU3VyeV0gYCArIFwiSW52YWxpZCBlbXB0eSBvYmplY3QgZm9yIFMudW5uZXN0IHNjaGVtYS5cIik7XG4gICAgfVxuICAgIGxldCBtdXQgPSBuZXcgU2NoZW1hKFwiYXJyYXlcIik7XG4gICAgbXV0Lml0ZW1zID0gaXRlbXMubWFwKChpdGVtLCBpZHgpID0+IHtcbiAgICAgIGxldCBsb2NhdGlvbiA9IGlkeC50b1N0cmluZygpO1xuICAgICAgcmV0dXJuIHtcbiAgICAgICAgc2NoZW1hOiBmYWN0b3J5JDIoaXRlbS5zY2hlbWEpLFxuICAgICAgICBsb2NhdGlvbjogbG9jYXRpb25cbiAgICAgIH07XG4gICAgfSk7XG4gICAgbXV0LmFkZGl0aW9uYWxJdGVtcyA9IFwic3RyaWN0XCI7XG4gICAgbXV0LnBhcnNlciA9IChiLCBpbnB1dCwgc2VsZlNjaGVtYSwgcGF0aCkgPT4ge1xuICAgICAgbGV0IGlucHV0VmFyID0gaW5wdXQudihiKTtcbiAgICAgIGxldCBpdGVyYXRvclZhciA9IHZhcldpdGhvdXRBbGxvY2F0aW9uKGIuZyk7XG4gICAgICBsZXQgYmIgPSB7XG4gICAgICAgIGM6IFwiXCIsXG4gICAgICAgIGw6IFwiXCIsXG4gICAgICAgIGE6IGluaXRpYWxBbGxvY2F0ZSxcbiAgICAgICAgZjogXCJcIixcbiAgICAgICAgZzogYi5nXG4gICAgICB9O1xuICAgICAgbGV0IGl0ZW1JbnB1dCA9IG1ha2UoYmIsIGZhbHNlKTtcbiAgICAgIGxldCBsZW5ndGhDb2RlID0gXCJcIjtcbiAgICAgIGZvciAobGV0IGlkeCA9IDAsIGlkeF9maW5pc2ggPSBpdGVtcy5sZW5ndGg7IGlkeCA8IGlkeF9maW5pc2g7ICsraWR4KSB7XG4gICAgICAgIGxldCBpdGVtID0gaXRlbXNbaWR4XTtcbiAgICAgICAgYWRkKGl0ZW1JbnB1dCwgaXRlbS5sb2NhdGlvbiwgdmFsKGJiLCBpbnB1dFZhciArIGBbYCArIGlkeCArIGBdW2AgKyBpdGVyYXRvclZhciArIGBdYCwgdW5rbm93bikpO1xuICAgICAgICBsZW5ndGhDb2RlID0gbGVuZ3RoQ29kZSArIChpbnB1dFZhciArIGBbYCArIGlkeCArIGBdLmxlbmd0aCxgKTtcbiAgICAgIH1cbiAgICAgIGxldCBvdXRwdXQgPSB2YWwoYiwgYG5ldyBBcnJheShNYXRoLm1heChgICsgbGVuZ3RoQ29kZSArIGApKWAsIHNlbGZTY2hlbWEudG8pO1xuICAgICAgbGV0IG91dHB1dFZhciA9IG91dHB1dC52KGIpO1xuICAgICAgbGV0IGl0ZW1PdXRwdXQgPSB3aXRoUGF0aFByZXBlbmQoYmIsIGNvbXBsZXRlKGl0ZW1JbnB1dCwgZmFsc2UpLCBwYXRoLCBpdGVyYXRvclZhciwgKGJiLCBpdGVtT3V0cHV0KSA9PiB7XG4gICAgICAgIGJiLmMgPSBiYi5jICsgYWRkS2V5KGJiLCBvdXRwdXQsIGl0ZXJhdG9yVmFyLCBpdGVtT3V0cHV0KSArIFwiO1wiO1xuICAgICAgfSwgKGIsIGlucHV0LCBwYXRoKSA9PiBwYXJzZShiLCBzY2hlbWEsIGlucHV0LCBwYXRoKSk7XG4gICAgICBsZXQgaXRlbUNvZGUgPSBhbGxvY2F0ZVNjb3BlKGJiKTtcbiAgICAgIGIuYyA9IGIuYyArIChgZm9yKGxldCBgICsgaXRlcmF0b3JWYXIgKyBgPTA7YCArIGl0ZXJhdG9yVmFyICsgYDxgICsgb3V0cHV0VmFyICsgYC5sZW5ndGg7KytgICsgaXRlcmF0b3JWYXIgKyBgKXtgICsgaXRlbUNvZGUgKyBgfWApO1xuICAgICAgaWYgKGl0ZW1PdXRwdXQuZiAmIDIpIHtcbiAgICAgICAgcmV0dXJuIGFzeW5jVmFsKG91dHB1dC5iLCBgUHJvbWlzZS5hbGwoYCArIG91dHB1dC5pICsgYClgKTtcbiAgICAgIH0gZWxzZSB7XG4gICAgICAgIHJldHVybiBvdXRwdXQ7XG4gICAgICB9XG4gICAgfTtcbiAgICBsZXQgdG8gPSBuZXcgU2NoZW1hKFwiYXJyYXlcIik7XG4gICAgdG8uaXRlbXMgPSBpbW11dGFibGVFbXB0eSQxO1xuICAgIHRvLmFkZGl0aW9uYWxJdGVtcyA9IHNjaGVtYTtcbiAgICB0by5zZXJpYWxpemVyID0gdW5uZXN0U2VyaWFsaXplcjtcbiAgICBtdXQudW5uZXN0ID0gdHJ1ZTtcbiAgICBtdXQudG8gPSB0bztcbiAgICByZXR1cm4gbXV0O1xuICB9XG4gIHRocm93IG5ldyBFcnJvcihgW1N1cnldIGAgKyBcIlMudW5uZXN0IHN1cHBvcnRzIG9ubHkgb2JqZWN0IHNjaGVtYXMuXCIpO1xufVxuXG5mdW5jdGlvbiBvcHRpb24oaXRlbSkge1xuICByZXR1cm4gZmFjdG9yeSQxKGl0ZW0sIHVuaXQpO1xufVxuXG5mdW5jdGlvbiB0dXBsZTEodjApIHtcbiAgcmV0dXJuIHR1cGxlKHMgPT4gcy5pdGVtKDAsIHYwKSk7XG59XG5cbmZ1bmN0aW9uIHR1cGxlMih2MCwgdjEpIHtcbiAgcmV0dXJuIGRlZmluaXRpb25Ub1NjaGVtYShbXG4gICAgdjAsXG4gICAgdjFcbiAgXSk7XG59XG5cbmZ1bmN0aW9uIHR1cGxlMyh2MCwgdjEsIHYyKSB7XG4gIHJldHVybiBkZWZpbml0aW9uVG9TY2hlbWEoW1xuICAgIHYwLFxuICAgIHYxLFxuICAgIHYyXG4gIF0pO1xufVxuXG5mdW5jdGlvbiBpbnRNaW4oc2NoZW1hLCBtaW5WYWx1ZSwgbWF5YmVNZXNzYWdlKSB7XG4gIGxldCBtZXNzYWdlID0gbWF5YmVNZXNzYWdlICE9PSB1bmRlZmluZWQgPyBtYXliZU1lc3NhZ2UgOiBgTnVtYmVyIG11c3QgYmUgZ3JlYXRlciB0aGFuIG9yIGVxdWFsIHRvIGAgKyBtaW5WYWx1ZTtcbiAgcmV0dXJuIGFkZFJlZmluZW1lbnQoc2NoZW1hLCBtZXRhZGF0YUlkJDIsIHtcbiAgICBraW5kOiB7XG4gICAgICBUQUc6IFwiTWluXCIsXG4gICAgICB2YWx1ZTogbWluVmFsdWVcbiAgICB9LFxuICAgIG1lc3NhZ2U6IG1lc3NhZ2VcbiAgfSwgKGIsIGlucHV0VmFyLCBwYXJhbSwgcGF0aCkgPT4gYGlmKGAgKyBpbnB1dFZhciArIGA8YCArIGVtYmVkKGIsIG1pblZhbHVlKSArIGApe2AgKyBmYWlsKGIsIG1lc3NhZ2UsIHBhdGgpICsgYH1gKTtcbn1cblxuZnVuY3Rpb24gaW50TWF4KHNjaGVtYSwgbWF4VmFsdWUsIG1heWJlTWVzc2FnZSkge1xuICBsZXQgbWVzc2FnZSA9IG1heWJlTWVzc2FnZSAhPT0gdW5kZWZpbmVkID8gbWF5YmVNZXNzYWdlIDogYE51bWJlciBtdXN0IGJlIGxvd2VyIHRoYW4gb3IgZXF1YWwgdG8gYCArIG1heFZhbHVlO1xuICByZXR1cm4gYWRkUmVmaW5lbWVudChzY2hlbWEsIG1ldGFkYXRhSWQkMiwge1xuICAgIGtpbmQ6IHtcbiAgICAgIFRBRzogXCJNYXhcIixcbiAgICAgIHZhbHVlOiBtYXhWYWx1ZVxuICAgIH0sXG4gICAgbWVzc2FnZTogbWVzc2FnZVxuICB9LCAoYiwgaW5wdXRWYXIsIHBhcmFtLCBwYXRoKSA9PiBgaWYoYCArIGlucHV0VmFyICsgYD5gICsgZW1iZWQoYiwgbWF4VmFsdWUpICsgYCl7YCArIGZhaWwoYiwgbWVzc2FnZSwgcGF0aCkgKyBgfWApO1xufVxuXG5mdW5jdGlvbiBwb3J0KHNjaGVtYSwgbWVzc2FnZSkge1xuICBsZXQgbXV0U3RhbmRhcmQgPSBpbnRlcm5hbFJlZmluZShzY2hlbWEsIChiLCBpbnB1dFZhciwgc2VsZlNjaGVtYSwgcGF0aCkgPT4gaW5wdXRWYXIgKyBgPjAmJmAgKyBpbnB1dFZhciArIGA8NjU1MzYmJmAgKyBpbnB1dFZhciArIGAlMT09PTB8fGAgKyAoXG4gICAgbWVzc2FnZSAhPT0gdW5kZWZpbmVkID8gZmFpbChiLCBtZXNzYWdlLCBwYXRoKSA6IGZhaWxXaXRoQXJnKGIsIHBhdGgsIGlucHV0ID0+ICh7XG4gICAgICAgIFRBRzogXCJJbnZhbGlkVHlwZVwiLFxuICAgICAgICBleHBlY3RlZDogc2VsZlNjaGVtYSxcbiAgICAgICAgcmVjZWl2ZWQ6IGlucHV0XG4gICAgICB9KSwgaW5wdXRWYXIpXG4gICkgKyBgO2ApO1xuICBtdXRTdGFuZGFyZC5mb3JtYXQgPSBcInBvcnRcIjtcbiAgcmV2ZXJzZShtdXRTdGFuZGFyZCkuZm9ybWF0ID0gXCJwb3J0XCI7XG4gIHJldHVybiBtdXRTdGFuZGFyZDtcbn1cblxuZnVuY3Rpb24gZmxvYXRNaW4oc2NoZW1hLCBtaW5WYWx1ZSwgbWF5YmVNZXNzYWdlKSB7XG4gIGxldCBtZXNzYWdlID0gbWF5YmVNZXNzYWdlICE9PSB1bmRlZmluZWQgPyBtYXliZU1lc3NhZ2UgOiBgTnVtYmVyIG11c3QgYmUgZ3JlYXRlciB0aGFuIG9yIGVxdWFsIHRvIGAgKyBtaW5WYWx1ZTtcbiAgcmV0dXJuIGFkZFJlZmluZW1lbnQoc2NoZW1hLCBtZXRhZGF0YUlkJDMsIHtcbiAgICBraW5kOiB7XG4gICAgICBUQUc6IFwiTWluXCIsXG4gICAgICB2YWx1ZTogbWluVmFsdWVcbiAgICB9LFxuICAgIG1lc3NhZ2U6IG1lc3NhZ2VcbiAgfSwgKGIsIGlucHV0VmFyLCBwYXJhbSwgcGF0aCkgPT4gYGlmKGAgKyBpbnB1dFZhciArIGA8YCArIGVtYmVkKGIsIG1pblZhbHVlKSArIGApe2AgKyBmYWlsKGIsIG1lc3NhZ2UsIHBhdGgpICsgYH1gKTtcbn1cblxuZnVuY3Rpb24gZmxvYXRNYXgoc2NoZW1hLCBtYXhWYWx1ZSwgbWF5YmVNZXNzYWdlKSB7XG4gIGxldCBtZXNzYWdlID0gbWF5YmVNZXNzYWdlICE9PSB1bmRlZmluZWQgPyBtYXliZU1lc3NhZ2UgOiBgTnVtYmVyIG11c3QgYmUgbG93ZXIgdGhhbiBvciBlcXVhbCB0byBgICsgbWF4VmFsdWU7XG4gIHJldHVybiBhZGRSZWZpbmVtZW50KHNjaGVtYSwgbWV0YWRhdGFJZCQzLCB7XG4gICAga2luZDoge1xuICAgICAgVEFHOiBcIk1heFwiLFxuICAgICAgdmFsdWU6IG1heFZhbHVlXG4gICAgfSxcbiAgICBtZXNzYWdlOiBtZXNzYWdlXG4gIH0sIChiLCBpbnB1dFZhciwgcGFyYW0sIHBhdGgpID0+IGBpZihgICsgaW5wdXRWYXIgKyBgPmAgKyBlbWJlZChiLCBtYXhWYWx1ZSkgKyBgKXtgICsgZmFpbChiLCBtZXNzYWdlLCBwYXRoKSArIGB9YCk7XG59XG5cbmZ1bmN0aW9uIGFycmF5TWluTGVuZ3RoKHNjaGVtYSwgbGVuZ3RoLCBtYXliZU1lc3NhZ2UpIHtcbiAgbGV0IG1lc3NhZ2UgPSBtYXliZU1lc3NhZ2UgIT09IHVuZGVmaW5lZCA/IG1heWJlTWVzc2FnZSA6IGBBcnJheSBtdXN0IGJlIGAgKyBsZW5ndGggKyBgIG9yIG1vcmUgaXRlbXMgbG9uZ2A7XG4gIHJldHVybiBhZGRSZWZpbmVtZW50KHNjaGVtYSwgbWV0YWRhdGFJZCwge1xuICAgIGtpbmQ6IHtcbiAgICAgIFRBRzogXCJNaW5cIixcbiAgICAgIGxlbmd0aDogbGVuZ3RoXG4gICAgfSxcbiAgICBtZXNzYWdlOiBtZXNzYWdlXG4gIH0sIChiLCBpbnB1dFZhciwgcGFyYW0sIHBhdGgpID0+IGBpZihgICsgaW5wdXRWYXIgKyBgLmxlbmd0aDxgICsgZW1iZWQoYiwgbGVuZ3RoKSArIGApe2AgKyBmYWlsKGIsIG1lc3NhZ2UsIHBhdGgpICsgYH1gKTtcbn1cblxuZnVuY3Rpb24gYXJyYXlNYXhMZW5ndGgoc2NoZW1hLCBsZW5ndGgsIG1heWJlTWVzc2FnZSkge1xuICBsZXQgbWVzc2FnZSA9IG1heWJlTWVzc2FnZSAhPT0gdW5kZWZpbmVkID8gbWF5YmVNZXNzYWdlIDogYEFycmF5IG11c3QgYmUgYCArIGxlbmd0aCArIGAgb3IgZmV3ZXIgaXRlbXMgbG9uZ2A7XG4gIHJldHVybiBhZGRSZWZpbmVtZW50KHNjaGVtYSwgbWV0YWRhdGFJZCwge1xuICAgIGtpbmQ6IHtcbiAgICAgIFRBRzogXCJNYXhcIixcbiAgICAgIGxlbmd0aDogbGVuZ3RoXG4gICAgfSxcbiAgICBtZXNzYWdlOiBtZXNzYWdlXG4gIH0sIChiLCBpbnB1dFZhciwgcGFyYW0sIHBhdGgpID0+IGBpZihgICsgaW5wdXRWYXIgKyBgLmxlbmd0aD5gICsgZW1iZWQoYiwgbGVuZ3RoKSArIGApe2AgKyBmYWlsKGIsIG1lc3NhZ2UsIHBhdGgpICsgYH1gKTtcbn1cblxuZnVuY3Rpb24gc3RyaW5nTWluTGVuZ3RoKHNjaGVtYSwgbGVuZ3RoLCBtYXliZU1lc3NhZ2UpIHtcbiAgbGV0IG1lc3NhZ2UgPSBtYXliZU1lc3NhZ2UgIT09IHVuZGVmaW5lZCA/IG1heWJlTWVzc2FnZSA6IGBTdHJpbmcgbXVzdCBiZSBgICsgbGVuZ3RoICsgYCBvciBtb3JlIGNoYXJhY3RlcnMgbG9uZ2A7XG4gIHJldHVybiBhZGRSZWZpbmVtZW50KHNjaGVtYSwgbWV0YWRhdGFJZCQxLCB7XG4gICAga2luZDoge1xuICAgICAgVEFHOiBcIk1pblwiLFxuICAgICAgbGVuZ3RoOiBsZW5ndGhcbiAgICB9LFxuICAgIG1lc3NhZ2U6IG1lc3NhZ2VcbiAgfSwgKGIsIGlucHV0VmFyLCBwYXJhbSwgcGF0aCkgPT4gYGlmKGAgKyBpbnB1dFZhciArIGAubGVuZ3RoPGAgKyBlbWJlZChiLCBsZW5ndGgpICsgYCl7YCArIGZhaWwoYiwgbWVzc2FnZSwgcGF0aCkgKyBgfWApO1xufVxuXG5mdW5jdGlvbiBzdHJpbmdNYXhMZW5ndGgoc2NoZW1hLCBsZW5ndGgsIG1heWJlTWVzc2FnZSkge1xuICBsZXQgbWVzc2FnZSA9IG1heWJlTWVzc2FnZSAhPT0gdW5kZWZpbmVkID8gbWF5YmVNZXNzYWdlIDogYFN0cmluZyBtdXN0IGJlIGAgKyBsZW5ndGggKyBgIG9yIGZld2VyIGNoYXJhY3RlcnMgbG9uZ2A7XG4gIHJldHVybiBhZGRSZWZpbmVtZW50KHNjaGVtYSwgbWV0YWRhdGFJZCQxLCB7XG4gICAga2luZDoge1xuICAgICAgVEFHOiBcIk1heFwiLFxuICAgICAgbGVuZ3RoOiBsZW5ndGhcbiAgICB9LFxuICAgIG1lc3NhZ2U6IG1lc3NhZ2VcbiAgfSwgKGIsIGlucHV0VmFyLCBwYXJhbSwgcGF0aCkgPT4gYGlmKGAgKyBpbnB1dFZhciArIGAubGVuZ3RoPmAgKyBlbWJlZChiLCBsZW5ndGgpICsgYCl7YCArIGZhaWwoYiwgbWVzc2FnZSwgcGF0aCkgKyBgfWApO1xufVxuXG5mdW5jdGlvbiBlbWFpbChzY2hlbWEsIG1lc3NhZ2VPcHQpIHtcbiAgbGV0IG1lc3NhZ2UgPSBtZXNzYWdlT3B0ICE9PSB1bmRlZmluZWQgPyBtZXNzYWdlT3B0IDogYEludmFsaWQgZW1haWwgYWRkcmVzc2A7XG4gIHJldHVybiBhZGRSZWZpbmVtZW50KHNjaGVtYSwgbWV0YWRhdGFJZCQxLCB7XG4gICAga2luZDogXCJFbWFpbFwiLFxuICAgIG1lc3NhZ2U6IG1lc3NhZ2VcbiAgfSwgKGIsIGlucHV0VmFyLCBwYXJhbSwgcGF0aCkgPT4gYGlmKCFgICsgZW1iZWQoYiwgZW1haWxSZWdleCkgKyBgLnRlc3QoYCArIGlucHV0VmFyICsgYCkpe2AgKyBmYWlsKGIsIG1lc3NhZ2UsIHBhdGgpICsgYH1gKTtcbn1cblxuZnVuY3Rpb24gdXVpZChzY2hlbWEsIG1lc3NhZ2VPcHQpIHtcbiAgbGV0IG1lc3NhZ2UgPSBtZXNzYWdlT3B0ICE9PSB1bmRlZmluZWQgPyBtZXNzYWdlT3B0IDogYEludmFsaWQgVVVJRGA7XG4gIHJldHVybiBhZGRSZWZpbmVtZW50KHNjaGVtYSwgbWV0YWRhdGFJZCQxLCB7XG4gICAga2luZDogXCJVdWlkXCIsXG4gICAgbWVzc2FnZTogbWVzc2FnZVxuICB9LCAoYiwgaW5wdXRWYXIsIHBhcmFtLCBwYXRoKSA9PiBgaWYoIWAgKyBlbWJlZChiLCB1dWlkUmVnZXgpICsgYC50ZXN0KGAgKyBpbnB1dFZhciArIGApKXtgICsgZmFpbChiLCBtZXNzYWdlLCBwYXRoKSArIGB9YCk7XG59XG5cbmZ1bmN0aW9uIGN1aWQoc2NoZW1hLCBtZXNzYWdlT3B0KSB7XG4gIGxldCBtZXNzYWdlID0gbWVzc2FnZU9wdCAhPT0gdW5kZWZpbmVkID8gbWVzc2FnZU9wdCA6IGBJbnZhbGlkIENVSURgO1xuICByZXR1cm4gYWRkUmVmaW5lbWVudChzY2hlbWEsIG1ldGFkYXRhSWQkMSwge1xuICAgIGtpbmQ6IFwiQ3VpZFwiLFxuICAgIG1lc3NhZ2U6IG1lc3NhZ2VcbiAgfSwgKGIsIGlucHV0VmFyLCBwYXJhbSwgcGF0aCkgPT4gYGlmKCFgICsgZW1iZWQoYiwgY3VpZFJlZ2V4KSArIGAudGVzdChgICsgaW5wdXRWYXIgKyBgKSl7YCArIGZhaWwoYiwgbWVzc2FnZSwgcGF0aCkgKyBgfWApO1xufVxuXG5mdW5jdGlvbiB1cmwoc2NoZW1hLCBtZXNzYWdlT3B0KSB7XG4gIGxldCBtZXNzYWdlID0gbWVzc2FnZU9wdCAhPT0gdW5kZWZpbmVkID8gbWVzc2FnZU9wdCA6IGBJbnZhbGlkIHVybGA7XG4gIHJldHVybiBhZGRSZWZpbmVtZW50KHNjaGVtYSwgbWV0YWRhdGFJZCQxLCB7XG4gICAga2luZDogXCJVcmxcIixcbiAgICBtZXNzYWdlOiBtZXNzYWdlXG4gIH0sIChiLCBpbnB1dFZhciwgcGFyYW0sIHBhdGgpID0+IGB0cnl7bmV3IFVSTChgICsgaW5wdXRWYXIgKyBgKX1jYXRjaChfKXtgICsgZmFpbChiLCBtZXNzYWdlLCBwYXRoKSArIGB9YCk7XG59XG5cbmZ1bmN0aW9uIHBhdHRlcm4oc2NoZW1hLCByZSwgbWVzc2FnZU9wdCkge1xuICBsZXQgbWVzc2FnZSA9IG1lc3NhZ2VPcHQgIT09IHVuZGVmaW5lZCA/IG1lc3NhZ2VPcHQgOiBgSW52YWxpZGA7XG4gIHJldHVybiBhZGRSZWZpbmVtZW50KHNjaGVtYSwgbWV0YWRhdGFJZCQxLCB7XG4gICAga2luZDoge1xuICAgICAgVEFHOiBcIlBhdHRlcm5cIixcbiAgICAgIHJlOiByZVxuICAgIH0sXG4gICAgbWVzc2FnZTogbWVzc2FnZVxuICB9LCAoYiwgaW5wdXRWYXIsIHBhcmFtLCBwYXRoKSA9PiAoXG4gICAgcmUuZ2xvYmFsID8gZW1iZWQoYiwgcmUpICsgYC5sYXN0SW5kZXg9MDtgIDogXCJcIlxuICApICsgKGBpZighYCArIGVtYmVkKGIsIHJlKSArIGAudGVzdChgICsgaW5wdXRWYXIgKyBgKSl7YCArIGZhaWwoYiwgbWVzc2FnZSwgcGF0aCkgKyBgfWApKTtcbn1cblxuZnVuY3Rpb24gZGF0ZXRpbWUoc2NoZW1hLCBtZXNzYWdlT3B0KSB7XG4gIGxldCBtZXNzYWdlID0gbWVzc2FnZU9wdCAhPT0gdW5kZWZpbmVkID8gbWVzc2FnZU9wdCA6IGBJbnZhbGlkIGRhdGV0aW1lIHN0cmluZyEgRXhwZWN0ZWQgVVRDYDtcbiAgbGV0IHJlZmluZW1lbnQgPSB7XG4gICAga2luZDogXCJEYXRldGltZVwiLFxuICAgIG1lc3NhZ2U6IG1lc3NhZ2VcbiAgfTtcbiAgbGV0IHJlZmluZW1lbnRzID0gc2NoZW1hW21ldGFkYXRhSWQkMV07XG4gIHJldHVybiB0cmFuc2Zvcm0oc2V0JDEoc2NoZW1hLCBtZXRhZGF0YUlkJDEsIHJlZmluZW1lbnRzICE9PSB1bmRlZmluZWQgPyByZWZpbmVtZW50cy5jb25jYXQocmVmaW5lbWVudCkgOiBbcmVmaW5lbWVudF0pLCBzID0+ICh7XG4gICAgcDogc3RyaW5nID0+IHtcbiAgICAgIGlmICghZGF0ZXRpbWVSZS50ZXN0KHN0cmluZykpIHtcbiAgICAgICAgcy5mYWlsKG1lc3NhZ2UsIHVuZGVmaW5lZCk7XG4gICAgICB9XG4gICAgICByZXR1cm4gbmV3IERhdGUoc3RyaW5nKTtcbiAgICB9LFxuICAgIHM6IGRhdGUgPT4gZGF0ZS50b0lTT1N0cmluZygpXG4gIH0pKTtcbn1cblxuZnVuY3Rpb24gdHJpbShzY2hlbWEpIHtcbiAgbGV0IHRyYW5zZm9ybWVyID0gc3RyaW5nID0+IHN0cmluZy50cmltKCk7XG4gIHJldHVybiB0cmFuc2Zvcm0oc2NoZW1hLCBwYXJhbSA9PiAoe1xuICAgIHA6IHRyYW5zZm9ybWVyLFxuICAgIHM6IHRyYW5zZm9ybWVyXG4gIH0pKTtcbn1cblxuZnVuY3Rpb24gbnVsbGFibGUoc2NoZW1hKSB7XG4gIHJldHVybiBmYWN0b3J5KFtcbiAgICBzY2hlbWEsXG4gICAgdW5pdCxcbiAgICAkJG51bGxcbiAgXSk7XG59XG5cbmZ1bmN0aW9uIG51bGxhYmxlQXNPcHRpb24oc2NoZW1hKSB7XG4gIHJldHVybiBmYWN0b3J5KFtcbiAgICBzY2hlbWEsXG4gICAgdW5pdCxcbiAgICBudWxsQXNVbml0XG4gIF0pO1xufVxuXG5mdW5jdGlvbiBqc191bmlvbih2YWx1ZXMpIHtcbiAgcmV0dXJuIGZhY3RvcnkodmFsdWVzLm1hcChkZWZpbml0aW9uVG9TY2hlbWEpKTtcbn1cblxuZnVuY3Rpb24ganNfdHJhbnNmb3JtKHNjaGVtYSwgbWF5YmVQYXJzZXIsIG1heWJlU2VyaWFsaXplcikge1xuICByZXR1cm4gdHJhbnNmb3JtKHNjaGVtYSwgcyA9PiAoe1xuICAgIHA6IG1heWJlUGFyc2VyICE9PSB1bmRlZmluZWQgPyB2ID0+IG1heWJlUGFyc2VyKHYsIHMpIDogdW5kZWZpbmVkLFxuICAgIHM6IG1heWJlU2VyaWFsaXplciAhPT0gdW5kZWZpbmVkID8gdiA9PiBtYXliZVNlcmlhbGl6ZXIodiwgcykgOiB1bmRlZmluZWRcbiAgfSkpO1xufVxuXG5mdW5jdGlvbiBqc19yZWZpbmUoc2NoZW1hLCByZWZpbmVyKSB7XG4gIHJldHVybiByZWZpbmUoc2NoZW1hLCBzID0+ICh2ID0+IHJlZmluZXIodiwgcykpKTtcbn1cblxuZnVuY3Rpb24gbm9vcChhKSB7XG4gIHJldHVybiBhO1xufVxuXG5mdW5jdGlvbiBqc19hc3luY1BhcnNlclJlZmluZShzY2hlbWEsIHJlZmluZSkge1xuICByZXR1cm4gdHJhbnNmb3JtKHNjaGVtYSwgcyA9PiAoe1xuICAgIGE6IHYgPT4gcmVmaW5lKHYsIHMpLnRoZW4oKCkgPT4gdiksXG4gICAgczogbm9vcFxuICB9KSk7XG59XG5cbmZ1bmN0aW9uIGpzX29wdGlvbmFsKHNjaGVtYSwgbWF5YmVPcikge1xuICBsZXQgc2NoZW1hJDEgPSBmYWN0b3J5KFtcbiAgICBzY2hlbWEsXG4gICAgdW5pdFxuICBdKTtcbiAgaWYgKG1heWJlT3IgPT09IHVuZGVmaW5lZCkge1xuICAgIHJldHVybiBzY2hlbWEkMTtcbiAgfVxuICBsZXQgb3IgPSBQcmltaXRpdmVfb3B0aW9uLnZhbEZyb21PcHRpb24obWF5YmVPcik7XG4gIGlmICh0eXBlb2Ygb3IgPT09IFwiZnVuY3Rpb25cIikge1xuICAgIHJldHVybiBnZXRXaXRoRGVmYXVsdChzY2hlbWEkMSwge1xuICAgICAgVEFHOiBcIkNhbGxiYWNrXCIsXG4gICAgICBfMDogb3JcbiAgICB9KTtcbiAgfSBlbHNlIHtcbiAgICByZXR1cm4gZ2V0V2l0aERlZmF1bHQoc2NoZW1hJDEsIHtcbiAgICAgIFRBRzogXCJWYWx1ZVwiLFxuICAgICAgXzA6IG9yXG4gICAgfSk7XG4gIH1cbn1cblxuZnVuY3Rpb24ganNfbnVsbGFibGUoc2NoZW1hLCBtYXliZU9yKSB7XG4gIGxldCBzY2hlbWEkMSA9IGZhY3RvcnkoW1xuICAgIHNjaGVtYSxcbiAgICBudWxsQXNVbml0XG4gIF0pO1xuICBpZiAobWF5YmVPciA9PT0gdW5kZWZpbmVkKSB7XG4gICAgcmV0dXJuIHNjaGVtYSQxO1xuICB9XG4gIGxldCBvciA9IFByaW1pdGl2ZV9vcHRpb24udmFsRnJvbU9wdGlvbihtYXliZU9yKTtcbiAgaWYgKHR5cGVvZiBvciA9PT0gXCJmdW5jdGlvblwiKSB7XG4gICAgcmV0dXJuIGdldFdpdGhEZWZhdWx0KHNjaGVtYSQxLCB7XG4gICAgICBUQUc6IFwiQ2FsbGJhY2tcIixcbiAgICAgIF8wOiBvclxuICAgIH0pO1xuICB9IGVsc2Uge1xuICAgIHJldHVybiBnZXRXaXRoRGVmYXVsdChzY2hlbWEkMSwge1xuICAgICAgVEFHOiBcIlZhbHVlXCIsXG4gICAgICBfMDogb3JcbiAgICB9KTtcbiAgfVxufVxuXG5mdW5jdGlvbiBqc19tZXJnZShzMSwgczIpIHtcbiAgbGV0IHM7XG4gIGlmIChzMS50eXBlID09PSBcIm9iamVjdFwiICYmIHMyLnR5cGUgPT09IFwib2JqZWN0XCIpIHtcbiAgICBsZXQgYWRkaXRpb25hbEl0ZW1zMSA9IHMxLmFkZGl0aW9uYWxJdGVtcztcbiAgICBpZiAodHlwZW9mIGFkZGl0aW9uYWxJdGVtczEgPT09IFwic3RyaW5nXCIgJiYgdHlwZW9mIHMyLmFkZGl0aW9uYWxJdGVtcyA9PT0gXCJzdHJpbmdcIiAmJiAhczEudG8gJiYgIXMyLnRvKSB7XG4gICAgICBsZXQgaXRlbXMyID0gczIuaXRlbXM7XG4gICAgICBsZXQgaXRlbXMxID0gczEuaXRlbXM7XG4gICAgICBsZXQgcHJvcGVydGllcyA9IHt9O1xuICAgICAgbGV0IGxvY2F0aW9ucyA9IFtdO1xuICAgICAgbGV0IGl0ZW1zID0gW107XG4gICAgICBmb3IgKGxldCBpZHggPSAwLCBpZHhfZmluaXNoID0gaXRlbXMxLmxlbmd0aDsgaWR4IDwgaWR4X2ZpbmlzaDsgKytpZHgpIHtcbiAgICAgICAgbGV0IGl0ZW0gPSBpdGVtczFbaWR4XTtcbiAgICAgICAgbG9jYXRpb25zLnB1c2goaXRlbS5sb2NhdGlvbik7XG4gICAgICAgIHByb3BlcnRpZXNbaXRlbS5sb2NhdGlvbl0gPSBpdGVtLnNjaGVtYTtcbiAgICAgIH1cbiAgICAgIGZvciAobGV0IGlkeCQxID0gMCwgaWR4X2ZpbmlzaCQxID0gaXRlbXMyLmxlbmd0aDsgaWR4JDEgPCBpZHhfZmluaXNoJDE7ICsraWR4JDEpIHtcbiAgICAgICAgbGV0IGl0ZW0kMSA9IGl0ZW1zMltpZHgkMV07XG4gICAgICAgIGlmICghKGl0ZW0kMS5sb2NhdGlvbiBpbiBwcm9wZXJ0aWVzKSkge1xuICAgICAgICAgIGxvY2F0aW9ucy5wdXNoKGl0ZW0kMS5sb2NhdGlvbik7XG4gICAgICAgIH1cbiAgICAgICAgcHJvcGVydGllc1tpdGVtJDEubG9jYXRpb25dID0gaXRlbSQxLnNjaGVtYTtcbiAgICAgIH1cbiAgICAgIGZvciAobGV0IGlkeCQyID0gMCwgaWR4X2ZpbmlzaCQyID0gbG9jYXRpb25zLmxlbmd0aDsgaWR4JDIgPCBpZHhfZmluaXNoJDI7ICsraWR4JDIpIHtcbiAgICAgICAgbGV0IGxvY2F0aW9uID0gbG9jYXRpb25zW2lkeCQyXTtcbiAgICAgICAgaXRlbXMucHVzaCh7XG4gICAgICAgICAgc2NoZW1hOiBwcm9wZXJ0aWVzW2xvY2F0aW9uXSxcbiAgICAgICAgICBsb2NhdGlvbjogbG9jYXRpb25cbiAgICAgICAgfSk7XG4gICAgICB9XG4gICAgICBsZXQgbXV0ID0gbmV3IFNjaGVtYShcIm9iamVjdFwiKTtcbiAgICAgIG11dC5pdGVtcyA9IGl0ZW1zO1xuICAgICAgbXV0LnByb3BlcnRpZXMgPSBwcm9wZXJ0aWVzO1xuICAgICAgbXV0LmFkZGl0aW9uYWxJdGVtcyA9IGFkZGl0aW9uYWxJdGVtczE7XG4gICAgICBtdXQuY29tcGlsZXIgPSBzY2hlbWFDb21waWxlcjtcbiAgICAgIHMgPSBtdXQ7XG4gICAgfSBlbHNlIHtcbiAgICAgIHMgPSB1bmRlZmluZWQ7XG4gICAgfVxuICB9IGVsc2Uge1xuICAgIHMgPSB1bmRlZmluZWQ7XG4gIH1cbiAgaWYgKHMgIT09IHVuZGVmaW5lZCkge1xuICAgIHJldHVybiBzO1xuICB9XG4gIHRocm93IG5ldyBFcnJvcihgW1N1cnldIGAgKyBcIlRoZSBtZXJnZSBzdXBwb3J0cyBvbmx5IHN0cnVjdHVyZWQgb2JqZWN0IHNjaGVtYXMgd2l0aG91dCB0cmFuc2Zvcm1hdGlvbnNcIik7XG59XG5cbmZ1bmN0aW9uIGdsb2JhbChvdmVycmlkZSkge1xuICBsZXQgZGVmYXVsdEFkZGl0aW9uYWxJdGVtcyA9IG92ZXJyaWRlLmRlZmF1bHRBZGRpdGlvbmFsSXRlbXM7XG4gIGdsb2JhbENvbmZpZy5hID0gZGVmYXVsdEFkZGl0aW9uYWxJdGVtcyAhPT0gdW5kZWZpbmVkID8gZGVmYXVsdEFkZGl0aW9uYWxJdGVtcyA6IFwic3RyaXBcIjtcbiAgbGV0IHByZXZEaXNhYmxlTmFuTnVtYmVyQ2hlY2sgPSBnbG9iYWxDb25maWcubjtcbiAgbGV0IGRpc2FibGVOYW5OdW1iZXJWYWxpZGF0aW9uID0gb3ZlcnJpZGUuZGlzYWJsZU5hbk51bWJlclZhbGlkYXRpb247XG4gIGdsb2JhbENvbmZpZy5uID0gZGlzYWJsZU5hbk51bWJlclZhbGlkYXRpb24gIT09IHVuZGVmaW5lZCA/IGRpc2FibGVOYW5OdW1iZXJWYWxpZGF0aW9uIDogZmFsc2U7XG4gIGlmIChwcmV2RGlzYWJsZU5hbk51bWJlckNoZWNrICE9PSBnbG9iYWxDb25maWcubikge1xuICAgIHJldHVybiByZXNldENhY2hlSW5QbGFjZShmbG9hdCk7XG4gIH1cbn1cblxubGV0IGpzb25TY2hlbWFNZXRhZGF0YUlkID0gYG06YCArIFwiSlNPTlNjaGVtYVwiO1xuXG5mdW5jdGlvbiBpbnRlcm5hbFRvSlNPTlNjaGVtYShzY2hlbWEsIGRlZnMpIHtcbiAgbGV0IGpzb25TY2hlbWEgPSB7fTtcbiAgc3dpdGNoIChzY2hlbWEudHlwZSkge1xuICAgIGNhc2UgXCJuZXZlclwiIDpcbiAgICAgIGpzb25TY2hlbWEubm90ID0ge307XG4gICAgICBicmVhaztcbiAgICBjYXNlIFwidW5rbm93blwiIDpcbiAgICAgIGJyZWFrO1xuICAgIGNhc2UgXCJzdHJpbmdcIiA6XG4gICAgICBsZXQgJCRjb25zdCA9IHNjaGVtYS5jb25zdDtcbiAgICAgIGpzb25TY2hlbWEudHlwZSA9IFwic3RyaW5nXCI7XG4gICAgICByZWZpbmVtZW50cyQxKHNjaGVtYSkuZm9yRWFjaChyZWZpbmVtZW50ID0+IHtcbiAgICAgICAgbGV0IG1hdGNoID0gcmVmaW5lbWVudC5raW5kO1xuICAgICAgICBpZiAodHlwZW9mIG1hdGNoICE9PSBcIm9iamVjdFwiKSB7XG4gICAgICAgICAgc3dpdGNoIChtYXRjaCkge1xuICAgICAgICAgICAgY2FzZSBcIkVtYWlsXCIgOlxuICAgICAgICAgICAgICBqc29uU2NoZW1hLmZvcm1hdCA9IFwiZW1haWxcIjtcbiAgICAgICAgICAgICAgcmV0dXJuO1xuICAgICAgICAgICAgY2FzZSBcIlV1aWRcIiA6XG4gICAgICAgICAgICAgIGpzb25TY2hlbWEuZm9ybWF0ID0gXCJ1dWlkXCI7XG4gICAgICAgICAgICAgIHJldHVybjtcbiAgICAgICAgICAgIGNhc2UgXCJDdWlkXCIgOlxuICAgICAgICAgICAgICByZXR1cm47XG4gICAgICAgICAgICBjYXNlIFwiVXJsXCIgOlxuICAgICAgICAgICAgICBqc29uU2NoZW1hLmZvcm1hdCA9IFwidXJpXCI7XG4gICAgICAgICAgICAgIHJldHVybjtcbiAgICAgICAgICAgIGNhc2UgXCJEYXRldGltZVwiIDpcbiAgICAgICAgICAgICAganNvblNjaGVtYS5mb3JtYXQgPSBcImRhdGUtdGltZVwiO1xuICAgICAgICAgICAgICByZXR1cm47XG4gICAgICAgICAgfVxuICAgICAgICB9IGVsc2Uge1xuICAgICAgICAgIHN3aXRjaCAobWF0Y2guVEFHKSB7XG4gICAgICAgICAgICBjYXNlIFwiTWluXCIgOlxuICAgICAgICAgICAgICBqc29uU2NoZW1hLm1pbkxlbmd0aCA9IG1hdGNoLmxlbmd0aDtcbiAgICAgICAgICAgICAgcmV0dXJuO1xuICAgICAgICAgICAgY2FzZSBcIk1heFwiIDpcbiAgICAgICAgICAgICAganNvblNjaGVtYS5tYXhMZW5ndGggPSBtYXRjaC5sZW5ndGg7XG4gICAgICAgICAgICAgIHJldHVybjtcbiAgICAgICAgICAgIGNhc2UgXCJMZW5ndGhcIiA6XG4gICAgICAgICAgICAgIGxldCBsZW5ndGggPSBtYXRjaC5sZW5ndGg7XG4gICAgICAgICAgICAgIGpzb25TY2hlbWEubWluTGVuZ3RoID0gbGVuZ3RoO1xuICAgICAgICAgICAgICBqc29uU2NoZW1hLm1heExlbmd0aCA9IGxlbmd0aDtcbiAgICAgICAgICAgICAgcmV0dXJuO1xuICAgICAgICAgICAgY2FzZSBcIlBhdHRlcm5cIiA6XG4gICAgICAgICAgICAgIGpzb25TY2hlbWEucGF0dGVybiA9IFN0cmluZyhtYXRjaC5yZSk7XG4gICAgICAgICAgICAgIHJldHVybjtcbiAgICAgICAgICB9XG4gICAgICAgIH1cbiAgICAgIH0pO1xuICAgICAgaWYgKCQkY29uc3QgIT09IHVuZGVmaW5lZCkge1xuICAgICAgICBqc29uU2NoZW1hLmNvbnN0ID0gJCRjb25zdDtcbiAgICAgIH1cbiAgICAgIGJyZWFrO1xuICAgIGNhc2UgXCJudW1iZXJcIiA6XG4gICAgICBsZXQgZm9ybWF0ID0gc2NoZW1hLmZvcm1hdDtcbiAgICAgIGxldCAkJGNvbnN0JDEgPSBzY2hlbWEuY29uc3Q7XG4gICAgICBpZiAoZm9ybWF0ICE9PSB1bmRlZmluZWQpIHtcbiAgICAgICAgaWYgKGZvcm1hdCA9PT0gXCJpbnQzMlwiKSB7XG4gICAgICAgICAganNvblNjaGVtYS50eXBlID0gXCJpbnRlZ2VyXCI7XG4gICAgICAgICAgcmVmaW5lbWVudHMkMihzY2hlbWEpLmZvckVhY2gocmVmaW5lbWVudCA9PiB7XG4gICAgICAgICAgICBsZXQgbWF0Y2ggPSByZWZpbmVtZW50LmtpbmQ7XG4gICAgICAgICAgICBpZiAobWF0Y2guVEFHID09PSBcIk1pblwiKSB7XG4gICAgICAgICAgICAgIGpzb25TY2hlbWEubWluaW11bSA9IG1hdGNoLnZhbHVlO1xuICAgICAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICAgICAganNvblNjaGVtYS5tYXhpbXVtID0gbWF0Y2gudmFsdWU7XG4gICAgICAgICAgICB9XG4gICAgICAgICAgfSk7XG4gICAgICAgIH0gZWxzZSB7XG4gICAgICAgICAganNvblNjaGVtYS50eXBlID0gXCJpbnRlZ2VyXCI7XG4gICAgICAgICAganNvblNjaGVtYS5tYXhpbXVtID0gNjU1MzU7XG4gICAgICAgICAganNvblNjaGVtYS5taW5pbXVtID0gMDtcbiAgICAgICAgfVxuICAgICAgfSBlbHNlIHtcbiAgICAgICAganNvblNjaGVtYS50eXBlID0gXCJudW1iZXJcIjtcbiAgICAgICAgcmVmaW5lbWVudHMkMyhzY2hlbWEpLmZvckVhY2gocmVmaW5lbWVudCA9PiB7XG4gICAgICAgICAgbGV0IG1hdGNoID0gcmVmaW5lbWVudC5raW5kO1xuICAgICAgICAgIGlmIChtYXRjaC5UQUcgPT09IFwiTWluXCIpIHtcbiAgICAgICAgICAgIGpzb25TY2hlbWEubWluaW11bSA9IG1hdGNoLnZhbHVlO1xuICAgICAgICAgIH0gZWxzZSB7XG4gICAgICAgICAgICBqc29uU2NoZW1hLm1heGltdW0gPSBtYXRjaC52YWx1ZTtcbiAgICAgICAgICB9XG4gICAgICAgIH0pO1xuICAgICAgfVxuICAgICAgaWYgKCQkY29uc3QkMSAhPT0gdW5kZWZpbmVkKSB7XG4gICAgICAgIGpzb25TY2hlbWEuY29uc3QgPSAkJGNvbnN0JDE7XG4gICAgICB9XG4gICAgICBicmVhaztcbiAgICBjYXNlIFwiYm9vbGVhblwiIDpcbiAgICAgIGxldCAkJGNvbnN0JDIgPSBzY2hlbWEuY29uc3Q7XG4gICAgICBqc29uU2NoZW1hLnR5cGUgPSBcImJvb2xlYW5cIjtcbiAgICAgIGlmICgkJGNvbnN0JDIgIT09IHVuZGVmaW5lZCkge1xuICAgICAgICBqc29uU2NoZW1hLmNvbnN0ID0gJCRjb25zdCQyO1xuICAgICAgfVxuICAgICAgYnJlYWs7XG4gICAgY2FzZSBcIm51bGxcIiA6XG4gICAgICBqc29uU2NoZW1hLnR5cGUgPSBcIm51bGxcIjtcbiAgICAgIGJyZWFrO1xuICAgIGNhc2UgXCJhcnJheVwiIDpcbiAgICAgIGxldCBhZGRpdGlvbmFsSXRlbXMgPSBzY2hlbWEuYWRkaXRpb25hbEl0ZW1zO1xuICAgICAgbGV0IGV4aXQgPSAwO1xuICAgICAgaWYgKGFkZGl0aW9uYWxJdGVtcyA9PT0gXCJzdHJpcFwiIHx8IGFkZGl0aW9uYWxJdGVtcyA9PT0gXCJzdHJpY3RcIikge1xuICAgICAgICBleGl0ID0gMTtcbiAgICAgIH0gZWxzZSB7XG4gICAgICAgIGpzb25TY2hlbWEuaXRlbXMgPSBpbnRlcm5hbFRvSlNPTlNjaGVtYShhZGRpdGlvbmFsSXRlbXMsIGRlZnMpO1xuICAgICAgICBqc29uU2NoZW1hLnR5cGUgPSBcImFycmF5XCI7XG4gICAgICAgIHJlZmluZW1lbnRzKHNjaGVtYSkuZm9yRWFjaChyZWZpbmVtZW50ID0+IHtcbiAgICAgICAgICBsZXQgbWF0Y2ggPSByZWZpbmVtZW50LmtpbmQ7XG4gICAgICAgICAgc3dpdGNoIChtYXRjaC5UQUcpIHtcbiAgICAgICAgICAgIGNhc2UgXCJNaW5cIiA6XG4gICAgICAgICAgICAgIGpzb25TY2hlbWEubWluSXRlbXMgPSBtYXRjaC5sZW5ndGg7XG4gICAgICAgICAgICAgIHJldHVybjtcbiAgICAgICAgICAgIGNhc2UgXCJNYXhcIiA6XG4gICAgICAgICAgICAgIGpzb25TY2hlbWEubWF4SXRlbXMgPSBtYXRjaC5sZW5ndGg7XG4gICAgICAgICAgICAgIHJldHVybjtcbiAgICAgICAgICAgIGNhc2UgXCJMZW5ndGhcIiA6XG4gICAgICAgICAgICAgIGxldCBsZW5ndGggPSBtYXRjaC5sZW5ndGg7XG4gICAgICAgICAgICAgIGpzb25TY2hlbWEubWF4SXRlbXMgPSBsZW5ndGg7XG4gICAgICAgICAgICAgIGpzb25TY2hlbWEubWluSXRlbXMgPSBsZW5ndGg7XG4gICAgICAgICAgICAgIHJldHVybjtcbiAgICAgICAgICB9XG4gICAgICAgIH0pO1xuICAgICAgfVxuICAgICAgaWYgKGV4aXQgPT09IDEpIHtcbiAgICAgICAgbGV0IGl0ZW1zID0gc2NoZW1hLml0ZW1zLm1hcChpdGVtID0+IChpbnRlcm5hbFRvSlNPTlNjaGVtYShpdGVtLnNjaGVtYSwgZGVmcykpKTtcbiAgICAgICAgbGV0IGl0ZW1zTnVtYmVyID0gaXRlbXMubGVuZ3RoO1xuICAgICAgICBqc29uU2NoZW1hLml0ZW1zID0gUHJpbWl0aXZlX29wdGlvbi5zb21lKGl0ZW1zKTtcbiAgICAgICAganNvblNjaGVtYS50eXBlID0gXCJhcnJheVwiO1xuICAgICAgICBqc29uU2NoZW1hLm1pbkl0ZW1zID0gaXRlbXNOdW1iZXI7XG4gICAgICAgIGpzb25TY2hlbWEubWF4SXRlbXMgPSBpdGVtc051bWJlcjtcbiAgICAgIH1cbiAgICAgIGJyZWFrO1xuICAgIGNhc2UgXCJvYmplY3RcIiA6XG4gICAgICBsZXQgYWRkaXRpb25hbEl0ZW1zJDEgPSBzY2hlbWEuYWRkaXRpb25hbEl0ZW1zO1xuICAgICAgbGV0IGV4aXQkMSA9IDA7XG4gICAgICBpZiAoYWRkaXRpb25hbEl0ZW1zJDEgPT09IFwic3RyaXBcIiB8fCBhZGRpdGlvbmFsSXRlbXMkMSA9PT0gXCJzdHJpY3RcIikge1xuICAgICAgICBleGl0JDEgPSAxO1xuICAgICAgfSBlbHNlIHtcbiAgICAgICAganNvblNjaGVtYS50eXBlID0gXCJvYmplY3RcIjtcbiAgICAgICAganNvblNjaGVtYS5hZGRpdGlvbmFsUHJvcGVydGllcyA9IGludGVybmFsVG9KU09OU2NoZW1hKGFkZGl0aW9uYWxJdGVtcyQxLCBkZWZzKTtcbiAgICAgIH1cbiAgICAgIGlmIChleGl0JDEgPT09IDEpIHtcbiAgICAgICAgbGV0IHByb3BlcnRpZXMgPSB7fTtcbiAgICAgICAgbGV0IHJlcXVpcmVkID0gW107XG4gICAgICAgIHNjaGVtYS5pdGVtcy5mb3JFYWNoKGl0ZW0gPT4ge1xuICAgICAgICAgIGxldCBmaWVsZFNjaGVtYSA9IGludGVybmFsVG9KU09OU2NoZW1hKGl0ZW0uc2NoZW1hLCBkZWZzKTtcbiAgICAgICAgICBpZiAoIWlzT3B0aW9uYWwoaXRlbS5zY2hlbWEpKSB7XG4gICAgICAgICAgICByZXF1aXJlZC5wdXNoKGl0ZW0ubG9jYXRpb24pO1xuICAgICAgICAgIH1cbiAgICAgICAgICBwcm9wZXJ0aWVzW2l0ZW0ubG9jYXRpb25dID0gZmllbGRTY2hlbWE7XG4gICAgICAgIH0pO1xuICAgICAgICBqc29uU2NoZW1hLnR5cGUgPSBcIm9iamVjdFwiO1xuICAgICAgICBqc29uU2NoZW1hLnByb3BlcnRpZXMgPSBwcm9wZXJ0aWVzO1xuICAgICAgICBsZXQgdG1wO1xuICAgICAgICB0bXAgPSBhZGRpdGlvbmFsSXRlbXMkMSA9PT0gXCJzdHJpcFwiIHx8IGFkZGl0aW9uYWxJdGVtcyQxID09PSBcInN0cmljdFwiID8gYWRkaXRpb25hbEl0ZW1zJDEgPT09IFwic3RyaXBcIiA6IHRydWU7XG4gICAgICAgIGpzb25TY2hlbWEuYWRkaXRpb25hbFByb3BlcnRpZXMgPSB0bXA7XG4gICAgICAgIGlmIChyZXF1aXJlZC5sZW5ndGggIT09IDApIHtcbiAgICAgICAgICBqc29uU2NoZW1hLnJlcXVpcmVkID0gcmVxdWlyZWQ7XG4gICAgICAgIH1cbiAgICAgIH1cbiAgICAgIGJyZWFrO1xuICAgIGNhc2UgXCJ1bmlvblwiIDpcbiAgICAgIGxldCBsaXRlcmFscyA9IFtdO1xuICAgICAgbGV0IGl0ZW1zJDEgPSBbXTtcbiAgICAgIHNjaGVtYS5hbnlPZi5mb3JFYWNoKGNoaWxkU2NoZW1hID0+IHtcbiAgICAgICAgaWYgKGNoaWxkU2NoZW1hLnR5cGUgPT09IFwidW5kZWZpbmVkXCIpIHtcbiAgICAgICAgICByZXR1cm47XG4gICAgICAgIH1cbiAgICAgICAgaXRlbXMkMS5wdXNoKGludGVybmFsVG9KU09OU2NoZW1hKGNoaWxkU2NoZW1hLCBkZWZzKSk7XG4gICAgICAgIGlmIChjb25zdEZpZWxkIGluIGNoaWxkU2NoZW1hKSB7XG4gICAgICAgICAgbGl0ZXJhbHMucHVzaChjaGlsZFNjaGVtYS5jb25zdCk7XG4gICAgICAgICAgcmV0dXJuO1xuICAgICAgICB9XG4gICAgICB9KTtcbiAgICAgIGxldCBpdGVtc051bWJlciQxID0gaXRlbXMkMS5sZW5ndGg7XG4gICAgICBsZXQgJCRkZWZhdWx0ID0gc2NoZW1hLmRlZmF1bHQ7XG4gICAgICBpZiAoJCRkZWZhdWx0ICE9PSB1bmRlZmluZWQpIHtcbiAgICAgICAganNvblNjaGVtYS5kZWZhdWx0ID0gUHJpbWl0aXZlX29wdGlvbi52YWxGcm9tT3B0aW9uKCQkZGVmYXVsdCk7XG4gICAgICB9XG4gICAgICBpZiAoaXRlbXNOdW1iZXIkMSA9PT0gMSkge1xuICAgICAgICBPYmplY3QuYXNzaWduKGpzb25TY2hlbWEsIGl0ZW1zJDFbMF0pO1xuICAgICAgfSBlbHNlIGlmIChsaXRlcmFscy5sZW5ndGggPT09IGl0ZW1zTnVtYmVyJDEpIHtcbiAgICAgICAganNvblNjaGVtYS5lbnVtID0gbGl0ZXJhbHM7XG4gICAgICB9IGVsc2Uge1xuICAgICAgICBqc29uU2NoZW1hLmFueU9mID0gaXRlbXMkMTtcbiAgICAgIH1cbiAgICAgIGJyZWFrO1xuICAgIGNhc2UgXCJyZWZcIiA6XG4gICAgICBsZXQgcmVmID0gc2NoZW1hLiRyZWY7XG4gICAgICBpZiAocmVmID09PSBkZWZzUGF0aCArIGpzb25OYW1lKSB7XG4gICAgICAgIFxuICAgICAgfSBlbHNlIHtcbiAgICAgICAganNvblNjaGVtYS4kcmVmID0gcmVmO1xuICAgICAgfVxuICAgICAgYnJlYWs7XG4gICAgZGVmYXVsdDpcbiAgICAgIHRocm93IG5ldyBFcnJvcihgW1N1cnldIGAgKyBcIlVuZXhwZWN0ZWQgc2NoZW1hIHR5cGVcIik7XG4gIH1cbiAgbGV0IG0gPSBzY2hlbWEuZGVzY3JpcHRpb247XG4gIGlmIChtICE9PSB1bmRlZmluZWQpIHtcbiAgICBqc29uU2NoZW1hLmRlc2NyaXB0aW9uID0gbTtcbiAgfVxuICBsZXQgbSQxID0gc2NoZW1hLnRpdGxlO1xuICBpZiAobSQxICE9PSB1bmRlZmluZWQpIHtcbiAgICBqc29uU2NoZW1hLnRpdGxlID0gbSQxO1xuICB9XG4gIGxldCBkZXByZWNhdGVkID0gc2NoZW1hLmRlcHJlY2F0ZWQ7XG4gIGlmIChkZXByZWNhdGVkICE9PSB1bmRlZmluZWQpIHtcbiAgICBqc29uU2NoZW1hLmRlcHJlY2F0ZWQgPSBkZXByZWNhdGVkO1xuICB9XG4gIGxldCBleGFtcGxlcyA9IHNjaGVtYS5leGFtcGxlcztcbiAgaWYgKGV4YW1wbGVzICE9PSB1bmRlZmluZWQpIHtcbiAgICBqc29uU2NoZW1hLmV4YW1wbGVzID0gZXhhbXBsZXM7XG4gIH1cbiAgbGV0IHNjaGVtYURlZnMgPSBzY2hlbWEuJGRlZnM7XG4gIGlmIChzY2hlbWFEZWZzICE9PSB1bmRlZmluZWQpIHtcbiAgICBPYmplY3QuYXNzaWduKGRlZnMsIHNjaGVtYURlZnMpO1xuICB9XG4gIGxldCBtZXRhZGF0YVJhd1NjaGVtYSA9IHNjaGVtYVtqc29uU2NoZW1hTWV0YWRhdGFJZF07XG4gIGlmIChtZXRhZGF0YVJhd1NjaGVtYSAhPT0gdW5kZWZpbmVkKSB7XG4gICAgT2JqZWN0LmFzc2lnbihqc29uU2NoZW1hLCBtZXRhZGF0YVJhd1NjaGVtYSk7XG4gIH1cbiAgcmV0dXJuIGpzb25TY2hlbWE7XG59XG5cbmZ1bmN0aW9uIHRvSlNPTlNjaGVtYShzY2hlbWEpIHtcbiAganNvbmFibGVWYWxpZGF0aW9uKHNjaGVtYSwgc2NoZW1hLCBcIlwiLCA4KTtcbiAgbGV0IGRlZnMgPSB7fTtcbiAgbGV0IGpzb25TY2hlbWEgPSBpbnRlcm5hbFRvSlNPTlNjaGVtYShzY2hlbWEsIGRlZnMpO1xuICAoKGRlbGV0ZSBkZWZzLkpTT04pKTtcbiAgbGV0IGRlZnNLZXlzID0gT2JqZWN0LmtleXMoZGVmcyk7XG4gIGlmIChkZWZzS2V5cy5sZW5ndGgpIHtcbiAgICBkZWZzS2V5cy5mb3JFYWNoKGtleSA9PiB7XG4gICAgICBkZWZzW2tleV0gPSBpbnRlcm5hbFRvSlNPTlNjaGVtYShkZWZzW2tleV0sIDApO1xuICAgIH0pO1xuICAgIGpzb25TY2hlbWEuJGRlZnMgPSBkZWZzO1xuICB9XG4gIHJldHVybiBqc29uU2NoZW1hO1xufVxuXG5mdW5jdGlvbiBleHRlbmRKU09OU2NoZW1hKHNjaGVtYSwganNvblNjaGVtYSkge1xuICBsZXQgZXhpc3RpbmdTY2hlbWFFeHRlbmQgPSBzY2hlbWFbanNvblNjaGVtYU1ldGFkYXRhSWRdO1xuICByZXR1cm4gc2V0JDEoc2NoZW1hLCBqc29uU2NoZW1hTWV0YWRhdGFJZCwgZXhpc3RpbmdTY2hlbWFFeHRlbmQgIT09IHVuZGVmaW5lZCA/IE9iamVjdC5hc3NpZ24oe30sIGV4aXN0aW5nU2NoZW1hRXh0ZW5kLCBqc29uU2NoZW1hKSA6IGpzb25TY2hlbWEpO1xufVxuXG5sZXQgcHJpbWl0aXZlVG9TY2hlbWEgPSBwYXJzZSQxO1xuXG5mdW5jdGlvbiB0b0ludFNjaGVtYShqc29uU2NoZW1hKSB7XG4gIGxldCBtaW5pbXVtID0ganNvblNjaGVtYS5taW5pbXVtO1xuICBsZXQgc2NoZW1hO1xuICBpZiAobWluaW11bSAhPT0gdW5kZWZpbmVkKSB7XG4gICAgc2NoZW1hID0gaW50TWluKGludCwgbWluaW11bSB8IDAsIHVuZGVmaW5lZCk7XG4gIH0gZWxzZSB7XG4gICAgbGV0IGV4Y2x1c2l2ZU1pbmltdW0gPSBqc29uU2NoZW1hLmV4Y2x1c2l2ZU1pbmltdW07XG4gICAgc2NoZW1hID0gZXhjbHVzaXZlTWluaW11bSAhPT0gdW5kZWZpbmVkID8gaW50TWluKGludCwgZXhjbHVzaXZlTWluaW11bSArIDEgfCAwLCB1bmRlZmluZWQpIDogaW50O1xuICB9XG4gIGxldCBtYXhpbXVtID0ganNvblNjaGVtYS5tYXhpbXVtO1xuICBpZiAobWF4aW11bSAhPT0gdW5kZWZpbmVkKSB7XG4gICAgcmV0dXJuIGludE1heChzY2hlbWEsIG1heGltdW0gfCAwLCB1bmRlZmluZWQpO1xuICB9XG4gIGxldCBleGNsdXNpdmVNaW5pbXVtJDEgPSBqc29uU2NoZW1hLmV4Y2x1c2l2ZU1pbmltdW07XG4gIGlmIChleGNsdXNpdmVNaW5pbXVtJDEgIT09IHVuZGVmaW5lZCkge1xuICAgIHJldHVybiBpbnRNYXgoc2NoZW1hLCBleGNsdXNpdmVNaW5pbXVtJDEgLSAxIHwgMCwgdW5kZWZpbmVkKTtcbiAgfSBlbHNlIHtcbiAgICByZXR1cm4gc2NoZW1hO1xuICB9XG59XG5cbmZ1bmN0aW9uIGRlZmluaXRpb25Ub0RlZmF1bHRWYWx1ZShkZWZpbml0aW9uKSB7XG4gIGlmICh0eXBlb2YgZGVmaW5pdGlvbiAhPT0gXCJvYmplY3RcIikge1xuICAgIHJldHVybjtcbiAgfSBlbHNlIHtcbiAgICByZXR1cm4gZGVmaW5pdGlvbi5kZWZhdWx0O1xuICB9XG59XG5cbmZ1bmN0aW9uIGZyb21KU09OU2NoZW1hKGpzb25TY2hlbWEpIHtcbiAgbGV0IGRlZmluaXRpb25Ub1NjaGVtYSQxID0gZGVmaW5pdGlvbiA9PiB7XG4gICAgaWYgKHR5cGVvZiBkZWZpbml0aW9uICE9PSBcIm9iamVjdFwiKSB7XG4gICAgICBpZiAoZGVmaW5pdGlvbiA9PT0gZmFsc2UpIHtcbiAgICAgICAgcmV0dXJuIG5ldmVyO1xuICAgICAgfSBlbHNlIHtcbiAgICAgICAgcmV0dXJuIGpzb247XG4gICAgICB9XG4gICAgfSBlbHNlIHtcbiAgICAgIHJldHVybiBmcm9tSlNPTlNjaGVtYShkZWZpbml0aW9uKTtcbiAgICB9XG4gIH07XG4gIGxldCB0eXBlXyA9IGpzb25TY2hlbWEudHlwZTtcbiAgbGV0IHNjaGVtYTtcbiAgbGV0IGV4aXQgPSAwO1xuICBsZXQgZXhpdCQxID0gMDtcbiAgaWYgKGpzb25TY2hlbWEubnVsbGFibGUpIHtcbiAgICBzY2hlbWEgPSBmYWN0b3J5JDUoZnJvbUpTT05TY2hlbWEoT2JqZWN0LmFzc2lnbih7fSwganNvblNjaGVtYSwge1xuICAgICAgbnVsbGFibGU6IGZhbHNlXG4gICAgfSkpKTtcbiAgfSBlbHNlIGlmICh0eXBlXyAhPT0gdW5kZWZpbmVkKSB7XG4gICAgbGV0IHR5cGVfJDEgPSBQcmltaXRpdmVfb3B0aW9uLnZhbEZyb21PcHRpb24odHlwZV8pO1xuICAgIGlmICh0eXBlXyQxID09PSBcIm9iamVjdFwiKSB7XG4gICAgICBsZXQgcHJvcGVydGllcyA9IGpzb25TY2hlbWEucHJvcGVydGllcztcbiAgICAgIGlmIChwcm9wZXJ0aWVzICE9PSB1bmRlZmluZWQpIHtcbiAgICAgICAgbGV0IHNjaGVtYSQxID0gb2JqZWN0KHMgPT4ge1xuICAgICAgICAgIGxldCBvYmogPSB7fTtcbiAgICAgICAgICBPYmplY3Qua2V5cyhwcm9wZXJ0aWVzKS5mb3JFYWNoKGtleSA9PiB7XG4gICAgICAgICAgICBsZXQgcHJvcGVydHkgPSBwcm9wZXJ0aWVzW2tleV07XG4gICAgICAgICAgICBsZXQgcHJvcGVydHlTY2hlbWEgPSBkZWZpbml0aW9uVG9TY2hlbWEkMShwcm9wZXJ0eSk7XG4gICAgICAgICAgICBsZXQgciA9IGpzb25TY2hlbWEucmVxdWlyZWQ7XG4gICAgICAgICAgICBsZXQgcHJvcGVydHlTY2hlbWEkMTtcbiAgICAgICAgICAgIGxldCBleGl0ID0gMDtcbiAgICAgICAgICAgIGlmIChyICE9PSB1bmRlZmluZWQgJiYgci5pbmNsdWRlcyhrZXkpKSB7XG4gICAgICAgICAgICAgIHByb3BlcnR5U2NoZW1hJDEgPSBwcm9wZXJ0eVNjaGVtYTtcbiAgICAgICAgICAgIH0gZWxzZSB7XG4gICAgICAgICAgICAgIGV4aXQgPSAxO1xuICAgICAgICAgICAgfVxuICAgICAgICAgICAgaWYgKGV4aXQgPT09IDEpIHtcbiAgICAgICAgICAgICAgbGV0IGRlZmF1bHRWYWx1ZSA9IGRlZmluaXRpb25Ub0RlZmF1bHRWYWx1ZShwcm9wZXJ0eSk7XG4gICAgICAgICAgICAgIGlmIChkZWZhdWx0VmFsdWUgIT09IHVuZGVmaW5lZCkge1xuICAgICAgICAgICAgICAgIGxldCBzY2hlbWEgPSBvcHRpb24ocHJvcGVydHlTY2hlbWEpO1xuICAgICAgICAgICAgICAgIHByb3BlcnR5U2NoZW1hJDEgPSBnZXRXaXRoRGVmYXVsdChzY2hlbWEsIHtcbiAgICAgICAgICAgICAgICAgIFRBRzogXCJWYWx1ZVwiLFxuICAgICAgICAgICAgICAgICAgXzA6IGRlZmF1bHRWYWx1ZVxuICAgICAgICAgICAgICAgIH0pO1xuICAgICAgICAgICAgICB9IGVsc2Uge1xuICAgICAgICAgICAgICAgIHByb3BlcnR5U2NoZW1hJDEgPSBvcHRpb24ocHJvcGVydHlTY2hlbWEpO1xuICAgICAgICAgICAgICB9XG4gICAgICAgICAgICB9XG4gICAgICAgICAgICBvYmpba2V5XSA9IHMuZihrZXksIHByb3BlcnR5U2NoZW1hJDEpO1xuICAgICAgICAgIH0pO1xuICAgICAgICAgIHJldHVybiBvYmo7XG4gICAgICAgIH0pO1xuICAgICAgICBsZXQgYWRkaXRpb25hbFByb3BlcnRpZXMgPSBqc29uU2NoZW1hLmFkZGl0aW9uYWxQcm9wZXJ0aWVzO1xuICAgICAgICBzY2hlbWEgPSBhZGRpdGlvbmFsUHJvcGVydGllcyA9PT0gZmFsc2UgPyBzdHJpY3Qoc2NoZW1hJDEpIDogc2NoZW1hJDE7XG4gICAgICB9IGVsc2Uge1xuICAgICAgICBsZXQgYWRkaXRpb25hbFByb3BlcnRpZXMkMSA9IGpzb25TY2hlbWEuYWRkaXRpb25hbFByb3BlcnRpZXM7XG4gICAgICAgIHNjaGVtYSA9IGFkZGl0aW9uYWxQcm9wZXJ0aWVzJDEgIT09IHVuZGVmaW5lZCA/IChcbiAgICAgICAgICAgIHR5cGVvZiBhZGRpdGlvbmFsUHJvcGVydGllcyQxICE9PSBcIm9iamVjdFwiID8gKFxuICAgICAgICAgICAgICAgIGFkZGl0aW9uYWxQcm9wZXJ0aWVzJDEgPT09IGZhbHNlID8gc3RyaWN0KG9iamVjdChwYXJhbSA9PiB7fSkpIDogZmFjdG9yeSQzKGpzb24pXG4gICAgICAgICAgICAgICkgOiBmYWN0b3J5JDMoZnJvbUpTT05TY2hlbWEoYWRkaXRpb25hbFByb3BlcnRpZXMkMSkpXG4gICAgICAgICAgKSA6IGRlZmluaXRpb25Ub1NjaGVtYSgpO1xuICAgICAgfVxuICAgIH0gZWxzZSBpZiAodHlwZV8kMSA9PT0gXCJhcnJheVwiKSB7XG4gICAgICBsZXQgaXRlbXMgPSBqc29uU2NoZW1hLml0ZW1zO1xuICAgICAgbGV0IHNjaGVtYSQyO1xuICAgICAgaWYgKGl0ZW1zICE9PSB1bmRlZmluZWQpIHtcbiAgICAgICAgbGV0IHNpbmdsZSA9IEpTT05TY2hlbWEuQXJyYXlhYmxlLmNsYXNzaWZ5KFByaW1pdGl2ZV9vcHRpb24udmFsRnJvbU9wdGlvbihpdGVtcykpO1xuICAgICAgICBpZiAoc2luZ2xlLlRBRyA9PT0gXCJTaW5nbGVcIikge1xuICAgICAgICAgIHNjaGVtYSQyID0gZmFjdG9yeSQyKGRlZmluaXRpb25Ub1NjaGVtYSQxKHNpbmdsZS5fMCkpO1xuICAgICAgICB9IGVsc2Uge1xuICAgICAgICAgIGxldCBhcnJheSA9IHNpbmdsZS5fMDtcbiAgICAgICAgICBzY2hlbWEkMiA9IHR1cGxlKHMgPT4gYXJyYXkubWFwKChkLCBpZHgpID0+IHMuaXRlbShpZHgsIGRlZmluaXRpb25Ub1NjaGVtYSQxKGQpKSkpO1xuICAgICAgICB9XG4gICAgICB9IGVsc2Uge1xuICAgICAgICBzY2hlbWEkMiA9IGZhY3RvcnkkMihqc29uKTtcbiAgICAgIH1cbiAgICAgIGxldCBtaW4gPSBqc29uU2NoZW1hLm1pbkl0ZW1zO1xuICAgICAgbGV0IHNjaGVtYSQzID0gbWluICE9PSB1bmRlZmluZWQgPyBhcnJheU1pbkxlbmd0aChzY2hlbWEkMiwgbWluLCB1bmRlZmluZWQpIDogc2NoZW1hJDI7XG4gICAgICBsZXQgbWF4ID0ganNvblNjaGVtYS5tYXhJdGVtcztcbiAgICAgIHNjaGVtYSA9IG1heCAhPT0gdW5kZWZpbmVkID8gYXJyYXlNYXhMZW5ndGgoc2NoZW1hJDMsIG1heCwgdW5kZWZpbmVkKSA6IHNjaGVtYSQzO1xuICAgIH0gZWxzZSB7XG4gICAgICBleGl0JDEgPSAyO1xuICAgIH1cbiAgfSBlbHNlIHtcbiAgICBleGl0JDEgPSAyO1xuICB9XG4gIGlmIChleGl0JDEgPT09IDIpIHtcbiAgICBsZXQgcHJpbWl0aXZlcyA9IGpzb25TY2hlbWEuZW51bTtcbiAgICBsZXQgZGVmaW5pdGlvbnMgPSBqc29uU2NoZW1hLmFsbE9mO1xuICAgIGxldCBkZWZpbml0aW9ucyQxID0ganNvblNjaGVtYS5hbnlPZjtcbiAgICBpZiAoZGVmaW5pdGlvbnMkMSAhPT0gdW5kZWZpbmVkKSB7XG4gICAgICBsZXQgbGVuID0gZGVmaW5pdGlvbnMkMS5sZW5ndGg7XG4gICAgICBzY2hlbWEgPSBsZW4gIT09IDEgPyAoXG4gICAgICAgICAgbGVuICE9PSAwID8gZmFjdG9yeShkZWZpbml0aW9ucyQxLm1hcChkZWZpbml0aW9uVG9TY2hlbWEkMSkpIDoganNvblxuICAgICAgICApIDogZGVmaW5pdGlvblRvU2NoZW1hJDEoZGVmaW5pdGlvbnMkMVswXSk7XG4gICAgfSBlbHNlIGlmIChkZWZpbml0aW9ucyAhPT0gdW5kZWZpbmVkKSB7XG4gICAgICBsZXQgbGVuJDEgPSBkZWZpbml0aW9ucy5sZW5ndGg7XG4gICAgICBzY2hlbWEgPSBsZW4kMSAhPT0gMSA/IChcbiAgICAgICAgICBsZW4kMSAhPT0gMCA/IHJlZmluZShqc29uLCBzID0+IChkYXRhID0+IHtcbiAgICAgICAgICAgICAgZGVmaW5pdGlvbnMuZm9yRWFjaChkID0+IHtcbiAgICAgICAgICAgICAgICB0cnkge1xuICAgICAgICAgICAgICAgICAgcmV0dXJuIGFzc2VydE9yVGhyb3coZGF0YSwgZGVmaW5pdGlvblRvU2NoZW1hJDEoZCkpO1xuICAgICAgICAgICAgICAgIH0gY2F0Y2ggKGV4bikge1xuICAgICAgICAgICAgICAgICAgcmV0dXJuIHMuZmFpbChcIlNob3VsZCBwYXNzIGZvciBhbGwgc2NoZW1hcyBvZiB0aGUgYWxsT2YgcHJvcGVydHkuXCIsIHVuZGVmaW5lZCk7XG4gICAgICAgICAgICAgICAgfVxuICAgICAgICAgICAgICB9KTtcbiAgICAgICAgICAgIH0pKSA6IGpzb25cbiAgICAgICAgKSA6IGRlZmluaXRpb25Ub1NjaGVtYSQxKGRlZmluaXRpb25zWzBdKTtcbiAgICB9IGVsc2Uge1xuICAgICAgbGV0IGRlZmluaXRpb25zJDIgPSBqc29uU2NoZW1hLm9uZU9mO1xuICAgICAgaWYgKGRlZmluaXRpb25zJDIgIT09IHVuZGVmaW5lZCkge1xuICAgICAgICBsZXQgbGVuJDIgPSBkZWZpbml0aW9ucyQyLmxlbmd0aDtcbiAgICAgICAgc2NoZW1hID0gbGVuJDIgIT09IDEgPyAoXG4gICAgICAgICAgICBsZW4kMiAhPT0gMCA/IHJlZmluZShqc29uLCBzID0+IChkYXRhID0+IHtcbiAgICAgICAgICAgICAgICBsZXQgaGFzT25lVmFsaWRSZWYgPSB7XG4gICAgICAgICAgICAgICAgICBjb250ZW50czogZmFsc2VcbiAgICAgICAgICAgICAgICB9O1xuICAgICAgICAgICAgICAgIGRlZmluaXRpb25zJDIuZm9yRWFjaChkID0+IHtcbiAgICAgICAgICAgICAgICAgIGxldCBwYXNzZWQ7XG4gICAgICAgICAgICAgICAgICB0cnkge1xuICAgICAgICAgICAgICAgICAgICBhc3NlcnRPclRocm93KGRhdGEsIGRlZmluaXRpb25Ub1NjaGVtYSQxKGQpKTtcbiAgICAgICAgICAgICAgICAgICAgcGFzc2VkID0gdHJ1ZTtcbiAgICAgICAgICAgICAgICAgIH0gY2F0Y2ggKGV4bikge1xuICAgICAgICAgICAgICAgICAgICBwYXNzZWQgPSBmYWxzZTtcbiAgICAgICAgICAgICAgICAgIH1cbiAgICAgICAgICAgICAgICAgIGlmIChwYXNzZWQpIHtcbiAgICAgICAgICAgICAgICAgICAgaWYgKGhhc09uZVZhbGlkUmVmLmNvbnRlbnRzKSB7XG4gICAgICAgICAgICAgICAgICAgICAgcy5mYWlsKFwiU2hvdWxkIHBhc3Mgc2luZ2xlIHNjaGVtYSBhY2NvcmRpbmcgdG8gdGhlIG9uZU9mIHByb3BlcnR5LlwiLCB1bmRlZmluZWQpO1xuICAgICAgICAgICAgICAgICAgICB9XG4gICAgICAgICAgICAgICAgICAgIGhhc09uZVZhbGlkUmVmLmNvbnRlbnRzID0gdHJ1ZTtcbiAgICAgICAgICAgICAgICAgICAgcmV0dXJuO1xuICAgICAgICAgICAgICAgICAgfVxuICAgICAgICAgICAgICAgIH0pO1xuICAgICAgICAgICAgICAgIGlmICghaGFzT25lVmFsaWRSZWYuY29udGVudHMpIHtcbiAgICAgICAgICAgICAgICAgIHJldHVybiBzLmZhaWwoXCJTaG91bGQgcGFzcyBhdCBsZWFzdCBvbmUgc2NoZW1hIGFjY29yZGluZyB0byB0aGUgb25lT2YgcHJvcGVydHkuXCIsIHVuZGVmaW5lZCk7XG4gICAgICAgICAgICAgICAgfVxuICAgICAgICAgICAgICB9KSkgOiBqc29uXG4gICAgICAgICAgKSA6IGRlZmluaXRpb25Ub1NjaGVtYSQxKGRlZmluaXRpb25zJDJbMF0pO1xuICAgICAgfSBlbHNlIHtcbiAgICAgICAgbGV0IG5vdCA9IGpzb25TY2hlbWEubm90O1xuICAgICAgICBpZiAobm90ICE9PSB1bmRlZmluZWQpIHtcbiAgICAgICAgICBzY2hlbWEgPSByZWZpbmUoanNvbiwgcyA9PiAoZGF0YSA9PiB7XG4gICAgICAgICAgICBsZXQgcGFzc2VkO1xuICAgICAgICAgICAgdHJ5IHtcbiAgICAgICAgICAgICAgYXNzZXJ0T3JUaHJvdyhkYXRhLCBkZWZpbml0aW9uVG9TY2hlbWEkMShub3QpKTtcbiAgICAgICAgICAgICAgcGFzc2VkID0gdHJ1ZTtcbiAgICAgICAgICAgIH0gY2F0Y2ggKGV4bikge1xuICAgICAgICAgICAgICBwYXNzZWQgPSBmYWxzZTtcbiAgICAgICAgICAgIH1cbiAgICAgICAgICAgIGlmIChwYXNzZWQpIHtcbiAgICAgICAgICAgICAgcmV0dXJuIHMuZmFpbChcIlNob3VsZCBOT1QgYmUgdmFsaWQgYWdhaW5zdCBzY2hlbWEgaW4gdGhlIG5vdCBwcm9wZXJ0eS5cIiwgdW5kZWZpbmVkKTtcbiAgICAgICAgICAgIH1cbiAgICAgICAgICB9KSk7XG4gICAgICAgIH0gZWxzZSBpZiAocHJpbWl0aXZlcyAhPT0gdW5kZWZpbmVkKSB7XG4gICAgICAgICAgbGV0IGxlbiQzID0gcHJpbWl0aXZlcy5sZW5ndGg7XG4gICAgICAgICAgc2NoZW1hID0gbGVuJDMgIT09IDEgPyAoXG4gICAgICAgICAgICAgIGxlbiQzICE9PSAwID8gZmFjdG9yeShwcmltaXRpdmVzLm1hcChwcmltaXRpdmVUb1NjaGVtYSkpIDoganNvblxuICAgICAgICAgICAgKSA6IHBhcnNlJDEocHJpbWl0aXZlc1swXSk7XG4gICAgICAgIH0gZWxzZSB7XG4gICAgICAgICAgbGV0ICQkY29uc3QgPSBqc29uU2NoZW1hLmNvbnN0O1xuICAgICAgICAgIGlmICgkJGNvbnN0ICE9PSB1bmRlZmluZWQpIHtcbiAgICAgICAgICAgIHNjaGVtYSA9IHBhcnNlJDEoJCRjb25zdCk7XG4gICAgICAgICAgfSBlbHNlIGlmICh0eXBlXyAhPT0gdW5kZWZpbmVkKSB7XG4gICAgICAgICAgICBsZXQgdHlwZV8kMiA9IFByaW1pdGl2ZV9vcHRpb24udmFsRnJvbU9wdGlvbih0eXBlXyk7XG4gICAgICAgICAgICBsZXQgZXhpdCQyID0gMDtcbiAgICAgICAgICAgIGxldCBleGl0JDMgPSAwO1xuICAgICAgICAgICAgaWYgKEFycmF5LmlzQXJyYXkodHlwZV8kMikpIHtcbiAgICAgICAgICAgICAgc2NoZW1hID0gZmFjdG9yeSh0eXBlXyQyLm1hcCh0eXBlXyA9PiBmcm9tSlNPTlNjaGVtYShPYmplY3QuYXNzaWduKHt9LCBqc29uU2NoZW1hLCB7XG4gICAgICAgICAgICAgICAgdHlwZTogUHJpbWl0aXZlX29wdGlvbi5zb21lKHR5cGVfKVxuICAgICAgICAgICAgICB9KSkpKTtcbiAgICAgICAgICAgIH0gZWxzZSBpZiAodHlwZV8kMiA9PT0gXCJzdHJpbmdcIikge1xuICAgICAgICAgICAgICBsZXQgcCA9IGpzb25TY2hlbWEucGF0dGVybjtcbiAgICAgICAgICAgICAgbGV0IHNjaGVtYSQ0ID0gcCAhPT0gdW5kZWZpbmVkID8gcGF0dGVybihzdHJpbmcsIG5ldyBSZWdFeHAocCksIHVuZGVmaW5lZCkgOiBzdHJpbmc7XG4gICAgICAgICAgICAgIGxldCBtaW5MZW5ndGggPSBqc29uU2NoZW1hLm1pbkxlbmd0aDtcbiAgICAgICAgICAgICAgbGV0IHNjaGVtYSQ1ID0gbWluTGVuZ3RoICE9PSB1bmRlZmluZWQgPyBzdHJpbmdNaW5MZW5ndGgoc2NoZW1hJDQsIG1pbkxlbmd0aCwgdW5kZWZpbmVkKSA6IHNjaGVtYSQ0O1xuICAgICAgICAgICAgICBsZXQgbWF4TGVuZ3RoID0ganNvblNjaGVtYS5tYXhMZW5ndGg7XG4gICAgICAgICAgICAgIGxldCBzY2hlbWEkNiA9IG1heExlbmd0aCAhPT0gdW5kZWZpbmVkID8gc3RyaW5nTWF4TGVuZ3RoKHNjaGVtYSQ1LCBtYXhMZW5ndGgsIHVuZGVmaW5lZCkgOiBzY2hlbWEkNTtcbiAgICAgICAgICAgICAgc3dpdGNoIChqc29uU2NoZW1hLmZvcm1hdCkge1xuICAgICAgICAgICAgICAgIGNhc2UgXCJkYXRlLXRpbWVcIiA6XG4gICAgICAgICAgICAgICAgICBzY2hlbWEgPSBkYXRldGltZShzY2hlbWEkNiwgdW5kZWZpbmVkKTtcbiAgICAgICAgICAgICAgICAgIGJyZWFrO1xuICAgICAgICAgICAgICAgIGNhc2UgXCJlbWFpbFwiIDpcbiAgICAgICAgICAgICAgICAgIHNjaGVtYSA9IGVtYWlsKHNjaGVtYSQ2LCB1bmRlZmluZWQpO1xuICAgICAgICAgICAgICAgICAgYnJlYWs7XG4gICAgICAgICAgICAgICAgY2FzZSBcInVyaVwiIDpcbiAgICAgICAgICAgICAgICAgIHNjaGVtYSA9IHVybChzY2hlbWEkNiwgdW5kZWZpbmVkKTtcbiAgICAgICAgICAgICAgICAgIGJyZWFrO1xuICAgICAgICAgICAgICAgIGNhc2UgXCJ1dWlkXCIgOlxuICAgICAgICAgICAgICAgICAgc2NoZW1hID0gdXVpZChzY2hlbWEkNiwgdW5kZWZpbmVkKTtcbiAgICAgICAgICAgICAgICAgIGJyZWFrO1xuICAgICAgICAgICAgICAgIGRlZmF1bHQ6XG4gICAgICAgICAgICAgICAgICBzY2hlbWEgPSBzY2hlbWEkNjtcbiAgICAgICAgICAgICAgfVxuICAgICAgICAgICAgfSBlbHNlIGlmICh0eXBlXyQyID09PSBcImludGVnZXJcIiB8fCBqc29uU2NoZW1hLmZvcm1hdCA9PT0gXCJpbnQ2NFwiICYmIHR5cGVfJDIgPT09IFwibnVtYmVyXCIpIHtcbiAgICAgICAgICAgICAgc2NoZW1hID0gdG9JbnRTY2hlbWEoanNvblNjaGVtYSk7XG4gICAgICAgICAgICB9IGVsc2Uge1xuICAgICAgICAgICAgICBleGl0JDMgPSA0O1xuICAgICAgICAgICAgfVxuICAgICAgICAgICAgaWYgKGV4aXQkMyA9PT0gNCkge1xuICAgICAgICAgICAgICBpZiAoanNvblNjaGVtYS5tdWx0aXBsZU9mICE9PSAxIHx8IHR5cGVfJDIgIT09IFwibnVtYmVyXCIpIHtcbiAgICAgICAgICAgICAgICBleGl0JDIgPSAzO1xuICAgICAgICAgICAgICB9IGVsc2Uge1xuICAgICAgICAgICAgICAgIHNjaGVtYSA9IHRvSW50U2NoZW1hKGpzb25TY2hlbWEpO1xuICAgICAgICAgICAgICB9XG4gICAgICAgICAgICB9XG4gICAgICAgICAgICBpZiAoZXhpdCQyID09PSAzKSB7XG4gICAgICAgICAgICAgIGlmICh0eXBlXyQyID09PSBcIm51bWJlclwiKSB7XG4gICAgICAgICAgICAgICAgbGV0IG1pbmltdW0gPSBqc29uU2NoZW1hLm1pbmltdW07XG4gICAgICAgICAgICAgICAgbGV0IHNjaGVtYSQ3O1xuICAgICAgICAgICAgICAgIGlmIChtaW5pbXVtICE9PSB1bmRlZmluZWQpIHtcbiAgICAgICAgICAgICAgICAgIHNjaGVtYSQ3ID0gZmxvYXRNaW4oZmxvYXQsIG1pbmltdW0sIHVuZGVmaW5lZCk7XG4gICAgICAgICAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICAgICAgICAgIGxldCBleGNsdXNpdmVNaW5pbXVtID0ganNvblNjaGVtYS5leGNsdXNpdmVNaW5pbXVtO1xuICAgICAgICAgICAgICAgICAgc2NoZW1hJDcgPSBleGNsdXNpdmVNaW5pbXVtICE9PSB1bmRlZmluZWQgPyBmbG9hdE1pbihmbG9hdCwgZXhjbHVzaXZlTWluaW11bSArIDEsIHVuZGVmaW5lZCkgOiBmbG9hdDtcbiAgICAgICAgICAgICAgICB9XG4gICAgICAgICAgICAgICAgbGV0IG1heGltdW0gPSBqc29uU2NoZW1hLm1heGltdW07XG4gICAgICAgICAgICAgICAgaWYgKG1heGltdW0gIT09IHVuZGVmaW5lZCkge1xuICAgICAgICAgICAgICAgICAgc2NoZW1hID0gZmxvYXRNYXgoc2NoZW1hJDcsIG1heGltdW0sIHVuZGVmaW5lZCk7XG4gICAgICAgICAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICAgICAgICAgIGxldCBleGNsdXNpdmVNaW5pbXVtJDEgPSBqc29uU2NoZW1hLmV4Y2x1c2l2ZU1pbmltdW07XG4gICAgICAgICAgICAgICAgICBzY2hlbWEgPSBleGNsdXNpdmVNaW5pbXVtJDEgIT09IHVuZGVmaW5lZCA/IGZsb2F0TWF4KHNjaGVtYSQ3LCBleGNsdXNpdmVNaW5pbXVtJDEgLSAxLCB1bmRlZmluZWQpIDogc2NoZW1hJDc7XG4gICAgICAgICAgICAgICAgfVxuICAgICAgICAgICAgICB9IGVsc2UgaWYgKHR5cGVfJDIgPT09IFwiYm9vbGVhblwiKSB7XG4gICAgICAgICAgICAgICAgc2NoZW1hID0gYm9vbDtcbiAgICAgICAgICAgICAgfSBlbHNlIGlmICh0eXBlXyQyID09PSBcIm51bGxcIikge1xuICAgICAgICAgICAgICAgIHNjaGVtYSA9IGpzX3NjaGVtYShudWxsKTtcbiAgICAgICAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICAgICAgICBleGl0ID0gMTtcbiAgICAgICAgICAgICAgfVxuICAgICAgICAgICAgfVxuICAgICAgICAgIH0gZWxzZSB7XG4gICAgICAgICAgICBleGl0ID0gMTtcbiAgICAgICAgICB9XG4gICAgICAgIH1cbiAgICAgIH1cbiAgICB9XG4gIH1cbiAgaWYgKGV4aXQgPT09IDEpIHtcbiAgICBsZXQgaWZfID0ganNvblNjaGVtYS5pZjtcbiAgICBpZiAoaWZfICE9PSB1bmRlZmluZWQpIHtcbiAgICAgIGxldCB0aGVuID0ganNvblNjaGVtYS50aGVuO1xuICAgICAgaWYgKHRoZW4gIT09IHVuZGVmaW5lZCkge1xuICAgICAgICBsZXQgZWxzZV8gPSBqc29uU2NoZW1hLmVsc2U7XG4gICAgICAgIGlmIChlbHNlXyAhPT0gdW5kZWZpbmVkKSB7XG4gICAgICAgICAgbGV0IGlmU2NoZW1hID0gZGVmaW5pdGlvblRvU2NoZW1hJDEoaWZfKTtcbiAgICAgICAgICBsZXQgdGhlblNjaGVtYSA9IGRlZmluaXRpb25Ub1NjaGVtYSQxKHRoZW4pO1xuICAgICAgICAgIGxldCBlbHNlU2NoZW1hID0gZGVmaW5pdGlvblRvU2NoZW1hJDEoZWxzZV8pO1xuICAgICAgICAgIHNjaGVtYSA9IHJlZmluZShqc29uLCBwYXJhbSA9PiAoZGF0YSA9PiB7XG4gICAgICAgICAgICBsZXQgcGFzc2VkO1xuICAgICAgICAgICAgdHJ5IHtcbiAgICAgICAgICAgICAgYXNzZXJ0T3JUaHJvdyhkYXRhLCBpZlNjaGVtYSk7XG4gICAgICAgICAgICAgIHBhc3NlZCA9IHRydWU7XG4gICAgICAgICAgICB9IGNhdGNoIChleG4pIHtcbiAgICAgICAgICAgICAgcGFzc2VkID0gZmFsc2U7XG4gICAgICAgICAgICB9XG4gICAgICAgICAgICBpZiAocGFzc2VkKSB7XG4gICAgICAgICAgICAgIHJldHVybiBhc3NlcnRPclRocm93KGRhdGEsIHRoZW5TY2hlbWEpO1xuICAgICAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICAgICAgcmV0dXJuIGFzc2VydE9yVGhyb3coZGF0YSwgZWxzZVNjaGVtYSk7XG4gICAgICAgICAgICB9XG4gICAgICAgICAgfSkpO1xuICAgICAgICB9IGVsc2Uge1xuICAgICAgICAgIHNjaGVtYSA9IGpzb247XG4gICAgICAgIH1cbiAgICAgIH0gZWxzZSB7XG4gICAgICAgIHNjaGVtYSA9IGpzb247XG4gICAgICB9XG4gICAgfSBlbHNlIHtcbiAgICAgIHNjaGVtYSA9IGpzb247XG4gICAgfVxuICB9XG4gIGlmIChqc29uU2NoZW1hLmRlc2NyaXB0aW9uID09PSB1bmRlZmluZWQgJiYganNvblNjaGVtYS5kZXByZWNhdGVkID09PSB1bmRlZmluZWQgJiYganNvblNjaGVtYS5leGFtcGxlcyA9PT0gdW5kZWZpbmVkICYmIGpzb25TY2hlbWEudGl0bGUgPT09IHVuZGVmaW5lZCkge1xuICAgIHJldHVybiBzY2hlbWE7XG4gIH1cbiAgcmV0dXJuIG1ldGEoc2NoZW1hLCB7XG4gICAgdGl0bGU6IGpzb25TY2hlbWEudGl0bGUsXG4gICAgZGVzY3JpcHRpb246IGpzb25TY2hlbWEuZGVzY3JpcHRpb24sXG4gICAgZGVwcmVjYXRlZDoganNvblNjaGVtYS5kZXByZWNhdGVkLFxuICAgIGV4YW1wbGVzOiBqc29uU2NoZW1hLmV4YW1wbGVzXG4gIH0pO1xufVxuXG5mdW5jdGlvbiBtaW4oc2NoZW1hLCBtaW5WYWx1ZSwgbWF5YmVNZXNzYWdlKSB7XG4gIHN3aXRjaCAoc2NoZW1hLnR5cGUpIHtcbiAgICBjYXNlIFwic3RyaW5nXCIgOlxuICAgICAgcmV0dXJuIHN0cmluZ01pbkxlbmd0aChzY2hlbWEsIG1pblZhbHVlLCBtYXliZU1lc3NhZ2UpO1xuICAgIGNhc2UgXCJudW1iZXJcIiA6XG4gICAgICBpZiAoc2NoZW1hLmZvcm1hdCAhPT0gdW5kZWZpbmVkKSB7XG4gICAgICAgIHJldHVybiBpbnRNaW4oc2NoZW1hLCBtaW5WYWx1ZSwgbWF5YmVNZXNzYWdlKTtcbiAgICAgIH0gZWxzZSB7XG4gICAgICAgIHJldHVybiBmbG9hdE1pbihzY2hlbWEsIG1pblZhbHVlLCBtYXliZU1lc3NhZ2UpO1xuICAgICAgfVxuICAgIGNhc2UgXCJhcnJheVwiIDpcbiAgICAgIHJldHVybiBhcnJheU1pbkxlbmd0aChzY2hlbWEsIG1pblZhbHVlLCBtYXliZU1lc3NhZ2UpO1xuICAgIGRlZmF1bHQ6XG4gICAgICBsZXQgbWVzc2FnZSA9IGBTLm1pbiBpcyBub3Qgc3VwcG9ydGVkIGZvciBgICsgdG9FeHByZXNzaW9uKHNjaGVtYSkgKyBgIHNjaGVtYS4gQ29lcmNlIHRoZSBzY2hlbWEgdG8gc3RyaW5nLCBudW1iZXIgb3IgYXJyYXkgdXNpbmcgUy50byBmaXJzdC5gO1xuICAgICAgdGhyb3cgbmV3IEVycm9yKGBbU3VyeV0gYCArIG1lc3NhZ2UpO1xuICB9XG59XG5cbmZ1bmN0aW9uIG1heChzY2hlbWEsIG1heFZhbHVlLCBtYXliZU1lc3NhZ2UpIHtcbiAgc3dpdGNoIChzY2hlbWEudHlwZSkge1xuICAgIGNhc2UgXCJzdHJpbmdcIiA6XG4gICAgICByZXR1cm4gc3RyaW5nTWF4TGVuZ3RoKHNjaGVtYSwgbWF4VmFsdWUsIG1heWJlTWVzc2FnZSk7XG4gICAgY2FzZSBcIm51bWJlclwiIDpcbiAgICAgIGlmIChzY2hlbWEuZm9ybWF0ICE9PSB1bmRlZmluZWQpIHtcbiAgICAgICAgcmV0dXJuIGludE1heChzY2hlbWEsIG1heFZhbHVlLCBtYXliZU1lc3NhZ2UpO1xuICAgICAgfSBlbHNlIHtcbiAgICAgICAgcmV0dXJuIGZsb2F0TWF4KHNjaGVtYSwgbWF4VmFsdWUsIG1heWJlTWVzc2FnZSk7XG4gICAgICB9XG4gICAgY2FzZSBcImFycmF5XCIgOlxuICAgICAgcmV0dXJuIGFycmF5TWF4TGVuZ3RoKHNjaGVtYSwgbWF4VmFsdWUsIG1heWJlTWVzc2FnZSk7XG4gICAgZGVmYXVsdDpcbiAgICAgIGxldCBtZXNzYWdlID0gYFMubWF4IGlzIG5vdCBzdXBwb3J0ZWQgZm9yIGAgKyB0b0V4cHJlc3Npb24oc2NoZW1hKSArIGAgc2NoZW1hLiBDb2VyY2UgdGhlIHNjaGVtYSB0byBzdHJpbmcsIG51bWJlciBvciBhcnJheSB1c2luZyBTLnRvIGZpcnN0LmA7XG4gICAgICB0aHJvdyBuZXcgRXJyb3IoYFtTdXJ5XSBgICsgbWVzc2FnZSk7XG4gIH1cbn1cblxuZnVuY3Rpb24gbGVuZ3RoKHNjaGVtYSwgbGVuZ3RoJDEsIG1heWJlTWVzc2FnZSkge1xuICBzd2l0Y2ggKHNjaGVtYS50eXBlKSB7XG4gICAgY2FzZSBcInN0cmluZ1wiIDpcbiAgICAgIGxldCBtZXNzYWdlID0gbWF5YmVNZXNzYWdlICE9PSB1bmRlZmluZWQgPyBtYXliZU1lc3NhZ2UgOiBgU3RyaW5nIG11c3QgYmUgZXhhY3RseSBgICsgbGVuZ3RoJDEgKyBgIGNoYXJhY3RlcnMgbG9uZ2A7XG4gICAgICByZXR1cm4gYWRkUmVmaW5lbWVudChzY2hlbWEsIG1ldGFkYXRhSWQkMSwge1xuICAgICAgICBraW5kOiB7XG4gICAgICAgICAgVEFHOiBcIkxlbmd0aFwiLFxuICAgICAgICAgIGxlbmd0aDogbGVuZ3RoJDFcbiAgICAgICAgfSxcbiAgICAgICAgbWVzc2FnZTogbWVzc2FnZVxuICAgICAgfSwgKGIsIGlucHV0VmFyLCBwYXJhbSwgcGF0aCkgPT4gYGlmKGAgKyBpbnB1dFZhciArIGAubGVuZ3RoIT09YCArIGVtYmVkKGIsIGxlbmd0aCQxKSArIGApe2AgKyBmYWlsKGIsIG1lc3NhZ2UsIHBhdGgpICsgYH1gKTtcbiAgICBjYXNlIFwiYXJyYXlcIiA6XG4gICAgICBsZXQgbWVzc2FnZSQxID0gbWF5YmVNZXNzYWdlICE9PSB1bmRlZmluZWQgPyBtYXliZU1lc3NhZ2UgOiBgQXJyYXkgbXVzdCBiZSBleGFjdGx5IGAgKyBsZW5ndGgkMSArIGAgaXRlbXMgbG9uZ2A7XG4gICAgICByZXR1cm4gYWRkUmVmaW5lbWVudChzY2hlbWEsIG1ldGFkYXRhSWQsIHtcbiAgICAgICAga2luZDoge1xuICAgICAgICAgIFRBRzogXCJMZW5ndGhcIixcbiAgICAgICAgICBsZW5ndGg6IGxlbmd0aCQxXG4gICAgICAgIH0sXG4gICAgICAgIG1lc3NhZ2U6IG1lc3NhZ2UkMVxuICAgICAgfSwgKGIsIGlucHV0VmFyLCBwYXJhbSwgcGF0aCkgPT4gYGlmKGAgKyBpbnB1dFZhciArIGAubGVuZ3RoIT09YCArIGVtYmVkKGIsIGxlbmd0aCQxKSArIGApe2AgKyBmYWlsKGIsIG1lc3NhZ2UkMSwgcGF0aCkgKyBgfWApO1xuICAgIGRlZmF1bHQ6XG4gICAgICBsZXQgbWVzc2FnZSQyID0gYFMubGVuZ3RoIGlzIG5vdCBzdXBwb3J0ZWQgZm9yIGAgKyB0b0V4cHJlc3Npb24oc2NoZW1hKSArIGAgc2NoZW1hLiBDb2VyY2UgdGhlIHNjaGVtYSB0byBzdHJpbmcgb3IgYXJyYXkgdXNpbmcgUy50byBmaXJzdC5gO1xuICAgICAgdGhyb3cgbmV3IEVycm9yKGBbU3VyeV0gYCArIG1lc3NhZ2UkMik7XG4gIH1cbn1cblxubGV0IFBhdGggPSB7XG4gIGVtcHR5OiBcIlwiLFxuICBkeW5hbWljOiBcIltdXCIsXG4gIHRvQXJyYXk6IHRvQXJyYXksXG4gIGZyb21BcnJheTogZnJvbUFycmF5LFxuICBmcm9tTG9jYXRpb246IGZyb21Mb2NhdGlvbixcbiAgY29uY2F0OiBjb25jYXRcbn07XG5cbmxldCBGbGFnID0ge1xuICBub25lOiAwLFxuICB0eXBlVmFsaWRhdGlvbjogMSxcbiAgYXN5bmM6IDIsXG4gIGFzc2VydE91dHB1dDogNCxcbiAganNvbmFibGVPdXRwdXQ6IDgsXG4gIGpzb25TdHJpbmdPdXRwdXQ6IDE2LFxuICByZXZlcnNlOiAzMixcbiAgaGFzOiBoYXNcbn07XG5cbmxldCBsaXRlcmFsID0ganNfc2NoZW1hO1xuXG5sZXQgYXJyYXkgPSBmYWN0b3J5JDI7XG5cbmxldCBkaWN0ID0gZmFjdG9yeSQzO1xuXG5sZXQgJCRudWxsJDEgPSBmYWN0b3J5JDU7XG5cbmxldCB1bmlvbiA9IGZhY3Rvcnk7XG5cbmxldCBwYXJzZUpzb25PclRocm93ID0gcGFyc2VPclRocm93O1xuXG5sZXQgU2NoZW1hJDEgPSB7fTtcblxubGV0IHNjaGVtYSA9IGZhY3RvcnkkNDtcblxubGV0ICQkT2JqZWN0ID0ge307XG5cbmxldCBPcHRpb24gPSB7XG4gIGdldE9yOiBnZXRPcixcbiAgZ2V0T3JXaXRoOiBnZXRPcldpdGhcbn07XG5cbmxldCBTdHJpbmdfUmVmaW5lbWVudCA9IHt9O1xuXG5sZXQgJCRTdHJpbmckMSA9IHtcbiAgUmVmaW5lbWVudDogU3RyaW5nX1JlZmluZW1lbnQsXG4gIHJlZmluZW1lbnRzOiByZWZpbmVtZW50cyQxXG59O1xuXG5sZXQgSW50X1JlZmluZW1lbnQgPSB7fTtcblxubGV0IEludCA9IHtcbiAgUmVmaW5lbWVudDogSW50X1JlZmluZW1lbnQsXG4gIHJlZmluZW1lbnRzOiByZWZpbmVtZW50cyQyXG59O1xuXG5sZXQgRmxvYXRfUmVmaW5lbWVudCA9IHt9O1xuXG5sZXQgRmxvYXQgPSB7XG4gIFJlZmluZW1lbnQ6IEZsb2F0X1JlZmluZW1lbnQsXG4gIHJlZmluZW1lbnRzOiByZWZpbmVtZW50cyQzXG59O1xuXG5sZXQgQXJyYXlfUmVmaW5lbWVudCA9IHt9O1xuXG5sZXQgJCRBcnJheSQxID0ge1xuICBSZWZpbmVtZW50OiBBcnJheV9SZWZpbmVtZW50LFxuICByZWZpbmVtZW50czogcmVmaW5lbWVudHNcbn07XG5cbmxldCBNZXRhZGF0YSA9IHtcbiAgSWQ6IElkLFxuICBnZXQ6IGdldCQxLFxuICBzZXQ6IHNldCQxXG59O1xuXG5leHBvcnQge1xuICBQYXRoLFxuICAkJEVycm9yLFxuICBGbGFnLFxuICBuZXZlcixcbiAgdW5rbm93bixcbiAgdW5pdCxcbiAgbnVsbEFzVW5pdCxcbiAgc3RyaW5nLFxuICBib29sLFxuICBpbnQsXG4gIGZsb2F0LFxuICBiaWdpbnQsXG4gIHN5bWJvbCxcbiAganNvbixcbiAgZW5hYmxlSnNvbixcbiAganNvblN0cmluZyxcbiAganNvblN0cmluZ1dpdGhTcGFjZSxcbiAgZW5hYmxlSnNvblN0cmluZyxcbiAgbGl0ZXJhbCxcbiAgYXJyYXksXG4gIHVubmVzdCxcbiAgbGlzdCxcbiAgaW5zdGFuY2UsXG4gIGRpY3QsXG4gIG9wdGlvbixcbiAgJCRudWxsJDEgYXMgJCRudWxsLFxuICBudWxsYWJsZSxcbiAgbnVsbGFibGVBc09wdGlvbixcbiAgdW5pb24sXG4gICQkZW51bSxcbiAgbWV0YSxcbiAgdHJhbnNmb3JtLFxuICByZWZpbmUsXG4gIHNoYXBlLFxuICB0byxcbiAgY29tcGlsZSxcbiAgcGFyc2VPclRocm93LFxuICBwYXJzZUpzb25PclRocm93LFxuICBwYXJzZUpzb25TdHJpbmdPclRocm93LFxuICBwYXJzZUFzeW5jT3JUaHJvdyxcbiAgY29udmVydE9yVGhyb3csXG4gIGNvbnZlcnRUb0pzb25PclRocm93LFxuICBjb252ZXJ0VG9Kc29uU3RyaW5nT3JUaHJvdyxcbiAgY29udmVydEFzeW5jT3JUaHJvdyxcbiAgcmV2ZXJzZUNvbnZlcnRPclRocm93LFxuICByZXZlcnNlQ29udmVydFRvSnNvbk9yVGhyb3csXG4gIHJldmVyc2VDb252ZXJ0VG9Kc29uU3RyaW5nT3JUaHJvdyxcbiAgYXNzZXJ0T3JUaHJvdyxcbiAgaXNBc3luYyxcbiAgcmVjdXJzaXZlLFxuICBub1ZhbGlkYXRpb24sXG4gIHRvRXhwcmVzc2lvbixcbiAgU2NoZW1hJDEgYXMgU2NoZW1hLFxuICBzY2hlbWEsXG4gICQkT2JqZWN0LFxuICBvYmplY3QsXG4gIHN0cmlwLFxuICBkZWVwU3RyaXAsXG4gIHN0cmljdCxcbiAgZGVlcFN0cmljdCxcbiAgVHVwbGUsXG4gIHR1cGxlLFxuICB0dXBsZTEsXG4gIHR1cGxlMixcbiAgdHVwbGUzLFxuICBPcHRpb24sXG4gICQkU3RyaW5nJDEgYXMgJCRTdHJpbmcsXG4gIEludCxcbiAgRmxvYXQsXG4gICQkQXJyYXkkMSBhcyAkJEFycmF5LFxuICBNZXRhZGF0YSxcbiAgcmV2ZXJzZSxcbiAgRXJyb3JDbGFzcyxcbiAgbWluLFxuICBmbG9hdE1pbixcbiAgbWF4LFxuICBmbG9hdE1heCxcbiAgbGVuZ3RoLFxuICBwb3J0LFxuICBlbWFpbCxcbiAgdXVpZCxcbiAgY3VpZCxcbiAgdXJsLFxuICBwYXR0ZXJuLFxuICBkYXRldGltZSxcbiAgdHJpbSxcbiAgdG9KU09OU2NoZW1hLFxuICBmcm9tSlNPTlNjaGVtYSxcbiAgZXh0ZW5kSlNPTlNjaGVtYSxcbiAgZ2xvYmFsLFxuICBicmFuZCxcbiAganNfc2FmZSxcbiAganNfc2FmZUFzeW5jLFxuICBqc191bmlvbixcbiAganNfb3B0aW9uYWwsXG4gIGpzX251bGxhYmxlLFxuICBqc19hc3luY1BhcnNlclJlZmluZSxcbiAganNfcmVmaW5lLFxuICBqc190cmFuc2Zvcm0sXG4gIGpzX3NjaGVtYSxcbiAganNfbWVyZ2UsXG59XG4vKiBzIE5vdCBhIHB1cmUgbW9kdWxlICovXG4iLCAiLy8gR2VuZXJhdGVkIGJ5IFJlU2NyaXB0LCBQTEVBU0UgRURJVCBXSVRIIENBUkVcblxuaW1wb3J0ICogYXMgU3VyeSBmcm9tIFwiLi9TdXJ5LnJlcy5tanNcIjtcblxubGV0IFBhdGggPSBTdXJ5LlBhdGg7XG5cbmxldCAkJEVycm9yID0gU3VyeS4kJEVycm9yO1xuXG5sZXQgRmxhZyA9IFN1cnkuRmxhZztcblxubGV0IG5ldmVyID0gU3VyeS5uZXZlcjtcblxubGV0IHVua25vd24gPSBTdXJ5LnVua25vd247XG5cbmxldCB1bml0ID0gU3VyeS51bml0O1xuXG5sZXQgbnVsbEFzVW5pdCA9IFN1cnkubnVsbEFzVW5pdDtcblxubGV0IHN0cmluZyA9IFN1cnkuc3RyaW5nO1xuXG5sZXQgYm9vbCA9IFN1cnkuYm9vbDtcblxubGV0IGludCA9IFN1cnkuaW50O1xuXG5sZXQgZmxvYXQgPSBTdXJ5LmZsb2F0O1xuXG5sZXQgYmlnaW50ID0gU3VyeS5iaWdpbnQ7XG5cbmxldCBzeW1ib2wgPSBTdXJ5LnN5bWJvbDtcblxubGV0IGpzb24gPSBTdXJ5Lmpzb247XG5cbmxldCBlbmFibGVKc29uID0gU3VyeS5lbmFibGVKc29uO1xuXG5sZXQganNvblN0cmluZyA9IFN1cnkuanNvblN0cmluZztcblxubGV0IGpzb25TdHJpbmdXaXRoU3BhY2UgPSBTdXJ5Lmpzb25TdHJpbmdXaXRoU3BhY2U7XG5cbmxldCBlbmFibGVKc29uU3RyaW5nID0gU3VyeS5lbmFibGVKc29uU3RyaW5nO1xuXG5sZXQgbGl0ZXJhbCA9IFN1cnkubGl0ZXJhbDtcblxubGV0IGFycmF5ID0gU3VyeS5hcnJheTtcblxubGV0IHVubmVzdCA9IFN1cnkudW5uZXN0O1xuXG5sZXQgbGlzdCA9IFN1cnkubGlzdDtcblxubGV0IGluc3RhbmNlID0gU3VyeS5pbnN0YW5jZTtcblxubGV0IGRpY3QgPSBTdXJ5LmRpY3Q7XG5cbmxldCBvcHRpb24gPSBTdXJ5Lm9wdGlvbjtcblxubGV0ICQkbnVsbCA9IFN1cnkuJCRudWxsO1xuXG5sZXQgbnVsbGFibGUgPSBTdXJ5Lm51bGxhYmxlO1xuXG5sZXQgbnVsbGFibGVBc09wdGlvbiA9IFN1cnkubnVsbGFibGVBc09wdGlvbjtcblxubGV0IHVuaW9uID0gU3VyeS51bmlvbjtcblxubGV0ICQkZW51bSA9IFN1cnkuJCRlbnVtO1xuXG5sZXQgbWV0YSA9IFN1cnkubWV0YTtcblxubGV0IHRyYW5zZm9ybSA9IFN1cnkudHJhbnNmb3JtO1xuXG5sZXQgcmVmaW5lID0gU3VyeS5yZWZpbmU7XG5cbmxldCBzaGFwZSA9IFN1cnkuc2hhcGU7XG5cbmxldCB0byA9IFN1cnkudG87XG5cbmxldCBjb21waWxlID0gU3VyeS5jb21waWxlO1xuXG5sZXQgcGFyc2VPclRocm93ID0gU3VyeS5wYXJzZU9yVGhyb3c7XG5cbmxldCBwYXJzZUpzb25PclRocm93ID0gU3VyeS5wYXJzZUpzb25PclRocm93O1xuXG5sZXQgcGFyc2VKc29uU3RyaW5nT3JUaHJvdyA9IFN1cnkucGFyc2VKc29uU3RyaW5nT3JUaHJvdztcblxubGV0IHBhcnNlQXN5bmNPclRocm93ID0gU3VyeS5wYXJzZUFzeW5jT3JUaHJvdztcblxubGV0IGNvbnZlcnRPclRocm93ID0gU3VyeS5jb252ZXJ0T3JUaHJvdztcblxubGV0IGNvbnZlcnRUb0pzb25PclRocm93ID0gU3VyeS5jb252ZXJ0VG9Kc29uT3JUaHJvdztcblxubGV0IGNvbnZlcnRUb0pzb25TdHJpbmdPclRocm93ID0gU3VyeS5jb252ZXJ0VG9Kc29uU3RyaW5nT3JUaHJvdztcblxubGV0IGNvbnZlcnRBc3luY09yVGhyb3cgPSBTdXJ5LmNvbnZlcnRBc3luY09yVGhyb3c7XG5cbmxldCByZXZlcnNlQ29udmVydE9yVGhyb3cgPSBTdXJ5LnJldmVyc2VDb252ZXJ0T3JUaHJvdztcblxubGV0IHJldmVyc2VDb252ZXJ0VG9Kc29uT3JUaHJvdyA9IFN1cnkucmV2ZXJzZUNvbnZlcnRUb0pzb25PclRocm93O1xuXG5sZXQgcmV2ZXJzZUNvbnZlcnRUb0pzb25TdHJpbmdPclRocm93ID0gU3VyeS5yZXZlcnNlQ29udmVydFRvSnNvblN0cmluZ09yVGhyb3c7XG5cbmxldCBhc3NlcnRPclRocm93ID0gU3VyeS5hc3NlcnRPclRocm93O1xuXG5sZXQgaXNBc3luYyA9IFN1cnkuaXNBc3luYztcblxubGV0IHJlY3Vyc2l2ZSA9IFN1cnkucmVjdXJzaXZlO1xuXG5sZXQgbm9WYWxpZGF0aW9uID0gU3VyeS5ub1ZhbGlkYXRpb247XG5cbmxldCB0b0V4cHJlc3Npb24gPSBTdXJ5LnRvRXhwcmVzc2lvbjtcblxubGV0IFNjaGVtYSA9IFN1cnkuU2NoZW1hO1xuXG5sZXQgc2NoZW1hID0gU3VyeS5zY2hlbWE7XG5cbmxldCAkJE9iamVjdCA9IFN1cnkuJCRPYmplY3Q7XG5cbmxldCBvYmplY3QgPSBTdXJ5Lm9iamVjdDtcblxubGV0IHN0cmlwID0gU3VyeS5zdHJpcDtcblxubGV0IGRlZXBTdHJpcCA9IFN1cnkuZGVlcFN0cmlwO1xuXG5sZXQgc3RyaWN0ID0gU3VyeS5zdHJpY3Q7XG5cbmxldCBkZWVwU3RyaWN0ID0gU3VyeS5kZWVwU3RyaWN0O1xuXG5sZXQgVHVwbGUgPSBTdXJ5LlR1cGxlO1xuXG5sZXQgdHVwbGUgPSBTdXJ5LnR1cGxlO1xuXG5sZXQgdHVwbGUxID0gU3VyeS50dXBsZTE7XG5cbmxldCB0dXBsZTIgPSBTdXJ5LnR1cGxlMjtcblxubGV0IHR1cGxlMyA9IFN1cnkudHVwbGUzO1xuXG5sZXQgT3B0aW9uID0gU3VyeS5PcHRpb247XG5cbmxldCAkJFN0cmluZyA9IFN1cnkuJCRTdHJpbmc7XG5cbmxldCBJbnQgPSBTdXJ5LkludDtcblxubGV0IEZsb2F0ID0gU3VyeS5GbG9hdDtcblxubGV0ICQkQXJyYXkgPSBTdXJ5LiQkQXJyYXk7XG5cbmxldCBNZXRhZGF0YSA9IFN1cnkuTWV0YWRhdGE7XG5cbmxldCByZXZlcnNlID0gU3VyeS5yZXZlcnNlO1xuXG5sZXQgbWluID0gU3VyeS5taW47XG5cbmxldCBmbG9hdE1pbiA9IFN1cnkuZmxvYXRNaW47XG5cbmxldCBtYXggPSBTdXJ5Lm1heDtcblxubGV0IGZsb2F0TWF4ID0gU3VyeS5mbG9hdE1heDtcblxubGV0IGxlbmd0aCA9IFN1cnkubGVuZ3RoO1xuXG5sZXQgcG9ydCA9IFN1cnkucG9ydDtcblxubGV0IGVtYWlsID0gU3VyeS5lbWFpbDtcblxubGV0IHV1aWQgPSBTdXJ5LnV1aWQ7XG5cbmxldCBjdWlkID0gU3VyeS5jdWlkO1xuXG5sZXQgdXJsID0gU3VyeS51cmw7XG5cbmxldCBwYXR0ZXJuID0gU3VyeS5wYXR0ZXJuO1xuXG5sZXQgZGF0ZXRpbWUgPSBTdXJ5LmRhdGV0aW1lO1xuXG5sZXQgdHJpbSA9IFN1cnkudHJpbTtcblxubGV0IHRvSlNPTlNjaGVtYSA9IFN1cnkudG9KU09OU2NoZW1hO1xuXG5sZXQgZnJvbUpTT05TY2hlbWEgPSBTdXJ5LmZyb21KU09OU2NoZW1hO1xuXG5sZXQgZXh0ZW5kSlNPTlNjaGVtYSA9IFN1cnkuZXh0ZW5kSlNPTlNjaGVtYTtcblxubGV0IGdsb2JhbCA9IFN1cnkuZ2xvYmFsO1xuXG5sZXQgRXJyb3JDbGFzcyA9IFN1cnkuRXJyb3JDbGFzcztcblxuZXhwb3J0IHtcbiAgUGF0aCxcbiAgJCRFcnJvcixcbiAgRmxhZyxcbiAgbmV2ZXIsXG4gIHVua25vd24sXG4gIHVuaXQsXG4gIG51bGxBc1VuaXQsXG4gIHN0cmluZyxcbiAgYm9vbCxcbiAgaW50LFxuICBmbG9hdCxcbiAgYmlnaW50LFxuICBzeW1ib2wsXG4gIGpzb24sXG4gIGVuYWJsZUpzb24sXG4gIGpzb25TdHJpbmcsXG4gIGpzb25TdHJpbmdXaXRoU3BhY2UsXG4gIGVuYWJsZUpzb25TdHJpbmcsXG4gIGxpdGVyYWwsXG4gIGFycmF5LFxuICB1bm5lc3QsXG4gIGxpc3QsXG4gIGluc3RhbmNlLFxuICBkaWN0LFxuICBvcHRpb24sXG4gICQkbnVsbCxcbiAgbnVsbGFibGUsXG4gIG51bGxhYmxlQXNPcHRpb24sXG4gIHVuaW9uLFxuICAkJGVudW0sXG4gIG1ldGEsXG4gIHRyYW5zZm9ybSxcbiAgcmVmaW5lLFxuICBzaGFwZSxcbiAgdG8sXG4gIGNvbXBpbGUsXG4gIHBhcnNlT3JUaHJvdyxcbiAgcGFyc2VKc29uT3JUaHJvdyxcbiAgcGFyc2VKc29uU3RyaW5nT3JUaHJvdyxcbiAgcGFyc2VBc3luY09yVGhyb3csXG4gIGNvbnZlcnRPclRocm93LFxuICBjb252ZXJ0VG9Kc29uT3JUaHJvdyxcbiAgY29udmVydFRvSnNvblN0cmluZ09yVGhyb3csXG4gIGNvbnZlcnRBc3luY09yVGhyb3csXG4gIHJldmVyc2VDb252ZXJ0T3JUaHJvdyxcbiAgcmV2ZXJzZUNvbnZlcnRUb0pzb25PclRocm93LFxuICByZXZlcnNlQ29udmVydFRvSnNvblN0cmluZ09yVGhyb3csXG4gIGFzc2VydE9yVGhyb3csXG4gIGlzQXN5bmMsXG4gIHJlY3Vyc2l2ZSxcbiAgbm9WYWxpZGF0aW9uLFxuICB0b0V4cHJlc3Npb24sXG4gIFNjaGVtYSxcbiAgc2NoZW1hLFxuICAkJE9iamVjdCxcbiAgb2JqZWN0LFxuICBzdHJpcCxcbiAgZGVlcFN0cmlwLFxuICBzdHJpY3QsXG4gIGRlZXBTdHJpY3QsXG4gIFR1cGxlLFxuICB0dXBsZSxcbiAgdHVwbGUxLFxuICB0dXBsZTIsXG4gIHR1cGxlMyxcbiAgT3B0aW9uLFxuICAkJFN0cmluZyxcbiAgSW50LFxuICBGbG9hdCxcbiAgJCRBcnJheSxcbiAgTWV0YWRhdGEsXG4gIHJldmVyc2UsXG4gIG1pbixcbiAgZmxvYXRNaW4sXG4gIG1heCxcbiAgZmxvYXRNYXgsXG4gIGxlbmd0aCxcbiAgcG9ydCxcbiAgZW1haWwsXG4gIHV1aWQsXG4gIGN1aWQsXG4gIHVybCxcbiAgcGF0dGVybixcbiAgZGF0ZXRpbWUsXG4gIHRyaW0sXG4gIHRvSlNPTlNjaGVtYSxcbiAgZnJvbUpTT05TY2hlbWEsXG4gIGV4dGVuZEpTT05TY2hlbWEsXG4gIGdsb2JhbCxcbiAgRXJyb3JDbGFzcyxcbn1cbi8qIFN1cnkgTm90IGEgcHVyZSBtb2R1bGUgKi9cbiIsICIvLyBHZW5lcmF0ZWQgYnkgUmVTY3JpcHQsIFBMRUFTRSBFRElUIFdJVEggQ0FSRVxuXG5pbXBvcnQgKiBhcyBTIGZyb20gXCJzdXJ5L3NyYy9TLnJlcy5tanNcIjtcbmltcG9ydCAqIGFzIFN0ZGxpYl9PcHRpb24gZnJvbSBcIkByZXNjcmlwdC9ydW50aW1lL2xpYi9lczYvU3RkbGliX09wdGlvbi5qc1wiO1xuaW1wb3J0ICogYXMgUHJpbWl0aXZlX29wdGlvbiBmcm9tIFwiQHJlc2NyaXB0L3J1bnRpbWUvbGliL2VzNi9QcmltaXRpdmVfb3B0aW9uLmpzXCI7XG5cblMuZW5hYmxlSnNvbigpO1xuXG5sZXQgdmVyc2lvbiA9IFwiMi4wXCI7XG5cbmxldCBlcnJvckNvZGVTY2hlbWEgPSBTLnVuaW9uKFtcbiAgUy5saXRlcmFsKC0zMjcwMCksXG4gIFMubGl0ZXJhbCgtMzI2MDApLFxuICBTLmxpdGVyYWwoLTMyNjAxKSxcbiAgUy5saXRlcmFsKC0zMjYwMiksXG4gIFMubGl0ZXJhbCgtMzI2MDMpXG5dKTtcblxubGV0IHNjaGVtYSA9IFMuc2NoZW1hKHMgPT4gKHtcbiAgY29kZTogcy5tKGVycm9yQ29kZVNjaGVtYSksXG4gIG1lc3NhZ2U6IHMubShTLnN0cmluZyksXG4gIGRhdGE6IHMubShTLm9wdGlvbihTLmpzb24pKVxufSkpO1xuXG5mdW5jdGlvbiBtYWtlKGNvZGUsIG1lc3NhZ2UsIGRhdGEpIHtcbiAgcmV0dXJuIHtcbiAgICBjb2RlOiBjb2RlLFxuICAgIG1lc3NhZ2U6IG1lc3NhZ2UsXG4gICAgZGF0YTogZGF0YVxuICB9O1xufVxuXG5mdW5jdGlvbiBjb2RlKHQpIHtcbiAgcmV0dXJuIHQuY29kZTtcbn1cblxuZnVuY3Rpb24gbWVzc2FnZSh0KSB7XG4gIHJldHVybiB0Lm1lc3NhZ2U7XG59XG5cbmZ1bmN0aW9uIGRhdGEodCkge1xuICByZXR1cm4gdC5kYXRhO1xufVxuXG5sZXQgUnBjRXJyb3IgPSB7XG4gIG1ha2U6IG1ha2UsXG4gIGNvZGU6IGNvZGUsXG4gIG1lc3NhZ2U6IG1lc3NhZ2UsXG4gIGRhdGE6IGRhdGEsXG4gIHNjaGVtYTogc2NoZW1hXG59O1xuXG5sZXQgc2NoZW1hJDEgPSBTLnNjaGVtYShzID0+ICh7XG4gIGpzb25ycGM6IHMubShTLnN0cmluZyksXG4gIGlkOiBzLm0oUy5pbnQpLFxuICBtZXRob2Q6IHMubShTLnN0cmluZyksXG4gIHBhcmFtczogcy5tKFMub3B0aW9uKFMuanNvbikpXG59KSk7XG5cbmZ1bmN0aW9uIG1ha2UkMShpZCwgbWV0aG9kLCBwYXJhbXMpIHtcbiAgcmV0dXJuIHtcbiAgICBqc29ucnBjOiB2ZXJzaW9uLFxuICAgIGlkOiBpZCxcbiAgICBtZXRob2Q6IG1ldGhvZCxcbiAgICBwYXJhbXM6IHBhcmFtc1xuICB9O1xufVxuXG5mdW5jdGlvbiBpZCh0KSB7XG4gIHJldHVybiB0LmlkO1xufVxuXG5mdW5jdGlvbiBtZXRob2QodCkge1xuICByZXR1cm4gdC5tZXRob2Q7XG59XG5cbmZ1bmN0aW9uIHBhcmFtcyh0KSB7XG4gIHJldHVybiB0LnBhcmFtcztcbn1cblxuZnVuY3Rpb24gdG9Kc29uKHQpIHtcbiAgcmV0dXJuIFMucmV2ZXJzZUNvbnZlcnRUb0pzb25PclRocm93KHQsIHNjaGVtYSQxKTtcbn1cblxubGV0IFJlcXVlc3QgPSB7XG4gIG1ha2U6IG1ha2UkMSxcbiAgaWQ6IGlkLFxuICBtZXRob2Q6IG1ldGhvZCxcbiAgcGFyYW1zOiBwYXJhbXMsXG4gIHRvSnNvbjogdG9Kc29uLFxuICBzY2hlbWE6IHNjaGVtYSQxXG59O1xuXG5sZXQgc2NoZW1hJDIgPSBTLnNjaGVtYShzID0+ICh7XG4gIGpzb25ycGM6IHMubShTLnN0cmluZyksXG4gIGlkOiBzLm0oUy5pbnQpLFxuICByZXN1bHQ6IHMubShTLm9wdGlvbihTLmpzb24pKSxcbiAgZXJyb3I6IHMubShTLm9wdGlvbihzY2hlbWEpKVxufSkpO1xuXG5mdW5jdGlvbiBtYWtlU3VjY2VzcyhpZCwgcmVzdWx0KSB7XG4gIHJldHVybiB7XG4gICAganNvbnJwYzogdmVyc2lvbixcbiAgICBpZDogaWQsXG4gICAgcmVzdWx0OiByZXN1bHQsXG4gICAgZXJyb3I6IHVuZGVmaW5lZFxuICB9O1xufVxuXG5mdW5jdGlvbiBtYWtlRXJyb3IoaWQsIGVycm9yKSB7XG4gIHJldHVybiB7XG4gICAganNvbnJwYzogdmVyc2lvbixcbiAgICBpZDogaWQsXG4gICAgcmVzdWx0OiB1bmRlZmluZWQsXG4gICAgZXJyb3I6IFByaW1pdGl2ZV9vcHRpb24uc29tZShlcnJvcilcbiAgfTtcbn1cblxuZnVuY3Rpb24gaWQkMSh0KSB7XG4gIHJldHVybiB0LmlkO1xufVxuXG5mdW5jdGlvbiByZXN1bHQodCkge1xuICByZXR1cm4gdC5yZXN1bHQ7XG59XG5cbmZ1bmN0aW9uIGVycm9yKHQpIHtcbiAgcmV0dXJuIHQuZXJyb3I7XG59XG5cbmZ1bmN0aW9uIGlzU3VjY2Vzcyh0KSB7XG4gIHJldHVybiBTdGRsaWJfT3B0aW9uLmlzU29tZSh0LnJlc3VsdCk7XG59XG5cbmZ1bmN0aW9uIGlzRXJyb3IodCkge1xuICByZXR1cm4gU3RkbGliX09wdGlvbi5pc1NvbWUodC5lcnJvcik7XG59XG5cbmZ1bmN0aW9uIGZyb21Kc29uRXhuKGpzb24pIHtcbiAgcmV0dXJuIFMucGFyc2VPclRocm93KGpzb24sIHNjaGVtYSQyKTtcbn1cblxubGV0IFJlc3BvbnNlID0ge1xuICBtYWtlU3VjY2VzczogbWFrZVN1Y2Nlc3MsXG4gIG1ha2VFcnJvcjogbWFrZUVycm9yLFxuICBpZDogaWQkMSxcbiAgcmVzdWx0OiByZXN1bHQsXG4gIGVycm9yOiBlcnJvcixcbiAgaXNTdWNjZXNzOiBpc1N1Y2Nlc3MsXG4gIGlzRXJyb3I6IGlzRXJyb3IsXG4gIGZyb21Kc29uRXhuOiBmcm9tSnNvbkV4bixcbiAgc2NoZW1hOiBzY2hlbWEkMlxufTtcblxubGV0IHNjaGVtYSQzID0gUy5zY2hlbWEocyA9PiAoe1xuICBqc29ucnBjOiBzLm0oUy5zdHJpbmcpLFxuICBtZXRob2Q6IHMubShTLnN0cmluZyksXG4gIHBhcmFtczogcy5tKFMub3B0aW9uKFMuanNvbikpXG59KSk7XG5cbmZ1bmN0aW9uIG1ha2UkMihtZXRob2QsIHBhcmFtcykge1xuICByZXR1cm4ge1xuICAgIGpzb25ycGM6IHZlcnNpb24sXG4gICAgbWV0aG9kOiBtZXRob2QsXG4gICAgcGFyYW1zOiBwYXJhbXNcbiAgfTtcbn1cblxuZnVuY3Rpb24gbWV0aG9kJDEodCkge1xuICByZXR1cm4gdC5tZXRob2Q7XG59XG5cbmZ1bmN0aW9uIHBhcmFtcyQxKHQpIHtcbiAgcmV0dXJuIHQucGFyYW1zO1xufVxuXG5mdW5jdGlvbiB0b0pzb24kMSh0KSB7XG4gIHJldHVybiBTLnJldmVyc2VDb252ZXJ0VG9Kc29uT3JUaHJvdyh0LCBzY2hlbWEkMyk7XG59XG5cbmxldCBOb3RpZmljYXRpb24gPSB7XG4gIG1ha2U6IG1ha2UkMixcbiAgbWV0aG9kOiBtZXRob2QkMSxcbiAgcGFyYW1zOiBwYXJhbXMkMSxcbiAgdG9Kc29uOiB0b0pzb24kMSxcbiAgc2NoZW1hOiBzY2hlbWEkM1xufTtcblxuZXhwb3J0IHtcbiAgdmVyc2lvbixcbiAgZXJyb3JDb2RlU2NoZW1hLFxuICBScGNFcnJvcixcbiAgUmVxdWVzdCxcbiAgUmVzcG9uc2UsXG4gIE5vdGlmaWNhdGlvbixcbn1cbi8qICBOb3QgYSBwdXJlIG1vZHVsZSAqL1xuIiwgIlxuXG5cbmZ1bmN0aW9uICQkZGVsZXRlJDEoZGljdCwgc3RyaW5nKSB7XG4gIGRlbGV0ZShkaWN0W3N0cmluZ10pO1xufVxuXG5sZXQgZm9yRWFjaCA9ICgoZGljdCwgZikgPT4ge1xuICBmb3IgKHZhciBpIGluIGRpY3QpIHtcbiAgICBmKGRpY3RbaV0pO1xuICB9XG59KTtcblxubGV0IGZvckVhY2hXaXRoS2V5ID0gKChkaWN0LCBmKSA9PiB7XG4gIGZvciAodmFyIGkgaW4gZGljdCkge1xuICAgIGYoZGljdFtpXSwgaSk7XG4gIH1cbn0pO1xuXG5sZXQgbWFwVmFsdWVzID0gKChkaWN0LCBmKSA9PiB7XG4gIHZhciB0YXJnZXQgPSB7fSwgaTtcbiAgZm9yIChpIGluIGRpY3QpIHtcbiAgICB0YXJnZXRbaV0gPSBmKGRpY3RbaV0pO1xuICB9XG4gIHJldHVybiB0YXJnZXQ7XG59KTtcblxubGV0IHNpemUgPSAoKGRpY3QpID0+IHtcbiAgdmFyIHNpemUgPSAwLCBpO1xuICBmb3IgKGkgaW4gZGljdCkge1xuICAgIHNpemUrKztcbiAgfVxuICByZXR1cm4gc2l6ZTtcbn0pO1xuXG5sZXQgaXNFbXB0eSA9ICgoZGljdCkgPT4ge1xuICBmb3IgKHZhciBfIGluIGRpY3QpIHtcbiAgICByZXR1cm4gZmFsc2VcbiAgfVxuICByZXR1cm4gdHJ1ZVxufSk7XG5cbmV4cG9ydCB7XG4gICQkZGVsZXRlJDEgYXMgJCRkZWxldGUsXG4gIHNpemUsXG4gIGlzRW1wdHksXG4gIGZvckVhY2gsXG4gIGZvckVhY2hXaXRoS2V5LFxuICBtYXBWYWx1ZXMsXG59XG4vKiBObyBzaWRlIGVmZmVjdCAqL1xuIiwgIi8vIEdlbmVyYXRlZCBieSBSZVNjcmlwdCwgUExFQVNFIEVESVQgV0lUSCBDQVJFXG5cbmltcG9ydCAqIGFzIFMgZnJvbSBcInN1cnkvc3JjL1MucmVzLm1qc1wiO1xuXG5TLmVuYWJsZUpzb24oKTtcblxubGV0IGltcGxlbWVudGF0aW9uU2NoZW1hID0gUy5zY2hlbWEocyA9PiAoe1xuICBuYW1lOiBzLm0oUy5zdHJpbmcpLFxuICB2ZXJzaW9uOiBzLm0oUy5zdHJpbmcpLFxuICB0aXRsZTogcy5tKFMub3B0aW9uKFMuc3RyaW5nKSlcbn0pKTtcblxubGV0IGZpbGVTeXN0ZW1DYXBhYmlsaXR5U2NoZW1hID0gUy5zY2hlbWEocyA9PiAoe1xuICByZWFkVGV4dEZpbGU6IHMubShTLm9wdGlvbihTLmJvb2wpKSxcbiAgd3JpdGVUZXh0RmlsZTogcy5tKFMub3B0aW9uKFMuYm9vbCkpXG59KSk7XG5cbmxldCBjbGllbnRDYXBhYmlsaXRpZXNTY2hlbWEgPSBTLnNjaGVtYShzID0+ICh7XG4gIGZzOiBzLm0oUy5vcHRpb24oZmlsZVN5c3RlbUNhcGFiaWxpdHlTY2hlbWEpKSxcbiAgdGVybWluYWw6IHMubShTLm9wdGlvbihTLmJvb2wpKVxufSkpO1xuXG5sZXQgcHJvbXB0Q2FwYWJpbGl0aWVzU2NoZW1hID0gUy5zY2hlbWEocyA9PiAoe1xuICBpbWFnZTogcy5tKFMub3B0aW9uKFMuYm9vbCkpLFxuICBhdWRpbzogcy5tKFMub3B0aW9uKFMuYm9vbCkpLFxuICBlbWJlZGRlZENvbnRleHQ6IHMubShTLm9wdGlvbihTLmJvb2wpKVxufSkpO1xuXG5sZXQgbWNwQ2FwYWJpbGl0aWVzU2NoZW1hID0gUy5zY2hlbWEocyA9PiAoe1xuICBodHRwOiBzLm0oUy5vcHRpb24oUy5ib29sKSksXG4gIHNzZTogcy5tKFMub3B0aW9uKFMuYm9vbCkpLFxuICB3ZWJzb2NrZXQ6IHMubShTLm9wdGlvbihTLmJvb2wpKVxufSkpO1xuXG5sZXQgYWdlbnRDYXBhYmlsaXRpZXNTY2hlbWEgPSBTLnNjaGVtYShzID0+ICh7XG4gIGxvYWRTZXNzaW9uOiBzLm0oUy5vcHRpb24oUy5ib29sKSksXG4gIG1jcENhcGFiaWxpdGllczogcy5tKFMub3B0aW9uKG1jcENhcGFiaWxpdGllc1NjaGVtYSkpLFxuICBwcm9tcHRDYXBhYmlsaXRpZXM6IHMubShTLm9wdGlvbihwcm9tcHRDYXBhYmlsaXRpZXNTY2hlbWEpKVxufSkpO1xuXG5sZXQgYXV0aE1ldGhvZFNjaGVtYSA9IFMuc2NoZW1hKHMgPT4gKHtcbiAgaWQ6IHMubShTLnN0cmluZyksXG4gIG5hbWU6IHMubShTLnN0cmluZyksXG4gIGRlc2NyaXB0aW9uOiBzLm0oUy5vcHRpb24oUy5zdHJpbmcpKVxufSkpO1xuXG5sZXQgaW5pdGlhbGl6ZVBhcmFtc1NjaGVtYSA9IFMuc2NoZW1hKHMgPT4gKHtcbiAgcHJvdG9jb2xWZXJzaW9uOiBzLm0oUy5pbnQpLFxuICBjbGllbnRDYXBhYmlsaXRpZXM6IHMubShTLm9wdGlvbihjbGllbnRDYXBhYmlsaXRpZXNTY2hlbWEpKSxcbiAgY2xpZW50SW5mbzogcy5tKFMub3B0aW9uKGltcGxlbWVudGF0aW9uU2NoZW1hKSlcbn0pKTtcblxubGV0IGluaXRpYWxpemVSZXN1bHRTY2hlbWEgPSBTLnNjaGVtYShzID0+ICh7XG4gIHByb3RvY29sVmVyc2lvbjogcy5tKFMuaW50KSxcbiAgYWdlbnRDYXBhYmlsaXRpZXM6IHMubShTLm9wdGlvbihhZ2VudENhcGFiaWxpdGllc1NjaGVtYSkpLFxuICBhZ2VudEluZm86IHMubShTLm9wdGlvbihpbXBsZW1lbnRhdGlvblNjaGVtYSkpLFxuICBhdXRoTWV0aG9kczogcy5tKFMub3B0aW9uKFMuYXJyYXkoYXV0aE1ldGhvZFNjaGVtYSkpKVxufSkpO1xuXG5sZXQgc2Vzc2lvbk5ld1Jlc3VsdFNjaGVtYSA9IFMuc2NoZW1hKHMgPT4gKHtcbiAgc2Vzc2lvbklkOiBzLm0oUy5zdHJpbmcpXG59KSk7XG5cbmxldCBjb250ZW50QmxvY2tTY2hlbWEgPSBTLnNjaGVtYShzID0+ICh7XG4gIHR5cGU6IHMubShTLnN0cmluZyksXG4gIHRleHQ6IHMubShTLm9wdGlvbihTLnN0cmluZykpXG59KSk7XG5cbmxldCBwcm9tcHRSZXN1bHRTY2hlbWEgPSBTLnNjaGVtYShzID0+ICh7XG4gIHN0b3BSZWFzb246IHMubShTLnN0cmluZylcbn0pKTtcblxubGV0IHNlc3Npb25VcGRhdGVTY2hlbWEgPSBTLnNjaGVtYShzID0+ICh7XG4gIHNlc3Npb25VcGRhdGU6IHMubShTLnN0cmluZyksXG4gIGNvbnRlbnQ6IHMubShjb250ZW50QmxvY2tTY2hlbWEpXG59KSk7XG5cbmxldCBzZXNzaW9uVXBkYXRlUGFyYW1zU2NoZW1hID0gUy5zY2hlbWEocyA9PiAoe1xuICBzZXNzaW9uSWQ6IHMubShTLnN0cmluZyksXG4gIHVwZGF0ZTogcy5tKHNlc3Npb25VcGRhdGVTY2hlbWEpXG59KSk7XG5cbmxldCBzZXNzaW9uVXBkYXRlTm90aWZpY2F0aW9uU2NoZW1hID0gUy5zY2hlbWEocyA9PiAoe1xuICBqc29ucnBjOiBzLm0oUy5zdHJpbmcpLFxuICBtZXRob2Q6IHMubShTLnN0cmluZyksXG4gIHBhcmFtczogcy5tKHNlc3Npb25VcGRhdGVQYXJhbXNTY2hlbWEpXG59KSk7XG5cbmxldCBjdXJyZW50UHJvdG9jb2xWZXJzaW9uID0gMTtcblxuZXhwb3J0IHtcbiAgY3VycmVudFByb3RvY29sVmVyc2lvbixcbiAgaW1wbGVtZW50YXRpb25TY2hlbWEsXG4gIGZpbGVTeXN0ZW1DYXBhYmlsaXR5U2NoZW1hLFxuICBjbGllbnRDYXBhYmlsaXRpZXNTY2hlbWEsXG4gIHByb21wdENhcGFiaWxpdGllc1NjaGVtYSxcbiAgbWNwQ2FwYWJpbGl0aWVzU2NoZW1hLFxuICBhZ2VudENhcGFiaWxpdGllc1NjaGVtYSxcbiAgYXV0aE1ldGhvZFNjaGVtYSxcbiAgaW5pdGlhbGl6ZVBhcmFtc1NjaGVtYSxcbiAgaW5pdGlhbGl6ZVJlc3VsdFNjaGVtYSxcbiAgc2Vzc2lvbk5ld1Jlc3VsdFNjaGVtYSxcbiAgY29udGVudEJsb2NrU2NoZW1hLFxuICBwcm9tcHRSZXN1bHRTY2hlbWEsXG4gIHNlc3Npb25VcGRhdGVTY2hlbWEsXG4gIHNlc3Npb25VcGRhdGVQYXJhbXNTY2hlbWEsXG4gIHNlc3Npb25VcGRhdGVOb3RpZmljYXRpb25TY2hlbWEsXG59XG4vKiAgTm90IGEgcHVyZSBtb2R1bGUgKi9cbiIsICIvLyBHZW5lcmF0ZWQgYnkgUmVTY3JpcHQsIFBMRUFTRSBFRElUIFdJVEggQ0FSRVxuXG5pbXBvcnQgKiBhcyBTIGZyb20gXCJzdXJ5L3NyYy9TLnJlcy5tanNcIjtcbmltcG9ydCAqIGFzIFN0ZGxpYl9EaWN0IGZyb20gXCJAcmVzY3JpcHQvcnVudGltZS9saWIvZXM2L1N0ZGxpYl9EaWN0LmpzXCI7XG5pbXBvcnQgKiBhcyBQcmltaXRpdmVfb3B0aW9uIGZyb20gXCJAcmVzY3JpcHQvcnVudGltZS9saWIvZXM2L1ByaW1pdGl2ZV9vcHRpb24uanNcIjtcbmltcG9ydCAqIGFzIFByaW1pdGl2ZV9leGNlcHRpb25zIGZyb20gXCJAcmVzY3JpcHQvcnVudGltZS9saWIvZXM2L1ByaW1pdGl2ZV9leGNlcHRpb25zLmpzXCI7XG5pbXBvcnQgKiBhcyBGcm9udG1hbkNsaWVudF9fSnNvblJwYyRBc2tUaGVMbG1Gcm9udG1hbkNsaWVudCBmcm9tIFwiLi9Gcm9udG1hbkNsaWVudF9fSnNvblJwYy5yZXMubWpzXCI7XG5pbXBvcnQgKiBhcyBGcm9udG1hbkNsaWVudF9fQUNQX19UeXBlcyRBc2tUaGVMbG1Gcm9udG1hbkNsaWVudCBmcm9tIFwiLi9Gcm9udG1hbkNsaWVudF9fQUNQX19UeXBlcy5yZXMubWpzXCI7XG5cbmxldCBpbml0aWFsU3RhdGVfcGVuZGluZ1JlcXVlc3RzID0ge307XG5cbmxldCBpbml0aWFsU3RhdGUgPSB7XG4gIGN1cnJlbnRJZDogMCxcbiAgY29ubmVjdGlvblN0YXRlOiBcIkRpc2Nvbm5lY3RlZFwiLFxuICBwZW5kaW5nUmVxdWVzdHM6IGluaXRpYWxTdGF0ZV9wZW5kaW5nUmVxdWVzdHNcbn07XG5cbmZ1bmN0aW9uIHJlZHVjZShzdGF0ZSwgYWN0aW9uKSB7XG4gIHN3aXRjaCAoYWN0aW9uLlRBRykge1xuICAgIGNhc2UgXCJSZXF1ZXN0U2VudFwiIDpcbiAgICAgIGxldCBpZCA9IGFjdGlvbi5fMDtcbiAgICAgIGxldCBuZXdQZW5kaW5nID0gT2JqZWN0LmFzc2lnbih7fSwgc3RhdGUucGVuZGluZ1JlcXVlc3RzKTtcbiAgICAgIG5ld1BlbmRpbmdbaWQudG9TdHJpbmcoKV0gPSBhY3Rpb24uXzE7XG4gICAgICByZXR1cm4ge1xuICAgICAgICBjdXJyZW50SWQ6IGlkLFxuICAgICAgICBjb25uZWN0aW9uU3RhdGU6IHN0YXRlLmNvbm5lY3Rpb25TdGF0ZSxcbiAgICAgICAgcGVuZGluZ1JlcXVlc3RzOiBuZXdQZW5kaW5nXG4gICAgICB9O1xuICAgIGNhc2UgXCJSZXNwb25zZVJlY2VpdmVkXCIgOlxuICAgICAgbGV0IG5ld1BlbmRpbmckMSA9IE9iamVjdC5hc3NpZ24oe30sIHN0YXRlLnBlbmRpbmdSZXF1ZXN0cyk7XG4gICAgICBTdGRsaWJfRGljdC4kJGRlbGV0ZShuZXdQZW5kaW5nJDEsIGFjdGlvbi5fMC50b1N0cmluZygpKTtcbiAgICAgIHJldHVybiB7XG4gICAgICAgIGN1cnJlbnRJZDogc3RhdGUuY3VycmVudElkLFxuICAgICAgICBjb25uZWN0aW9uU3RhdGU6IHN0YXRlLmNvbm5lY3Rpb25TdGF0ZSxcbiAgICAgICAgcGVuZGluZ1JlcXVlc3RzOiBuZXdQZW5kaW5nJDFcbiAgICAgIH07XG4gICAgY2FzZSBcIkNvbm5lY3Rpb25TdGF0ZUNoYW5nZWRcIiA6XG4gICAgICByZXR1cm4ge1xuICAgICAgICBjdXJyZW50SWQ6IHN0YXRlLmN1cnJlbnRJZCxcbiAgICAgICAgY29ubmVjdGlvblN0YXRlOiBhY3Rpb24uXzAsXG4gICAgICAgIHBlbmRpbmdSZXF1ZXN0czogc3RhdGUucGVuZGluZ1JlcXVlc3RzXG4gICAgICB9O1xuICB9XG59XG5cbmZ1bmN0aW9uIGhhbmRsZVJlc3BvbnNlKHN0YXRlLCBwYXlsb2FkKSB7XG4gIHRyeSB7XG4gICAgbGV0IHJlc3BvbnNlID0gRnJvbnRtYW5DbGllbnRfX0pzb25ScGMkQXNrVGhlTGxtRnJvbnRtYW5DbGllbnQuUmVzcG9uc2UuZnJvbUpzb25FeG4ocGF5bG9hZCk7XG4gICAgbGV0IGlkID0gRnJvbnRtYW5DbGllbnRfX0pzb25ScGMkQXNrVGhlTGxtRnJvbnRtYW5DbGllbnQuUmVzcG9uc2UuaWQocmVzcG9uc2UpO1xuICAgIGxldCBpZFN0ciA9IGlkLnRvU3RyaW5nKCk7XG4gICAgbGV0IG1hdGNoID0gc3RhdGUucGVuZGluZ1JlcXVlc3RzW2lkU3RyXTtcbiAgICBpZiAobWF0Y2ggIT09IHVuZGVmaW5lZCkge1xuICAgICAgbGV0IHJlamVjdCA9IG1hdGNoLnJlamVjdDtcbiAgICAgIGxldCByZXN1bHQgPSBGcm9udG1hbkNsaWVudF9fSnNvblJwYyRBc2tUaGVMbG1Gcm9udG1hbkNsaWVudC5SZXNwb25zZS5yZXN1bHQocmVzcG9uc2UpO1xuICAgICAgaWYgKHJlc3VsdCAhPT0gdW5kZWZpbmVkKSB7XG4gICAgICAgIG1hdGNoLnJlc29sdmUocmVzdWx0KTtcbiAgICAgIH0gZWxzZSB7XG4gICAgICAgIGxldCBlcnIgPSBGcm9udG1hbkNsaWVudF9fSnNvblJwYyRBc2tUaGVMbG1Gcm9udG1hbkNsaWVudC5SZXNwb25zZS5lcnJvcihyZXNwb25zZSk7XG4gICAgICAgIGlmIChlcnIgIT09IHVuZGVmaW5lZCkge1xuICAgICAgICAgIHJlamVjdChGcm9udG1hbkNsaWVudF9fSnNvblJwYyRBc2tUaGVMbG1Gcm9udG1hbkNsaWVudC5ScGNFcnJvci5tZXNzYWdlKFByaW1pdGl2ZV9vcHRpb24udmFsRnJvbU9wdGlvbihlcnIpKSk7XG4gICAgICAgIH0gZWxzZSB7XG4gICAgICAgICAgcmVqZWN0KFwiVW5rbm93biBlcnJvclwiKTtcbiAgICAgICAgfVxuICAgICAgfVxuICAgICAgcmV0dXJuIHJlZHVjZShzdGF0ZSwge1xuICAgICAgICBUQUc6IFwiUmVzcG9uc2VSZWNlaXZlZFwiLFxuICAgICAgICBfMDogaWRcbiAgICAgIH0pO1xuICAgIH1cbiAgICBjb25zb2xlLndhcm4oYFJlY2VpdmVkIHJlc3BvbnNlIGZvciB1bmtub3duIHJlcXVlc3Q6IGAgKyBpZFN0cik7XG4gICAgcmV0dXJuIHN0YXRlO1xuICB9IGNhdGNoIChleG4pIHtcbiAgICBjb25zb2xlLmxvZyhcIlJlY2VpdmVkIG5vbi1yZXNwb25zZSBtZXNzYWdlOlwiLCBwYXlsb2FkKTtcbiAgICByZXR1cm4gc3RhdGU7XG4gIH1cbn1cblxuZnVuY3Rpb24gYnVpbGRJbml0aWFsaXplUGFyYW1zKGNvbmZpZykge1xuICBsZXQgcGFyYW1zX2NsaWVudENhcGFiaWxpdGllcyA9IGNvbmZpZy5jbGllbnRDYXBhYmlsaXRpZXM7XG4gIGxldCBwYXJhbXNfY2xpZW50SW5mbyA9IGNvbmZpZy5jbGllbnRJbmZvO1xuICBsZXQgcGFyYW1zID0ge1xuICAgIHByb3RvY29sVmVyc2lvbjogRnJvbnRtYW5DbGllbnRfX0FDUF9fVHlwZXMkQXNrVGhlTGxtRnJvbnRtYW5DbGllbnQuY3VycmVudFByb3RvY29sVmVyc2lvbixcbiAgICBjbGllbnRDYXBhYmlsaXRpZXM6IHBhcmFtc19jbGllbnRDYXBhYmlsaXRpZXMsXG4gICAgY2xpZW50SW5mbzogcGFyYW1zX2NsaWVudEluZm9cbiAgfTtcbiAgcmV0dXJuIFMucmV2ZXJzZUNvbnZlcnRUb0pzb25PclRocm93KHBhcmFtcywgRnJvbnRtYW5DbGllbnRfX0FDUF9fVHlwZXMkQXNrVGhlTGxtRnJvbnRtYW5DbGllbnQuaW5pdGlhbGl6ZVBhcmFtc1NjaGVtYSk7XG59XG5cbmZ1bmN0aW9uIHBhcnNlSW5pdGlhbGl6ZVJlc3VsdChqc29uKSB7XG4gIHRyeSB7XG4gICAgcmV0dXJuIHtcbiAgICAgIFRBRzogXCJPa1wiLFxuICAgICAgXzA6IFMucGFyc2VPclRocm93KGpzb24sIEZyb250bWFuQ2xpZW50X19BQ1BfX1R5cGVzJEFza1RoZUxsbUZyb250bWFuQ2xpZW50LmluaXRpYWxpemVSZXN1bHRTY2hlbWEpXG4gICAgfTtcbiAgfSBjYXRjaCAocmF3X2UpIHtcbiAgICBsZXQgZSA9IFByaW1pdGl2ZV9leGNlcHRpb25zLmludGVybmFsVG9FeGNlcHRpb24ocmF3X2UpO1xuICAgIGlmIChlLlJFX0VYTl9JRCA9PT0gUy4kJEVycm9yKSB7XG4gICAgICByZXR1cm4ge1xuICAgICAgICBUQUc6IFwiRXJyb3JcIixcbiAgICAgICAgXzA6IGUuXzEubWVzc2FnZVxuICAgICAgfTtcbiAgICB9XG4gICAgdGhyb3cgZTtcbiAgfVxufVxuXG5mdW5jdGlvbiBwYXJzZVNlc3Npb25OZXdSZXN1bHQoanNvbikge1xuICB0cnkge1xuICAgIHJldHVybiB7XG4gICAgICBUQUc6IFwiT2tcIixcbiAgICAgIF8wOiBTLnBhcnNlT3JUaHJvdyhqc29uLCBGcm9udG1hbkNsaWVudF9fQUNQX19UeXBlcyRBc2tUaGVMbG1Gcm9udG1hbkNsaWVudC5zZXNzaW9uTmV3UmVzdWx0U2NoZW1hKVxuICAgIH07XG4gIH0gY2F0Y2ggKHJhd19lKSB7XG4gICAgbGV0IGUgPSBQcmltaXRpdmVfZXhjZXB0aW9ucy5pbnRlcm5hbFRvRXhjZXB0aW9uKHJhd19lKTtcbiAgICBpZiAoZS5SRV9FWE5fSUQgPT09IFMuJCRFcnJvcikge1xuICAgICAgcmV0dXJuIHtcbiAgICAgICAgVEFHOiBcIkVycm9yXCIsXG4gICAgICAgIF8wOiBlLl8xLm1lc3NhZ2VcbiAgICAgIH07XG4gICAgfVxuICAgIHRocm93IGU7XG4gIH1cbn1cblxuZnVuY3Rpb24gcGFyc2VQcm9tcHRSZXN1bHQoanNvbikge1xuICB0cnkge1xuICAgIHJldHVybiB7XG4gICAgICBUQUc6IFwiT2tcIixcbiAgICAgIF8wOiBTLnBhcnNlT3JUaHJvdyhqc29uLCBGcm9udG1hbkNsaWVudF9fQUNQX19UeXBlcyRBc2tUaGVMbG1Gcm9udG1hbkNsaWVudC5wcm9tcHRSZXN1bHRTY2hlbWEpXG4gICAgfTtcbiAgfSBjYXRjaCAocmF3X2UpIHtcbiAgICBsZXQgZSA9IFByaW1pdGl2ZV9leGNlcHRpb25zLmludGVybmFsVG9FeGNlcHRpb24ocmF3X2UpO1xuICAgIGlmIChlLlJFX0VYTl9JRCA9PT0gUy4kJEVycm9yKSB7XG4gICAgICByZXR1cm4ge1xuICAgICAgICBUQUc6IFwiRXJyb3JcIixcbiAgICAgICAgXzA6IGUuXzEubWVzc2FnZVxuICAgICAgfTtcbiAgICB9XG4gICAgdGhyb3cgZTtcbiAgfVxufVxuXG5mdW5jdGlvbiBwYXJzZVNlc3Npb25VcGRhdGVOb3RpZmljYXRpb24oanNvbikge1xuICB0cnkge1xuICAgIHJldHVybiB7XG4gICAgICBUQUc6IFwiT2tcIixcbiAgICAgIF8wOiBTLnBhcnNlT3JUaHJvdyhqc29uLCBGcm9udG1hbkNsaWVudF9fQUNQX19UeXBlcyRBc2tUaGVMbG1Gcm9udG1hbkNsaWVudC5zZXNzaW9uVXBkYXRlTm90aWZpY2F0aW9uU2NoZW1hKVxuICAgIH07XG4gIH0gY2F0Y2ggKHJhd19lKSB7XG4gICAgbGV0IGUgPSBQcmltaXRpdmVfZXhjZXB0aW9ucy5pbnRlcm5hbFRvRXhjZXB0aW9uKHJhd19lKTtcbiAgICBpZiAoZS5SRV9FWE5fSUQgPT09IFMuJCRFcnJvcikge1xuICAgICAgcmV0dXJuIHtcbiAgICAgICAgVEFHOiBcIkVycm9yXCIsXG4gICAgICAgIF8wOiBlLl8xLm1lc3NhZ2VcbiAgICAgIH07XG4gICAgfVxuICAgIHRocm93IGU7XG4gIH1cbn1cblxuZnVuY3Rpb24gaXNJbml0aWFsaXplZChzdGF0ZSkge1xuICBsZXQgbWF0Y2ggPSBzdGF0ZS5jb25uZWN0aW9uU3RhdGU7XG4gIHJldHVybiB0eXBlb2YgbWF0Y2ggPT09IFwib2JqZWN0XCI7XG59XG5cbmZ1bmN0aW9uIGdldENvbm5lY3Rpb25TdGF0ZShzdGF0ZSkge1xuICByZXR1cm4gc3RhdGUuY29ubmVjdGlvblN0YXRlO1xufVxuXG5sZXQgVHlwZXM7XG5cbmxldCBKc29uUnBjO1xuXG5sZXQgQ2hhbm5lbDtcblxuZXhwb3J0IHtcbiAgVHlwZXMsXG4gIEpzb25ScGMsXG4gIENoYW5uZWwsXG4gIGluaXRpYWxTdGF0ZSxcbiAgcmVkdWNlLFxuICBoYW5kbGVSZXNwb25zZSxcbiAgYnVpbGRJbml0aWFsaXplUGFyYW1zLFxuICBwYXJzZUluaXRpYWxpemVSZXN1bHQsXG4gIHBhcnNlU2Vzc2lvbk5ld1Jlc3VsdCxcbiAgcGFyc2VQcm9tcHRSZXN1bHQsXG4gIHBhcnNlU2Vzc2lvblVwZGF0ZU5vdGlmaWNhdGlvbixcbiAgaXNJbml0aWFsaXplZCxcbiAgZ2V0Q29ubmVjdGlvblN0YXRlLFxufVxuLyogUyBOb3QgYSBwdXJlIG1vZHVsZSAqL1xuIiwgIi8vIEdlbmVyYXRlZCBieSBSZVNjcmlwdCwgUExFQVNFIEVESVQgV0lUSCBDQVJFXG5cbmltcG9ydCAqIGFzIFMgZnJvbSBcInN1cnkvc3JjL1MucmVzLm1qc1wiO1xuaW1wb3J0ICogYXMgU3RkbGliX0pTT04gZnJvbSBcIkByZXNjcmlwdC9ydW50aW1lL2xpYi9lczYvU3RkbGliX0pTT04uanNcIjtcbmltcG9ydCAqIGFzIFN0ZGxpYl9PcHRpb24gZnJvbSBcIkByZXNjcmlwdC9ydW50aW1lL2xpYi9lczYvU3RkbGliX09wdGlvbi5qc1wiO1xuaW1wb3J0ICogYXMgUHJpbWl0aXZlX2V4Y2VwdGlvbnMgZnJvbSBcIkByZXNjcmlwdC9ydW50aW1lL2xpYi9lczYvUHJpbWl0aXZlX2V4Y2VwdGlvbnMuanNcIjtcbmltcG9ydCAqIGFzIEZyb250bWFuQ2xpZW50X19Kc29uUnBjJEFza1RoZUxsbUZyb250bWFuQ2xpZW50IGZyb20gXCIuL0Zyb250bWFuQ2xpZW50X19Kc29uUnBjLnJlcy5tanNcIjtcbmltcG9ydCAqIGFzIEZyb250bWFuUHJvdG9jb2xfX01DUCRBc2tUaGVMbG1Gcm9udG1hblByb3RvY29sIGZyb20gXCJAYXNrLXRoZS1sbG0vZnJvbnRtYW4tcHJvdG9jb2wvc3JjL0Zyb250bWFuUHJvdG9jb2xfX01DUC5yZXMubWpzXCI7XG5pbXBvcnQgKiBhcyBGcm9udG1hbkNsaWVudF9fTUNQX19UeXBlcyRBc2tUaGVMbG1Gcm9udG1hbkNsaWVudCBmcm9tIFwiLi9Gcm9udG1hbkNsaWVudF9fTUNQX19UeXBlcy5yZXMubWpzXCI7XG5pbXBvcnQgKiBhcyBGcm9udG1hbkNsaWVudF9fTUNQX19TZXJ2ZXIkQXNrVGhlTGxtRnJvbnRtYW5DbGllbnQgZnJvbSBcIi4vRnJvbnRtYW5DbGllbnRfX01DUF9fU2VydmVyLnJlcy5tanNcIjtcblxubGV0IHJlcXVlc3RTY2hlbWEgPSBTLm9iamVjdChzID0+IHtcbiAgcy5mKFwianNvbnJwY1wiLCBTLmxpdGVyYWwoXCIyLjBcIikpO1xuICBsZXQgaWQgPSBzLmYoXCJpZFwiLCBTLmludCk7XG4gIGxldCBtZXRob2QgPSBzLmYoXCJtZXRob2RcIiwgUy5zdHJpbmcpO1xuICBsZXQgcGFyYW1zID0gcy5mKFwicGFyYW1zXCIsIFMub3B0aW9uKFMuanNvbikpO1xuICByZXR1cm4ge1xuICAgIFRBRzogXCJSZXF1ZXN0XCIsXG4gICAgaWQ6IGlkLFxuICAgIG1ldGhvZDogbWV0aG9kLFxuICAgIHBhcmFtczogcGFyYW1zXG4gIH07XG59KTtcblxubGV0IG5vdGlmaWNhdGlvblNjaGVtYSA9IFMub2JqZWN0KHMgPT4ge1xuICBzLmYoXCJqc29ucnBjXCIsIFMubGl0ZXJhbChcIjIuMFwiKSk7XG4gIGxldCBtZXRob2QgPSBzLmYoXCJtZXRob2RcIiwgUy5zdHJpbmcpO1xuICBsZXQgcGFyYW1zID0gcy5mKFwicGFyYW1zXCIsIFMub3B0aW9uKFMuanNvbikpO1xuICByZXR1cm4ge1xuICAgIFRBRzogXCJOb3RpZmljYXRpb25cIixcbiAgICBtZXRob2Q6IG1ldGhvZCxcbiAgICBwYXJhbXM6IHBhcmFtc1xuICB9O1xufSk7XG5cbmZ1bmN0aW9uIGhhc0lkRmllbGQoanNvbikge1xuICBsZXQgb2JqID0gU3RkbGliX0pTT04uRGVjb2RlLm9iamVjdChqc29uKTtcbiAgaWYgKG9iaiAhPT0gdW5kZWZpbmVkKSB7XG4gICAgcmV0dXJuIFN0ZGxpYl9PcHRpb24uaXNTb21lKG9ialtcImlkXCJdKTtcbiAgfSBlbHNlIHtcbiAgICByZXR1cm4gZmFsc2U7XG4gIH1cbn1cblxuZnVuY3Rpb24gcGFyc2UoanNvbikge1xuICBsZXQgc2NoZW1hID0gaGFzSWRGaWVsZChqc29uKSA/IHJlcXVlc3RTY2hlbWEgOiBub3RpZmljYXRpb25TY2hlbWE7XG4gIHRyeSB7XG4gICAgcmV0dXJuIHtcbiAgICAgIFRBRzogXCJPa1wiLFxuICAgICAgXzA6IFMucGFyc2VPclRocm93KGpzb24sIHNjaGVtYSlcbiAgICB9O1xuICB9IGNhdGNoIChyYXdfZSkge1xuICAgIGxldCBlID0gUHJpbWl0aXZlX2V4Y2VwdGlvbnMuaW50ZXJuYWxUb0V4Y2VwdGlvbihyYXdfZSk7XG4gICAgaWYgKGUuUkVfRVhOX0lEID09PSBTLiQkRXJyb3IpIHtcbiAgICAgIHJldHVybiB7XG4gICAgICAgIFRBRzogXCJFcnJvclwiLFxuICAgICAgICBfMDogZS5fMS5tZXNzYWdlXG4gICAgICB9O1xuICAgIH1cbiAgICB0aHJvdyBlO1xuICB9XG59XG5cbmZ1bmN0aW9uIHNlbmRSZXNwb25zZShoYW5kbGVyLCBpZCwgcmVzdWx0KSB7XG4gIGxldCByZXNwb25zZSA9IEZyb250bWFuQ2xpZW50X19Kc29uUnBjJEFza1RoZUxsbUZyb250bWFuQ2xpZW50LlJlc3BvbnNlLm1ha2VTdWNjZXNzKGlkLCByZXN1bHQpO1xuICBsZXQgcGF5bG9hZCA9IFMucmV2ZXJzZUNvbnZlcnRUb0pzb25PclRocm93KHJlc3BvbnNlLCBGcm9udG1hbkNsaWVudF9fSnNvblJwYyRBc2tUaGVMbG1Gcm9udG1hbkNsaWVudC5SZXNwb25zZS5zY2hlbWEpO1xuICBTdGRsaWJfT3B0aW9uLmZvckVhY2goaGFuZGxlci5vbk1lc3NhZ2UsIGNiID0+IGNiKFwiU2VuZFwiLCBwYXlsb2FkKSk7XG4gIGhhbmRsZXIuY2hhbm5lbC5wdXNoKFwibWNwOm1lc3NhZ2VcIiwgcGF5bG9hZCk7XG59XG5cbmZ1bmN0aW9uIHNlbmRFcnJvcihoYW5kbGVyLCBpZCwgX2NvZGUsIG1lc3NhZ2UpIHtcbiAgbGV0IGVycm9yID0gRnJvbnRtYW5DbGllbnRfX0pzb25ScGMkQXNrVGhlTGxtRnJvbnRtYW5DbGllbnQuUnBjRXJyb3IubWFrZSgtMzI2MDEsIG1lc3NhZ2UsIHVuZGVmaW5lZCk7XG4gIGxldCByZXNwb25zZSA9IEZyb250bWFuQ2xpZW50X19Kc29uUnBjJEFza1RoZUxsbUZyb250bWFuQ2xpZW50LlJlc3BvbnNlLm1ha2VFcnJvcihpZCwgZXJyb3IpO1xuICBsZXQgcGF5bG9hZCA9IFMucmV2ZXJzZUNvbnZlcnRUb0pzb25PclRocm93KHJlc3BvbnNlLCBGcm9udG1hbkNsaWVudF9fSnNvblJwYyRBc2tUaGVMbG1Gcm9udG1hbkNsaWVudC5SZXNwb25zZS5zY2hlbWEpO1xuICBTdGRsaWJfT3B0aW9uLmZvckVhY2goaGFuZGxlci5vbk1lc3NhZ2UsIGNiID0+IGNiKFwiU2VuZFwiLCBwYXlsb2FkKSk7XG4gIGhhbmRsZXIuY2hhbm5lbC5wdXNoKFwibWNwOm1lc3NhZ2VcIiwgcGF5bG9hZCk7XG59XG5cbmZ1bmN0aW9uIGhhbmRsZUluaXRpYWxpemUoaGFuZGxlciwgaWQsIF9wYXJhbXMpIHtcbiAgbGV0IHJlc3VsdCA9IEZyb250bWFuQ2xpZW50X19NQ1BfX1NlcnZlciRBc2tUaGVMbG1Gcm9udG1hbkNsaWVudC5idWlsZEluaXRpYWxpemVSZXN1bHQoaGFuZGxlci5zZXJ2ZXIpO1xuICBsZXQgcmVzdWx0SnNvbiA9IFMucmV2ZXJzZUNvbnZlcnRUb0pzb25PclRocm93KHJlc3VsdCwgRnJvbnRtYW5DbGllbnRfX01DUF9fVHlwZXMkQXNrVGhlTGxtRnJvbnRtYW5DbGllbnQuaW5pdGlhbGl6ZVJlc3VsdFNjaGVtYSk7XG4gIHNlbmRSZXNwb25zZShoYW5kbGVyLCBpZCwgcmVzdWx0SnNvbik7XG59XG5cbmZ1bmN0aW9uIGhhbmRsZVRvb2xzTGlzdChoYW5kbGVyLCBpZCkge1xuICBsZXQgcmVzdWx0ID0gRnJvbnRtYW5DbGllbnRfX01DUF9fU2VydmVyJEFza1RoZUxsbUZyb250bWFuQ2xpZW50LmJ1aWxkVG9vbHNMaXN0UmVzdWx0KGhhbmRsZXIuc2VydmVyKTtcbiAgbGV0IHJlc3VsdEpzb24gPSBTLnJldmVyc2VDb252ZXJ0VG9Kc29uT3JUaHJvdyhyZXN1bHQsIEZyb250bWFuQ2xpZW50X19NQ1BfX1R5cGVzJEFza1RoZUxsbUZyb250bWFuQ2xpZW50LnRvb2xzTGlzdFJlc3VsdFNjaGVtYSk7XG4gIHNlbmRSZXNwb25zZShoYW5kbGVyLCBpZCwgcmVzdWx0SnNvbik7XG59XG5cbmFzeW5jIGZ1bmN0aW9uIGhhbmRsZVRvb2xzQ2FsbChoYW5kbGVyLCBpZCwgcGFyYW1zKSB7XG4gIGlmIChwYXJhbXMgPT09IHVuZGVmaW5lZCkge1xuICAgIHJldHVybiBzZW5kRXJyb3IoaGFuZGxlciwgaWQsIEZyb250bWFuUHJvdG9jb2xfX01DUCRBc2tUaGVMbG1Gcm9udG1hblByb3RvY29sLkVycm9yQ29kZS5pbnZhbGlkUGFyYW1zLCBcIk1pc3NpbmcgcGFyYW1zIGZvciB0b29scy9jYWxsXCIpO1xuICB9XG4gIHRyeSB7XG4gICAgbGV0IG1hdGNoID0gUy5wYXJzZU9yVGhyb3cocGFyYW1zLCBGcm9udG1hbkNsaWVudF9fTUNQX19UeXBlcyRBc2tUaGVMbG1Gcm9udG1hbkNsaWVudC50b29sQ2FsbFBhcmFtc1NjaGVtYSk7XG4gICAgbGV0IHJlc3VsdCA9IGF3YWl0IEZyb250bWFuQ2xpZW50X19NQ1BfX1NlcnZlciRBc2tUaGVMbG1Gcm9udG1hbkNsaWVudC5leGVjdXRlVG9vbChoYW5kbGVyLnNlcnZlciwgbWF0Y2gubmFtZSwgbWF0Y2guYXJndW1lbnRzLCB1bmRlZmluZWQpO1xuICAgIGxldCByZXN1bHRKc29uID0gUy5yZXZlcnNlQ29udmVydFRvSnNvbk9yVGhyb3cocmVzdWx0LCBGcm9udG1hbkNsaWVudF9fTUNQX19UeXBlcyRBc2tUaGVMbG1Gcm9udG1hbkNsaWVudC5jYWxsVG9vbFJlc3VsdFNjaGVtYSk7XG4gICAgcmV0dXJuIHNlbmRSZXNwb25zZShoYW5kbGVyLCBpZCwgcmVzdWx0SnNvbik7XG4gIH0gY2F0Y2ggKHJhd19lKSB7XG4gICAgbGV0IGUgPSBQcmltaXRpdmVfZXhjZXB0aW9ucy5pbnRlcm5hbFRvRXhjZXB0aW9uKHJhd19lKTtcbiAgICBpZiAoZS5SRV9FWE5fSUQgPT09IFMuJCRFcnJvcikge1xuICAgICAgcmV0dXJuIHNlbmRFcnJvcihoYW5kbGVyLCBpZCwgRnJvbnRtYW5Qcm90b2NvbF9fTUNQJEFza1RoZUxsbUZyb250bWFuUHJvdG9jb2wuRXJyb3JDb2RlLmludmFsaWRQYXJhbXMsIGBJbnZhbGlkIHBhcmFtczogYCArIGUuXzEubWVzc2FnZSk7XG4gICAgfVxuICAgIHRocm93IGU7XG4gIH1cbn1cblxuYXN5bmMgZnVuY3Rpb24gaGFuZGxlTWVzc2FnZShoYW5kbGVyLCBwYXlsb2FkKSB7XG4gIFN0ZGxpYl9PcHRpb24uZm9yRWFjaChoYW5kbGVyLm9uTWVzc2FnZSwgY2IgPT4gY2IoXCJSZWNlaXZlXCIsIHBheWxvYWQpKTtcbiAgbGV0IG1zZyA9IHBhcnNlKHBheWxvYWQpO1xuICBpZiAobXNnLlRBRyA9PT0gXCJPa1wiKSB7XG4gICAgbGV0IG1hdGNoID0gbXNnLl8wO1xuICAgIGlmIChtYXRjaC5UQUcgIT09IFwiUmVxdWVzdFwiKSB7XG4gICAgICByZXR1cm47XG4gICAgfVxuICAgIGxldCBwYXJhbXMgPSBtYXRjaC5wYXJhbXM7XG4gICAgbGV0IG1ldGhvZCA9IG1hdGNoLm1ldGhvZDtcbiAgICBsZXQgaWQgPSBtYXRjaC5pZDtcbiAgICBzd2l0Y2ggKG1ldGhvZCkge1xuICAgICAgY2FzZSBcImluaXRpYWxpemVcIiA6XG4gICAgICAgIHJldHVybiBoYW5kbGVJbml0aWFsaXplKGhhbmRsZXIsIGlkLCBwYXJhbXMpO1xuICAgICAgY2FzZSBcInRvb2xzL2NhbGxcIiA6XG4gICAgICAgIHJldHVybiBhd2FpdCBoYW5kbGVUb29sc0NhbGwoaGFuZGxlciwgaWQsIHBhcmFtcyk7XG4gICAgICBjYXNlIFwidG9vbHMvbGlzdFwiIDpcbiAgICAgICAgcmV0dXJuIGhhbmRsZVRvb2xzTGlzdChoYW5kbGVyLCBpZCk7XG4gICAgICBkZWZhdWx0OlxuICAgICAgICByZXR1cm4gc2VuZEVycm9yKGhhbmRsZXIsIGlkLCBGcm9udG1hblByb3RvY29sX19NQ1AkQXNrVGhlTGxtRnJvbnRtYW5Qcm90b2NvbC5FcnJvckNvZGUubWV0aG9kTm90Rm91bmQsIGBNZXRob2Qgbm90IGZvdW5kOiBgICsgbWV0aG9kKTtcbiAgICB9XG4gIH0gZWxzZSB7XG4gICAgY29uc29sZS5lcnJvcihgRmFpbGVkIHRvIHBhcnNlIE1DUCBtZXNzYWdlOiBgICsgbXNnLl8wKTtcbiAgICByZXR1cm47XG4gIH1cbn1cblxuZnVuY3Rpb24gYXR0YWNoKGNoYW5uZWwsIHNlcnZlciwgb25NZXNzYWdlKSB7XG4gIGxldCBoYW5kbGVyID0ge1xuICAgIHNlcnZlcjogc2VydmVyLFxuICAgIGNoYW5uZWw6IGNoYW5uZWwsXG4gICAgb25NZXNzYWdlOiBvbk1lc3NhZ2VcbiAgfTtcbiAgY2hhbm5lbC5vbihcIm1jcDptZXNzYWdlXCIsIHBheWxvYWQgPT4ge1xuICAgIGhhbmRsZU1lc3NhZ2UoaGFuZGxlciwgcGF5bG9hZCk7XG4gIH0pO1xuICByZXR1cm4gaGFuZGxlcjtcbn1cblxuZnVuY3Rpb24gZGV0YWNoKGhhbmRsZXIpIHtcbiAgaGFuZGxlci5jaGFubmVsLm9mZihcIm1jcDptZXNzYWdlXCIpO1xufVxuXG5sZXQgVHlwZXM7XG5cbmxldCBTZXJ2ZXI7XG5cbmxldCBDaGFubmVsO1xuXG5sZXQgSnNvblJwYztcblxuZXhwb3J0IHtcbiAgVHlwZXMsXG4gIFNlcnZlcixcbiAgQ2hhbm5lbCxcbiAgSnNvblJwYyxcbiAgcmVxdWVzdFNjaGVtYSxcbiAgbm90aWZpY2F0aW9uU2NoZW1hLFxuICBoYXNJZEZpZWxkLFxuICBwYXJzZSxcbiAgc2VuZFJlc3BvbnNlLFxuICBzZW5kRXJyb3IsXG4gIGhhbmRsZUluaXRpYWxpemUsXG4gIGhhbmRsZVRvb2xzTGlzdCxcbiAgaGFuZGxlVG9vbHNDYWxsLFxuICBoYW5kbGVNZXNzYWdlLFxuICBhdHRhY2gsXG4gIGRldGFjaCxcbn1cbi8qIHJlcXVlc3RTY2hlbWEgTm90IGEgcHVyZSBtb2R1bGUgKi9cbiIsICJcblxuXG5mdW5jdGlvbiBjbGFzc2lmeSh2YWx1ZSkge1xuICBsZXQgbWF0Y2ggPSBPYmplY3QucHJvdG90eXBlLnRvU3RyaW5nLmNhbGwodmFsdWUpO1xuICBzd2l0Y2ggKG1hdGNoKSB7XG4gICAgY2FzZSBcIltvYmplY3QgQXJyYXldXCIgOlxuICAgICAgcmV0dXJuIHtcbiAgICAgICAgVEFHOiBcIkFycmF5XCIsXG4gICAgICAgIF8wOiB2YWx1ZVxuICAgICAgfTtcbiAgICBjYXNlIFwiW29iamVjdCBCb29sZWFuXVwiIDpcbiAgICAgIHJldHVybiB7XG4gICAgICAgIFRBRzogXCJCb29sXCIsXG4gICAgICAgIF8wOiB2YWx1ZVxuICAgICAgfTtcbiAgICBjYXNlIFwiW29iamVjdCBOdWxsXVwiIDpcbiAgICAgIHJldHVybiBcIk51bGxcIjtcbiAgICBjYXNlIFwiW29iamVjdCBOdW1iZXJdXCIgOlxuICAgICAgcmV0dXJuIHtcbiAgICAgICAgVEFHOiBcIk51bWJlclwiLFxuICAgICAgICBfMDogdmFsdWVcbiAgICAgIH07XG4gICAgY2FzZSBcIltvYmplY3QgU3RyaW5nXVwiIDpcbiAgICAgIHJldHVybiB7XG4gICAgICAgIFRBRzogXCJTdHJpbmdcIixcbiAgICAgICAgXzA6IHZhbHVlXG4gICAgICB9O1xuICAgIGRlZmF1bHQ6XG4gICAgICByZXR1cm4ge1xuICAgICAgICBUQUc6IFwiT2JqZWN0XCIsXG4gICAgICAgIF8wOiB2YWx1ZVxuICAgICAgfTtcbiAgfVxufVxuXG5sZXQgQ2xhc3NpZnkgPSB7XG4gIGNsYXNzaWZ5OiBjbGFzc2lmeVxufTtcblxubGV0IEVuY29kZSA9IHt9O1xuXG5mdW5jdGlvbiBib29sKGpzb24pIHtcbiAgaWYgKHR5cGVvZiBqc29uID09PSBcImJvb2xlYW5cIikge1xuICAgIHJldHVybiBqc29uO1xuICB9XG59XG5cbmZ1bmN0aW9uICQkbnVsbChqc29uKSB7XG4gIGlmIChqc29uID09PSBudWxsKSB7XG4gICAgcmV0dXJuIG51bGw7XG4gIH1cbn1cblxuZnVuY3Rpb24gc3RyaW5nKGpzb24pIHtcbiAgaWYgKHR5cGVvZiBqc29uID09PSBcInN0cmluZ1wiKSB7XG4gICAgcmV0dXJuIGpzb247XG4gIH1cbn1cblxuZnVuY3Rpb24gZmxvYXQoanNvbikge1xuICBpZiAodHlwZW9mIGpzb24gPT09IFwibnVtYmVyXCIpIHtcbiAgICByZXR1cm4ganNvbjtcbiAgfVxufVxuXG5mdW5jdGlvbiBvYmplY3QoanNvbikge1xuICBpZiAodHlwZW9mIGpzb24gPT09IFwib2JqZWN0XCIgJiYganNvbiAhPT0gbnVsbCAmJiAhQXJyYXkuaXNBcnJheShqc29uKSkge1xuICAgIHJldHVybiBqc29uO1xuICB9XG59XG5cbmZ1bmN0aW9uIGFycmF5KGpzb24pIHtcbiAgaWYgKEFycmF5LmlzQXJyYXkoanNvbikpIHtcbiAgICByZXR1cm4ganNvbjtcbiAgfVxufVxuXG5sZXQgRGVjb2RlID0ge1xuICBib29sOiBib29sLFxuICAkJG51bGw6ICQkbnVsbCxcbiAgc3RyaW5nOiBzdHJpbmcsXG4gIGZsb2F0OiBmbG9hdCxcbiAgb2JqZWN0OiBvYmplY3QsXG4gIGFycmF5OiBhcnJheVxufTtcblxuZXhwb3J0IHtcbiAgQ2xhc3NpZnksXG4gIEVuY29kZSxcbiAgRGVjb2RlLFxufVxuLyogTm8gc2lkZSBlZmZlY3QgKi9cbiIsICIvLyBHZW5lcmF0ZWQgYnkgUmVTY3JpcHQsIFBMRUFTRSBFRElUIFdJVEggQ0FSRVxuXG5pbXBvcnQgKiBhcyBTIGZyb20gXCJzdXJ5L3NyYy9TLnJlcy5tanNcIjtcblxuUy5lbmFibGVKc29uKCk7XG5cbmxldCBjYXBhYmlsaXRpZXNTY2hlbWEgPSBTLnNjaGVtYShzID0+ICh7XG4gIHRvb2xzOiBzLm0oUy5vcHRpb24oUy5kaWN0KFMuanNvbikpKSxcbiAgcmVzb3VyY2VzOiBzLm0oUy5vcHRpb24oUy5kaWN0KFMuanNvbikpKSxcbiAgcHJvbXB0czogcy5tKFMub3B0aW9uKFMuZGljdChTLmpzb24pKSlcbn0pKTtcblxubGV0IGluZm9TY2hlbWEgPSBTLnNjaGVtYShzID0+ICh7XG4gIG5hbWU6IHMubShTLnN0cmluZyksXG4gIHZlcnNpb246IHMubShTLnN0cmluZylcbn0pKTtcblxubGV0IGluaXRpYWxpemVQYXJhbXNTY2hlbWEgPSBTLnNjaGVtYShzID0+ICh7XG4gIHByb3RvY29sVmVyc2lvbjogcy5tKFMuc3RyaW5nKSxcbiAgY2FwYWJpbGl0aWVzOiBzLm0oY2FwYWJpbGl0aWVzU2NoZW1hKSxcbiAgY2xpZW50SW5mbzogcy5tKGluZm9TY2hlbWEpXG59KSk7XG5cbmxldCBpbml0aWFsaXplUmVzdWx0U2NoZW1hID0gUy5zY2hlbWEocyA9PiAoe1xuICBwcm90b2NvbFZlcnNpb246IHMubShTLnN0cmluZyksXG4gIGNhcGFiaWxpdGllczogcy5tKGNhcGFiaWxpdGllc1NjaGVtYSksXG4gIHNlcnZlckluZm86IHMubShpbmZvU2NoZW1hKVxufSkpO1xuXG5sZXQgdG9vbENhbGxQYXJhbXNTY2hlbWEgPSBTLnNjaGVtYShzID0+ICh7XG4gIGNhbGxJZDogcy5tKFMuc3RyaW5nKSxcbiAgbmFtZTogcy5tKFMuc3RyaW5nKSxcbiAgYXJndW1lbnRzOiBzLm0oUy5vcHRpb24oUy5kaWN0KFMuanNvbikpKVxufSkpO1xuXG5sZXQgdG9vbFJlc3VsdENvbnRlbnRTY2hlbWEgPSBTLnNjaGVtYShzID0+ICh7XG4gIHR5cGU6IHMubShTLnN0cmluZyksXG4gIHRleHQ6IHMubShTLnN0cmluZylcbn0pKTtcblxubGV0IHRvb2xFcnJvclNjaGVtYSA9IFMuc2NoZW1hKHMgPT4gKHtcbiAgY29kZTogcy5tKFMuaW50KSxcbiAgbWVzc2FnZTogcy5tKFMuc3RyaW5nKVxufSkpO1xuXG5sZXQgY2FsbFRvb2xSZXN1bHRTY2hlbWEgPSBTLnNjaGVtYShzID0+ICh7XG4gIGNvbnRlbnQ6IHMubShTLmFycmF5KHRvb2xSZXN1bHRDb250ZW50U2NoZW1hKSksXG4gIGlzRXJyb3I6IHMubShTLm9wdGlvbihTLmJvb2wpKVxufSkpO1xuXG5sZXQgdG9vbHNMaXN0UmVzdWx0U2NoZW1hID0gUy5zY2hlbWEocyA9PiAoe1xuICB0b29sczogcy5tKFMuYXJyYXkoUy5qc29uKSlcbn0pKTtcblxubGV0IEVycm9yQ29kZSA9IHtcbiAgaW52YWxpZFBhcmFtczogLTMyNjAyLFxuICBzZXJ2ZXJFcnJvcjogLTMyMDAwLFxuICBtZXRob2ROb3RGb3VuZDogLTMyNjAxXG59O1xuXG5sZXQgcHJvdG9jb2xWZXJzaW9uID0gXCJEUkFGVC0yMDI1LXYzXCI7XG5cbmV4cG9ydCB7XG4gIHByb3RvY29sVmVyc2lvbixcbiAgY2FwYWJpbGl0aWVzU2NoZW1hLFxuICBpbmZvU2NoZW1hLFxuICBpbml0aWFsaXplUGFyYW1zU2NoZW1hLFxuICBpbml0aWFsaXplUmVzdWx0U2NoZW1hLFxuICB0b29sQ2FsbFBhcmFtc1NjaGVtYSxcbiAgdG9vbFJlc3VsdENvbnRlbnRTY2hlbWEsXG4gIHRvb2xFcnJvclNjaGVtYSxcbiAgY2FsbFRvb2xSZXN1bHRTY2hlbWEsXG4gIHRvb2xzTGlzdFJlc3VsdFNjaGVtYSxcbiAgRXJyb3JDb2RlLFxufVxuLyogIE5vdCBhIHB1cmUgbW9kdWxlICovXG4iLCAiLy8gR2VuZXJhdGVkIGJ5IFJlU2NyaXB0LCBQTEVBU0UgRURJVCBXSVRIIENBUkVcblxuaW1wb3J0ICogYXMgRnJvbnRtYW5Qcm90b2NvbF9fTUNQJEFza1RoZUxsbUZyb250bWFuUHJvdG9jb2wgZnJvbSBcIkBhc2stdGhlLWxsbS9mcm9udG1hbi1wcm90b2NvbC9zcmMvRnJvbnRtYW5Qcm90b2NvbF9fTUNQLnJlcy5tanNcIjtcblxubGV0IHByb3RvY29sVmVyc2lvbiA9IEZyb250bWFuUHJvdG9jb2xfX01DUCRBc2tUaGVMbG1Gcm9udG1hblByb3RvY29sLnByb3RvY29sVmVyc2lvbjtcblxubGV0IGNhcGFiaWxpdGllc1NjaGVtYSA9IEZyb250bWFuUHJvdG9jb2xfX01DUCRBc2tUaGVMbG1Gcm9udG1hblByb3RvY29sLmNhcGFiaWxpdGllc1NjaGVtYTtcblxubGV0IGluZm9TY2hlbWEgPSBGcm9udG1hblByb3RvY29sX19NQ1AkQXNrVGhlTGxtRnJvbnRtYW5Qcm90b2NvbC5pbmZvU2NoZW1hO1xuXG5sZXQgaW5pdGlhbGl6ZVBhcmFtc1NjaGVtYSA9IEZyb250bWFuUHJvdG9jb2xfX01DUCRBc2tUaGVMbG1Gcm9udG1hblByb3RvY29sLmluaXRpYWxpemVQYXJhbXNTY2hlbWE7XG5cbmxldCBpbml0aWFsaXplUmVzdWx0U2NoZW1hID0gRnJvbnRtYW5Qcm90b2NvbF9fTUNQJEFza1RoZUxsbUZyb250bWFuUHJvdG9jb2wuaW5pdGlhbGl6ZVJlc3VsdFNjaGVtYTtcblxubGV0IHRvb2xDYWxsUGFyYW1zU2NoZW1hID0gRnJvbnRtYW5Qcm90b2NvbF9fTUNQJEFza1RoZUxsbUZyb250bWFuUHJvdG9jb2wudG9vbENhbGxQYXJhbXNTY2hlbWE7XG5cbmxldCB0b29sUmVzdWx0Q29udGVudFNjaGVtYSA9IEZyb250bWFuUHJvdG9jb2xfX01DUCRBc2tUaGVMbG1Gcm9udG1hblByb3RvY29sLnRvb2xSZXN1bHRDb250ZW50U2NoZW1hO1xuXG5sZXQgdG9vbEVycm9yU2NoZW1hID0gRnJvbnRtYW5Qcm90b2NvbF9fTUNQJEFza1RoZUxsbUZyb250bWFuUHJvdG9jb2wudG9vbEVycm9yU2NoZW1hO1xuXG5sZXQgY2FsbFRvb2xSZXN1bHRTY2hlbWEgPSBGcm9udG1hblByb3RvY29sX19NQ1AkQXNrVGhlTGxtRnJvbnRtYW5Qcm90b2NvbC5jYWxsVG9vbFJlc3VsdFNjaGVtYTtcblxubGV0IHRvb2xzTGlzdFJlc3VsdFNjaGVtYSA9IEZyb250bWFuUHJvdG9jb2xfX01DUCRBc2tUaGVMbG1Gcm9udG1hblByb3RvY29sLnRvb2xzTGlzdFJlc3VsdFNjaGVtYTtcblxubGV0IEVycm9yQ29kZSA9IEZyb250bWFuUHJvdG9jb2xfX01DUCRBc2tUaGVMbG1Gcm9udG1hblByb3RvY29sLkVycm9yQ29kZTtcblxuZXhwb3J0IHtcbiAgcHJvdG9jb2xWZXJzaW9uLFxuICBjYXBhYmlsaXRpZXNTY2hlbWEsXG4gIGluZm9TY2hlbWEsXG4gIGluaXRpYWxpemVQYXJhbXNTY2hlbWEsXG4gIGluaXRpYWxpemVSZXN1bHRTY2hlbWEsXG4gIHRvb2xDYWxsUGFyYW1zU2NoZW1hLFxuICB0b29sUmVzdWx0Q29udGVudFNjaGVtYSxcbiAgdG9vbEVycm9yU2NoZW1hLFxuICBjYWxsVG9vbFJlc3VsdFNjaGVtYSxcbiAgdG9vbHNMaXN0UmVzdWx0U2NoZW1hLFxuICBFcnJvckNvZGUsXG59XG4vKiBGcm9udG1hblByb3RvY29sX19NQ1AtQXNrVGhlTGxtRnJvbnRtYW5Qcm90b2NvbCBOb3QgYSBwdXJlIG1vZHVsZSAqL1xuIiwgIi8vIEdlbmVyYXRlZCBieSBSZVNjcmlwdCwgUExFQVNFIEVESVQgV0lUSCBDQVJFXG5cbmltcG9ydCAqIGFzIFMgZnJvbSBcInN1cnkvc3JjL1MucmVzLm1qc1wiO1xuaW1wb3J0ICogYXMgU3RkbGliX09wdGlvbiBmcm9tIFwiQHJlc2NyaXB0L3J1bnRpbWUvbGliL2VzNi9TdGRsaWJfT3B0aW9uLmpzXCI7XG5pbXBvcnQgKiBhcyBQcmltaXRpdmVfZXhjZXB0aW9ucyBmcm9tIFwiQHJlc2NyaXB0L3J1bnRpbWUvbGliL2VzNi9QcmltaXRpdmVfZXhjZXB0aW9ucy5qc1wiO1xuaW1wb3J0ICogYXMgRnJvbnRtYW5DbGllbnRfX1JlbGF5JEFza1RoZUxsbUZyb250bWFuQ2xpZW50IGZyb20gXCIuL0Zyb250bWFuQ2xpZW50X19SZWxheS5yZXMubWpzXCI7XG5pbXBvcnQgKiBhcyBGcm9udG1hbkNsaWVudF9fTUNQX19UeXBlcyRBc2tUaGVMbG1Gcm9udG1hbkNsaWVudCBmcm9tIFwiLi9Gcm9udG1hbkNsaWVudF9fTUNQX19UeXBlcy5yZXMubWpzXCI7XG5cbmZ1bmN0aW9uIG1ha2UocmVsYXksIHNlcnZlck5hbWVPcHQsIHNlcnZlclZlcnNpb25PcHQpIHtcbiAgbGV0IHNlcnZlck5hbWUgPSBzZXJ2ZXJOYW1lT3B0ICE9PSB1bmRlZmluZWQgPyBzZXJ2ZXJOYW1lT3B0IDogXCJmcm9udG1hbi1icm93c2VyXCI7XG4gIGxldCBzZXJ2ZXJWZXJzaW9uID0gc2VydmVyVmVyc2lvbk9wdCAhPT0gdW5kZWZpbmVkID8gc2VydmVyVmVyc2lvbk9wdCA6IFwiMS4wLjBcIjtcbiAgcmV0dXJuIHtcbiAgICB0b29sczogW10sXG4gICAgcmVsYXk6IHJlbGF5LFxuICAgIHNlcnZlckluZm86IHtcbiAgICAgIG5hbWU6IHNlcnZlck5hbWUsXG4gICAgICB2ZXJzaW9uOiBzZXJ2ZXJWZXJzaW9uXG4gICAgfVxuICB9O1xufVxuXG5mdW5jdGlvbiByZWdpc3RlclRvb2xNb2R1bGUoc2VydmVyLCB0b29sTW9kdWxlKSB7XG4gIHJldHVybiB7XG4gICAgdG9vbHM6IHNlcnZlci50b29scy5jb25jYXQoW3Rvb2xNb2R1bGVdKSxcbiAgICByZWxheTogc2VydmVyLnJlbGF5LFxuICAgIHNlcnZlckluZm86IHNlcnZlci5zZXJ2ZXJJbmZvXG4gIH07XG59XG5cbmxldCB0b29sV2lyZVNjaGVtYSA9IFMub2JqZWN0KHMgPT4gKHtcbiAgbmFtZTogcy5mKFwibmFtZVwiLCBTLnN0cmluZyksXG4gIGRlc2NyaXB0aW9uOiBzLmYoXCJkZXNjcmlwdGlvblwiLCBTLnN0cmluZyksXG4gIGlucHV0U2NoZW1hOiBzLmYoXCJpbnB1dFNjaGVtYVwiLCBTLmpzb24pXG59KSk7XG5cbmZ1bmN0aW9uIHNlcmlhbGl6ZVRvb2wobSkge1xuICByZXR1cm4gUy5yZXZlcnNlQ29udmVydFRvSnNvbk9yVGhyb3coe1xuICAgIG5hbWU6IG0ubmFtZSxcbiAgICBkZXNjcmlwdGlvbjogbS5kZXNjcmlwdGlvbixcbiAgICBpbnB1dFNjaGVtYTogUy50b0pTT05TY2hlbWEobS5pbnB1dFNjaGVtYSlcbiAgfSwgdG9vbFdpcmVTY2hlbWEpO1xufVxuXG5mdW5jdGlvbiBnZXRUb29sc0pzb24oc2VydmVyKSB7XG4gIGxldCBsb2NhbFRvb2xzID0gc2VydmVyLnRvb2xzLm1hcChzZXJpYWxpemVUb29sKTtcbiAgbGV0IHJlbGF5VG9vbHMgPSBGcm9udG1hbkNsaWVudF9fUmVsYXkkQXNrVGhlTGxtRnJvbnRtYW5DbGllbnQuZ2V0VG9vbHNKc29uKHNlcnZlci5yZWxheSk7XG4gIHJldHVybiBsb2NhbFRvb2xzLmNvbmNhdChyZWxheVRvb2xzKTtcbn1cblxuZnVuY3Rpb24gZ2V0VG9vbEJ5TmFtZShzZXJ2ZXIsIG5hbWUpIHtcbiAgcmV0dXJuIHNlcnZlci50b29scy5maW5kKG0gPT4gbS5uYW1lID09PSBuYW1lKTtcbn1cblxuYXN5bmMgZnVuY3Rpb24gZXhlY3V0ZUxvY2FsVG9vbCh0b29sTW9kdWxlLCAkJGFyZ3VtZW50cykge1xuICBsZXQgaW5wdXRKc29uID0gU3RkbGliX09wdGlvbi5nZXRPcigkJGFyZ3VtZW50cywge30pO1xuICB0cnkge1xuICAgIGxldCBpbnB1dCA9IFMucGFyc2VPclRocm93KGlucHV0SnNvbiwgdG9vbE1vZHVsZS5pbnB1dFNjaGVtYSk7XG4gICAgbGV0IHJlc3VsdCA9IGF3YWl0IHRvb2xNb2R1bGUuZXhlY3V0ZShpbnB1dCk7XG4gICAgaWYgKHJlc3VsdC5UQUcgIT09IFwiT2tcIikge1xuICAgICAgcmV0dXJuIHtcbiAgICAgICAgY29udGVudDogW3tcbiAgICAgICAgICAgIHR5cGU6IFwidGV4dFwiLFxuICAgICAgICAgICAgdGV4dDogcmVzdWx0Ll8wXG4gICAgICAgICAgfV0sXG4gICAgICAgIGlzRXJyb3I6IHRydWVcbiAgICAgIH07XG4gICAgfVxuICAgIGxldCBvdXRwdXRKc29uID0gUy5yZXZlcnNlQ29udmVydFRvSnNvbk9yVGhyb3cocmVzdWx0Ll8wLCB0b29sTW9kdWxlLm91dHB1dFNjaGVtYSk7XG4gICAgcmV0dXJuIHtcbiAgICAgIGNvbnRlbnQ6IFt7XG4gICAgICAgICAgdHlwZTogXCJ0ZXh0XCIsXG4gICAgICAgICAgdGV4dDogSlNPTi5zdHJpbmdpZnkob3V0cHV0SnNvbilcbiAgICAgICAgfV0sXG4gICAgICBpc0Vycm9yOiB1bmRlZmluZWRcbiAgICB9O1xuICB9IGNhdGNoIChyYXdfZSkge1xuICAgIGxldCBlID0gUHJpbWl0aXZlX2V4Y2VwdGlvbnMuaW50ZXJuYWxUb0V4Y2VwdGlvbihyYXdfZSk7XG4gICAgaWYgKGUuUkVfRVhOX0lEID09PSBTLiQkRXJyb3IpIHtcbiAgICAgIHJldHVybiB7XG4gICAgICAgIGNvbnRlbnQ6IFt7XG4gICAgICAgICAgICB0eXBlOiBcInRleHRcIixcbiAgICAgICAgICAgIHRleHQ6IGBJbnZhbGlkIGlucHV0OiBgICsgZS5fMS5tZXNzYWdlXG4gICAgICAgICAgfV0sXG4gICAgICAgIGlzRXJyb3I6IHRydWVcbiAgICAgIH07XG4gICAgfVxuICAgIHRocm93IGU7XG4gIH1cbn1cblxuYXN5bmMgZnVuY3Rpb24gZXhlY3V0ZVRvb2woc2VydmVyLCBuYW1lLCAkJGFyZ3VtZW50cywgb25Qcm9ncmVzcykge1xuICBsZXQgdG9vbE1vZHVsZSA9IGdldFRvb2xCeU5hbWUoc2VydmVyLCBuYW1lKTtcbiAgaWYgKHRvb2xNb2R1bGUgIT09IHVuZGVmaW5lZCkge1xuICAgIHJldHVybiBhd2FpdCBleGVjdXRlTG9jYWxUb29sKHRvb2xNb2R1bGUsICQkYXJndW1lbnRzKTtcbiAgfVxuICBpZiAoIUZyb250bWFuQ2xpZW50X19SZWxheSRBc2tUaGVMbG1Gcm9udG1hbkNsaWVudC5oYXNUb29sKHNlcnZlci5yZWxheSwgbmFtZSkpIHtcbiAgICByZXR1cm4ge1xuICAgICAgY29udGVudDogW3tcbiAgICAgICAgICB0eXBlOiBcInRleHRcIixcbiAgICAgICAgICB0ZXh0OiBgVG9vbCBub3QgZm91bmQ6IGAgKyBuYW1lXG4gICAgICAgIH1dLFxuICAgICAgaXNFcnJvcjogdHJ1ZVxuICAgIH07XG4gIH1cbiAgbGV0IHJlc3VsdCA9IGF3YWl0IEZyb250bWFuQ2xpZW50X19SZWxheSRBc2tUaGVMbG1Gcm9udG1hbkNsaWVudC5leGVjdXRlVG9vbChzZXJ2ZXIucmVsYXksIG5hbWUsICQkYXJndW1lbnRzLCBvblByb2dyZXNzKTtcbiAgaWYgKHJlc3VsdC5UQUcgPT09IFwiT2tcIikge1xuICAgIHJldHVybiByZXN1bHQuXzA7XG4gIH0gZWxzZSB7XG4gICAgcmV0dXJuIHtcbiAgICAgIGNvbnRlbnQ6IFt7XG4gICAgICAgICAgdHlwZTogXCJ0ZXh0XCIsXG4gICAgICAgICAgdGV4dDogcmVzdWx0Ll8wXG4gICAgICAgIH1dLFxuICAgICAgaXNFcnJvcjogdHJ1ZVxuICAgIH07XG4gIH1cbn1cblxuZnVuY3Rpb24gYnVpbGRJbml0aWFsaXplUmVzdWx0KHNlcnZlcikge1xuICByZXR1cm4ge1xuICAgIHByb3RvY29sVmVyc2lvbjogRnJvbnRtYW5DbGllbnRfX01DUF9fVHlwZXMkQXNrVGhlTGxtRnJvbnRtYW5DbGllbnQucHJvdG9jb2xWZXJzaW9uLFxuICAgIGNhcGFiaWxpdGllczoge1xuICAgICAgdG9vbHM6IHt9LFxuICAgICAgcmVzb3VyY2VzOiB1bmRlZmluZWQsXG4gICAgICBwcm9tcHRzOiB1bmRlZmluZWRcbiAgICB9LFxuICAgIHNlcnZlckluZm86IHNlcnZlci5zZXJ2ZXJJbmZvXG4gIH07XG59XG5cbmZ1bmN0aW9uIGJ1aWxkVG9vbHNMaXN0UmVzdWx0KHNlcnZlcikge1xuICByZXR1cm4ge1xuICAgIHRvb2xzOiBnZXRUb29sc0pzb24oc2VydmVyKVxuICB9O1xufVxuXG5sZXQgVHlwZXM7XG5cbmxldCBUb29sO1xuXG5sZXQgUmVsYXk7XG5cbmV4cG9ydCB7XG4gIFR5cGVzLFxuICBUb29sLFxuICBSZWxheSxcbiAgbWFrZSxcbiAgcmVnaXN0ZXJUb29sTW9kdWxlLFxuICB0b29sV2lyZVNjaGVtYSxcbiAgc2VyaWFsaXplVG9vbCxcbiAgZ2V0VG9vbHNKc29uLFxuICBnZXRUb29sQnlOYW1lLFxuICBleGVjdXRlTG9jYWxUb29sLFxuICBleGVjdXRlVG9vbCxcbiAgYnVpbGRJbml0aWFsaXplUmVzdWx0LFxuICBidWlsZFRvb2xzTGlzdFJlc3VsdCxcbn1cbi8qIHRvb2xXaXJlU2NoZW1hIE5vdCBhIHB1cmUgbW9kdWxlICovXG4iLCAiLy8gR2VuZXJhdGVkIGJ5IFJlU2NyaXB0LCBQTEVBU0UgRURJVCBXSVRIIENBUkVcblxuaW1wb3J0ICogYXMgUyBmcm9tIFwic3VyeS9zcmMvUy5yZXMubWpzXCI7XG5pbXBvcnQgKiBhcyBQcmltaXRpdmVfb3B0aW9uIGZyb20gXCJAcmVzY3JpcHQvcnVudGltZS9saWIvZXM2L1ByaW1pdGl2ZV9vcHRpb24uanNcIjtcbmltcG9ydCAqIGFzIFByaW1pdGl2ZV9leGNlcHRpb25zIGZyb20gXCJAcmVzY3JpcHQvcnVudGltZS9saWIvZXM2L1ByaW1pdGl2ZV9leGNlcHRpb25zLmpzXCI7XG5pbXBvcnQgKiBhcyBGcm9udG1hbkNsaWVudF9fU1NFJEFza1RoZUxsbUZyb250bWFuQ2xpZW50IGZyb20gXCIuL0Zyb250bWFuQ2xpZW50X19TU0UucmVzLm1qc1wiO1xuaW1wb3J0ICogYXMgRnJvbnRtYW5DbGllbnRfX01DUF9fVHlwZXMkQXNrVGhlTGxtRnJvbnRtYW5DbGllbnQgZnJvbSBcIi4vRnJvbnRtYW5DbGllbnRfX01DUF9fVHlwZXMucmVzLm1qc1wiO1xuaW1wb3J0ICogYXMgRnJvbnRtYW5DbGllbnRfX1JlbGF5X19UeXBlcyRBc2tUaGVMbG1Gcm9udG1hbkNsaWVudCBmcm9tIFwiLi9Gcm9udG1hbkNsaWVudF9fUmVsYXlfX1R5cGVzLnJlcy5tanNcIjtcblxuZnVuY3Rpb24gbWFrZShiYXNlVXJsKSB7XG4gIHJldHVybiB7XG4gICAgYmFzZVVybDogYmFzZVVybCxcbiAgICBzdGF0ZTogXCJEaXNjb25uZWN0ZWRcIlxuICB9O1xufVxuXG5mdW5jdGlvbiBpc0Nvbm5lY3RlZChyZWxheSkge1xuICBsZXQgbWF0Y2ggPSByZWxheS5zdGF0ZTtcbiAgaWYgKHR5cGVvZiBtYXRjaCAhPT0gXCJvYmplY3RcIikge1xuICAgIHJldHVybiBmYWxzZTtcbiAgfSBlbHNlIHtcbiAgICByZXR1cm4gbWF0Y2guVEFHID09PSBcIkNvbm5lY3RlZFwiO1xuICB9XG59XG5cbmZ1bmN0aW9uIGdldFN0YXRlKHJlbGF5KSB7XG4gIHJldHVybiByZWxheS5zdGF0ZTtcbn1cblxuYXN5bmMgZnVuY3Rpb24gY29ubmVjdChyZWxheSkge1xuICBsZXQgdXJsID0gcmVsYXkuYmFzZVVybCArIGAvX19mcm9udG1hbi90b29sc2A7XG4gIGxldCByZXNwb25zZSA9IGF3YWl0IGZldGNoKHVybCk7XG4gIGlmIChyZXNwb25zZS5vaykge1xuICAgIGxldCBqc29uID0gYXdhaXQgcmVzcG9uc2UuanNvbigpO1xuICAgIHRyeSB7XG4gICAgICBsZXQgZGF0YSA9IFMucGFyc2VPclRocm93KGpzb24sIEZyb250bWFuQ2xpZW50X19SZWxheV9fVHlwZXMkQXNrVGhlTGxtRnJvbnRtYW5DbGllbnQudG9vbHNSZXNwb25zZVNjaGVtYSk7XG4gICAgICByZWxheS5zdGF0ZSA9IHtcbiAgICAgICAgVEFHOiBcIkNvbm5lY3RlZFwiLFxuICAgICAgICB0b29sczogZGF0YS50b29scyxcbiAgICAgICAgc2VydmVySW5mbzogZGF0YS5zZXJ2ZXJJbmZvXG4gICAgICB9O1xuICAgICAgcmV0dXJuIHtcbiAgICAgICAgVEFHOiBcIk9rXCIsXG4gICAgICAgIF8wOiB1bmRlZmluZWRcbiAgICAgIH07XG4gICAgfSBjYXRjaCAocmF3X2UpIHtcbiAgICAgIGxldCBlID0gUHJpbWl0aXZlX2V4Y2VwdGlvbnMuaW50ZXJuYWxUb0V4Y2VwdGlvbihyYXdfZSk7XG4gICAgICBpZiAoZS5SRV9FWE5fSUQgPT09IFMuJCRFcnJvcikge1xuICAgICAgICBsZXQgbXNnID0gYEludmFsaWQgdG9vbHMgcmVzcG9uc2U6IGAgKyBlLl8xLm1lc3NhZ2U7XG4gICAgICAgIHJlbGF5LnN0YXRlID0ge1xuICAgICAgICAgIFRBRzogXCJFcnJvclwiLFxuICAgICAgICAgIF8wOiBtc2dcbiAgICAgICAgfTtcbiAgICAgICAgcmV0dXJuIHtcbiAgICAgICAgICBUQUc6IFwiRXJyb3JcIixcbiAgICAgICAgICBfMDogbXNnXG4gICAgICAgIH07XG4gICAgICB9XG4gICAgICB0aHJvdyBlO1xuICAgIH1cbiAgfSBlbHNlIHtcbiAgICBsZXQgbXNnJDEgPSBgSFRUUCBgICsgcmVzcG9uc2Uuc3RhdHVzLnRvU3RyaW5nKCkgKyBgOiBgICsgcmVzcG9uc2Uuc3RhdHVzVGV4dDtcbiAgICByZWxheS5zdGF0ZSA9IHtcbiAgICAgIFRBRzogXCJFcnJvclwiLFxuICAgICAgXzA6IG1zZyQxXG4gICAgfTtcbiAgICByZXR1cm4ge1xuICAgICAgVEFHOiBcIkVycm9yXCIsXG4gICAgICBfMDogbXNnJDFcbiAgICB9O1xuICB9XG59XG5cbmZ1bmN0aW9uIGRpc2Nvbm5lY3QocmVsYXkpIHtcbiAgcmVsYXkuc3RhdGUgPSBcIkRpc2Nvbm5lY3RlZFwiO1xufVxuXG5mdW5jdGlvbiBnZXRUb29sc0pzb24ocmVsYXkpIHtcbiAgbGV0IG1hdGNoID0gcmVsYXkuc3RhdGU7XG4gIGlmICh0eXBlb2YgbWF0Y2ggIT09IFwib2JqZWN0XCIpIHtcbiAgICByZXR1cm4gW107XG4gIH0gZWxzZSBpZiAobWF0Y2guVEFHID09PSBcIkNvbm5lY3RlZFwiKSB7XG4gICAgcmV0dXJuIG1hdGNoLnRvb2xzLm1hcCh0b29sID0+ICh7XG4gICAgICBuYW1lOiB0b29sLm5hbWUsXG4gICAgICBkZXNjcmlwdGlvbjogdG9vbC5kZXNjcmlwdGlvbixcbiAgICAgIGlucHV0U2NoZW1hOiB0b29sLmlucHV0U2NoZW1hXG4gICAgfSkpO1xuICB9IGVsc2Uge1xuICAgIHJldHVybiBbXTtcbiAgfVxufVxuXG5mdW5jdGlvbiBoYXNUb29sKHJlbGF5LCBuYW1lKSB7XG4gIGxldCBtYXRjaCA9IHJlbGF5LnN0YXRlO1xuICBpZiAodHlwZW9mIG1hdGNoICE9PSBcIm9iamVjdFwiIHx8IG1hdGNoLlRBRyAhPT0gXCJDb25uZWN0ZWRcIikge1xuICAgIHJldHVybiBmYWxzZTtcbiAgfSBlbHNlIHtcbiAgICByZXR1cm4gbWF0Y2gudG9vbHMuc29tZSh0b29sID0+IHRvb2wubmFtZSA9PT0gbmFtZSk7XG4gIH1cbn1cblxuYXN5bmMgZnVuY3Rpb24gZXhlY3V0ZVRvb2wocmVsYXksIG5hbWUsICQkYXJndW1lbnRzLCBvblByb2dyZXNzKSB7XG4gIGlmICghaXNDb25uZWN0ZWQocmVsYXkpKSB7XG4gICAgcmV0dXJuIHtcbiAgICAgIFRBRzogXCJFcnJvclwiLFxuICAgICAgXzA6IFwiUmVsYXkgbm90IGNvbm5lY3RlZFwiXG4gICAgfTtcbiAgfVxuICBsZXQgdXJsID0gcmVsYXkuYmFzZVVybCArIGAvX19mcm9udG1hbi90b29scy9jYWxsYDtcbiAgbGV0IHJlcXVlc3QgPSB7XG4gICAgbmFtZTogbmFtZSxcbiAgICBhcmd1bWVudHM6ICQkYXJndW1lbnRzXG4gIH07XG4gIGxldCBib2R5ID0gUy5yZXZlcnNlQ29udmVydFRvSnNvbk9yVGhyb3cocmVxdWVzdCwgRnJvbnRtYW5DbGllbnRfX1JlbGF5X19UeXBlcyRBc2tUaGVMbG1Gcm9udG1hbkNsaWVudC50b29sQ2FsbFJlcXVlc3RTY2hlbWEpO1xuICBsZXQgcmVzcG9uc2UgPSBhd2FpdCBmZXRjaCh1cmwsIHtcbiAgICBtZXRob2Q6IFwiUE9TVFwiLFxuICAgIGhlYWRlcnM6IHtcbiAgICAgIFwiQ29udGVudC1UeXBlXCI6IFwiYXBwbGljYXRpb24vanNvblwiLFxuICAgICAgQWNjZXB0OiBcInRleHQvZXZlbnQtc3RyZWFtXCJcbiAgICB9LFxuICAgIGJvZHk6IFByaW1pdGl2ZV9vcHRpb24uc29tZShKU09OLnN0cmluZ2lmeShib2R5KSlcbiAgfSk7XG4gIGlmICghcmVzcG9uc2Uub2spIHtcbiAgICByZXR1cm4ge1xuICAgICAgVEFHOiBcIkVycm9yXCIsXG4gICAgICBfMDogYEhUVFAgYCArIHJlc3BvbnNlLnN0YXR1cy50b1N0cmluZygpICsgYDogYCArIHJlc3BvbnNlLnN0YXR1c1RleHRcbiAgICB9O1xuICB9XG4gIGxldCBqc29uID0gYXdhaXQgRnJvbnRtYW5DbGllbnRfX1NTRSRBc2tUaGVMbG1Gcm9udG1hbkNsaWVudC5yZWFkU3RyZWFtKHJlc3BvbnNlLCBvblByb2dyZXNzKTtcbiAgaWYgKGpzb24uVEFHICE9PSBcIk9rXCIpIHtcbiAgICByZXR1cm4ge1xuICAgICAgVEFHOiBcIkVycm9yXCIsXG4gICAgICBfMDoganNvbi5fMFxuICAgIH07XG4gIH1cbiAgdHJ5IHtcbiAgICBsZXQgcmVzdWx0ID0gUy5wYXJzZU9yVGhyb3coanNvbi5fMCwgRnJvbnRtYW5DbGllbnRfX01DUF9fVHlwZXMkQXNrVGhlTGxtRnJvbnRtYW5DbGllbnQuY2FsbFRvb2xSZXN1bHRTY2hlbWEpO1xuICAgIHJldHVybiB7XG4gICAgICBUQUc6IFwiT2tcIixcbiAgICAgIF8wOiByZXN1bHRcbiAgICB9O1xuICB9IGNhdGNoIChyYXdfZSkge1xuICAgIGxldCBlID0gUHJpbWl0aXZlX2V4Y2VwdGlvbnMuaW50ZXJuYWxUb0V4Y2VwdGlvbihyYXdfZSk7XG4gICAgaWYgKGUuUkVfRVhOX0lEID09PSBTLiQkRXJyb3IpIHtcbiAgICAgIHJldHVybiB7XG4gICAgICAgIFRBRzogXCJFcnJvclwiLFxuICAgICAgICBfMDogYEludmFsaWQgcmVzdWx0OiBgICsgZS5fMS5tZXNzYWdlXG4gICAgICB9O1xuICAgIH1cbiAgICB0aHJvdyBlO1xuICB9XG59XG5cbmxldCBUeXBlcztcblxubGV0IE1DUFR5cGVzO1xuXG5sZXQgU1NFO1xuXG5leHBvcnQge1xuICBUeXBlcyxcbiAgTUNQVHlwZXMsXG4gIFNTRSxcbiAgbWFrZSxcbiAgaXNDb25uZWN0ZWQsXG4gIGdldFN0YXRlLFxuICBjb25uZWN0LFxuICBkaXNjb25uZWN0LFxuICBnZXRUb29sc0pzb24sXG4gIGhhc1Rvb2wsXG4gIGV4ZWN1dGVUb29sLFxufVxuLyogUyBOb3QgYSBwdXJlIG1vZHVsZSAqL1xuIiwgIlxuXG5pbXBvcnQgKiBhcyBQcmltaXRpdmVfb3B0aW9uIGZyb20gXCIuL1ByaW1pdGl2ZV9vcHRpb24uanNcIjtcblxuZnVuY3Rpb24gbWFrZShsZW5ndGgsIHgpIHtcbiAgaWYgKGxlbmd0aCA8PSAwKSB7XG4gICAgcmV0dXJuIFtdO1xuICB9XG4gIGxldCBhcnIgPSBuZXcgQXJyYXkobGVuZ3RoKTtcbiAgYXJyLmZpbGwoeCk7XG4gIHJldHVybiBhcnI7XG59XG5cbmZ1bmN0aW9uIGZyb21Jbml0aWFsaXplcihsZW5ndGgsIGYpIHtcbiAgaWYgKGxlbmd0aCA8PSAwKSB7XG4gICAgcmV0dXJuIFtdO1xuICB9XG4gIGxldCBhcnIgPSBuZXcgQXJyYXkobGVuZ3RoKTtcbiAgZm9yIChsZXQgaSA9IDA7IGkgPCBsZW5ndGg7ICsraSkge1xuICAgIGFycltpXSA9IGYoaSk7XG4gIH1cbiAgcmV0dXJuIGFycjtcbn1cblxuZnVuY3Rpb24gaXNFbXB0eShhcnIpIHtcbiAgcmV0dXJuIGFyci5sZW5ndGggPT09IDA7XG59XG5cbmZ1bmN0aW9uIGVxdWFsKGEsIGIsIGVxKSB7XG4gIGxldCBsZW4gPSBhLmxlbmd0aDtcbiAgaWYgKGxlbiA9PT0gYi5sZW5ndGgpIHtcbiAgICBsZXQgX2kgPSAwO1xuICAgIHdoaWxlICh0cnVlKSB7XG4gICAgICBsZXQgaSA9IF9pO1xuICAgICAgaWYgKGkgPT09IGxlbikge1xuICAgICAgICByZXR1cm4gdHJ1ZTtcbiAgICAgIH1cbiAgICAgIGlmICghZXEoYVtpXSwgYltpXSkpIHtcbiAgICAgICAgcmV0dXJuIGZhbHNlO1xuICAgICAgfVxuICAgICAgX2kgPSBpICsgMSB8IDA7XG4gICAgICBjb250aW51ZTtcbiAgICB9O1xuICB9IGVsc2Uge1xuICAgIHJldHVybiBmYWxzZTtcbiAgfVxufVxuXG5mdW5jdGlvbiBjb21wYXJlKGEsIGIsIGNtcCkge1xuICBsZXQgbGVuQSA9IGEubGVuZ3RoO1xuICBsZXQgbGVuQiA9IGIubGVuZ3RoO1xuICBpZiAobGVuQSA8IGxlbkIpIHtcbiAgICByZXR1cm4gLTE7XG4gIH0gZWxzZSBpZiAobGVuQSA+IGxlbkIpIHtcbiAgICByZXR1cm4gMTtcbiAgfSBlbHNlIHtcbiAgICBsZXQgX2kgPSAwO1xuICAgIHdoaWxlICh0cnVlKSB7XG4gICAgICBsZXQgaSA9IF9pO1xuICAgICAgaWYgKGkgPT09IGxlbkEpIHtcbiAgICAgICAgcmV0dXJuIDA7XG4gICAgICB9XG4gICAgICBsZXQgYyA9IGNtcChhW2ldLCBiW2ldKTtcbiAgICAgIGlmIChjICE9PSAwKSB7XG4gICAgICAgIHJldHVybiBjO1xuICAgICAgfVxuICAgICAgX2kgPSBpICsgMSB8IDA7XG4gICAgICBjb250aW51ZTtcbiAgICB9O1xuICB9XG59XG5cbmZ1bmN0aW9uIGluZGV4T2ZPcHQoYXJyLCBpdGVtKSB7XG4gIGxldCBpbmRleCA9IGFyci5pbmRleE9mKGl0ZW0pO1xuICBpZiAoaW5kZXggIT09IC0xKSB7XG4gICAgcmV0dXJuIGluZGV4O1xuICB9XG59XG5cbmZ1bmN0aW9uIGxhc3RJbmRleE9mT3B0KGFyciwgaXRlbSkge1xuICBsZXQgaW5kZXggPSBhcnIubGFzdEluZGV4T2YoaXRlbSk7XG4gIGlmIChpbmRleCAhPT0gLTEpIHtcbiAgICByZXR1cm4gaW5kZXg7XG4gIH1cbn1cblxuZnVuY3Rpb24gcmVkdWNlKGFyciwgaW5pdCwgZikge1xuICByZXR1cm4gYXJyLnJlZHVjZShmLCBpbml0KTtcbn1cblxuZnVuY3Rpb24gcmVkdWNlV2l0aEluZGV4KGFyciwgaW5pdCwgZikge1xuICByZXR1cm4gYXJyLnJlZHVjZShmLCBpbml0KTtcbn1cblxuZnVuY3Rpb24gcmVkdWNlUmlnaHQoYXJyLCBpbml0LCBmKSB7XG4gIHJldHVybiBhcnIucmVkdWNlUmlnaHQoZiwgaW5pdCk7XG59XG5cbmZ1bmN0aW9uIHJlZHVjZVJpZ2h0V2l0aEluZGV4KGFyciwgaW5pdCwgZikge1xuICByZXR1cm4gYXJyLnJlZHVjZVJpZ2h0KGYsIGluaXQpO1xufVxuXG5mdW5jdGlvbiBmaW5kSW5kZXhPcHQoYXJyYXksIGZpbmRlcikge1xuICBsZXQgaW5kZXggPSBhcnJheS5maW5kSW5kZXgoZmluZGVyKTtcbiAgaWYgKGluZGV4ICE9PSAtMSkge1xuICAgIHJldHVybiBpbmRleDtcbiAgfVxufVxuXG5mdW5jdGlvbiBmaW5kTGFzdEluZGV4T3B0KGFycmF5LCBmaW5kZXIpIHtcbiAgbGV0IGluZGV4ID0gYXJyYXkuZmluZExhc3RJbmRleChmaW5kZXIpO1xuICBpZiAoaW5kZXggIT09IC0xKSB7XG4gICAgcmV0dXJuIGluZGV4O1xuICB9XG59XG5cbmZ1bmN0aW9uIHN3YXBVbnNhZmUoeHMsIGksIGopIHtcbiAgbGV0IHRtcCA9IHhzW2ldO1xuICB4c1tpXSA9IHhzW2pdO1xuICB4c1tqXSA9IHRtcDtcbn1cblxuZnVuY3Rpb24gcmFuZG9tX2ludChtaW4sIG1heCkge1xuICByZXR1cm4gKE1hdGguZmxvb3IoTWF0aC5yYW5kb20oKSAqIChtYXggLSBtaW4gfCAwKSkgfCAwKSArIG1pbiB8IDA7XG59XG5cbmZ1bmN0aW9uIHNodWZmbGUoeHMpIHtcbiAgbGV0IGxlbiA9IHhzLmxlbmd0aDtcbiAgZm9yIChsZXQgaSA9IDA7IGkgPCBsZW47ICsraSkge1xuICAgIHN3YXBVbnNhZmUoeHMsIGksIHJhbmRvbV9pbnQoaSwgbGVuKSk7XG4gIH1cbn1cblxuZnVuY3Rpb24gdG9TaHVmZmxlZCh4cykge1xuICBsZXQgcmVzdWx0ID0geHMuc2xpY2UoKTtcbiAgc2h1ZmZsZShyZXN1bHQpO1xuICByZXR1cm4gcmVzdWx0O1xufVxuXG5mdW5jdGlvbiBmaWx0ZXJNYXAoYSwgZikge1xuICBsZXQgbCA9IGEubGVuZ3RoO1xuICBsZXQgciA9IG5ldyBBcnJheShsKTtcbiAgbGV0IGogPSAwO1xuICBmb3IgKGxldCBpID0gMDsgaSA8IGw7ICsraSkge1xuICAgIGxldCB2ID0gYVtpXTtcbiAgICBsZXQgdiQxID0gZih2KTtcbiAgICBpZiAodiQxICE9PSB1bmRlZmluZWQpIHtcbiAgICAgIHJbal0gPSBQcmltaXRpdmVfb3B0aW9uLnZhbEZyb21PcHRpb24odiQxKTtcbiAgICAgIGogPSBqICsgMSB8IDA7XG4gICAgfVxuICB9XG4gIHIubGVuZ3RoID0gajtcbiAgcmV0dXJuIHI7XG59XG5cbmZ1bmN0aW9uIGtlZXBTb21lKF9feCkge1xuICByZXR1cm4gZmlsdGVyTWFwKF9feCwgeCA9PiB4KTtcbn1cblxuZnVuY3Rpb24gZmlsdGVyTWFwV2l0aEluZGV4KGEsIGYpIHtcbiAgbGV0IGwgPSBhLmxlbmd0aDtcbiAgbGV0IHIgPSBuZXcgQXJyYXkobCk7XG4gIGxldCBqID0gMDtcbiAgZm9yIChsZXQgaSA9IDA7IGkgPCBsOyArK2kpIHtcbiAgICBsZXQgdiA9IGFbaV07XG4gICAgbGV0IHYkMSA9IGYodiwgaSk7XG4gICAgaWYgKHYkMSAhPT0gdW5kZWZpbmVkKSB7XG4gICAgICByW2pdID0gUHJpbWl0aXZlX29wdGlvbi52YWxGcm9tT3B0aW9uKHYkMSk7XG4gICAgICBqID0gaiArIDEgfCAwO1xuICAgIH1cbiAgfVxuICByLmxlbmd0aCA9IGo7XG4gIHJldHVybiByO1xufVxuXG5mdW5jdGlvbiBmaW5kTWFwKGFyciwgZikge1xuICBsZXQgX2kgPSAwO1xuICB3aGlsZSAodHJ1ZSkge1xuICAgIGxldCBpID0gX2k7XG4gICAgaWYgKGkgPT09IGFyci5sZW5ndGgpIHtcbiAgICAgIHJldHVybjtcbiAgICB9XG4gICAgbGV0IHIgPSBmKGFycltpXSk7XG4gICAgaWYgKHIgIT09IHVuZGVmaW5lZCkge1xuICAgICAgcmV0dXJuIHI7XG4gICAgfVxuICAgIF9pID0gaSArIDEgfCAwO1xuICAgIGNvbnRpbnVlO1xuICB9O1xufVxuXG5mdW5jdGlvbiBsYXN0KGEpIHtcbiAgcmV0dXJuIGFbYS5sZW5ndGggLSAxIHwgMF07XG59XG5cbmV4cG9ydCB7XG4gIG1ha2UsXG4gIGZyb21Jbml0aWFsaXplcixcbiAgZXF1YWwsXG4gIGNvbXBhcmUsXG4gIGlzRW1wdHksXG4gIGluZGV4T2ZPcHQsXG4gIGxhc3RJbmRleE9mT3B0LFxuICByZWR1Y2UsXG4gIHJlZHVjZVdpdGhJbmRleCxcbiAgcmVkdWNlUmlnaHQsXG4gIHJlZHVjZVJpZ2h0V2l0aEluZGV4LFxuICBmaW5kSW5kZXhPcHQsXG4gIGZpbmRMYXN0SW5kZXhPcHQsXG4gIGZpbHRlck1hcCxcbiAgZmlsdGVyTWFwV2l0aEluZGV4LFxuICBrZWVwU29tZSxcbiAgdG9TaHVmZmxlZCxcbiAgc2h1ZmZsZSxcbiAgZmluZE1hcCxcbiAgbGFzdCxcbn1cbi8qIE5vIHNpZGUgZWZmZWN0ICovXG4iLCAiXG5cbmltcG9ydCAqIGFzIFByaW1pdGl2ZV9vcHRpb24gZnJvbSBcIi4vUHJpbWl0aXZlX29wdGlvbi5qc1wiO1xuXG5mdW5jdGlvbiBmcm9tRXhjZXB0aW9uKGV4bikge1xuICBpZiAoZXhuLlJFX0VYTl9JRCA9PT0gXCJKc0V4blwiKSB7XG4gICAgcmV0dXJuIFByaW1pdGl2ZV9vcHRpb24uc29tZShleG4uXzEpO1xuICB9XG59XG5cbmxldCBnZXRPclVuZGVmaW5lZCA9IChmaWVsZE5hbWUgPT4gdCA9PiAodCAmJiB0eXBlb2YgdFtmaWVsZE5hbWVdID09PSBcInN0cmluZ1wiID8gdFtmaWVsZE5hbWVdIDogdW5kZWZpbmVkKSk7XG5cbmxldCBzdGFjayA9IGdldE9yVW5kZWZpbmVkKFwic3RhY2tcIik7XG5cbmxldCBtZXNzYWdlID0gZ2V0T3JVbmRlZmluZWQoXCJtZXNzYWdlXCIpO1xuXG5sZXQgbmFtZSA9IGdldE9yVW5kZWZpbmVkKFwibmFtZVwiKTtcblxubGV0IGZpbGVOYW1lID0gZ2V0T3JVbmRlZmluZWQoXCJmaWxlTmFtZVwiKTtcblxuZXhwb3J0IHtcbiAgZnJvbUV4Y2VwdGlvbixcbiAgc3RhY2ssXG4gIG1lc3NhZ2UsXG4gIG5hbWUsXG4gIGZpbGVOYW1lLFxufVxuLyogc3RhY2sgTm90IGEgcHVyZSBtb2R1bGUgKi9cbiIsICIvLyBHZW5lcmF0ZWQgYnkgUmVTY3JpcHQsIFBMRUFTRSBFRElUIFdJVEggQ0FSRVxuXG5pbXBvcnQgKiBhcyBTdGRsaWJfQXJyYXkgZnJvbSBcIkByZXNjcmlwdC9ydW50aW1lL2xpYi9lczYvU3RkbGliX0FycmF5LmpzXCI7XG5pbXBvcnQgKiBhcyBTdGRsaWJfSnNFeG4gZnJvbSBcIkByZXNjcmlwdC9ydW50aW1lL2xpYi9lczYvU3RkbGliX0pzRXhuLmpzXCI7XG5pbXBvcnQgKiBhcyBTdGRsaWJfT3B0aW9uIGZyb20gXCJAcmVzY3JpcHQvcnVudGltZS9saWIvZXM2L1N0ZGxpYl9PcHRpb24uanNcIjtcbmltcG9ydCAqIGFzIFByaW1pdGl2ZV9vcHRpb24gZnJvbSBcIkByZXNjcmlwdC9ydW50aW1lL2xpYi9lczYvUHJpbWl0aXZlX29wdGlvbi5qc1wiO1xuaW1wb3J0ICogYXMgUHJpbWl0aXZlX2V4Y2VwdGlvbnMgZnJvbSBcIkByZXNjcmlwdC9ydW50aW1lL2xpYi9lczYvUHJpbWl0aXZlX2V4Y2VwdGlvbnMuanNcIjtcblxuZnVuY3Rpb24gcGFyc2VFdmVudFR5cGUocykge1xuICBzd2l0Y2ggKHMpIHtcbiAgICBjYXNlIFwiZXJyb3JcIiA6XG4gICAgICByZXR1cm4gXCJlcnJvclwiO1xuICAgIGNhc2UgXCJwcm9ncmVzc1wiIDpcbiAgICAgIHJldHVybiBcInByb2dyZXNzXCI7XG4gICAgY2FzZSBcInJlc3VsdFwiIDpcbiAgICAgIHJldHVybiBcInJlc3VsdFwiO1xuICAgIGRlZmF1bHQ6XG4gICAgICByZXR1cm4gXCJ1bmtub3duXCI7XG4gIH1cbn1cblxuZnVuY3Rpb24gcGFyc2VFdmVudEJsb2NrKGJsb2NrKSB7XG4gIGxldCBsaW5lcyA9IGJsb2NrLnNwbGl0KFwiXFxuXCIpO1xuICBsZXQgZXZlbnRUeXBlU3RyID0gU3RkbGliX09wdGlvbi5nZXRPcihTdGRsaWJfT3B0aW9uLm1hcChsaW5lcy5maW5kKGxpbmUgPT4gbGluZS5zdGFydHNXaXRoKFwiZXZlbnQ6XCIpKSwgbGluZSA9PiBsaW5lLnNsaWNlKDYsIGxpbmUubGVuZ3RoKS50cmltKCkpLCBcIlwiKTtcbiAgbGV0IGRhdGEgPSBsaW5lcy5maWx0ZXIobGluZSA9PiBsaW5lLnN0YXJ0c1dpdGgoXCJkYXRhOlwiKSkubWFwKGxpbmUgPT4gbGluZS5zbGljZSg1LCBsaW5lLmxlbmd0aCkudHJpbSgpKS5qb2luKFwiXFxuXCIpO1xuICBpZiAoZGF0YSA9PT0gXCJcIikge1xuICAgIHJldHVybjtcbiAgfSBlbHNlIHtcbiAgICByZXR1cm4ge1xuICAgICAgZXZlbnRUeXBlOiBwYXJzZUV2ZW50VHlwZShldmVudFR5cGVTdHIpLFxuICAgICAgZGF0YTogZGF0YVxuICAgIH07XG4gIH1cbn1cblxuZnVuY3Rpb24gcHJvY2Vzc0V2ZW50KGV2ZW50LCBvblByb2dyZXNzKSB7XG4gIGxldCBtYXRjaCA9IGV2ZW50LmV2ZW50VHlwZTtcbiAgaWYgKG1hdGNoID09PSBcImVycm9yXCIpIHtcbiAgICByZXR1cm4ge1xuICAgICAgVEFHOiBcIkVycm9yXCIsXG4gICAgICBfMDogZXZlbnQuZGF0YVxuICAgIH07XG4gIH1cbiAgaWYgKG1hdGNoID09PSBcInByb2dyZXNzXCIpIHtcbiAgICBTdGRsaWJfT3B0aW9uLmZvckVhY2gob25Qcm9ncmVzcywgY2IgPT4gY2IoZXZlbnQuZGF0YSkpO1xuICAgIHJldHVybjtcbiAgfVxuICBpZiAobWF0Y2ggIT09IFwicmVzdWx0XCIpIHtcbiAgICByZXR1cm47XG4gIH1cbiAgbGV0IHRtcDtcbiAgdHJ5IHtcbiAgICB0bXAgPSB7XG4gICAgICBUQUc6IFwiT2tcIixcbiAgICAgIF8wOiBKU09OLnBhcnNlKGV2ZW50LmRhdGEpXG4gICAgfTtcbiAgfSBjYXRjaCAocmF3X2V4bikge1xuICAgIGxldCBleG4gPSBQcmltaXRpdmVfZXhjZXB0aW9ucy5pbnRlcm5hbFRvRXhjZXB0aW9uKHJhd19leG4pO1xuICAgIGxldCBtc2cgPSBTdGRsaWJfT3B0aW9uLmdldE9yKFN0ZGxpYl9PcHRpb24uZmxhdE1hcChTdGRsaWJfSnNFeG4uZnJvbUV4Y2VwdGlvbihleG4pLCBTdGRsaWJfSnNFeG4ubWVzc2FnZSksIFwidW5rbm93blwiKTtcbiAgICB0bXAgPSB7XG4gICAgICBUQUc6IFwiRXJyb3JcIixcbiAgICAgIF8wOiBgRmFpbGVkIHRvIHBhcnNlIHJlc3VsdCBKU09OOiBgICsgbXNnXG4gICAgfTtcbiAgfVxuICByZXR1cm4gdG1wO1xufVxuXG5mdW5jdGlvbiBleG5NZXNzYWdlKGV4bikge1xuICByZXR1cm4gU3RkbGliX09wdGlvbi5nZXRPcihTdGRsaWJfT3B0aW9uLmZsYXRNYXAoU3RkbGliX0pzRXhuLmZyb21FeGNlcHRpb24oZXhuKSwgU3RkbGliX0pzRXhuLm1lc3NhZ2UpLCBcInVua25vd25cIik7XG59XG5cbmZ1bmN0aW9uIHByb2Nlc3NCbG9ja3MoYmxvY2tzLCBvblByb2dyZXNzKSB7XG4gIHJldHVybiBTdGRsaWJfQXJyYXkucmVkdWNlV2l0aEluZGV4KGJsb2NrcywgdW5kZWZpbmVkLCAoYWNjLCBibG9jaywgX2kpID0+IHtcbiAgICBpZiAoYWNjICE9PSB1bmRlZmluZWQpIHtcbiAgICAgIHJldHVybiBhY2M7XG4gICAgfVxuICAgIGxldCBldmVudCA9IHBhcnNlRXZlbnRCbG9jayhibG9jayk7XG4gICAgaWYgKGV2ZW50ICE9PSB1bmRlZmluZWQpIHtcbiAgICAgIHJldHVybiBwcm9jZXNzRXZlbnQoZXZlbnQsIG9uUHJvZ3Jlc3MpO1xuICAgIH1cbiAgfSk7XG59XG5cbmFzeW5jIGZ1bmN0aW9uIHJlYWRTdHJlYW0ocmVzcG9uc2UsIG9uUHJvZ3Jlc3MpIHtcbiAgbGV0IGJvZHkgPSByZXNwb25zZS5ib2R5O1xuICBpZiAoYm9keSA9PT0gbnVsbCkge1xuICAgIHJldHVybiB7XG4gICAgICBUQUc6IFwiRXJyb3JcIixcbiAgICAgIF8wOiBcIk5vIHJlc3BvbnNlIGJvZHlcIlxuICAgIH07XG4gIH1cbiAgbGV0IHJlYWRlciA9IGJvZHkuZ2V0UmVhZGVyKCk7XG4gIGxldCBkZWNvZGVyID0gbmV3IFRleHREZWNvZGVyKCk7XG4gIGxldCBpbmNvbXBsZXRlQ2h1bmsgPSB7XG4gICAgY29udGVudHM6IFwiXCJcbiAgfTtcbiAgbGV0IHJlc3VsdCA9IHtcbiAgICBjb250ZW50czogdW5kZWZpbmVkXG4gIH07XG4gIHRyeSB7XG4gICAgd2hpbGUgKFN0ZGxpYl9PcHRpb24uaXNOb25lKHJlc3VsdC5jb250ZW50cykpIHtcbiAgICAgIGxldCBjaHVuayA9IGF3YWl0IHJlYWRlci5yZWFkKCk7XG4gICAgICBpZiAoY2h1bmsuZG9uZSkge1xuICAgICAgICByZXN1bHQuY29udGVudHMgPSB7XG4gICAgICAgICAgVEFHOiBcIkVycm9yXCIsXG4gICAgICAgICAgXzA6IFwiU3RyZWFtIGVuZGVkIHdpdGhvdXQgcmVzdWx0XCJcbiAgICAgICAgfTtcbiAgICAgIH0gZWxzZSB7XG4gICAgICAgIFN0ZGxpYl9PcHRpb24uZ2V0T3IoU3RkbGliX09wdGlvbi5tYXAoUHJpbWl0aXZlX29wdGlvbi5mcm9tTnVsbGFibGUoY2h1bmsudmFsdWUpLCBieXRlcyA9PiB7XG4gICAgICAgICAgbGV0IHRleHQgPSBkZWNvZGVyLmRlY29kZShieXRlcywge1xuICAgICAgICAgICAgc3RyZWFtOiB0cnVlXG4gICAgICAgICAgfSk7XG4gICAgICAgICAgbGV0IGZ1bGxUZXh0ID0gaW5jb21wbGV0ZUNodW5rLmNvbnRlbnRzICsgdGV4dDtcbiAgICAgICAgICBsZXQgcGFydHMgPSBmdWxsVGV4dC5zcGxpdChcIlxcblxcblwiKTtcbiAgICAgICAgICBsZXQgcGFydHNDb3VudCA9IHBhcnRzLmxlbmd0aDtcbiAgICAgICAgICBpbmNvbXBsZXRlQ2h1bmsuY29udGVudHMgPSBwYXJ0c1twYXJ0c0NvdW50IC0gMSB8IDBdO1xuICAgICAgICAgIGxldCBjb21wbGV0ZUJsb2NrcyA9IHBhcnRzLnNsaWNlKDAsIHBhcnRzQ291bnQgLSAxIHwgMCk7XG4gICAgICAgICAgcmVzdWx0LmNvbnRlbnRzID0gcHJvY2Vzc0Jsb2Nrcyhjb21wbGV0ZUJsb2Nrcywgb25Qcm9ncmVzcyk7XG4gICAgICAgIH0pLCB1bmRlZmluZWQpO1xuICAgICAgfVxuICAgIH07XG4gICAgcmV0dXJuIFN0ZGxpYl9PcHRpb24uZ2V0T3IocmVzdWx0LmNvbnRlbnRzLCB7XG4gICAgICBUQUc6IFwiRXJyb3JcIixcbiAgICAgIF8wOiBcIlN0cmVhbSBlbmRlZCB3aXRob3V0IHJlc3VsdFwiXG4gICAgfSk7XG4gIH0gY2F0Y2ggKHJhd19leG4pIHtcbiAgICBsZXQgZXhuID0gUHJpbWl0aXZlX2V4Y2VwdGlvbnMuaW50ZXJuYWxUb0V4Y2VwdGlvbihyYXdfZXhuKTtcbiAgICByZXR1cm4ge1xuICAgICAgVEFHOiBcIkVycm9yXCIsXG4gICAgICBfMDogYFN0cmVhbSByZWFkIGVycm9yOiBgICsgZXhuTWVzc2FnZShleG4pXG4gICAgfTtcbiAgfVxufVxuXG5sZXQgV2ViU3RyZWFtcztcblxuZXhwb3J0IHtcbiAgV2ViU3RyZWFtcyxcbiAgcGFyc2VFdmVudFR5cGUsXG4gIHBhcnNlRXZlbnRCbG9jayxcbiAgcHJvY2Vzc0V2ZW50LFxuICBleG5NZXNzYWdlLFxuICBwcm9jZXNzQmxvY2tzLFxuICByZWFkU3RyZWFtLFxufVxuLyogU3RkbGliX0pzRXhuIE5vdCBhIHB1cmUgbW9kdWxlICovXG4iLCAiLy8gR2VuZXJhdGVkIGJ5IFJlU2NyaXB0LCBQTEVBU0UgRURJVCBXSVRIIENBUkVcblxuaW1wb3J0ICogYXMgUyBmcm9tIFwic3VyeS9zcmMvUy5yZXMubWpzXCI7XG5pbXBvcnQgKiBhcyBGcm9udG1hblByb3RvY29sX19NQ1AkQXNrVGhlTGxtRnJvbnRtYW5Qcm90b2NvbCBmcm9tIFwiLi9Gcm9udG1hblByb3RvY29sX19NQ1AucmVzLm1qc1wiO1xuXG5sZXQgcmVtb3RlVG9vbFNjaGVtYSA9IFMuc2NoZW1hKHMgPT4gKHtcbiAgbmFtZTogcy5tKFMuc3RyaW5nKSxcbiAgZGVzY3JpcHRpb246IHMubShTLnN0cmluZyksXG4gIGlucHV0U2NoZW1hOiBzLm0oUy5qc29uKVxufSkpO1xuXG5sZXQgdG9vbHNSZXNwb25zZVNjaGVtYSA9IFMuc2NoZW1hKHMgPT4gKHtcbiAgdG9vbHM6IHMubShTLmFycmF5KHJlbW90ZVRvb2xTY2hlbWEpKSxcbiAgc2VydmVySW5mbzogcy5tKEZyb250bWFuUHJvdG9jb2xfX01DUCRBc2tUaGVMbG1Gcm9udG1hblByb3RvY29sLmluZm9TY2hlbWEpXG59KSk7XG5cbmxldCB0b29sQ2FsbFJlcXVlc3RTY2hlbWEgPSBTLnNjaGVtYShzID0+ICh7XG4gIG5hbWU6IHMubShTLnN0cmluZyksXG4gIGFyZ3VtZW50czogcy5tKFMub3B0aW9uKFMuZGljdChTLmpzb24pKSlcbn0pKTtcblxubGV0IE1DUDtcblxuZXhwb3J0IHtcbiAgTUNQLFxuICByZW1vdGVUb29sU2NoZW1hLFxuICB0b29sc1Jlc3BvbnNlU2NoZW1hLFxuICB0b29sQ2FsbFJlcXVlc3RTY2hlbWEsXG59XG4vKiByZW1vdGVUb29sU2NoZW1hIE5vdCBhIHB1cmUgbW9kdWxlICovXG4iLCAiLy8gR2VuZXJhdGVkIGJ5IFJlU2NyaXB0LCBQTEVBU0UgRURJVCBXSVRIIENBUkVcblxuaW1wb3J0ICogYXMgRnJvbnRtYW5Qcm90b2NvbF9fUmVsYXkkQXNrVGhlTGxtRnJvbnRtYW5Qcm90b2NvbCBmcm9tIFwiQGFzay10aGUtbGxtL2Zyb250bWFuLXByb3RvY29sL3NyYy9Gcm9udG1hblByb3RvY29sX19SZWxheS5yZXMubWpzXCI7XG5cbmxldCBNQ1AgPSBGcm9udG1hblByb3RvY29sX19SZWxheSRBc2tUaGVMbG1Gcm9udG1hblByb3RvY29sLk1DUDtcblxubGV0IHJlbW90ZVRvb2xTY2hlbWEgPSBGcm9udG1hblByb3RvY29sX19SZWxheSRBc2tUaGVMbG1Gcm9udG1hblByb3RvY29sLnJlbW90ZVRvb2xTY2hlbWE7XG5cbmxldCB0b29sc1Jlc3BvbnNlU2NoZW1hID0gRnJvbnRtYW5Qcm90b2NvbF9fUmVsYXkkQXNrVGhlTGxtRnJvbnRtYW5Qcm90b2NvbC50b29sc1Jlc3BvbnNlU2NoZW1hO1xuXG5sZXQgdG9vbENhbGxSZXF1ZXN0U2NoZW1hID0gRnJvbnRtYW5Qcm90b2NvbF9fUmVsYXkkQXNrVGhlTGxtRnJvbnRtYW5Qcm90b2NvbC50b29sQ2FsbFJlcXVlc3RTY2hlbWE7XG5cbmV4cG9ydCB7XG4gIE1DUCxcbiAgcmVtb3RlVG9vbFNjaGVtYSxcbiAgdG9vbHNSZXNwb25zZVNjaGVtYSxcbiAgdG9vbENhbGxSZXF1ZXN0U2NoZW1hLFxufVxuLyogRnJvbnRtYW5Qcm90b2NvbF9fUmVsYXktQXNrVGhlTGxtRnJvbnRtYW5Qcm90b2NvbCBOb3QgYSBwdXJlIG1vZHVsZSAqL1xuIiwgIi8vIEdlbmVyYXRlZCBieSBSZVNjcmlwdCwgUExFQVNFIEVESVQgV0lUSCBDQVJFXG5cbmltcG9ydCAqIGFzIFMgZnJvbSBcInN1cnkvc3JjL1MucmVzLm1qc1wiO1xuXG5sZXQgaW5wdXRTY2hlbWEgPSBTLnNjaGVtYShzID0+ICh7XG4gIG1lc3NhZ2U6IHMubShTLnN0cmluZylcbn0pKTtcblxubGV0IG91dHB1dFNjaGVtYSA9IFMuc2NoZW1hKHMgPT4gKHtcbiAgbG9nZ2VkOiBzLm0oUy5ib29sKVxufSkpO1xuXG5hc3luYyBmdW5jdGlvbiBleGVjdXRlKGlucHV0KSB7XG4gIGNvbnNvbGUubG9nKGBbTUNQIFRvb2xdIGAgKyBpbnB1dC5tZXNzYWdlKTtcbiAgcmV0dXJuIHtcbiAgICBUQUc6IFwiT2tcIixcbiAgICBfMDoge1xuICAgICAgbG9nZ2VkOiB0cnVlXG4gICAgfVxuICB9O1xufVxuXG5sZXQgbmFtZSA9IFwiY29uc29sZV9sb2dcIjtcblxubGV0IGRlc2NyaXB0aW9uID0gXCJMb2dzIGEgbWVzc2FnZSB0byB0aGUgYnJvd3NlciBjb25zb2xlXCI7XG5cbmV4cG9ydCB7XG4gIG5hbWUsXG4gIGRlc2NyaXB0aW9uLFxuICBpbnB1dFNjaGVtYSxcbiAgb3V0cHV0U2NoZW1hLFxuICBleGVjdXRlLFxufVxuLyogaW5wdXRTY2hlbWEgTm90IGEgcHVyZSBtb2R1bGUgKi9cbiJdLAogICJtYXBwaW5ncyI6ICI7Ozs7Ozs7QUFBQTtBQUFBO0FBQUEsaUJBQUFBO0FBQUEsRUFBQTtBQUFBO0FBQUEsZ0JBQUFDO0FBQUEsRUFBQTtBQUFBO0FBQUE7QUFBQTtBQUFBLHVCQUFBQztBQUFBLEVBQUE7QUFBQTtBQUFBO0FBQUE7QUFBQTtBQUFBO0FBQUE7OztBQ0NPLElBQUksVUFBVSxDQUFDLFVBQVU7QUFDOUIsTUFBRyxPQUFPLFVBQVUsWUFBVztBQUM3QixXQUFPO0VBQ1QsT0FBTztBQUNMLFFBQUlDLFdBQVUsV0FBVztBQUFFLGFBQU87SUFBTTtBQUN4QyxXQUFPQTtFQUNUO0FBQ0Y7QUNSTyxJQUFNLGFBQWEsT0FBTyxTQUFTLGNBQWMsT0FBTztBQUN4RCxJQUFNLFlBQVksT0FBTyxXQUFXLGNBQWMsU0FBUztBQUMzRCxJQUFNLFNBQVMsY0FBYyxhQUFhO0FBQzFDLElBQU0sY0FBYztBQUNwQixJQUFNLGdCQUFnQixFQUFDLFlBQVksR0FBRyxNQUFNLEdBQUcsU0FBUyxHQUFHLFFBQVEsRUFBQztBQUNwRSxJQUFNLGtCQUFrQjtBQUN4QixJQUFNLGtCQUFrQjtBQUN4QixJQUFNLGlCQUFpQjtFQUM1QixRQUFRO0VBQ1IsU0FBUztFQUNULFFBQVE7RUFDUixTQUFTO0VBQ1QsU0FBUztBQUNYO0FBQ08sSUFBTSxpQkFBaUI7RUFDNUIsT0FBTztFQUNQLE9BQU87RUFDUCxNQUFNO0VBQ04sT0FBTztFQUNQLE9BQU87QUFDVDtBQUVPLElBQU0sYUFBYTtFQUN4QixVQUFVO0VBQ1YsV0FBVztBQUNiO0FBQ08sSUFBTSxhQUFhO0VBQ3hCLFVBQVU7QUFDWjtBQUNPLElBQU0sb0JBQW9CO0FDdEJqQyxJQUFxQixPQUFyQixNQUEwQjtFQUN4QixZQUFZLFNBQVMsT0FBTyxTQUFTLFNBQVE7QUFDM0MsU0FBSyxVQUFVO0FBQ2YsU0FBSyxRQUFR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UTtBQUFBLElBQ1Y7QUFBQSxFQUNGO0FBQ0Y7QUFFQSxJQUFJQyxRQUFPO0FBRVgsSUFBSSxjQUFjOyIsCiAgIm5hbWVzIjogWyJDaGFubmVsIiwgIlNvY2tldCIsICJpc0luaXRpYWxpemVkIiwgImNsb3N1cmUiLCAicGFyYW1zIiwgInJlYXNvbiIsICJtZXRob2QiLCAiZGF0YSIsICJ1cmwiLCAiY29kZSIsICJtZXNzYWdlIiwgImRhdGEiLCAiY29kZSIsICJyZWFzb24iLCAicGFyYW1zIiwgImVycm9yIiwgInZhbCIsICJyZXN1bHQiLCAibWFwIiwgImlkIiwgInN0cmluZyIsICJkIiwgInRvQXJyYXkiLCAic2NoZW1hIiwgInVua25vd24iLCAic3RyaW5nIiwgIm5hbWUiLCAibG9jYXRpb24iLCAiY29kZSIsICJlcnJvciIsICJsb2NhdGlvbiIsICJtZXNzYWdlIiwgInNjaGVtYSIsICJzY2hlbWEiLCAibG9jYXRpb24iLCAiZ2xvYmFsIiwgInZhbCIsICJzY2hlbWEkMSIsICJtYXAiLCAiY29kZSIsICJhcmciLCAiZGVzY3JpcHRpb24iLCAiYiIsICJlcnJvclZhciIsICJpc0FzeW5jIiwgImVycm9yIiwgInNjaGVtYSIsICJsZW5ndGgiLCAiY29kZSIsICJsb2NhdGlvbiIsICJtdXQiLCAiaW5wdXQiLCAiaGFzIiwgIm1hcCIsICJjb21waWxlciIsICJ0byIsICJwYXJzZXIiLCAic2NoZW1hJDEiLCAicyIsICJwIiwgInRvQXJyYXkiLCAic2NoZW1hIiwgInNjaGVtYSIsICJzY2hlbWEiLCAiaW5wdXQiLCAic2NoZW1hIiwgImlucHV0U2NoZW1hIiwgImNhdWdodCIsICJzY2hlbWEkMSIsICJzY2hlbWEkMiIsICJjb2RlIiwgImlucHV0VmFyIiwgInRvIiwgImhhcyIsICJtYXRjaCIsICJtYXRjaCQxIiwgIm11dCIsICJwcm9wZXJ0aWVzIiwgIm91dHB1dFNjaGVtYSIsICJtZXNzYWdlIiwgInMiLCAiYiIsICJjb21waWxlciIsICJzY2hlbWEiLCAiYiIsICJpbnB1dCIsICJwYXRoIiwgImIiLCAiaW5wdXQiLCAicGF0aCIsICJzY2hlbWEiLCAic2NoZW1hIiwgIm91dHB1dFNjaGVtYSIsICJpdGVtIiwgIm1lc3NhZ2UiLCAibG9jYXRpb24iLCAic2NoZW1hIiwgImxlbmd0aCIsICJzY2hlbWEkMSIsICJjdHgiLCAiZmllbGROYW1lIiwgInRvIiwgInJlc3VsdCIsICJyaXRlbSIsICJ0b0FycmF5IiwgIml0ZW1zIiwgImlzQXJyYXkiLCAib2JqZWN0VmFsIiwgInNjaGVtYSIsICJsb2NhdGlvbiIsICJzY2hlbWEkMSIsICJtZXNzYWdlIiwgImN0eCIsICJzY2hlbWEiLCAic2NoZW1hIiwgInJlZmluZW1lbnQiLCAibGVuZ3RoIiwgIiQkRXJyb3IiLCAic3RyaW5nIiwgImJvb2wiLCAiaW50IiwgImpzb24iLCAiZW5hYmxlSnNvbiIsICJsaXRlcmFsIiwgImFycmF5IiwgImRpY3QiLCAib3B0aW9uIiwgInVuaW9uIiwgInBhcnNlT3JUaHJvdyIsICJyZXZlcnNlQ29udmVydFRvSnNvbk9yVGhyb3ciLCAic2NoZW1hIiwgIm9iamVjdCIsICJ0b0pTT05TY2hlbWEiLCAiZW5hYmxlSnNvbiIsICJ1bmlvbiIsICJsaXRlcmFsIiwgInNjaGVtYSIsICJzIiwgInN0cmluZyIsICJvcHRpb24iLCAianNvbiIsICJtYWtlIiwgImNvZGUiLCAibWVzc2FnZSIsICJkYXRhIiwgImludCIsICJpZCIsICJtZXRob2QiLCAicGFyYW1zIiwgInJldmVyc2VDb252ZXJ0VG9Kc29uT3JUaHJvdyIsICJyZXN1bHQiLCAiZXJyb3IiLCAicGFyc2VPclRocm93IiwgImRpY3QiLCAic3RyaW5nIiwgImVuYWJsZUpzb24iLCAic2NoZW1hIiwgInMiLCAic3RyaW5nIiwgIm9wdGlvbiIsICJib29sIiwgImludCIsICJhcnJheSIsICJpZCIsICJyZXN1bHQiLCAicGFyYW1zIiwgInJldmVyc2VDb252ZXJ0VG9Kc29uT3JUaHJvdyIsICJqc29uIiwgInBhcnNlT3JUaHJvdyIsICIkJEVycm9yIiwgIm5hbWUiLCAidmVyc2lvbiIsICJwYXJhbSIsICJpZCIsICJwYXJhbXMiLCAianNvbiIsICJyZXN1bHQiLCAibWFwIiwgImlzSW5pdGlhbGl6ZWQiLCAiQ2hhbm5lbCIsICJTb2NrZXQiLCAiQ2hhbm5lbCIsICJKc29uUnBjIiwgIlR5cGVzIiwgInBhcnNlIiwgImJvb2wiLCAianNvbiIsICIkJG51bGwiLCAic3RyaW5nIiwgImZsb2F0IiwgIm9iamVjdCIsICJhcnJheSIsICJlbmFibGVKc29uIiwgInNjaGVtYSIsICJzIiwgIm9wdGlvbiIsICJkaWN0IiwgImpzb24iLCAic3RyaW5nIiwgImluaXRpYWxpemVQYXJhbXNTY2hlbWEiLCAiaW5pdGlhbGl6ZVJlc3VsdFNjaGVtYSIsICJpbnQiLCAiYXJyYXkiLCAiYm9vbCIsICJwcm90b2NvbFZlcnNpb24iLCAiaW5pdGlhbGl6ZVJlc3VsdFNjaGVtYSIsICJ0b29sQ2FsbFBhcmFtc1NjaGVtYSIsICJjYWxsVG9vbFJlc3VsdFNjaGVtYSIsICJ0b29sc0xpc3RSZXN1bHRTY2hlbWEiLCAiVHlwZXMiLCAiZXhlY3V0ZVRvb2wiLCAiZ2V0VG9vbHNKc29uIiwgIm1ha2UiLCAiVHlwZXMiLCAiY29ubmVjdCIsICJnZXRTdGF0ZSIsICJtYWtlIiwgIm1lc3NhZ2UiLCAicyIsICJkYXRhIiwgIm1lc3NhZ2UiLCAicmVzdWx0IiwgInNjaGVtYSIsICJzIiwgInN0cmluZyIsICJqc29uIiwgImFycmF5IiwgIm9wdGlvbiIsICJkaWN0IiwgInRvb2xzUmVzcG9uc2VTY2hlbWEiLCAidG9vbENhbGxSZXF1ZXN0U2NoZW1hIiwgIm1ha2UiLCAiZ2V0U3RhdGUiLCAiY29ubmVjdCIsICJ1cmwiLCAianNvbiIsICJkYXRhIiwgInBhcnNlT3JUaHJvdyIsICJ0b29sc1Jlc3BvbnNlU2NoZW1hIiwgIiQkRXJyb3IiLCAibmFtZSIsICJyZXZlcnNlQ29udmVydFRvSnNvbk9yVGhyb3ciLCAidG9vbENhbGxSZXF1ZXN0U2NoZW1hIiwgInJlc3VsdCIsICJjYWxsVG9vbFJlc3VsdFNjaGVtYSIsICJUeXBlcyIsICJtYWtlIiwgIm9iamVjdCIsICJzIiwgInN0cmluZyIsICJqc29uIiwgInJldmVyc2VDb252ZXJ0VG9Kc29uT3JUaHJvdyIsICJ0b0pTT05TY2hlbWEiLCAiZ2V0VG9vbHNKc29uIiwgIm5hbWUiLCAicGFyc2VPclRocm93IiwgInJlc3VsdCIsICIkJEVycm9yIiwgImV4ZWN1dGVUb29sIiwgInByb3RvY29sVmVyc2lvbiIsICJUeXBlcyIsICJvYmplY3QiLCAicyIsICJsaXRlcmFsIiwgImlkIiwgImludCIsICJtZXRob2QiLCAic3RyaW5nIiwgInBhcmFtcyIsICJvcHRpb24iLCAianNvbiIsICJwYXJzZSIsICJzY2hlbWEiLCAicGFyc2VPclRocm93IiwgIiQkRXJyb3IiLCAicmVzdWx0IiwgInJldmVyc2VDb252ZXJ0VG9Kc29uT3JUaHJvdyIsICJtZXNzYWdlIiwgImVycm9yIiwgImluaXRpYWxpemVSZXN1bHRTY2hlbWEiLCAidG9vbHNMaXN0UmVzdWx0U2NoZW1hIiwgInRvb2xDYWxsUGFyYW1zU2NoZW1hIiwgImV4ZWN1dGVUb29sIiwgImNhbGxUb29sUmVzdWx0U2NoZW1hIiwgIlR5cGVzIiwgIkNoYW5uZWwiLCAiSnNvblJwYyIsICJuYW1lIiwgInNjaGVtYSIsICJzIiwgInN0cmluZyIsICJib29sIiwgIm5hbWUiXQp9Cg==
