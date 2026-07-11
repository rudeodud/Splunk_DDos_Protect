const http = require("http");
const https = require("https");
const { splunkConfig, isSplunkConfigured } = require("../config/splunk");

async function sendToSplunk(event) {
  if (!isSplunkConfigured()) {
    return {
      delivered: false,
      reason: "Splunk HEC is not configured. Set SPLUNK_HEC_URL and SPLUNK_HEC_TOKEN.",
    };
  }

  const payload = {
    time: Math.floor(Date.now() / 1000),
    host: "virtual-store",
    source: splunkConfig.source,
    sourcetype: splunkConfig.sourcetype,
    index: splunkConfig.index,
    event,
  };

  return postJson(splunkConfig.hecUrl, payload);
}

function postJson(targetUrl, payload) {
  return new Promise((resolve, reject) => {
    const parsedUrl = new URL(targetUrl);
    const client = parsedUrl.protocol === "http:" ? http : https;
    const body = JSON.stringify(payload);

    const request = client.request(
      {
        hostname: parsedUrl.hostname,
        port: parsedUrl.port || (parsedUrl.protocol === "http:" ? 80 : 443),
        path: `${parsedUrl.pathname}${parsedUrl.search}`,
        method: "POST",
        rejectUnauthorized: !splunkConfig.insecure,
        headers: {
          Authorization: `Splunk ${splunkConfig.hecToken}`,
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(body),
        },
      },
      (response) => {
        let responseBody = "";
        response.setEncoding("utf8");
        response.on("data", (chunk) => {
          responseBody += chunk;
        });
        response.on("end", () => {
          if (response.statusCode < 200 || response.statusCode >= 300) {
            reject(new Error(`Splunk HEC request failed: ${response.statusCode} ${responseBody}`));
            return;
          }

          resolve({
            delivered: true,
            status: response.statusCode,
            response: responseBody,
          });
        });
      }
    );

    request.on("error", reject);
    request.write(body);
    request.end();
  });
}

module.exports = {
  sendToSplunk,
};
