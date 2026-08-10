{pkgs, ...}: let
  hearingPython = pkgs.python3.withPackages (ps: [
    ps.faster-whisper
    ps.pyaudio
    ps.sounddevice
    ps.numpy
    ps.silero-vad
  ]);
in {
  environment.systemPackages = with pkgs; [
    hearingPython
    alsa-utils
    pulseaudio
    pipewire
  ];
}
