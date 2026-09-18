function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));
const _fs = _interopRequireDefault(require('fs'));

function setupDiscordTheme(cssPath, styleId = 'ctp-discord-theme') {
  let cachedCss = null;

  const loadCss = () => {
    if (!cachedCss) {
      try {
        if (_fs.default.existsSync(cssPath)) {
          cachedCss = _fs.default.readFileSync(cssPath, 'utf8');
        }
      } catch (e) {
        console.error('[Catppuccin Discord] Failed to read CSS file:', e);
      }
    }
    return cachedCss;
  };

  const ensureClasses = () => {
    try {
      const targets = [document.documentElement, document.body, document.getElementById('app-mount')];
      for (const el of targets) {
        if (el) {
          if (!el.classList.contains('visual-refresh')) el.classList.add('visual-refresh');
          if (!el.classList.contains('theme-dark')) el.classList.add('theme-dark');
          el.setAttribute('data-theme', 'dark');
        }
      }
    } catch (_) {}
  };

  const applyTheme = () => {
    try {
      ensureClasses();
      const css = loadCss();
      if (!css) return;

      const target = document.head || document.documentElement;
      if (!target) return;

      let styleEl = document.getElementById(styleId);
      if (!styleEl) {
        styleEl = document.createElement('style');
        styleEl.id = styleId;
        styleEl.type = 'text/css';
        styleEl.textContent = css;
        target.appendChild(styleEl);
      } else {
        if (styleEl.nextSibling || styleEl.parentNode !== target) {
          target.appendChild(styleEl);
        }
      }
    } catch (e) {
      console.error('[Catppuccin Discord] Injection error:', e);
    }
  };

  applyTheme();

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', applyTheme);
  }
  window.addEventListener('load', applyTheme);

  try {
    const observer = new MutationObserver(() => {
      applyTheme();
    });

    const initObserver = () => {
      if (document.documentElement) {
        observer.observe(document.documentElement, {
          childList: false,
          subtree: false,
          attributes: true,
          attributeFilter: ['class', 'data-theme']
        });
      }
      if (document.head) {
        observer.observe(document.head, {
          childList: true,
          subtree: false
        });
      }
    };

    initObserver();
    if (!document.head) {
      document.addEventListener('DOMContentLoaded', initObserver);
    }
  } catch (e) {
    console.warn('[Catppuccin Discord] MutationObserver error:', e);
  }

  setInterval(applyTheme, 1500);
}

module.exports = (Ferdium, settings) => {
  const getMessages = () => {
    let directCount = 0;
    const directCountPerServer = document.querySelectorAll(
      '[class*="lowerBadge_"] [class*="numberBadge_"]',
    );

    for (const directCountBadge of directCountPerServer) {
      directCount += Ferdium.safeParseInt(directCountBadge.textContent);
    }

    const indirectCountPerServer =
      document.title.search('• Discord') === -1 ? 0 : 1;

    Ferdium.setBadge(directCount, indirectCountPerServer);
  };

  Ferdium.loop(getMessages);

  const cssFile = _path.default.join(__dirname, 'service.css');
  Ferdium.injectCSS(cssFile);
  setupDiscordTheme(cssFile, 'ctp-discord-theme');

  document.addEventListener(
    'click',
    event => {
      const link = event.target.closest('a[href^="http"]');
      const button = event.target.closest('button[title^="http"]');

      if (link || button) {
        const url = link
          ? link.getAttribute('href')
          : button.getAttribute('title');
        const skipDomains = [
          /^https:\/\/discordapp\.com\/channels\//i,
          /^https:\/\/discord\.com\/channels\//i,
        ];

        let stayInsideDiscord;
        skipDomains.every(skipDomain => {
          stayInsideDiscord = skipDomain.test(url);
          return !stayInsideDiscord;
        });

        if (!Ferdium.isImage(link) && !stayInsideDiscord) {
          event.preventDefault();
          event.stopPropagation();

          if (
            url.includes('discordapp.com/attachments/') ||
            settings.trapLinkClicks === true
          ) {
            window.location.href = url;
          } else {
            Ferdium.openNewWindow(url);
          }
        }
      }
    },
    true,
  );
};
