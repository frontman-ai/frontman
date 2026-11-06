#!/usr/bin/env python3
"""Restrict the runtime browser to its two HTTPS fixture endpoints."""

import http.server
import os
import select
import socket
import sys
import threading


class BlockedListener(http.server.ThreadingHTTPServer):
    daemon_threads = True
    connected = threading.Event()

    def get_request(self):
        connection, address = super().get_request()
        with open(sys.argv[3], "a", encoding="utf-8") as output:
            output.write("connection\n")
        self.connected.set()
        return connection, address


class Reject(http.server.BaseHTTPRequestHandler):
    def handle(self):
        self.request.close()

    def log_message(self, *args):
        pass


class Proxy(http.server.BaseHTTPRequestHandler):
    allowed = {f"127.0.0.1:{int(port)}" for port in sys.argv[1:3]}
    timeout = 30

    def log_message(self, *args):
        pass

    def do_CONNECT(self):
        if self.path not in self.allowed:
            self.send_error(403)
            return
        port = int(self.path.rsplit(":", 1)[1])
        with socket.create_connection(("127.0.0.1", port), timeout=10) as upstream:
            self.send_response(200, "Connection established")
            self.end_headers()
            sockets = (self.connection, upstream)
            while True:
                readable, _, _ = select.select(sockets, [], [], 30)
                if not readable:
                    return
                for source in readable:
                    data = source.recv(65536)
                    if not data:
                        return
                    (upstream if source is self.connection else self.connection).sendall(data)

    def do_GET(self):
        self.send_error(403)

    do_POST = do_GET
    do_HEAD = do_GET


blocked = BlockedListener(("127.0.0.1", 0), Reject)
proxy = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Proxy)
proxy.daemon_threads = True
threading.Thread(target=blocked.serve_forever, daemon=True).start()
with socket.create_connection(("127.0.0.1", blocked.server_port), timeout=5):
    if not blocked.connected.wait(5):
        raise RuntimeError("Blocked listener did not accept its control connection")
os.unlink(sys.argv[3])
print(proxy.server_port, blocked.server_port, flush=True)
threading.Thread(target=proxy.serve_forever, daemon=True).start()
try:
    sys.stdin.buffer.read()
finally:
    proxy.shutdown()
    blocked.shutdown()
    proxy.server_close()
    blocked.server_close()
