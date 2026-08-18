{pkgs, ...}: let
  jarvisPython = pkgs.python3.withPackages (ps: [
    ps.opencv4
    ps.pillow
    ps.numpy
    ps.requests
    ps.faster-whisper
    ps.pyaudio
    ps.sounddevice
    ps.chromadb
    ps.psutil
    ps.pyyaml
    ps.aiohttp
    ps.websockets
    ps.silero-vad
    ps.beautifulsoup4
    ps.lxml
  ]);
in {
  environment.systemPackages = with pkgs; [
    jarvisPython
    git
    jq
    curl
    wget
    xh
    libnotify
    inotify-tools
    alsa-utils
    pulseaudio
    pipewire
    piper-tts
    v4l-utils
    ollama-vulkan
    grim
    slurp
    ydotool
    wtype
    wl-clipboard
    chromium
    playwright
  ];

  users.users.grajpap.extraGroups = [
    "audio"
    "video"
    "input"
    "libvirtd"
    "docker"
  ];

  security.rtkit.enable = true;
}
