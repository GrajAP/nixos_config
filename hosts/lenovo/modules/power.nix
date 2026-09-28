{
  lib,
  pkgs,
  ...
}: let
  backlightDir = "/sys/class/backlight/intel_backlight";

  # Args: closed|off and open|on.
  #
  # Saving the exact level matters: this panel reports max_brightness 937, and
  # the previous handler wrote a hardcoded 200 on lid-open, which left the
  # screen at ~21% every time. bl_power is also gated, because that is what
  # actually cuts the backlight on i915.
  # writeShellScriptBin, not writeShellScript: the latter puts the script at
  # the root of its store path, so "${x}/bin/name" would not resolve.
  lidBacklight = pkgs.writeShellScriptBin "lid-backlight" ''
    set -eu
    dir=${backlightDir}
    state=/var/lib/server-state/backlight

    [ -d "$dir" ] || exit 0
    mkdir -p "$(dirname "$state")"

    case "''${1:-}" in
      closed | off)
        # Remember the current level exactly once per close.
        if [ ! -s "$state" ]; then
          cat "$dir/actual_brightness" > "$state" 2>/dev/null || true
        fi
        echo 0 > "$dir/brightness" 2>/dev/null || true
        echo 0 > "$dir/bl_power" 2>/dev/null || true
        ;;
      open | on)
        if [ -s "$state" ]; then
          level=$(cat "$state")
        else
          level=$(( $(cat "$dir/max_brightness") / 2 ))
        fi
        echo 1 > "$dir/bl_power" 2>/dev/null || true
        echo "$level" > "$dir/brightness" 2>/dev/null || true
        rm -f "$state"
        ;;
    esac
  '';
  blankIfClosed = pkgs.writeShellScriptBin "blank-if-lid-closed" ''
    set -eu
    state=$(awk '{print $2}' /proc/acpi/button/lid/*/state 2>/dev/null | head -n1)
    if [ "$state" = "closed" ]; then
      ${lidBacklight}/bin/lid-backlight closed
    fi
  '';
in {
  # ===========================================================================
  # OPTIONS
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # CPU mitigations: THE security/perf trade-off on this box.
  #
  # A stock 25.11 kernel runs PTI, retpolines, IBPB, RDT and friends on this
  # Haswell. That is a measurable power draw and part of why the clock sags
  # under sustained load. This machine exposes nothing but Tailscale and
  # key-only SSH, so the speculative-execution attack surface is close to empty.
  #
  # It is left ON by default. Flip to false only if you accept the regression:
  # an attacker who can already run code here gains a class of exploit that
  # patching would otherwise close. Requires a reboot to take effect, because
  # mitigations are fixed at boot.
  # ---------------------------------------------------------------------------
  options.power.cpuMitigations = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether to keep kernel CPU vulnerability mitigations enabled.
      Set to false to boot with `mitigations=off` (lower power draw, no
      speculative-execution hardening).
    '';
  };

  config = {
    # ===========================================================================
    # POWER, THERMALS, LID
    # ===========================================================================

    services = {
      # ---------------------------------------------------------------------------
      # Lid / suspend policy: the lid is expected to stay closed indefinitely.
      # ---------------------------------------------------------------------------
      logind.settings.Login = {
        HandleLidSwitch = "ignore";
        HandleLidSwitchExternalPower = "ignore";
        HandleLidSwitchDocked = "ignore";
        LidSwitchIgnoreInhibited = "no";
      };

      # ---------------------------------------------------------------------------
      # Backlight
      # ---------------------------------------------------------------------------
      acpid = {
        enable = true;
        handlers.lid = {
          event = "button/lid.*";
          action = "${lidBacklight}/bin/lid-backlight $(awk '{print $2}' /proc/acpi/button/lid/*/state 2>/dev/null | head -n1)";
        };
      };

      # ---------------------------------------------------------------------------
      # TLP
      #
      # TLP is now the only power daemon. `powerManagement.powertop` used to be
      # enabled alongside it, which runs `powertop --auto-tune` a few seconds
      # *after* TLP on every boot and silently overwrites TLP's AC profile --
      # including PCIE_ASPM_ON_AC, which was observably stuck at `default` instead
      # of the `powersupersave` the config asked for. The two tools are mutually
      # exclusive by design; TLP wins because it distinguishes AC from battery.
      # ---------------------------------------------------------------------------
      tlp = {
        enable = true;
        settings = {
          CPU_SCALING_GOVERNOR_ON_AC = "powersave";
          CPU_ENERGY_PERF_POLICY_ON_AC = "balance_power";
          PLATFORM_PROFILE_ON_AC = "balanced";

          # Now actually effective, because powertop no longer runs after TLP.
          PCIE_ASPM_ON_AC = "powersupersave";
          RUNTIME_PM_ON_AC = "on";
          SATA_LINKPWR_ON_AC = "med_power";
          WIFI_PWR_ON_AC = "on";
          USB_AUTOSUSPEND = 1;

          # Keep the battery between 40% and 80% while plugged in 24/7.
          START_CHARGE_THRESH_BAT0 = 40;
          STOP_CHARGE_THRESH_BAT0 = 80;
        };
      };

      # If the CPU ever sticks at 800MHz under load, disable this first: TLP and
      # thermald together are a known source of odd throttling on some Haswell
      # laptops.
      thermald.enable = true;

      # power-profiles-daemon would fight TLP for the same knobs.
      power-profiles-daemon.enable = false;
    };

    systemd = {
      # Masking the targets is what actually prevents suspend; logind's lid handling
      # alone would not. Verified after every switch with:
      #   systemctl is-enabled sleep.target   ->  masked
      targets = {
        sleep.enable = false;
        suspend.enable = false;
        hibernate.enable = false;
        "hybrid-sleep".enable = false;
      };

      services = {
        # A stale saved level must not survive a power cut, or a lid that was closed
        # when the machine died would restore a value forever.
        lid-backlight-init = {
          description = "Clear stale saved backlight level at boot";
          wantedBy = ["multi-user.target"];
          before = ["multi-user.target"];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pkgs.coreutils}/bin/rm -f /var/lib/server-state/backlight";
          };
        };

        # If the lid is already closed at boot, blank immediately rather than waiting
        # for an ACPI event that may never arrive.
        blank-backlight-if-lid-closed = {
          description = "Blank the panel if the lid is closed at boot";
          wantedBy = ["multi-user.target"];
          after = ["lid-backlight-init.service"];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${blankIfClosed}/bin/blank-if-lid-closed";
          };
        };
      };
    };

    powerManagement = {
      enable = true;
      cpuFreqGovernor = "powersave";
    };
  };
}
