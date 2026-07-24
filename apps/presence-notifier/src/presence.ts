export type Transition = "baseline" | "online" | "offline" | "unchanged";

export interface DiscordPresenceSnapshot {
  status?: string;
  user?: {id?: string};
}

export interface StoredState {
  version: 1;
  statuses: Record<string, boolean>;
  lastMessageAtByRecipient: Record<string, number>;
}

export function emptyState(): StoredState {
  return {
    version: 1,
    statuses: {},
    lastMessageAtByRecipient: {},
  };
}

export function parseState(value: unknown): StoredState {
  if (typeof value !== "object" || value === null) {
    return emptyState();
  }

  const candidate = value as Partial<StoredState>;
  if (candidate.version !== 1 || typeof candidate.statuses !== "object" || candidate.statuses === null) {
    return emptyState();
  }

  const statuses: Record<string, boolean> = {};
  for (const [source, online] of Object.entries(candidate.statuses)) {
    if (typeof online === "boolean") {
      statuses[source] = online;
    }
  }

  const lastMessageAtByRecipient: Record<string, number> = {};
  if (
    typeof candidate.lastMessageAtByRecipient === "object"
    && candidate.lastMessageAtByRecipient !== null
  ) {
    for (const [recipientId, timestamp] of Object.entries(candidate.lastMessageAtByRecipient)) {
      if (typeof timestamp === "number" && Number.isFinite(timestamp)) {
        lastMessageAtByRecipient[recipientId] = timestamp;
      }
    }
  }

  return {
    version: 1,
    statuses,
    lastMessageAtByRecipient,
  };
}

export function observe(state: StoredState, source: string, online: boolean): Transition {
  const previous = state.statuses[source];
  state.statuses[source] = online;

  if (previous === undefined) {
    return "baseline";
  }
  if (previous === online) {
    return "unchanged";
  }
  return online ? "online" : "offline";
}

export function discordGuildMatches(
  configuredGuildId: string | undefined,
  eventGuildId: string | undefined,
): boolean {
  return eventGuildId !== undefined
    && (configuredGuildId === undefined || eventGuildId === configuredGuildId);
}

export function discordGuildPresenceStatus(
  presences: DiscordPresenceSnapshot[] | undefined,
  targetUserId: string,
  guildIsExplicitlyConfigured: boolean,
): boolean | undefined {
  const targetPresence = presences?.find((presence) => presence.user?.id === targetUserId);
  if (targetPresence !== undefined) {
    return targetPresence.status !== "offline";
  }
  return guildIsExplicitlyConfigured ? false : undefined;
}

export function cooldownRemainingSeconds(
  state: StoredState,
  recipientId: string,
  now: number,
  cooldownSeconds: number,
): number {
  const lastMessageAt = state.lastMessageAtByRecipient[recipientId];
  if (lastMessageAt === undefined) {
    return 0;
  }

  const remainingMilliseconds = lastMessageAt + cooldownSeconds * 1000 - now;
  return Math.max(0, Math.ceil(remainingMilliseconds / 1000));
}
