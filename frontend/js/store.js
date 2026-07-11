const products = {
  "edge-shield": {
    id: "edge-shield",
    name: "Edge Shield Hoodie",
    category: "apparel",
    price: 79000,
    currency: "KRW",
  },
  "waf-cap": {
    id: "waf-cap",
    name: "WAF Guard Cap",
    category: "apparel",
    price: 32000,
    currency: "KRW",
  },
  "log-bucket": {
    id: "log-bucket",
    name: "Log Bucket Tote",
    category: "bag",
    price: 45000,
    currency: "KRW",
  },
  "splunk-mug": {
    id: "splunk-mug",
    name: "Splunk Query Mug",
    category: "drinkware",
    price: 21000,
    currency: "KRW",
  },
};

const statusEl = document.querySelector("#deliveryStatus");
const previewEl = document.querySelector("#eventPreview");

function getSessionId() {
  const key = "splunkStoreSessionId";
  const existing = window.localStorage.getItem(key);
  if (existing) return existing;

  const created = crypto.randomUUID();
  window.localStorage.setItem(key, created);
  return created;
}

function setStatus(text, className) {
  statusEl.className = `status-pill ${className || ""}`.trim();
  statusEl.textContent = text;
}

function buildEvent(product) {
  return {
    session_id: getSessionId(),
    page: window.location.pathname,
    product,
    browser_time: new Date().toISOString(),
  };
}

async function sendProductClick(product, button) {
  const event = buildEvent(product);
  previewEl.textContent = JSON.stringify(event, null, 2);
  setStatus("전송 중", "warn");
  button.disabled = true;

  try {
    const response = await fetch("/api/events/product-click", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(event),
    });

    const result = await response.json();
    previewEl.textContent = JSON.stringify(result, null, 2);

    if (!response.ok || !result.ok) {
      setStatus("전송 실패", "error");
      return;
    }

    setStatus(result.splunk && result.splunk.delivered ? "Splunk 전송" : "로컬 저장", "ok");
  } catch (error) {
    previewEl.textContent = JSON.stringify({ ok: false, error: error.message, event }, null, 2);
    setStatus("전송 실패", "error");
  } finally {
    button.disabled = false;
  }
}

document.querySelectorAll(".product-card").forEach((card) => {
  const product = products[card.dataset.productId];
  const button = card.querySelector("button");

  button.addEventListener("click", () => {
    sendProductClick(product, button);
  });
});
