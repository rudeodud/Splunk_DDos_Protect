const fs = require("fs");
const path = require("path");
const { sendToSplunk } = require("../services/splunkHecClient");

const logDir = path.join(__dirname, "..", "logs");
const fallbackLogPath = path.join(logDir, "store-events.ndjson");

function normalizeProductClick(body, request) {
  const now = new Date().toISOString();
  const product = body.product || {};

  return {
    event_type: "product_click",
    timestamp: now,
    session_id: String(body.session_id || "anonymous"),
    page: String(body.page || "/"),
    product: {
      id: String(product.id || "unknown"),
      name: String(product.name || "unknown"),
      category: String(product.category || "unknown"),
      price: Number(product.price || 0),
      currency: String(product.currency || "KRW"),
    },
    client: {
      ip: request.headers["x-forwarded-for"] || request.socket.remoteAddress || "unknown",
      user_agent: request.headers["user-agent"] || "unknown",
      referer: request.headers.referer || "",
    },
  };
}

function appendFallbackLog(event) {
  fs.mkdirSync(logDir, { recursive: true });
  fs.appendFileSync(fallbackLogPath, `${JSON.stringify(event)}\n`, "utf8");
}

async function handleProductClick(request, response, body) {
  const event = normalizeProductClick(body, request);
  appendFallbackLog(event);

  try {
    const splunkResult = await sendToSplunk(event);
    response.writeHead(202, { "Content-Type": "application/json" });
    response.end(JSON.stringify({ ok: true, event, splunk: splunkResult }));
  } catch (error) {
    response.writeHead(502, { "Content-Type": "application/json" });
    response.end(
      JSON.stringify({
        ok: false,
        event,
        error: error.message,
        fallback_log: "backend/logs/store-events.ndjson",
      })
    );
  }
}

module.exports = {
  handleProductClick,
};
