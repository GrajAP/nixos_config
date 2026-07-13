"use strict";

(() => {
  const markerKey = "nixCatppuccinSeed";
  const markerValue = "@seedVersion@";
  const bundlePath = "catppuccin-mocha-blue.json";

  async function seedCatppuccin() {
    if (globalThis._busy) {
      await globalThis._busy;
    }

    const stored = await chrome.storage.local.get(markerKey);
    if (stored[markerKey] === markerValue) {
      return;
    }

    const response = await fetch(chrome.runtime.getURL(bundlePath));
    if (!response.ok) {
      throw new Error(`Cannot read ${bundlePath}: ${response.status}`);
    }

    const [header, ...styles] = await response.json();
    globalThis.API.setPrefs({
      updateInterval: header.settings.updateInterval,
      updateOnlyEnabled: header.settings.updateOnlyEnabled,
      patchCsp: header.settings.patchCsp,
    });

    const existing = await globalThis.API.styles.getAll();
    const byUpdateUrl = new Map(
      existing
        .filter((style) => style.updateUrl)
        .map((style) => [style.updateUrl, style]),
    );

    for (const style of styles) {
      const current = byUpdateUrl.get(style.updateUrl);
      if (!current) {
        continue;
      }

      style.id = current.id;
      style._id = current._id;
      style.installDate = current.installDate;
      style.enabled = current.enabled;
      if (current.customName) {
        style.customName = current.customName;
      }
    }

    for (let offset = 0; offset < styles.length; offset += 20) {
      const result = await globalThis.API.styles.importMany(
        styles.slice(offset, offset + 20),
      );
      const failed = result.filter((item) => item && item.err);
      if (failed.length) {
        throw new Error(`Stylus failed to import ${failed.length} userstyles`);
      }
    }

    await chrome.storage.local.set({[markerKey]: markerValue});
    console.info(
      `Nix installed ${styles.length} Catppuccin Mocha Blue userstyles`,
    );
  }

  globalThis.keepAlive(
    seedCatppuccin().catch((error) => {
      console.error("Nix Catppuccin userstyle import failed", error);
    }),
  );
})();
