import {spawn} from "node:child_process";
import {mkdir, readFile, rename, writeFile} from "node:fs/promises";
import {homedir} from "node:os";
import path from "node:path";

import {
  cooldownRemainingSeconds,
  emptyState,
  observe,
  parseState,
  type StoredState,
} from "./presence.ts";

const DISCORD_API = "https://discord.com/api/v10";
const DISCORD_GATEWAY = "wss://gateway.discord.gg/?v=10&encoding=json";
const GUILDS_INTENT = 1 << 0;
const GUILD_PRESENCES_INTENT = 1 << 8;

type LogLevel = "debug" | "info" | "warn" | "error";

interface Config {
  discordToken?: string;
  discordGuildId?: string;
  discordPresenceUserId?: string;
  discordPresenceLabel: string;
  discordPresenceRecipientId?: string;
  steamApiKey?: string;
  steamUserId?: string;
  steamVanityName?: string;
  steamLabel: string;
  steamDiscordRecipientId?: string;
  messageText: string;
  messageCooldownSeconds: number;
  steamPollSeconds: number;
  stateFile: string;
  dryRun: boolean;
}

interface GatewayPayload {
  op: number;
  d: unknown;
  s?: number | null;
  t?: string | null;
}

interface PresencePayload {
  guild_id?: string;
  status?: string;
  user?: {id?: string};
}

interface GuildCreatePayload {
  id?: string;
  unavailable?: boolean;
  presences?: PresencePayload[];
}

interface ReadyPayload {
  session_id?: string;
  resume_gateway_url?: string;
}

function log(level: LogLevel, event: string, details: Record<string, unknown> = {}): void {
  const line = JSON.stringify({
    timestamp: new Date().toISOString(),
    level,
    event,
    ...details,
  });
  (level === "error" ? console.error : console.log)(line);
}

function integerFromEnvironment(name: string, fallback: number, minimum: number): number {
  const raw = process.env[name];
  if (raw === undefined || raw.trim() === "") {
    return fallback;
  }

  const parsed = Number.parseInt(raw, 10);
  if (!Number.isSafeInteger(parsed) || parsed < minimum) {
    throw new Error(`${name} must be an integer greater than or equal to ${minimum}`);
  }
  return parsed;
}

function booleanFromEnvironment(name: string): boolean {
  return ["1", "true", "yes"].includes((process.env[name] ?? "").trim().toLowerCase());
}

function defaultStateFile(): string {
  const stateDirectory = process.env.STATE_DIRECTORY
    ?? path.join(process.env.XDG_STATE_HOME ?? path.join(homedir(), ".local", "state"), "presence-notifier");
  return path.join(stateDirectory, "state.json");
}

function loadConfig(): Config {
  const discordPresenceUserId = process.env.DISCORD_PRESENCE_USER_ID?.trim() || undefined;
  const messageText = process.env.MESSAGE_TEXT ?? "gramy?";
  if (messageText.trim() === "" || messageText.length > 2_000) {
    throw new Error("MESSAGE_TEXT must contain between 1 and 2000 characters");
  }
  return {
    discordToken: process.env.DISCORD_BOT_TOKEN?.trim() || undefined,
    discordGuildId: process.env.DISCORD_GUILD_ID?.trim() || undefined,
    discordPresenceUserId,
    discordPresenceLabel: process.env.DISCORD_PRESENCE_LABEL?.trim() || "Discord user",
    discordPresenceRecipientId:
      process.env.DISCORD_PRESENCE_RECIPIENT_ID?.trim() || discordPresenceUserId,
    steamApiKey: process.env.STEAM_WEB_API_KEY?.trim() || undefined,
    steamUserId: process.env.STEAM_USER_ID?.trim() || undefined,
    steamVanityName: process.env.STEAM_VANITY_NAME?.trim() || undefined,
    steamLabel: process.env.STEAM_LABEL?.trim() || "Steam user",
    steamDiscordRecipientId: process.env.STEAM_DISCORD_RECIPIENT_ID?.trim() || undefined,
    messageText,
    messageCooldownSeconds: integerFromEnvironment("MESSAGE_COOLDOWN_SECONDS", 21_600, 60),
    steamPollSeconds: integerFromEnvironment("STEAM_POLL_SECONDS", 60, 30),
    stateFile: process.env.PRESENCE_STATE_FILE?.trim() || defaultStateFile(),
    dryRun: booleanFromEnvironment("DRY_RUN") || process.argv.includes("--dry-run"),
  };
}

