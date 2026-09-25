_: {
  services = {
    udiskie.enable = true;
    gpg-agent = {
      enable = true;
      enableSshSupport = false;
      enableZshIntegration = true;
    };
  };
  # SSH keys live in gnome-keyring (unlocked by PAM at login), not in
  # gpg-agent, so point every local shell/service at the gcr socket.
  sshAuthSock = {
    enable = true;
    initialization = {
      bash = ''
        if [ -S "$XDG_RUNTIME_DIR/gcr/ssh" ]; then
          export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/gcr/ssh"
        fi
      '';
      fish = ''
        if test -S "$XDG_RUNTIME_DIR/gcr/ssh"
          set -x SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/gcr/ssh"
        end
      '';
      nushell = ''
        if ("$env.XDG_RUNTIME_DIR/gcr/ssh" | path exists) {
          $env.SSH_AUTH_SOCK = $"($env.XDG_RUNTIME_DIR)/gcr/ssh"
        }
      '';
    };
    systemd.socketProviderUnit = "gcr-ssh-agent.socket";
  };
  programs = {
    gpg.enable = true;
    man.enable = true;
    eza.enable = true;
    dircolors = {
      enable = true;
      enableZshIntegration = true;
    };

    skim = {
      enable = true;
      enableZshIntegration = true;
      defaultCommand = "rg --files --hidden";
      changeDirWidgetOptions = [
        "--preview 'eza --icons --git --color always -T -L 3 {} | head -200'"
        "--exact"
      ];
    };
    zoxide = {
      enable = true;
      enableZshIntegration = true;
    };
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    tealdeer = {
      enable = true;
      settings = {
        display = {
          compact = false;
          use_pager = true;
        };
        updates = {
          auto_update = true;
        };
      };
    };
    bat = {
      enable = true;
      config = {
        pager = "less -FR";
      };
    };
  };
}
