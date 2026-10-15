#!/usr/bin/env node
const http = require("http");
const net = require("net");
const { spawn } = require("child_process");

const realBin = process.env.REAL_OPENCODE_BIN || "opencode";
const version = process.env.OPENCODE_VERSION || "1.18.31";

const args = process.argv.slice(2);
if (args.includes("-v") || args.includes("--version")) {
  console.log(version);
  process.exit(0);
}

if (!args.includes("serve")) {
  const child = spawn(realBin, args, { stdio: "inherit" });
  child.on("exit", (code) => {
    process.exit(code !== null ? code : 1);
  });
  return;
}

let listenHost = "127.0.0.1";
let listenPort = 0;
for (const arg of args) {
  if (arg.startsWith("--hostname=")) {
    listenHost = arg.split("=")[1];
  } else if (arg.startsWith("--port=")) {
    listenPort = parseInt(arg.split("=")[1], 10);
  }
}

if (!listenPort) {
  console.error("Error: listen port required (--port=<port>)");
  process.exit(1);
}

async function checkHealth(port) {
  return new Promise((resolve) => {
    const req = http.get(`http://127.0.0.1:${port}/global/health`, { timeout: 800 }, (res) => {
      resolve(res.statusCode === 200);
    });
    req.on("error", () => resolve(false));
    req.on("timeout", () => {
      req.destroy();
      resolve(false);
    });
  });
}

async function getFreePort() {
  return new Promise((resolve, reject) => {
    const srv = net.createServer();
    srv.listen(0, "127.0.0.1", () => {
      const port = srv.address().port;
      srv.close(() => resolve(port));
    });
    srv.on("error", reject);
  });
}

async function main() {
  let targetPort = 40960;
  let targetHost = "127.0.0.1";
  let childProcess = null;

  const daemonActive = await checkHealth(targetPort);
  if (!daemonActive) {
    targetPort = await getFreePort();
    const childArgs = args.filter(a => !a.startsWith("--hostname=") && !a.startsWith("--port="));
    childArgs.push(`--hostname=127.0.0.1`, `--port=${targetPort}`);

    childProcess = spawn(realBin, childArgs, {
      stdio: ["ignore", "pipe", "inherit"],
      env: process.env
    });

    childProcess.on("exit", (code) => {
      process.exit(code !== null ? code : 1);
    });

    let ready = false;
    for (let i = 0; i < 60; i++) {
      if (await checkHealth(targetPort)) {
        ready = true;
        break;
      }
      await new Promise(r => setTimeout(r, 250));
    }
    if (!ready) {
      console.error("Failed to start underlying opencode serve process");
      if (childProcess) childProcess.kill("SIGTERM");
      process.exit(1);
    }
  }

  const server = http.createServer((clientReq, clientRes) => {
    const isPostSession = clientReq.method === "POST" && (clientReq.url === "/session" || clientReq.url.startsWith("/session?"));

    if (isPostSession) {
      let chunks = [];
      clientReq.on("data", c => chunks.push(c));
      clientReq.on("end", () => {
        let bodyStr = Buffer.concat(chunks).toString("utf-8");
        try {
          let json = bodyStr ? JSON.parse(bodyStr) : {};
          if (!json.title) {
            json.title = "T3 " + Date.now();
          }
          bodyStr = JSON.stringify(json);
        } catch (e) {}

        const newBody = Buffer.from(bodyStr, "utf-8");
        const headers = {
          ...clientReq.headers,
          host: `${targetHost}:${targetPort}`,
          "content-length": newBody.length
        };

        const proxyReq = http.request({
          hostname: targetHost,
          port: targetPort,
          path: clientReq.url,
          method: "POST",
          headers
        }, (proxyRes) => {
          clientRes.writeHead(proxyRes.statusCode, proxyRes.headers);
          proxyRes.pipe(clientRes);
        });

        proxyReq.on("error", (err) => {
          if (!clientRes.headersSent) {
            clientRes.writeHead(502, { "Content-Type": "text/plain" });
          }
          clientRes.end(`Proxy error: ${err.message}`);
        });

        proxyReq.end(newBody);
      });
      return;
    }

    let bodyBuffer = null;
    if (clientReq.method === "POST" && clientReq.url.includes("prompt_async")) {
      let chunks = [];
      clientReq.on("data", c => chunks.push(c));
      clientReq.on("end", () => {
        try {
          let json = JSON.parse(Buffer.concat(chunks).toString("utf-8"));
          if (json.messageID) {
            delete json.messageID;
          }
          bodyBuffer = Buffer.from(JSON.stringify(json), "utf-8");
        } catch (e) {
          bodyBuffer = Buffer.concat(chunks);
        }
        forwardRequest(bodyBuffer);
      });
      return;
    }

    forwardRequest(null);

    function forwardRequest(bufferedBody) {
      const options = {
        hostname: targetHost,
        port: targetPort,
        path: clientReq.url,
        method: clientReq.method,
        headers: {
          ...clientReq.headers,
          host: `${targetHost}:${targetPort}`,
          ...(bufferedBody ? { "content-length": bufferedBody.length } : {})
        }
      };

      const proxyReq = http.request(options, (proxyRes) => {
        clientRes.writeHead(proxyRes.statusCode, proxyRes.headers);
        proxyRes.pipe(clientRes);
      });

      proxyReq.on("error", (err) => {
        if (!clientRes.headersSent) {
          clientRes.writeHead(502, { "Content-Type": "text/plain" });
        }
        clientRes.end(`Proxy error: ${err.message}`);
      });

      if (bufferedBody) {
        proxyReq.end(bufferedBody);
      } else {
        clientReq.pipe(proxyReq);
      }
    }
  });

  server.on("upgrade", (req, socket, head) => {
    const proxySocket = net.connect(targetPort, targetHost, () => {
      let raw = `${req.method} ${req.url} HTTP/${req.httpVersion}\r\n`;
      for (const [key, value] of Object.entries(req.headers)) {
        if (Array.isArray(value)) {
          for (const v of value) raw += `${key}: ${v}\r\n`;
        } else {
          raw += `${key}: ${value}\r\n`;
        }
      }
      raw += "\r\n";
      proxySocket.write(raw);
      if (head && head.length > 0) proxySocket.write(head);
      socket.pipe(proxySocket);
      proxySocket.pipe(socket);
    });

    proxySocket.on("error", () => socket.destroy());
    socket.on("error", () => proxySocket.destroy());
  });

  server.listen(listenPort, listenHost, () => {
    console.log(`opencode server listening on http://${listenHost}:${listenPort}`);
  });

  function shutdown() {
    if (childProcess) {
      try { childProcess.kill("SIGTERM"); } catch (e) {}
    }
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(0), 1000).unref();
  }

  process.on("SIGTERM", shutdown);
  process.on("SIGINT", shutdown);
  process.on("SIGHUP", shutdown);
  process.on("exit", () => {
    if (childProcess) {
      try { childProcess.kill("SIGTERM"); } catch (e) {}
    }
  });
}

main().catch(err => {
  console.error("Fatal proxy error:", err);
  process.exit(1);
});
