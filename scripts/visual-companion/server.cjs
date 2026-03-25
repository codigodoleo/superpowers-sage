#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const http = require("http");
const url = require("url");

function parseArgs(argv) {
  const args = {
    host: "127.0.0.1",
    port: 0,
    sessionDir: "",
  };

  for (let i = 2; i < argv.length; i += 1) {
    const key = argv[i];
    const value = argv[i + 1];
    if (key === "--host") args.host = value;
    if (key === "--port") args.port = Number(value || 0);
    if (key === "--session-dir") args.sessionDir = value;
  }

  return args;
}

function latestLayout(sessionDir) {
  const files = fs
    .readdirSync(sessionDir)
    .filter((name) => /^layout-v\d+\.html$/.test(name))
    .sort((a, b) => {
      const av = Number(a.match(/\d+/)[0]);
      const bv = Number(b.match(/\d+/)[0]);
      return bv - av;
    });

  if (files.length > 0) return path.join(sessionDir, files[0]);
  return path.join(__dirname, "frame-template.html");
}

function latestLayoutName(sessionDir) {
  const filePath = latestLayout(sessionDir);
  return path.basename(filePath);
}

function nextLayoutPath(sessionDir) {
  const files = fs
    .readdirSync(sessionDir)
    .filter((name) => /^layout-v\d+\.html$/.test(name));

  let max = 0;
  for (const name of files) {
    const match = name.match(/layout-v(\d+)\.html/);
    if (!match) continue;
    const value = Number(match[1]);
    if (value > max) max = value;
  }

  return path.join(sessionDir, `layout-v${max + 1}.html`);
}

function appendEvent(sessionDir, payload) {
  const eventPath = path.join(sessionDir, "events.jsonl");
  const row = JSON.stringify(payload) + "\n";
  fs.appendFileSync(eventPath, row, "utf8");
}

function sendJson(res, statusCode, obj) {
  res.statusCode = statusCode;
  res.setHeader("content-type", "application/json; charset=utf-8");
  res.end(JSON.stringify(obj));
}

const args = parseArgs(process.argv);
if (!args.sessionDir) {
  console.error("Missing --session-dir");
  process.exit(1);
}

const sessionDir = path.resolve(args.sessionDir);
if (!fs.existsSync(sessionDir)) {
  fs.mkdirSync(sessionDir, { recursive: true });
}

const server = http.createServer((req, res) => {
  const parsed = url.parse(req.url, true);

  if (req.method === "GET" && parsed.pathname === "/health") {
    const sessionPath = path.join(sessionDir, "session.json");
    const status = fs.existsSync(sessionPath)
      ? JSON.parse(fs.readFileSync(sessionPath, "utf8")).status
      : "unknown";

    sendJson(res, 200, {
      ok: true,
      status,
      session_dir: sessionDir,
      latest_layout: latestLayoutName(sessionDir),
      timestamp: new Date().toISOString(),
    });
    return;
  }

  if (req.method === "GET" && parsed.pathname === "/") {
    const htmlPath = latestLayout(sessionDir);
    const html = fs.readFileSync(htmlPath, "utf8");
    res.statusCode = 200;
    res.setHeader("content-type", "text/html; charset=utf-8");
    res.end(html);
    return;
  }

  if (req.method === "GET" && parsed.pathname === "/helper.js") {
    const helperPath = path.join(__dirname, "helper.js");
    const js = fs.readFileSync(helperPath, "utf8");
    res.statusCode = 200;
    res.setHeader("content-type", "application/javascript; charset=utf-8");
    res.end(js);
    return;
  }

  if (req.method === "GET" && parsed.pathname === "/session") {
    const sessionPath = path.join(sessionDir, "session.json");
    const data = fs.existsSync(sessionPath)
      ? JSON.parse(fs.readFileSync(sessionPath, "utf8"))
      : { status: "unknown" };
    sendJson(res, 200, data);
    return;
  }

  if (req.method === "POST" && parsed.pathname === "/event") {
    let body = "";
    req.on("data", (chunk) => {
      body += chunk;
      if (body.length > 256 * 1024) {
        req.destroy();
      }
    });
    req.on("end", () => {
      try {
        const payload = JSON.parse(body || "{}");
        payload.timestamp = payload.timestamp || new Date().toISOString();
        appendEvent(sessionDir, payload);
        sendJson(res, 200, { ok: true });
      } catch (err) {
        sendJson(res, 400, { ok: false, error: err.message });
      }
    });
    return;
  }

  if (req.method === "POST" && parsed.pathname === "/layout") {
    let body = "";
    req.on("data", (chunk) => {
      body += chunk;
      if (body.length > 512 * 1024) {
        req.destroy();
      }
    });
    req.on("end", () => {
      try {
        const payload = JSON.parse(body || "{}");
        const html = String(payload.html || "").trim();
        if (!html) {
          sendJson(res, 400, { ok: false, error: "Missing html" });
          return;
        }

        const filePath = nextLayoutPath(sessionDir);
        fs.writeFileSync(filePath, html + "\n", "utf8");

        appendEvent(sessionDir, {
          type: "layout-update",
          section: payload.section || "unknown",
          layout: path.basename(filePath),
          source: "server",
          timestamp: new Date().toISOString(),
        });

        sendJson(res, 200, {
          ok: true,
          layout: path.basename(filePath),
        });
      } catch (err) {
        sendJson(res, 400, { ok: false, error: err.message });
      }
    });
    return;
  }

  if (req.method === "GET" && parsed.pathname === "/events") {
    const eventsPath = path.join(sessionDir, "events.jsonl");
    const text = fs.existsSync(eventsPath)
      ? fs.readFileSync(eventsPath, "utf8")
      : "";
    res.statusCode = 200;
    res.setHeader("content-type", "text/plain; charset=utf-8");
    res.end(text);
    return;
  }

  res.statusCode = 404;
  res.end("Not found");
});

server.listen(args.port, args.host, () => {
  const addr = server.address();
  const info = {
    type: "server-started",
    host: args.host,
    port: addr.port,
    url: `http://${args.host}:${addr.port}`,
    session_dir: sessionDir,
    started_at: new Date().toISOString(),
  };

  const infoPath = path.join(sessionDir, ".server-info");
  fs.writeFileSync(infoPath, JSON.stringify(info, null, 2) + "\n", "utf8");
  console.log(JSON.stringify(info));
});
