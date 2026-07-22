import assert from "node:assert/strict";
import test from "node:test";

import {
  cooldownRemainingSeconds,
  emptyState,
  observe,
  parseState,
} from "../src/presence.ts";

test("the first observation establishes a baseline", () => {
  const state = emptyState();

  assert.equal(observe(state, "discord:123", true), "baseline");
  assert.equal(observe(state, "discord:123", true), "unchanged");
});

test("an offline to online change emits one transition", () => {
  const state = emptyState();

  assert.equal(observe(state, "steam:456", false), "baseline");
  assert.equal(observe(state, "steam:456", true), "online");
  assert.equal(observe(state, "steam:456", true), "unchanged");
  assert.equal(observe(state, "steam:456", false), "offline");
});

test("the message cooldown is isolated per recipient", () => {
  const state = emptyState();
  state.lastMessageAtByRecipient.alice = 10_000;

  assert.equal(cooldownRemainingSeconds(state, "alice", 11_000, 10), 9);
  assert.equal(cooldownRemainingSeconds(state, "alice", 20_000, 10), 0);
  assert.equal(cooldownRemainingSeconds(state, "alice", 25_000, 10), 0);
  assert.equal(cooldownRemainingSeconds(state, "bob", 11_000, 10), 0);
});

test("invalid persisted fields are ignored", () => {
  assert.deepEqual(
    parseState({
      version: 1,
      statuses: {discord: true, broken: "yes"},
      lastMessageAtByRecipient: {alice: 12_000, broken: "yesterday"},
    }),
    {
      version: 1,
      statuses: {discord: true},
      lastMessageAtByRecipient: {alice: 12_000},
    },
  );
});
