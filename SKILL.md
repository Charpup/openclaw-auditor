---
name: openclaw-auditor
description: >-
  TRIGGER: OpenClaw, openclaw.json, Galatea agent, openclaw doctor, config.apply,
  config.patch, ClawHub, openclaw-auditor, Gateway issues, audit OpenClaw config,
  schema validation, agent proposal review.
  Static configuration audit for OpenClaw — review agent proposals, validate
  openclaw.json changes, catch schema errors before execution. Use when: user
  shares an OpenClaw agent proposal for review, asks about openclaw.json config,
  channel integrations (Discord/Feishu/Telegram/WhatsApp), or any openclaw CLI
  config command. Default research entry: docs.openclaw.ai/llms.txt.
metadata:
  openclaw:
    emoji: "🔍"
    requires:
      bins: ["curl", "jq"]
      env: []
    os: ["linux", "macos", "windows"]
    install: []
---

# OpenClaw Auditor

Static config audit for OpenClaw (Galatea agent has high op privileges but limited schema awareness — Claude reviews proposals, catches errors before execution, suggests safer alternatives).

Counterpart skill: **openclaw-upgrade-ops** = orchestration / live incident response. When you'd call upgrade-ops: actually changing version, applying plugin, post-upgrade verification, troubleshooting live failures. When you'd call this skill: static review of a proposed config diff or Galatea agent proposal, no orchestration.

## Default research workflow

**Step 1 — always start with llms.txt** (the agent-friendly doc index, refreshed by upstream on every release):

```bash
bash scripts/fetch-llms-index.sh <topic>      # e.g. <topic>=channels.feishu, gateway, auth
# or directly:
curl -s https://docs.openclaw.ai/llms.txt | grep -i <topic>
```

llms.txt lists every doc page as plain markdown URLs — scan for relevance, then only fetch what matches:

```bash
bash scripts/fetch-doc.sh gateway/configuration
# or directly:
curl -s -H "Accept: text/markdown" https://docs.openclaw.ai/<path>
```

**Step 2 — fall back only if llms.txt doesn't surface the answer**:
- GitHub issues / discussions (search via WebSearch with `site:github.com/openclaw/openclaw/issues`)
- `https://github.com/Charpup/openclaw-config-validator` for authoritative JSON Schema
- `references/schema-quick-ref.md` (local snapshot — STABLE rules only, schema fields lag upstream)
- ClawHub (`https://clawhub.ai/skills`) before building anything custom

`references/resources.md` has the full link library + fetching protocol cheat sheet.

## Where to look (decision flow)

| If you're doing… | Read first |
|---|---|
| Reviewing an **agent proposal from Notion** | `references/audit-checklist.md` (5-step framework + Notion writeback template) |
| Diagnosing a **specific symptom** (`config validate FAILED: ...`, `401 despite env var`, etc.) | `references/symptom-index.md` (⌘F the literal string) |
| Auditing a proposed **`openclaw.json` diff** | `scripts/config-snapshot.sh` (capture baseline + baseHash) → `references/audit-checklist.md` step (c)/(d) |
| Wondering **why** a SOP rule exists (e.g. "why config.patch over config.apply?") | `references/success-patterns.md` (SP1–SP6 with rationale) |
| Looking for a **prior similar incident** | `examples/` (audit-perspective case studies, dated by event) |
| Need stable **node/risk reference** | `references/schema-quick-ref.md` (top-level node risk table + pre-modification checklist) |

## Audit process (5-step short form)

Full version with Notion writeback template lives in `references/audit-checklist.md`. Inline summary:

1. **Read the proposal** — understand the *intent* before the *diff*
2. **Identify risk level** — 🟢 workspace files / SOUL.md / skills · 🟡 channel/model/tool · 🔴 gateway/auth/sandbox/secrets/config.apply
3. **Validate against current schema** — fetch live via Step 1 above; never trust local schema-quick-ref for field names
4. **Research unknowns** — llms.txt → GitHub issues → DeepWiki, in that order
5. **Write back to Notion** — risk + issues + recommended commands + doc links (template in audit-checklist.md)

