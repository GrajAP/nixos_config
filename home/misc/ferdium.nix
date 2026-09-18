{lib, ...}: let
  discordDarkmodeCss = ./ferdium-discord-darkmode.css;
  discordWebviewJs = ./ferdium-discord-webview.js;
  discordIndexJs = ./ferdium-discord-index.js;
  discordNotificationCompatJs = ./ferdium-discord-notification-compatibility.js;
  gmailDarkmodeCss = ./ferdium-gmail-darkmode.css;
  whatsappDarkmodeCss = ./ferdium-whatsapp-darkmode.css;
in {
  home.activation.ferdiumCatppuccin = lib.hm.dag.entryAfter ["writeBoundary"] ''
        recipes_dir="$HOME/.config/Ferdium/recipes"

        # 1. Setup Discord recipe with persistent theme & version pinning
        discord_dir="$recipes_dir/discord"
        mkdir -p "$discord_dir"

        # Copy Catppuccin stylesheet to service.css, darkmode.css, and user.css
        cp -f "${discordDarkmodeCss}" "$discord_dir/service.css"
        cp -f "${discordDarkmodeCss}" "$discord_dir/darkmode.css"
        cp -f "${discordDarkmodeCss}" "$discord_dir/user.css"

        # Copy persistent webview and index scripts
        cp -f "${discordWebviewJs}" "$discord_dir/webview.js"
        cp -f "${discordIndexJs}" "$discord_dir/index.js"
        cp -f "${discordNotificationCompatJs}" "$discord_dir/notification-compatibility.js"

        # Write user.js for DOM readiness fallback
        cat << 'EOF' > "$discord_dir/user.js"
    module.exports = (config, userScript) => {
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
      ensureClasses();
      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', ensureClasses);
      }
      window.addEventListener('load', ensureClasses);
    };
    EOF

        # Write package.json with version 999.999.999 to prevent Ferdium recipe auto-updater from overwriting it
        cat << 'EOF' > "$discord_dir/package.json"
    {
      "id": "discord",
      "name": "Discord",
      "version": "999.999.999",
      "license": "MIT",
      "config": {
        "serviceURL": "https://discord.com/app",
        "hasNotificationSound": true,
        "hasIndirectMessages": true
      },
      "defaultIcon": "https://cdn.jsdelivr.net/gh/ferdium/ferdium-recipes@main/recipes/discord/icon.svg"
    }
    EOF

        # 2. Setup Gmail recipe
        gmail_dir="$recipes_dir/gmail"
        if [ -d "$gmail_dir" ]; then
          cp -f "${gmailDarkmodeCss}" "$gmail_dir/darkmode.css"
        fi

        # 3. Setup WhatsApp recipe with persistent Catppuccin theme & version pinning.
        # The stock darkmode.css is an outdated Franz-era stylesheet that no longer
        # matches web.whatsapp.com, and the recipe auto-updater wipes custom files.
        whatsapp_dir="$recipes_dir/whatsapp"
        if [ -d "$whatsapp_dir" ]; then
          cp -f "${whatsappDarkmodeCss}" "$whatsapp_dir/darkmode.css"

          # Pin the version so the auto-updater stops overwriting the theme.
          # NOTE: this also freezes webview.js badge-selector updates; unpin
          # (delete the dir, restart Ferdium) if unread badges ever go stale.
          sed -i 's/"version": "[^"]*"/"version": "999.999.999"/' "$whatsapp_dir/package.json"
        fi
  '';
}
