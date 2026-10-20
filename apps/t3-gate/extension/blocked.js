"use strict";

const params = new URLSearchParams(location.search);
const blockedUrl = params.get("u") || "";

const hostEl = document.getElementById("blocked-host");
const stateEl = document.getElementById("state");
const hostsEl = document.getElementById("hosts");
const retryBtn = document.getElementById("retry");

if (blockedUrl) {
  try {
    hostEl.textContent = new URL(blockedUrl).hostname;
  } catch {
    hostEl.textContent = "Ta strona";
  }
}

function render(result) {
  if (!result || result.busy === null) {
    stateEl.textContent = "Nie mogę odczytać stanu agentów (t3-gate nie odpowiada).";
    stateEl.className = "no";
  } else if (result.busy) {
    stateEl.textContent = "Agent pracuje, odblokowuję.";
    stateEl.className = "ok";
  } else {
    stateEl.textContent = "Żaden agent nie pracuje.";
    stateEl.className = "no";
  }

  hostsEl.textContent = "";
  const hosts = (result && result.raw && result.raw.hosts) || {};
  for (const [name, info] of Object.entries(hosts)) {
    const row = document.createElement("div");
    const label = document.createElement("span");
    label.textContent = name;
    const value = document.createElement("span");
    value.className = info.ok && info.running > 0 ? "ok" : "no";
    value.textContent = info.ok ? info.running + " pracuje" : "nieosiągalny";
    row.append(label, value);
    hostsEl.append(row);
  }
}

async function refresh() {
  stateEl.textContent = "Sprawdzam stan agentów…";
  stateEl.className = "";
  const result = await chrome.runtime.sendMessage({ type: "get-status" });
  render(result);
  if (result && result.busy && blockedUrl) {
    location.replace(blockedUrl);
  }
}

retryBtn.addEventListener("click", refresh);
refresh();
