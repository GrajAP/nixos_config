"use strict";

const pill = document.getElementById("pill");
const hostsEl = document.getElementById("hosts");
const whenEl = document.getElementById("when");
const refreshBtn = document.getElementById("refresh");
const optionsBtn = document.getElementById("options");

function render(result) {
  if (!result || result.busy === null) {
    pill.textContent = "brak łączności";
    pill.className = "";
  } else if (result.busy) {
    pill.textContent = "agent pracuje";
    pill.className = "busy";
  } else {
    pill.textContent = "zablokowane";
    pill.className = "idle";
  }

  hostsEl.textContent = "";
  const hosts = (result && result.raw && result.raw.hosts) || {};
  for (const [name, info] of Object.entries(hosts)) {
    const row = document.createElement("div");
    const label = document.createElement("span");
    label.textContent = name;
    const value = document.createElement("span");
    value.className = "v";
    if (!info.ok) {
      value.textContent = "nieosiągalny";
      value.classList.add("down");
    } else if (info.running > 0) {
      value.textContent = info.running + " pracuje";
      value.classList.add("running");
    } else {
      value.textContent = "0";
    }
    row.append(label, value);
    hostsEl.append(row);
  }

  if (result && result.checkedAt) {
    whenEl.textContent =
      "sprawdzono " + new Date(result.checkedAt).toLocaleTimeString();
  }
}

async function refresh() {
  pill.textContent = "…";
  pill.className = "";
  const result = await chrome.runtime.sendMessage({ type: "get-status" });
  render(result);
}

refreshBtn.addEventListener("click", refresh);
optionsBtn.addEventListener("click", () => chrome.runtime.openOptionsPage());
refresh();
