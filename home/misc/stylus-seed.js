"use strict";

(() => {
  const markerKey = "nixCatppuccinSeed";
  const markerValue = "@seedVersion@";
  const bundlePath = "catppuccin-mocha-blue.json";
  const customStylesPath = "custom-userstyles.json";

  async function importCustomStyles() {
    const response = await fetch(chrome.runtime.getURL(customStylesPath));
    if (!response.ok) {
      throw new Error(`Cannot read ${customStylesPath}: ${response.status}`);
    }

    const customStyles = await response.json();
    const existing = await globalThis.API.styles.getAll();
    const byUpdateUrl = new Map(
      existing
        .filter((style) => style.updateUrl)
        .map((style) => [style.updateUrl, style]),
    );

    for (const style of customStyles) {
      const current = byUpdateUrl.get(style.updateUrl);
      if (current) {
        style.id = current.id;
        style._id = current._id;
        style.installDate = current.installDate;
        style.enabled = current.enabled;
        if (current.customName) {
          style.customName = current.customName;
        }
      }
    }

    for (let offset = 0; offset < customStyles.length; offset += 20) {
      const result = await globalThis.API.styles.importMany(
        customStyles.slice(offset, offset + 20),
      );
      const failed = result.filter((item) => item && item.err);
      if (failed.length) {
        throw new Error(
          `Stylus failed to import ${failed.length} custom userstyles`,
        );
      }
    }

    console.info(
      `Nix imported ${customStyles.length} custom Catppuccin userstyles`,
    );
  }

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
    await globalThis.API.setPrefs({
      updateInterval: header.settings.updateInterval,
      updateOnlyEnabled: header.settings.updateOnlyEnabled,
      patchCsp: header.settings.patchCsp,
      styleViaASS: false,
    });

    const existing = await globalThis.API.styles.getAll();
    const byUpdateUrl = new Map(
      existing
        .filter((style) => style.updateUrl)
        .map((style) => [style.updateUrl, style]),
    );
    const byName = new Map(
      existing
        .filter((style) => style.name)
        .map((style) => [style.name, style]),
    );

    for (const style of styles) {
      const current =
        (style.updateUrl && byUpdateUrl.get(style.updateUrl)) ||
        byName.get(style.name);
      if (current) {
        style.id = current.id;
        style._id = current._id;
        style.installDate = current.installDate;
        style.enabled = current.enabled;
        if (current.customName) {
          style.customName = current.customName;
        }
      }
      // No `continue` for missing styles: importMany installs them fresh,
      // so wiped/new profiles get the full bundle, not just updates.
      if (style.name === "Chess.com Catppuccin") {
        style.enabled = true;
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

    await importCustomStyles();

    await chrome.storage.local.set({[markerKey]: markerValue});
    console.info(
      `Nix installed ${styles.length} Catppuccin Mocha Blue userstyles + custom userstyles`,
    );
  }

  globalThis.keepAlive(
    seedCatppuccin().catch((error) => {
      console.error("Nix Catppuccin userstyle import failed", error);
    }),
  );
})();
