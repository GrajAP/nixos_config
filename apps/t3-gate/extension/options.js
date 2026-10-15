"use strict";

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

const blocklistEl = document.getElementById("blocklist");
const unknownEl = document.getElementById("unknown");
const saveBtn = document.getElementById("save");
const savedEl = document.getElementById("saved");

function parseBlocklist(text) {
  return text
    .split("\n")
    .map((line) => line.trim().toLowerCase())
    .filter((line) => line.length > 0)
    .map((line) => line.replace(/^https?:\/\//, "").replace(/\/.*$/, ""))
    .filter((line, index, all) => all.indexOf(line) === index);
}

async function load() {
  const stored = await chrome.storage.sync.get({
    blocklist: DEFAULT_BLOCKLIST,
    blockWhenUnknown: true,
  });
  blocklistEl.value = stored.blocklist.join("\n");
  unknownEl.checked = stored.blockWhenUnknown;
}

saveBtn.addEventListener("click", async () => {
  const blocklist = parseBlocklist(blocklistEl.value);
  await chrome.storage.sync.set({
    blocklist: blocklist.length ? blocklist : DEFAULT_BLOCKLIST,
    blockWhenUnknown: unknownEl.checked,
  });
  blocklistEl.value = (blocklist.length ? blocklist : DEFAULT_BLOCKLIST).join(
    "\n",
  );
  savedEl.textContent = "Zapisano";
  setTimeout(() => (savedEl.textContent = ""), 2000);
});

load();
