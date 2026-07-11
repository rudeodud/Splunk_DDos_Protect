const splunkConfig = {
  hecUrl: process.env.SPLUNK_HEC_URL || "",
  hecToken: process.env.SPLUNK_HEC_TOKEN || "",
  index: process.env.SPLUNK_HEC_INDEX || "main",
  source: process.env.SPLUNK_HEC_SOURCE || "virtual-store",
  sourcetype: process.env.SPLUNK_HEC_SOURCETYPE || "ddos:store:click",
  insecure: process.env.SPLUNK_HEC_INSECURE === "true",
};

function isSplunkConfigured() {
  return Boolean(splunkConfig.hecUrl && splunkConfig.hecToken);
}

module.exports = {
  splunkConfig,
  isSplunkConfigured,
};
