import { createHash, randomBytes } from "node:crypto";
import { createServer } from "node:http";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { spawn } from "node:child_process";
import { chmod, mkdir, readFile, rename, writeFile } from "node:fs/promises";

const clientId = "d420a117a32841c2b3474932e49fb54b";
const redirectUri = "http://127.0.0.1:8989/login";
const cacheRoot = process.env.XDG_CACHE_HOME || join(homedir(), ".cache");
const tokenPath = join(cacheRoot, "quickshell", "spotify-picker-token.json");
const compatibleTokenPath = join(cacheRoot, "spotify-player", "user_client_token.json");

function print(payload) {
  process.stdout.write(`${JSON.stringify(payload)}\n`);
}

function base64Url(value) {
  return value.toString("base64url");
}

function expiryFrom(token) {
  if (Number.isFinite(Number(token.expiresAt)))
    return Number(token.expiresAt);
  if (typeof token.expires_at === "string")
    return Date.parse(token.expires_at);
  return 0;
}

function normalizedToken(token) {
  return {
    accessToken: token.accessToken || token.access_token || "",
    refreshToken: token.refreshToken || token.refresh_token || "",
    expiresAt: expiryFrom(token),
    scope: token.scope || "",
  };
}

async function readJson(path) {
  try {
    return JSON.parse(await readFile(path, "utf8"));
  } catch {
    return null;
  }
}

async function saveToken(token) {
  const normalized = normalizedToken(token);
  await mkdir(dirname(tokenPath), { recursive: true, mode: 0o700 });
  const temporaryPath = `${tokenPath}.${process.pid}.tmp`;
  await writeFile(temporaryPath, `${JSON.stringify(normalized)}\n`, { mode: 0o600 });
  await chmod(temporaryPath, 0o600);
  await rename(temporaryPath, tokenPath);
}

async function loadToken() {
  const ownToken = await readJson(tokenPath);
  if (ownToken)
    return normalizedToken(ownToken);

  const compatibleToken = await readJson(compatibleTokenPath);
  if (!compatibleToken)
    return null;

  const normalized = normalizedToken(compatibleToken);
  if (normalized.accessToken && normalized.refreshToken)
    await saveToken(normalized);
  return normalized;
}

async function refreshToken(token) {
  if (!token?.refreshToken)
    throw new Error("auth_required");

  const body = new URLSearchParams({
    client_id: clientId,
    grant_type: "refresh_token",
    refresh_token: token.refreshToken,
  });
  const response = await fetch("https://accounts.spotify.com/api/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body,
  });
  if (!response.ok)
    throw new Error("auth_required");

  const fresh = await response.json();
  const next = {
    accessToken: fresh.access_token,
    refreshToken: fresh.refresh_token || token.refreshToken,
    expiresAt: Date.now() + Number(fresh.expires_in || 3600) * 1000,
    scope: fresh.scope || token.scope,
  };
  await saveToken(next);
  return next;
}

async function validToken() {
  let token = await loadToken();
  if (!token?.accessToken)
    throw new Error("auth_required");
  if (!token.expiresAt || token.expiresAt <= Date.now() + 60_000)
    token = await refreshToken(token);
  return token;
}

async function search(query) {
  const token = await validToken();
  const url = new URL("https://api.spotify.com/v1/search");
  url.searchParams.set("q", query);
  url.searchParams.set("type", "track");
  url.searchParams.set("limit", "8");

  let response = await fetch(url, {
    headers: { authorization: `Bearer ${token.accessToken}` },
  });
  if (response.status === 401) {
    const refreshed = await refreshToken(token);
    response = await fetch(url, {
      headers: { authorization: `Bearer ${refreshed.accessToken}` },
    });
  }
  if (!response.ok)
    throw new Error(`spotify_${response.status}`);

  const payload = await response.json();
  return (payload.tracks?.items || []).map(track => ({
    id: track.id || "",
    uri: track.uri || `spotify:track:${track.id}`,
    title: track.name || "Unknown title",
    artists: (track.artists || []).map(artist => artist.name).join(", "),
    album: track.album?.name || "",
    image: track.album?.images?.[0]?.url || "",
    durationMs: Number(track.duration_ms || 0),
    explicit: Boolean(track.explicit),
  }));
}

