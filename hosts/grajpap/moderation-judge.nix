# Bespotted moderation judge: Bielik-11B-v3.0 on the RX 580 through llama.cpp
# (Vulkan). Bespotted production on lenovo asks it over the tailnet, with a 3 s
# limit, and keeps publishing without it when the PC is off or busy.
#
# The model takes almost all 8 GB of VRAM, so the guard below stops the judge
# while a Steam game runs and starts it again afterwards.
{
  config,
  pkgs,
  lib,
  ...
}: let
  port = 8095;
  modelDir = "/mnt/SSD2/models/bespotted-judge";
  model = "${modelDir}/bielik-11b-v3-instruct-q4km.gguf";
  llama = pkgs.llama-cpp.override {vulkanSupport = true;};

  # The first request after loading takes about 6 s, over the backend's 3 s
  # limit, so the service answers one itself before it counts as started.
  judgeWarmup = pkgs.writeShellApplication {
    name = "bespotted-judge-warmup";
    runtimeInputs = [pkgs.curl];
    text = ''
      for _ in $(seq 1 180); do
        if curl -sf -m 2 http://127.0.0.1:${toString port}/health >/dev/null; then
          curl -sf -m 60 http://127.0.0.1:${toString port}/v1/chat/completions \
            -H 'Content-Type: application/json' \
            -d '{"messages":[{"role":"user","content":"Kebab przy PWR jest dobry"}],"max_tokens":4,"temperature":0}' >/dev/null
          exit 0
        fi
        sleep 1
      done
      exit 1
    '';
  };

  judgeGameGuard = pkgs.writeShellApplication {
    name = "bespotted-judge-game-guard";
    runtimeInputs = with pkgs; [coreutils procps systemd];
    text = ''
      service="bespotted-judge.service"
      stopped_marker="/run/bespotted-judge-game-guard/stopped"

      game_running() {
        pgrep -f 'SteamLaunch AppId=[1-9]' >/dev/null \
          || pgrep -x -i 'cs2|cs2_linux64|cs2\.exe|rocketleague(\.exe?)?' >/dev/null
      }

      while true; do
        if game_running; then
          if systemctl is-active --quiet "$service"; then
            touch "$stopped_marker"
            systemctl stop "$service"
          fi
        elif [[ -e "$stopped_marker" ]]; then
          systemctl start "$service"
          rm -f "$stopped_marker"
        fi
        sleep 5
      done
    '';
  };
in {
  systemd.services.bespotted-judge = {
    description = "Bespotted moderation judge (Bielik-11B, llama.cpp Vulkan)";
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
    unitConfig.RequiresMountsFor = modelDir;
    serviceConfig = {
      ExecStart = lib.concatStringsSep " " [
        "${llama}/bin/llama-server"
        "--model ${model}"
        "--n-gpu-layers 99"
        "--ctx-size 2048"
        "--parallel 1"
        "--threads 6"
        "--host 0.0.0.0"
        "--port ${toString port}"
        "--no-webui"
      ];
      ExecStartPost = lib.getExe judgeWarmup;
      TimeoutStartSec = 240;
      DynamicUser = true;
      SupplementaryGroups = ["video" "render"];
      Restart = "on-failure";
      RestartSec = 10;
      Nice = 5;
      ProtectHome = true;
      ProtectSystem = "strict";
      ReadOnlyPaths = [modelDir];
      NoNewPrivileges = true;
      PrivateTmp = true;
    };
  };

  systemd.services.bespotted-judge-game-guard = {
    description = "Stop the Bespotted judge while a game needs the GPU";
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      ExecStart = lib.getExe judgeGameGuard;
      Restart = "always";
      RestartSec = 5;
      RuntimeDirectory = "bespotted-judge-game-guard";
      RuntimeDirectoryPreserve = "yes";
    };
  };

  # Only the tailnet reaches the judge; the LAN and the internet do not.
  networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = [port];
}