function configSummary(config: Config): Record<string, unknown> {
  const discordPresence = Boolean(
    config.discordToken && config.discordGuildId && config.discordPresenceUserId,
  );
  const steamPresence = Boolean(
    config.steamApiKey && (config.steamUserId || config.steamVanityName),
  );
  const discordMessage = Boolean(config.discordToken && config.discordPresenceRecipientId);
  const steamMessage = Boolean(config.discordToken && config.steamDiscordRecipientId);

  return {
    ready: (discordPresence || steamPresence)
      && (!discordPresence || discordMessage)
      && (!steamPresence || steamMessage),
    monitors: {
      discord: {
        ready: discordPresence,
        messageReady: discordMessage,
        messageMissing: [
          !config.discordToken && "DISCORD_BOT_TOKEN",
          !config.discordPresenceRecipientId && "DISCORD_PRESENCE_RECIPIENT_ID",
        ].filter(Boolean),
        label: config.discordPresenceLabel,
        missing: [
          !config.discordToken && "DISCORD_BOT_TOKEN",
          !config.discordGuildId && "DISCORD_GUILD_ID",
          !config.discordPresenceUserId && "DISCORD_PRESENCE_USER_ID",
        ].filter(Boolean),
      },
      steam: {
        ready: steamPresence,
        messageReady: steamMessage,
        messageMissing: [
          !config.discordToken && "DISCORD_BOT_TOKEN",
          !config.steamDiscordRecipientId && "STEAM_DISCORD_RECIPIENT_ID",
        ].filter(Boolean),
        label: config.steamLabel,
        missing: [
          !config.steamApiKey && "STEAM_WEB_API_KEY",
          !(config.steamUserId || config.steamVanityName) && "STEAM_USER_ID or STEAM_VANITY_NAME",
        ].filter(Boolean),
      },
      messenger: {
        ready: false,
        reason: "Meta does not provide an official personal-account presence API",
      },
    },
    outboundDiscordMessages: {
      botTokenConfigured: Boolean(config.discordToken),
      routes: {
        discordPresence: Boolean(config.discordPresenceRecipientId),
        steamPresence: Boolean(config.steamDiscordRecipientId),
      },
    },
    dryRun: config.dryRun,
    stateFile: config.stateFile,
  };
}

async function loadState(stateFile: string): Promise<StoredState> {
  try {
    return parseState(JSON.parse(await readFile(stateFile, "utf8")));
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== "ENOENT") {
      log("warn", "state_load_failed", {message: String(error)});
    }
    return emptyState();
  }
}

async function saveState(stateFile: string, state: StoredState): Promise<void> {
  await mkdir(path.dirname(stateFile), {recursive: true, mode: 0o700});
  const temporaryFile = `${stateFile}.tmp-${process.pid}`;
  await writeFile(temporaryFile, `${JSON.stringify(state, null, 2)}\n`, {mode: 0o600});
  await rename(temporaryFile, stateFile);
}

function notifyDesktop(label: string, source: string): void {
  const child = spawn(
    "notify-send",
    [
      "--app-name=Presence Notifier",
      "--icon=dialog-information",
      `${label} jest online`,
      `Wykryto aktywność w ${source}.`,
    ],
    {stdio: "ignore"},
  );
  child.on("error", (error) => log("warn", "desktop_notification_failed", {message: String(error)}));
  child.unref();
}

