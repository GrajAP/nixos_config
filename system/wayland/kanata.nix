# Home-row mods on every desktop. Hosts only set
# services.kanata.keyboards.internalKeyboard.devices. Keep the keyboard name:
# quickshell and home/scripts/katana-switch drive
# kanata-internalKeyboard.service by name.
{
  services.kanata = {
    enable = true;
    keyboards.internalKeyboard = {
      extraArgs = ["--nodelay"];
      extraDefCfg = "process-unmapped-keys yes";
      config = ''
        (defsrc
          caps a s d f j k l ; rmet
        )
        (defvar
          tap-time 200
          hold-time 200
        )
        (defalias
          escctrl (tap-hold $tap-time $hold-time esc lctl)
          a (tap-hold $tap-time $hold-time a lalt)
          s (tap-hold $tap-time $hold-time s ralt)
          d (tap-hold $tap-time $hold-time d lsft)
          f (tap-hold $tap-time $hold-time f lctl)
          j (tap-hold $tap-time $hold-time j lctl)
          k (tap-hold $tap-time $hold-time k lsft)
          l (tap-hold $tap-time $hold-time l ralt)
          ; (tap-hold $tap-time $hold-time ; lalt)
        )
        (deflayer base
          @escctrl @a @s @d @f @j @k @l @; lalt
        )
      '';
    };
  };
}
