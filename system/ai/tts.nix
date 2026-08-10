{pkgs, ...}: let
  piperPython = pkgs.python3.withPackages (ps: [
    ps.pyaudio
    ps.sounddevice
    ps.numpy
  ]);
in {
  environment.systemPackages = with pkgs; [
    piper-tts
    piperPython
  ];
}
