const fs = require("fs");
const http = require("http");
const path = require("path");
const { loadEnv } = require("./config/loadEnv");

loadEnv();

const { handleProductClick } = require("./controllers/eventsController");

const port = Number(process.env.PORT || 3000);
const host = process.env.HOST || "127.0.0.1";
const rootDir = path.resolve(__dirname, "..");
const frontendDir = path.join(rootDir, "frontend");

const contentTypes = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".svg": "image/svg+xml",
};

function sendJson(response, status, payload) {
  response.writeHead(status, { "Content-Type": "application/json" });
  response.end(JSON.stringify(payload));
}

function readJsonBody(request) {
  return new Promise((resolve, reject) => {
    let body = "";
    request.on("data", (chunk) => {
      body += chunk;
      if (body.length > 1024 * 1024) {
        reject(new Error("Request body is too large."));
        request.destroy();
      }
    });
    request.on("end", () => {
      try {
        resolve(body ? JSON.parse(body) : {});
      } catch {
        reject(new Error("Invalid JSON request body."));
      }
    });
    request.on("error", reject);
  });
}

function serveStatic(request, response) {
  const requestPath = decodeURIComponent(new URL(request.url, `http://${request.headers.host}`).pathname);
  const normalizedPath = requestPath === "/" ? "/index.html" : requestPath;
  const filePath = path.normalize(path.join(frontendDir, normalizedPath));

  if (!filePath.startsWith(frontendDir)) {
    response.writeHead(403);
    response.end("Forbidden");
    return;
  }

  fs.readFile(filePath, (error, data) => {
    if (error) {
      response.writeHead(404);
      response.end("Not found");
      return;
    }

    const ext = path.extname(filePath);
    response.writeHead(200, { "Content-Type": contentTypes[ext] || "application/octet-stream" });
    response.end(data);
  });
}

const server = http.createServer(async (request, response) => {
  const url = new URL(request.url, `http://${request.headers.host}`);

  if (request.method === "GET" && url.pathname === "/api/health") {
    sendJson(response, 200, { ok: true, service: "virtual-store-events" });
    return;
  }

  if (request.method === "POST" && url.pathname === "/api/events/product-click") {
    try {
      const body = await readJsonBody(request);
      await handleProductClick(request, response, body);
    } catch (error) {
      sendJson(response, 400, { ok: false, error: error.message });
    }
    return;
  }

  if (request.method === "GET") {
    serveStatic(request, response);
    return;
  }

  sendJson(response, 405, { ok: false, error: "Method not allowed." });
});

server.listen(port, host, () => {
  console.log(`Virtual store listening on http://${host}:${port}`);
});