function callbackPage(title, message, color) {
  return `<!doctype html>
<html lang="en">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${title}</title>
<style>
  :root { color-scheme: dark; font-family: Inter, system-ui, sans-serif; }
  body { min-height: 100vh; margin: 0; display: grid; place-items: center; background: #1e1e2e; color: #cdd6f4; }
  main { width: min(420px, calc(100% - 48px)); padding: 28px; border: 1px solid #45475a; border-radius: 18px; background: #181825; box-shadow: 0 20px 70px #11111b99; }
  b { color: ${color}; font-size: 20px; } p { color: #a6adc8; line-height: 1.55; margin-bottom: 0; }
</style>
<main><b>${title}</b><p>${message}</p></main>`;
}

async function authenticate() {
  const verifier = base64Url(randomBytes(64));
  const challenge = base64Url(createHash("sha256").update(verifier).digest());
  const state = base64Url(randomBytes(20));
  const authorizeUrl = new URL("https://accounts.spotify.com/authorize");
  authorizeUrl.searchParams.set("client_id", clientId);
  authorizeUrl.searchParams.set("response_type", "code");
  authorizeUrl.searchParams.set("redirect_uri", redirectUri);
  authorizeUrl.searchParams.set("code_challenge_method", "S256");
  authorizeUrl.searchParams.set("code_challenge", challenge);
  authorizeUrl.searchParams.set("state", state);

  let timeout;
  const code = await new Promise((resolve, reject) => {
    const server = createServer((request, response) => {
      const callbackUrl = new URL(request.url || "/", redirectUri);
      if (callbackUrl.pathname !== "/login") {
        response.writeHead(404).end();
        return;
      }
      if (callbackUrl.searchParams.get("state") !== state) {
        response.writeHead(400, { "content-type": "text/html; charset=utf-8" });
        response.end(callbackPage("Connection rejected", "The authorization state did not match. Return to the widget and try again.", "#f38ba8"));
        clearTimeout(timeout);
        server.close();
        reject(new Error("oauth_state"));
        return;
      }
      const authCode = callbackUrl.searchParams.get("code");
      if (!authCode) {
        response.writeHead(400, { "content-type": "text/html; charset=utf-8" });
        response.end(callbackPage("Connection cancelled", "Spotify did not return an authorization code.", "#fab387"));
        clearTimeout(timeout);
        server.close();
        reject(new Error("oauth_cancelled"));
        return;
      }
      response.writeHead(200, { "content-type": "text/html; charset=utf-8" });
      response.end(callbackPage("Spotify connected", "You can close this tab and return to the music widget.", "#a6e3a1"));
      clearTimeout(timeout);
      server.close();
      resolve(authCode);
    });

    server.on("error", error => {
      clearTimeout(timeout);
      reject(error);
    });
    server.listen(8989, "127.0.0.1", () => {
      const browser = spawn("xdg-open", [authorizeUrl.toString()], {
        detached: true,
        stdio: "ignore",
      });
      browser.unref();
    });
    timeout = setTimeout(() => {
      server.close();
      reject(new Error("oauth_timeout"));
    }, 300_000);
  });

  const body = new URLSearchParams({
    client_id: clientId,
    grant_type: "authorization_code",
    code,
    redirect_uri: redirectUri,
    code_verifier: verifier,
  });
  const response = await fetch("https://accounts.spotify.com/api/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body,
  });
  if (!response.ok)
    throw new Error(`token_${response.status}`);

  const token = await response.json();
  await saveToken({
    accessToken: token.access_token,
    refreshToken: token.refresh_token,
    expiresAt: Date.now() + Number(token.expires_in || 3600) * 1000,
    scope: token.scope || "",
  });
}

async function main() {
  const command = process.argv[2] || "status";
  if (command === "status") {
    const token = await loadToken();
    print({ ok: true, authenticated: Boolean(token?.accessToken && token?.refreshToken) });
    return;
  }
  if (command === "authenticate") {
    await authenticate();
    print({ ok: true, authenticated: true });
    return;
  }
  if (command === "search") {
    const query = process.argv.slice(3).join(" ").trim();
    if (query.length < 2) {
      print({ ok: false, code: "query_short", message: "Type at least two characters" });
      return;
    }
    print({ ok: true, authenticated: true, tracks: await search(query) });
    return;
  }
  throw new Error("unknown_command");
}

main().catch(error => {
  const code = error.message === "auth_required" ? "auth_required" : "request_failed";
  const message = code === "auth_required"
    ? "Connect Spotify to search its catalogue"
    : "Spotify search is temporarily unavailable";
  print({ ok: false, code, message });
  process.exitCode = 1;
});
