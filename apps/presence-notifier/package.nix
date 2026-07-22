{
  lib,
  libnotify,
  makeWrapper,
  nodejs,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation {
  pname = "presence-notifier";
  version = "1.0.0";
  src = ./.;

  nativeBuildInputs = [
    makeWrapper
    nodejs
  ];

  dontBuild = true;
  doCheck = true;

  checkPhase = ''
    runHook preCheck
    node --test test/*.test.ts
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -d "$out/share/presence-notifier" "$out/bin"
    cp -r README.md package.json src "$out/share/presence-notifier/"
    makeWrapper ${nodejs}/bin/node "$out/bin/presence-notifier" \
      --add-flags "$out/share/presence-notifier/src/main.ts" \
      --prefix PATH : ${lib.makeBinPath [libnotify]}
    runHook postInstall
  '';

  meta = {
    description = "Discord and Steam presence notifier with rate-limited Discord messages";
    homepage = "https://github.com/grajpap/nixos_config";
    license = lib.licenses.gpl3Plus;
    mainProgram = "presence-notifier";
    platforms = lib.platforms.linux;
  };
}
