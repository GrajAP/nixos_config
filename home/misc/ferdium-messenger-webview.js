function injectTheme(cssPath, styleId = 'ctp-messenger-theme') {
  let cachedCss = null;

  const loadCss = () => {
    if (!cachedCss && _fs.default.existsSync(cssPath)) {
      cachedCss = _fs.default.readFileSync(cssPath, 'utf8');
    }
    return cachedCss;
  };

  const apply = () => {
    try {
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
        if (document.head && styleEl.parentNode !== document.head) {
          document.head.appendChild(styleEl);
        } else if (styleEl.nextSibling) {
          target.appendChild(styleEl);
        }
      }
    } catch (e) {
      console.error('[Catppuccin Messenger] Injection error:', e);
    }
  };

  apply();
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', apply);
  }
  window.addEventListener('load', apply);
  setInterval(apply, 1500);
}

function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));
const _fs = _interopRequireDefault(require('fs'));

function hideInstallMessage() {
  const installMessage = document.querySelector('.usczdcwk');
  if (installMessage) {
    installMessage.style.display =
      installMessage.style.display === 'none'
        ? installMessage.style.display
        : 'none';
  }
}

module.exports = (Ferdium, settings) => {
  const getMessages = () => {
    let count = 0;
    let newMessengerUI = false;

    /*
     * try the counting with the new UI
     */
    for (let href of ['/', '/requests/', '/marketplace/']) {
      const elem = document.querySelector(
        `a[href^='${href}t/'][role='link'][tabindex='0']`,
      );
      if (elem && elem.ariaLabel) {
        newMessengerUI = true;
        const match = elem.ariaLabel.match(/(\d+)/g);
        if (match) {
          count += Ferdium.safeParseInt(match[0]);
        }
      }
    }

    /*
     * do the old counting if the interface is not the last one
     */
    if (!newMessengerUI) {
      count = [
        ...document.querySelectorAll(
          '.bp9cbjyn.j83agx80.owycx6da:not(.btwxx1t3)',
        ),
      ]
        .map(elem => {
          const hasPing = !!elem.querySelector(
            '.pq6dq46d.is6700om.qu0x051f.esr5mh6w.e9989ue4.r7d6kgcz.s45kfl79.emlxlaya.bkmhp75w.spb7xbtv.cyypbtt7.fwizqjfa',
          );
          const isMuted = !!elem.querySelector(
            '.a8c37x1j.ms05siws.l3qrxjdp.b7h9ocf4.trssfv1o',
          );

          return hasPing && !isMuted;
        })
        .reduce((prev, curr) => prev + curr, 0);

      /*
       * add count of message requests on top of notification counter
       */
      const messageRequestsElement = document.querySelector('._5nxf');
      if (messageRequestsElement) {
        count += Ferdium.safeParseInt(messageRequestsElement.textContent);
      }
    }

    Ferdium.setBadge(count);
  };

  const loopRoutine = () => {
    getMessages();
    hideInstallMessage();
  };

  Ferdium.loop(loopRoutine);

  // Inject Catppuccin Mocha Blue theme
  const cssFile = _path.default.join(__dirname, 'service.css');
  Ferdium.injectCSS(cssFile);
  injectTheme(cssFile, 'ctp-messenger-theme');

  // Inject iOS Peek Preview and Ghost Mode JS if present
  const peekScriptPath = _path.default.join(__dirname, 'peek-preview.js');
  if (_fs.default.existsSync(peekScriptPath)) {
    if (typeof Ferdium.injectJSUnsafe === 'function') {
      Ferdium.injectJSUnsafe(peekScriptPath);
    } else {
      try {
        const code = _fs.default.readFileSync(peekScriptPath, 'utf8');
        const scriptEl = document.createElement('script');
        scriptEl.textContent = code;
        (document.head || document.documentElement).appendChild(scriptEl);
      } catch (e) {
        console.error('[iOS Peek] Failed to inject script:', e);
      }
    }
  }

  localStorage.setItem(
    '_cs_desktopNotifsEnabled',
    JSON.stringify({
      __t: Date.now(),
      __v: true,
    }),
  );

  if (typeof Ferdium.onNotify === 'function') {
    Ferdium.onNotify(notification => {
      if (typeof notification.title !== 'string') {
        notification.title =
          ((notification.title.props || {}).content || [])[0] || 'Messenger';
      }

      if (typeof notification.options.body !== 'string') {
        notification.options.body =
          (((notification.options.body || {}).props || {}).content || [])[0] ||
          '';
      }

      return notification;
    });
  }

  document.addEventListener(
    'click',
    event => {
      // Don't intercept clicks inside iOS Peek modal
      if (event.target.closest('#ios-peek-overlay')) return;

      const link = event.target.closest('a[href^="http"]');
      const button = event.target.closest('button[title^="http"]');

      if (link || button) {
        const url = link
          ? link.getAttribute('href')
          : button.getAttribute('title');

        if (!url) return;

        // Never intercept internal Messenger / Facebook links, calls or video conferences
        try {
          const parsed = new URL(url, window.location.href);
          const host = parsed.hostname.toLowerCase();
          const isInternalHost =
            host === 'messenger.com' ||
            host.endsWith('.messenger.com') ||
            host === 'facebook.com' ||
            host.endsWith('.facebook.com');

          if (isInternalHost) {
            if (
              parsed.pathname.includes('/call/') ||
              parsed.pathname.includes('/groupcall/') ||
              parsed.pathname.includes('/videocall/') ||
              parsed.search.includes('call_id') ||
              parsed.pathname.startsWith('/messages') ||
              parsed.pathname.startsWith('/t/')
            ) {
              return;
            }
          }
        } catch (_) {}

        event.preventDefault();
        event.stopPropagation();

        if (url.includes('fbsbx.com') || settings.trapLinkClicks === true) {
          window.location.href = url;
        } else {
          Ferdium.openNewWindow(url);
        }
      }
    },
    true,
  );
};
