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
      const chunk = customStyles.slice(offset, offset + 20);
      try {
        const result = await globalThis.API.styles.importMany(chunk);
        const failed = result.filter((item) => item && item.err);
        if (failed.length) {
          console.warn(`Stylus custom styles batch failures:`, failed);
        }
      } catch (batchErr) {
        for (const single of chunk) {
          try {
            await globalThis.API.styles.importMany([single]);
          } catch (singleErr) {
            console.warn(`Stylus failed custom style "${single.name}":`, singleErr);
          }
        }
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
      updateInterval: header.settings?.updateInterval ?? 24,
      updateOnlyEnabled: header.settings?.updateOnlyEnabled ?? false,
      patchCsp: header.settings?.patchCsp ?? true,
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
      const chunk = styles.slice(offset, offset + 20);
      try {
        const result = await globalThis.API.styles.importMany(chunk);
        const failed = result.filter((item) => item && item.err);
        if (failed.length) {
          console.warn(`Stylus imported batch with ${failed.length} failures:`, failed);
        }
      } catch (batchErr) {
        console.warn(`Stylus batch import failed at offset ${offset}, falling back to item-by-item:`, batchErr);
        for (const singleStyle of chunk) {
          try {
            await globalThis.API.styles.importMany([singleStyle]);
          } catch (singleErr) {
            console.warn(`Stylus failed to import style "${singleStyle.name}":`, singleErr);
          }
        }
      }
    }

    await importCustomStyles();

    await chrome.storage.local.set({[markerKey]: markerValue});
    console.info(
      `Nix installed ${styles.length} Catppuccin Mocha Blue userstyles + custom userstyles`,
    );
  }

  globalThis.keepAlive(
    seedCatppuccin().catch((error) =>
      console.error("Nix Catppuccin userstyle import failed", error),
    ),
  );
})();
