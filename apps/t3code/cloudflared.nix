# cloudflared for the T3 Connect tunnel.
#
# T3 refuses any cloudflared older than 2026.10.3 ("T3CODE_CLOUDFLARED_PATH
# must point to cloudflared 2026.10.3 or newer") and the host then shows as
# unreachable. nixpkgs-stable and the locked unstable are both older, and the
# source build needs a newer Go than the lock has, so use the upstream static
# binary. Bump it when T3 raises the floor again.
{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "cloudflared";
  version = "2026.11.1";

  src = fetchurl {
    url = "https://github.com/cloudflare/cloudflared/releases/download/${finalAttrs.version}/cloudflared-linux-amd64";
    hash = "sha256-l7s7AtI6WYD8nBWhonDmktoZI/ED+SDVsW1JMdWrVec=";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/cloudflared"
    runHook postInstall
  '';

  meta = {
    description = "Cloudflare Tunnel client, upstream release binary";
    homepage = "https://github.com/cloudflare/cloudflared";
    license = lib.licenses.asl20;
    mainProgram = "cloudflared";
    platforms = ["x86_64-linux"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
})
