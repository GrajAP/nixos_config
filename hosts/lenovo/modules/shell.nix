{pkgs, ...}: {
  # ===========================================================================
  # SHELL
  # ===========================================================================

  programs = {
    zsh = {
      enable = true;
      enableCompletion = true;
      enableLsColors = true;
      histSize = 10000;
      histFile = "$HOME/.zsh_history";

      setOptions = [
        # Timestamped history. On a server, knowing when something was run is worth
        # more than the bytes: the old NO_EXTENDED_HISTORY setting threw that away.
        "EXTENDED_HISTORY"
        "INC_APPEND_HISTORY" # live append across windows, no lost entries
        "HIST_EXPIRE_DUPS_FIRST"
        "HIST_IGNORE_DUPS"
        "HIST_IGNORE_SPACE"
        "HIST_REDUCE_BLANKS"
        "HIST_FCNTL_LOCK"
      ];

      shellAliases = {
        ".." = "cd ..";
        "..." = "cd ../../";
        "...." = "cd ../../../";
        "....." = "cd ../../../../";
        "......" = "cd ../../../../../";

        # These shadow the real binaries in interactive use only; scripts are
        # unaffected because aliases do not apply to them.
        cat = "bat --style=plain";
        grep = "rg";
        ls = "eza -h --git --icons --color=auto --group-directories-first -s extension";
        l = "ls -lF --time-style=long-iso --icons";
        ll = "eza -l";
        la = "eza -lah --tree";
        lla = "eza -la";
        tree = "eza --tree --icons";
        du = "dust";
        ps = "procs";
        diff = "diff --color=auto";
        m = "mkdir -p";
        g = "git";
        n = "nix";

        # skim is a drop-in fzf replacement, so completion and key bindings work
        # either way. Note `fzf` resolves to `sk` inside other aliases too.
        fzf = "sk";

        wget = "wget --hsts-file=\"$HOME/.local/share/wget-hsts\"";
        untar = "tar -xvf";
        untargz = "tar -xzf";

        # `fetch` is a real command in several toolchains. Aliasing it to
        # fastfetch is a footgun that has bitten people before, so it is gone.
        uuid = "cat /proc/sys/kernel/random/uuid";

        cd = "z";
        fcd = "z $(find -type d | sk)";

        # --- system ---
        sc = "sudo systemctl";
        scu = "systemctl --user ";
        kys = "shutdown now";
        burn = "pkill -9";

        # --- nixos ---
        edit = "nvim /etc/nixos";
        rebuild = "/etc/nixos/rebuild.sh";
        nhs = "nh os switch /etc/nixos";
        nrb = "sudo nixos-rebuild switch --flake /etc/nixos";
        nrt = "sudo nixos-rebuild test --flake /etc/nixos";
        nfu = "sudo nix flake update --flake /etc/nixos && rebuild";
        ndiff = "nvd diff /run/booted-system /run/current-system";
        ngc = "sudo nix-collect-garbage -d && nh clean all";

        # --- server shortcuts ---
        alert = "sudo tail -f /var/log/server-alert.log";
        bklog = "sudo journalctl -u homenest-backup -n 50 --no-pager";
        smart = "sudo smartctl -a /dev/sda";
        dfc = "df -hT -x tmpfs -x devtmpfs";

        gpl = "curl https://www.gnu.org/licenses/gpl-3.0.txt -o LICENSE";
        agpl = "curl https://www.gnu.org/licenses/agpl-3.0.txt -o LICENSE";
        ytmp3 = "yt-dlp -x --continue --add-metadata --embed-thumbnail --audio-format mp3 --audio-quality 0 --metadata-from-title=\"%(artist)s - %(title)s\" --prefer-ffmpeg -o \"%(title)s.%(ext)s\"";
      };

      shellInit = ''
        # MANPAGER has to be an exported *variable*: man reads $MANPAGER from the
        # environment. As a shellAlias it defined a command named MANPAGER, which
        # nothing ever called, so `man` silently kept using the system pager.
        export MANPAGER="sh -c 'col -bx | bat -l man -p'"
        export LESS="-R -F -X"
      '';

      interactiveShellInit = ''
        source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
        ZSH_AUTOSUGGEST_STRATEGY=(history)

        eval "$(${pkgs.zoxide}/bin/zoxide init zsh)"

        source ${pkgs.skim}/share/skim/completion.zsh
        source ${pkgs.skim}/share/skim/key-bindings.zsh

        hash -d dl="$HOME/Downloads"
        hash -d docs="$HOME/Documents"
        hash -d dots="/etc/nixos"
        hash -d media="/run/media/$USER"
        hash -d music="$HOME/Music"
        hash -d notes="$HOME/Documents/notes"
        hash -d vids="$HOME/Videos"

        # zsh-syntax-highlighting must be sourced last.
        source ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
        ZSH_HIGHLIGHT_HIGHLIGHTERS=(main)
      '';
    };

    starship = {
      enable = true;
      settings = {
        add_newline = false;
        command_timeout = 1000;
        scan_timeout = 100;
        character = {
          error_symbol = "[󰊠](bold red)";
          success_symbol = "[󰊠](bold green)";
          vicmd_symbol = "[󰊠](bold yellow)";
          format = "$symbol [|](bold bright-black) ";
        };
        git_commit.commit_hash_length = 7;
        hostname = {
          ssh_only = true;
          format = "[$hostname](bold blue) ";
          disabled = false;
        };
        line_break.disabled = false;
        lua.symbol = "[](blue) ";
        python.symbol = "[](blue) ";

        # Named palette for `format` strings to reference. The old config set
        # `palette = "base16"`, which is not a starship setting at all and was
        # silently ignored; this keeps the same colours under a real name.
        palettes.catppuccin_mocha = {
          base00 = "#1e1e2e";
          base01 = "#181825";
          base02 = "#313244";
          base03 = "#45475a";
          base04 = "#585b70";
          base05 = "#cdd6f4";
          base06 = "#f5e0dc";
          base07 = "#b4befe";
          base08 = "#f38ba8";
          base09 = "#fab387";
          base0A = "#f9e2af";
          base0B = "#a6e3a1";
          base0C = "#94e2d5";
          base0D = "#89b4fa";
          base0E = "#cba6f7";
          base0F = "#f2cdcd";
          base10 = "#11111b";
          base11 = "#11111b";
          base12 = "#f38ba8";
          base13 = "#f9e2af";
          base14 = "#a6e3a1";
          base15 = "#94e2d5";
          base16 = "#a6adc8";
          base17 = "#f5e0dc";
          black = "#11111b";
          blue = "#89b4fa";
          "bright-black" = "#45475a";
          "bright-blue" = "#89b4fa";
          "bright-cyan" = "#94e2d5";
          "bright-green" = "#a6e3a1";
          "bright-magenta" = "#f5c2e7";
          "bright-purple" = "#cba6f7";
          "bright-red" = "#f38ba8";
          "bright-white" = "#a6adc8";
          "bright-yellow" = "#f9e2af";
          brown = "#f2cdcd";
          cyan = "#94e2d5";
          green = "#a6e3a1";
          magenta = "#f5c2e7";
          orange = "#fab387";
          purple = "#cba6f7";
          red = "#f38ba8";
          white = "#cdd6f4";
          yellow = "#f9e2af";
        };
      };
    };

    direnv.enable = true;
  };

  # An empty ~/.zshrc keeps zsh from running its interactive first-run wizard on
  # every new shell. tmpfiles only creates it when missing and re-applies
  # ownership and mode, so real content in that file is not truncated.
  systemd.tmpfiles.rules = [
    "f /home/grajpap/.zshrc 0644 grajpap users -"
  ];
}
