"use strict";

const GATE_URL = "http://127.0.0.1:4599/status";
const STATUS_TTL_MS = 12000;
const GATE_TIMEOUT_MS = 5000;
const BLOCK_PAGE = chrome.runtime.getURL("blocked.html");

const DEFAULT_BLOCKLIST = [
  "youtube.com",
  "youtu.be",
  "m.youtube.com",
  "x.com",
  "twitter.com",
  "mobile.twitter.com",
  "reddit.com",
  "instagram.com",
  "facebook.com",
  "tiktok.com",
  "twitch.tv",
  "netflix.com",
  "9gag.com",
  "shorts.com",
];

let blocklist = DEFAULT_BLOCKLIST;
let blockWhenUnknown = true;
let status = { busy: null, checkedAt: 0 };
let inflight = null;

async function loadSettings() {
  const stored = await chrome.storage.sync.get({
    blocklist: DEFAULT_BLOCKLIST,
    blockWhenUnknown: true,
  });
  blocklist = stored.blocklist;
  blockWhenUnknown = stored.blockWhenUnknown;
}

async function refreshStatus(force) {
  const now = Date.now();
  if (
    !force &&
    status.checkedAt !== 0 &&
    now - status.checkedAt < STATUS_TTL_MS
  ) {
    return status;
  }
  if (inflight) return inflight;

  inflight = (async () => {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), GATE_TIMEOUT_MS);
    try {
      const res = await fetch(GATE_URL, {
        cache: "no-store",
        signal: controller.signal,
      });
      const data = await res.json();
      status = { busy: Boolean(data.busy), checkedAt: Date.now(), raw: data };
    } catch (error) {
      status = { busy: null, checkedAt: Date.now(), error: String(error) };
    } finally {
      clearTimeout(timer);
      inflight = null;
    }
    updateBadge();
    return status;
  })();

  return inflight;
}

function updateBadge() {
  const text = status.busy === true ? "ON" : status.busy === false ? "OFF" : "?";
  const color =
    status.busy === true
      ? "#2e7d32"
      : status.busy === false
        ? "#c62828"
        : "#616161";
  chrome.action.setBadgeText({ text });
  chrome.action.setBadgeBackgroundColor({ color });
}

function isBlockedUrl(url) {
  if (!url) return false;
  let parsed;
  try {
    parsed = new URL(url);
  } catch {
    return false;
  }
  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") return false;
  if (url.startsWith(BLOCK_PAGE)) return false;
  return blocklist.some(
    (domain) =>
      parsed.hostname === domain || parsed.hostname.endsWith("." + domain),
  );
}

async function maybeBlock(tabId, url) {
  if (!isBlockedUrl(url)) return;
  const current = await refreshStatus(false);
  const mustBlock =
    current.busy === false || (current.busy === null && blockWhenUnknown);
  if (!mustBlock) return;
  const target = BLOCK_PAGE + "?u=" + encodeURIComponent(url);
  try {
    await chrome.tabs.update(tabId, { url: target });
  } catch {
    /* the tab closed before the redirect landed */
  }
}

chrome.webNavigation.onBeforeNavigate.addListener((details) => {
  if (details.frameId !== 0) return;
  maybeBlock(details.tabId, details.url);
});

chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
  if (changeInfo.url || changeInfo.status === "loading") {
    maybeBlock(tabId, tab.url);
  }
});

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message && message.type === "get-status") {
    refreshStatus(true).then((value) => sendResponse(value));
    return true;
  }
  return false;
});

chrome.alarms.create("poll", { periodInMinutes: 0.5 });
chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === "poll") refreshStatus(true);
});

chrome.storage.onChanged.addListener(() => {
  loadSettings();
});

async function start() {
  await loadSettings();
  await refreshStatus(true);
}

chrome.runtime.onInstalled.addListener(start);
chrome.runtime.onStartup.addListener(start);
start();
