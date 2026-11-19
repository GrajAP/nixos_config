"use strict";

(() => {
  const markerKey = "nixCatppuccinSeed";
  const markerValue = "@seedVersion@";
  const bundlePath = "catppuccin-mocha-blue.json";
  const customStylesPath = "custom-userstyles.json";

  async function readBundle(path) {
    const response = await fetch(chrome.runtime.getURL(path));
    if (!response.ok) {
      throw new Error(`Cannot read ${path}: ${response.status}`);
    }
    return response.json();
  }

  async function importStyles(styles) {
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
        for (const single of chunk) {
          try {
            await globalThis.API.styles.importMany([single]);
          } catch (singleErr) {
            console.warn(`Stylus failed to import style "${single.name}":`, singleErr);
          }
        }
      }
    }
  }

  async function seedCatppuccin() {
    if (globalThis._busy) {
      await globalThis._busy;
    }

    const stored = await chrome.storage.local.get(markerKey);
    const fullSeed = stored[markerKey] !== markerValue;

    const [header, ...styles] = await readBundle(bundlePath);
    const customStyles = await readBundle(customStylesPath);

    if (fullSeed) {
      await globalThis.API.setPrefs({
        updateInterval: header.settings?.updateInterval ?? 24,
        updateOnlyEnabled: header.settings?.updateOnlyEnabled ?? false,
        patchCsp: header.settings?.patchCsp ?? true,
        styleViaASS: false,
      });
    }

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

    // A full seed refreshes every bundled style. Otherwise only styles that
    // went missing from the Stylus database are installed again.
    const toImport = [];
    for (const style of [...styles, ...customStyles]) {
      const current =
        (style.updateUrl && byUpdateUrl.get(style.updateUrl)) ||
        byName.get(style.name);
      if (current) {
        if (!fullSeed) {
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
      if (style.name === "Chess.com Catppuccin") {
        style.enabled = true;
      }
      toImport.push(style);
    }

    await importStyles(toImport);

    if (fullSeed) {
      await chrome.storage.local.set({[markerKey]: markerValue});
    }
    if (toImport.length) {
      console.info(
        `Nix installed ${toImport.length} Catppuccin userstyles (${fullSeed ? "full seed" : "missing only"})`,
      );
    }
  }

  globalThis.keepAlive(
    seedCatppuccin().catch((error) =>
      console.error("Nix Catppuccin userstyle import failed", error),
    ),
  );
})();