## Key safety rules

- `config.apply` replaces the **entire** config — prefer `config.patch` for partial updates (preserves per-agent overrides)
- Always recommend `bash scripts/config-snapshot.sh` before any change (captures backup + baseHash)
- `openclaw doctor` is the first diagnostic step for any startup failure
- Gateway refuses to start on invalid config — only diagnostic commands work in this state
- Never add fields that don't exist in the schema (most common Galatea mistake)
- Channel account keys vary: WhatsApp uses credential dirs, Telegram/Discord use `botToken` (NOT `token`)
- **`auth-profiles.json` priority > env vars** — rotating an env API key alone won't take effect (see `examples/audit-2026-04-08-f2-*`)
- **systemd unit drop-ins are also config surface** — PATH/Environment chunks count, audit them too (see `examples/audit-2026-04-27-f9-*`)

## Notion interaction protocol

- Notion is the bridge between Claude and the OpenClaw (Galatea) agent
- User provides Notion page links; read via Notion MCP tools
- Write audit results back to the same or linked page
- If page context is insufficient, ask user to request more from the agent — don't guess
- Keep instructions to the agent action-oriented and copy-paste executable
- For emergency overrides applied during incident response, **always include a TODO-revert marker** with target window (see `examples/audit-2026-04-28-f12-*` — the F12 Discord rate-limit workaround is still un-reverted because no marker was set)

## Coordination with openclaw-upgrade-ops

Upgrade-ops calls this skill when it needs to mutate `openclaw.json` mid-upgrade (e.g. migrating a deprecated field after a breaking schema change, or applying an emergency channel toggle). Don't bypass — that's how F1 (network field cascade) and F12 (un-marked Discord rollback) happened.

The shared authoritative source for failure modes F1–F12 lives in `~/claude_code_workspace/knowledge-base/openclaw/upgrade-runbook.md` §2. Both skills index into that table; this skill does **not** maintain its own copy.

## Anti-patterns (don't)

- ❌ Approve a `config.apply` proposal without first listing all current per-agent overrides (will be silently nuked)
- ❌ Trust the local `references/schema-quick-ref.md` for current schema fields — fetch llms.txt
- ❌ Audit only `openclaw.json` and skip systemd unit / drop-ins / `~/.openclaw/agents/*/auth-profiles.json` (they're all config surface)
- ❌ Approve emergency config changes without a TODO-revert marker + target window
- ❌ Recommend a fix without giving the user the rollback command in the same message

## Compounding the skill

When this skill is used and a new audit-relevant pattern surfaces (a class of mistake, a new schema breaking change, a non-obvious precedence rule):

1. Add a row to `references/symptom-index.md` (literal symptom → cause → one-line fix)
2. Add an SP entry to `references/success-patterns.md` if it's a positive rule worth following
3. Write a case study in `examples/audit-<YYYY-MM-DD>-<short-name>.md` using the existing template (context / timeline / root cause / what auditor would have caught / lessons)
4. If the precedence/risk affects existing auditor evals, add a row to `evals/evals.json`
5. Update `references/audit-checklist.md` only if the *process* changes, not the *content*

The point of `examples/` is that future-Claude inherits not just the rules but the reasoning — what the proposer's intent was, what the auditor missed (or caught), what the precedence chain actually was. Don't just write "F2 = check auth-profiles". Write what the user originally asked for, what assumption felt safe, when it broke. That's what compounds.

## Files this skill reads / writes

Reads:
- `references/*.md` (organized for fast access)
- `examples/*.md` (case studies for context)
- `~/.openclaw/openclaw.json` and `~/.openclaw/agents/*/agent/auth-profiles.json` (current state)
- `~/claude_code_workspace/knowledge-base/openclaw/upgrade-runbook.md` §2 (authoritative F-mode table)

Writes:
- Notion pages (audit results back to whatever page the user shared)
- `~/.openclaw/openclaw.json.bak.<TS>` via `scripts/config-snapshot.sh` (never edits the live config directly — recommends commands for the user to run)