async function sleep(milliseconds: number): Promise<void> {
  await new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function discordRequest(
  config: Config,
  endpoint: string,
  body: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  if (!config.discordToken) {
    throw new Error("Discord bot token is not configured");
  }

  for (let attempt = 1; attempt <= 3; attempt += 1) {
    const response = await fetch(`${DISCORD_API}${endpoint}`, {
      method: "POST",
      headers: {
        Authorization: `Bot ${config.discordToken}`,
        "Content-Type": "application/json",
        "User-Agent": "DiscordBot (https://github.com/grajpap/nixos_config, 1.0)",
      },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(15_000),
    });

    const responseBody = await response.json().catch(() => ({})) as Record<string, unknown>;
    if (response.ok) {
      return responseBody;
    }

    if (response.status === 429 && attempt < 3) {
      const retrySeconds = typeof responseBody.retry_after === "number" ? responseBody.retry_after : 1;
      await sleep(Math.min(30_000, Math.ceil(retrySeconds * 1000)));
      continue;
    }
    if (response.status >= 500 && attempt < 3) {
      await sleep(attempt * 1_000);
      continue;
    }

    throw new Error(`Discord API ${endpoint} returned HTTP ${response.status}`);
  }

  throw new Error(`Discord API ${endpoint} failed after retries`);
}

async function sendDiscordMessage(config: Config, recipientId: string): Promise<void> {
  const channel = await discordRequest(config, "/users/@me/channels", {
    recipient_id: recipientId,
  });
  if (typeof channel.id !== "string") {
    throw new Error("Discord did not return a DM channel ID");
  }
  await discordRequest(config, `/channels/${channel.id}/messages`, {content: config.messageText});
}

class PresenceCoordinator {
  private queue: Promise<void> = Promise.resolve();
  private readonly config: Config;
  private readonly state: StoredState;

  constructor(config: Config, state: StoredState) {
    this.config = config;
    this.state = state;
  }

  record(
    sourceId: string,
    sourceName: string,
    label: string,
    recipientId: string | undefined,
    online: boolean,
  ): void {
    this.queue = this.queue
      .then(async () => {
        const transition = observe(this.state, sourceId, online);
        await saveState(this.config.stateFile, this.state);
        log("info", "presence_observed", {source: sourceName, label, online, transition});

        if (transition !== "online") {
          return;
        }

        notifyDesktop(label, sourceName);
        const remaining = cooldownRemainingSeconds(
          this.state,
          recipientId ?? "",
          Date.now(),
          this.config.messageCooldownSeconds,
        );
        if (remaining > 0) {
          log("info", "message_suppressed_by_cooldown", {remainingSeconds: remaining});
          return;
        }
        if (!this.config.discordToken || !recipientId) {
          log("warn", "message_not_configured", {source: sourceName});
          return;
        }
        if (this.config.dryRun) {
          log("info", "message_dry_run", {content: this.config.messageText});
          return;
        }

        await sendDiscordMessage(this.config, recipientId);
        this.state.lastMessageAtByRecipient[recipientId] = Date.now();
        await saveState(this.config.stateFile, this.state);
        log("info", "discord_message_sent", {content: this.config.messageText});
      })
      .catch((error) => log("error", "presence_action_failed", {message: String(error)}));
  }
}

class DiscordPresenceMonitor {
  private socket?: WebSocket;
  private sequence: number | null = null;
  private sessionId?: string;
  private resumeGatewayUrl?: string;
  private heartbeatTimer?: ReturnType<typeof setTimeout>;
  private heartbeatAcknowledged = true;
  private reconnectAttempts = 0;
  private stopped = false;
  private readonly config: Config;
  private readonly coordinator: PresenceCoordinator;

  constructor(config: Config, coordinator: PresenceCoordinator) {
    this.config = config;
    this.coordinator = coordinator;
  }

  start(): void {
    this.connect();
  }

  stop(): void {
    this.stopped = true;
    clearTimeout(this.heartbeatTimer);
    this.socket?.close(1000, "service stopping");
  }

  private connect(): void {
    const gateway = this.resumeGatewayUrl
      ? `${this.resumeGatewayUrl}?v=10&encoding=json`
      : DISCORD_GATEWAY;
    log("info", "discord_gateway_connecting", {resuming: Boolean(this.sessionId)});
    this.socket = new WebSocket(gateway);
    this.socket.addEventListener("message", (event) => void this.onMessage(event));
    this.socket.addEventListener("close", (event) => this.onClose(event));
    this.socket.addEventListener("error", () => log("warn", "discord_gateway_socket_error"));
  }

  private send(payload: Record<string, unknown>): void {
    if (this.socket?.readyState === WebSocket.OPEN) {
      this.socket.send(JSON.stringify(payload));
    }
  }

  private scheduleHeartbeat(interval: number): void {
    clearTimeout(this.heartbeatTimer);
    const tick = (): void => {
      if (!this.heartbeatAcknowledged) {
        log("warn", "discord_heartbeat_missed");
        this.socket?.close(4000, "heartbeat not acknowledged");
        return;
      }
      this.heartbeatAcknowledged = false;
      this.send({op: 1, d: this.sequence});
      this.heartbeatTimer = setTimeout(tick, interval);
    };
    this.heartbeatTimer = setTimeout(tick, Math.floor(Math.random() * interval));
  }

  private identifyOrResume(): void {
    if (this.sessionId && this.sequence !== null && this.config.discordToken) {
      this.send({
        op: 6,
        d: {
          token: this.config.discordToken,
          session_id: this.sessionId,
          seq: this.sequence,
        },
      });
      return;
    }

    this.send({
      op: 2,
      d: {
        token: this.config.discordToken,
        intents: GUILDS_INTENT | GUILD_PRESENCES_INTENT,
        properties: {
          os: "linux",
          browser: "presence-notifier",
          device: "presence-notifier",
        },
      },
    });
  }

  private async onMessage(event: MessageEvent): Promise<void> {
    let payload: GatewayPayload;
    try {
      payload = JSON.parse(String(event.data)) as GatewayPayload;
    } catch (error) {
      log("warn", "discord_gateway_invalid_payload", {message: String(error)});
      return;
    }

    if (typeof payload.s === "number") {
      this.sequence = payload.s;
    }

    if (payload.op === 10) {
      const hello = payload.d as {heartbeat_interval?: number};
      if (typeof hello.heartbeat_interval !== "number") {
        this.socket?.close(4000, "invalid hello payload");
        return;
      }
      this.heartbeatAcknowledged = true;
      this.scheduleHeartbeat(hello.heartbeat_interval);
      this.identifyOrResume();
      return;
    }
    if (payload.op === 11) {
      this.heartbeatAcknowledged = true;
      return;
    }
    if (payload.op === 1) {
      this.send({op: 1, d: this.sequence});
      return;
    }
    if (payload.op === 7) {
      this.socket?.close(4000, "gateway requested reconnect");
      return;
    }
    if (payload.op === 9) {
      if (payload.d === false) {
        this.sessionId = undefined;
        this.resumeGatewayUrl = undefined;
        this.sequence = null;
      }
      this.socket?.close(4000, "invalid session");
      return;
    }
    if (payload.op !== 0) {
      return;
    }

    if (payload.t === "READY") {
      const ready = payload.d as ReadyPayload;
      this.sessionId = ready.session_id;
      this.resumeGatewayUrl = ready.resume_gateway_url;
      this.reconnectAttempts = 0;
      log("info", "discord_gateway_ready");
      return;
    }
    if (payload.t === "RESUMED") {
      this.reconnectAttempts = 0;
      log("info", "discord_gateway_resumed");
      return;
    }
    if (payload.t === "GUILD_CREATE") {
      const guild = payload.d as GuildCreatePayload;
      if (guild.unavailable || guild.id !== this.config.discordGuildId) {
        return;
      }
      const targetPresence = guild.presences?.find(
        (presence) => presence.user?.id === this.config.discordPresenceUserId,
      );
      this.coordinator.record(
        `discord:${this.config.discordPresenceUserId}`,
        "Discord",
        this.config.discordPresenceLabel,
        this.config.discordPresenceRecipientId,
        targetPresence !== undefined && targetPresence.status !== "offline",
      );
      return;
    }
    if (payload.t === "PRESENCE_UPDATE") {
      const presence = payload.d as PresencePayload;
      if (
        presence.guild_id === this.config.discordGuildId
        && presence.user?.id === this.config.discordPresenceUserId
      ) {
        this.coordinator.record(
          `discord:${this.config.discordPresenceUserId}`,
          "Discord",
          this.config.discordPresenceLabel,
          this.config.discordPresenceRecipientId,
          presence.status !== "offline",
        );
      }
    }
  }

  private onClose(event: CloseEvent): void {
    clearTimeout(this.heartbeatTimer);
    if (this.stopped) {
      return;
    }

    if ([4004, 4013, 4014].includes(event.code)) {
      log("error", "discord_gateway_fatal_close", {
        code: event.code,
        reason: event.reason,
        hint: event.code === 4014 ? "Enable Presence Intent in the Discord Developer Portal" : undefined,
      });
      this.stopped = true;
      process.exitCode = 1;
      process.kill(process.pid, "SIGTERM");
      return;
    }

    this.reconnectAttempts += 1;
    const delay = Math.min(30_000, 1_000 * 2 ** Math.min(this.reconnectAttempts, 5));
    log("warn", "discord_gateway_closed", {code: event.code, reconnectInMs: delay});
    setTimeout(() => {
      if (!this.stopped) {
        this.connect();
      }
    }, delay);
  }
}

async function resolveSteamUserId(config: Config): Promise<string> {
  if (config.steamUserId) {
    return config.steamUserId;
  }
  if (!config.steamApiKey || !config.steamVanityName) {
    throw new Error("Steam API key and user ID or vanity name are required");
  }

  const url = new URL("https://api.steampowered.com/ISteamUser/ResolveVanityURL/v1/");
  url.searchParams.set("key", config.steamApiKey);
  url.searchParams.set("vanityurl", config.steamVanityName);
  const response = await fetch(url, {signal: AbortSignal.timeout(15_000)});
  if (!response.ok) {
    throw new Error(`Steam vanity lookup returned HTTP ${response.status}`);
  }
  const body = await response.json() as {response?: {success?: number; steamid?: string; message?: string}};
  if (body.response?.success !== 1 || !body.response.steamid) {
    throw new Error(body.response?.message ?? `Steam vanity name ${config.steamVanityName} was not found`);
  }
  return body.response.steamid;
}

async function pollSteam(config: Config, steamUserId: string): Promise<boolean> {
  const url = new URL("https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/");
  url.searchParams.set("key", config.steamApiKey ?? "");
  url.searchParams.set("steamids", steamUserId);
  const response = await fetch(url, {signal: AbortSignal.timeout(15_000)});
  if (!response.ok) {
    throw new Error(`Steam player lookup returned HTTP ${response.status}`);
  }
  const body = await response.json() as {response?: {players?: Array<{personastate?: number}>}};
  const player = body.response?.players?.[0];
  if (!player) {
    throw new Error("Steam did not return the configured player; check profile visibility and Steam ID");
  }
  return typeof player.personastate === "number" && player.personastate > 0;
}

function startSteamMonitor(
  config: Config,
  coordinator: PresenceCoordinator,
): {stop: () => void} {
  let stopped = false;
  let timer: ReturnType<typeof setTimeout> | undefined;

  const run = async (): Promise<void> => {
    try {
      const steamUserId = await resolveSteamUserId(config);
      const online = await pollSteam(config, steamUserId);
      coordinator.record(
        `steam:${steamUserId}`,
        "Steam",
        config.steamLabel,
        config.steamDiscordRecipientId,
        online,
      );
    } catch (error) {
      log("error", "steam_poll_failed", {message: String(error)});
    } finally {
      if (!stopped) {
        timer = setTimeout(() => void run(), config.steamPollSeconds * 1000);
      }
    }
  };

  void run();
  return {
    stop: () => {
      stopped = true;
      clearTimeout(timer);
    },
  };
}

async function main(): Promise<void> {
  let config: Config;
  try {
    config = loadConfig();
  } catch (error) {
    log("error", "invalid_configuration", {message: String(error)});
    process.exitCode = 2;
    return;
  }

  const summary = configSummary(config);
  if (process.argv.includes("--check-config")) {
    console.log(JSON.stringify(summary, null, 2));
    process.exitCode = summary.ready === true ? 0 : 2;
    return;
  }
  if (process.argv.includes("--status")) {
    console.log(JSON.stringify(await loadState(config.stateFile), null, 2));
    return;
  }

  const discordReady = Boolean(
    config.discordToken && config.discordGuildId && config.discordPresenceUserId,
  );
  const steamReady = Boolean(config.steamApiKey && (config.steamUserId || config.steamVanityName));
  if (!discordReady && !steamReady) {
    log("error", "no_presence_monitor_configured", {summary});
    process.exitCode = 2;
    return;
  }

  log("info", "service_starting", {summary});
  const state = await loadState(config.stateFile);
  const coordinator = new PresenceCoordinator(config, state);
  const discordMonitor = discordReady ? new DiscordPresenceMonitor(config, coordinator) : undefined;
  const steamMonitor = steamReady ? startSteamMonitor(config, coordinator) : undefined;
  discordMonitor?.start();

  await new Promise<void>((resolve) => {
    const stop = (): void => {
      discordMonitor?.stop();
      steamMonitor?.stop();
      resolve();
    };
    process.once("SIGINT", stop);
    process.once("SIGTERM", stop);
  });
  log("info", "service_stopped");
}

await main();
