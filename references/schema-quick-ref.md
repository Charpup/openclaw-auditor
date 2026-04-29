# OpenClaw Config Schema Quick Reference

> ⚠️ **OUTDATED FOR FIELD NAMES — STABLE FOR PROCESS RULES**
>
> Last refreshed against OpenClaw 2026.2.26+. **Schema fields drift on every minor release** (e.g. `channels.feishu.renderMode` was narrowed to `auto/raw/card` in v4.10 — see `../examples/audit-2026-04-12-f4-feishu-rendermode-schema.md`).
>
> **For current schema** — always fetch live:
> ```bash
> bash ../scripts/fetch-llms-index.sh <topic>     # find relevant doc pages
> bash ../scripts/fetch-doc.sh gateway/configuration   # read clean markdown
> ```
>
> **What this file IS still good for**:
> - Top-level node risk levels (🟢/🟡/🔴) — these are stable across versions
> - The "config modification methods" table — `config.apply` vs `config.patch` semantics haven't changed
> - Pre-modification checklist — generic safety steps
> - Forbidden patterns / common Galatea mistakes — these recur across versions
>
> **What this file is NOT good for**: field names, enum values, required keys, schema validation. Use llms.txt for those.

Based on OpenClaw 2026.2.26+ as a snapshot. For current schema, fetch `https://docs.openclaw.ai/gateway/configuration`.

## Config File

- Path: `~/.openclaw/openclaw.json` (JSON5, comments + trailing commas allowed)
- Validation: Zod schema (`OpenClawSchema`), strict — unknown keys cause Gateway to refuse to start
- Recovery: `openclaw doctor` → `openclaw doctor --fix`

## Top-Level Nodes (23 total)

| Node | Risk | Purpose |
|------|------|---------|
| `agents` | 🟡 | Agent defaults, per-agent overrides, identity, workspace, sandbox, tools |
| `models` | 🟡 | Provider configs, custom base URLs, API keys (use env vars) |
| `session` | 🟡 | Session scoping, history limits, context behavior |
| `commands` | 🟢 | Chat command handling |
| `channels.whatsapp` | 🟡 | WhatsApp: allowFrom, dmPolicy, groups, accounts, readReceipts |
| `channels.telegram` | 🟡 | Telegram: botToken, accounts, groups, allowFrom |
| `channels.discord` | 🟡 | Discord: botToken, accounts, guilds |
| `channels.slack` | 🟡 | Slack: socket mode config |
| `channels.feishu` | 🟡 | Feishu/Lark integration |
| `channels.googlechat` | 🟡 | Google Chat: webhook config |
| `channels.signal` | 🟡 | Signal: signal-cli integration |
| `channels.imessage` | 🟡 | iMessage: imsg CLI |
| `channels.mattermost` | 🟡 | Mattermost: bot token |
| `messages` | 🟢 | Prefixes, ack reactions, TTS, queue, inbound settings |
| `tools` | 🟡 | Tool policies, agentToAgent, exec settings |
| `browser` | 🟢 | Managed browser config |
| `hooks` | 🟡 | Gateway webhooks |
| `talk` | 🟢 | Voice mode (macOS/iOS/Android) |
| `skills` | 🟢 | Skills directory config |
| `plugins` | 🟡 | Extension plugins |
| `bindings` | 🟡 | Multi-agent message routing |
| `gateway` | 🔴 | Server bind, port, auth, reload — RARELY modify |
| `logging` | 🟢 | Log level, file path, console style, redaction |
| `env` | 🟢 | Env vars, shellEnv opt-in |
| `auth` | 🔴 | Auth profiles, provider order — sensitive |
| `wizard` | 🟢 | Metadata from CLI wizards (auto-managed) |
| `ui` | 🟢 | Appearance settings |
| `cron` | 🟡 | Scheduled jobs and wake events |
| `discovery` | 🟡 | mDNS/Bonjour broadcast, wide-area DNS-SD |
| `canvasHost` | 🟢 | LAN Canvas file server |
| `secrets` | 🔴 | Secret provider config (`secrets.providers`, `secrets.defaults`) — credential storage |

## Config Modification Methods

| Method | Scope | Risk | Use when |
|--------|-------|------|----------|
| `config.patch` | Partial merge | 🟡 | Changing specific keys (PREFERRED) |
| `config.apply` | Full replace | 🔴 | Complete config rewrite (DANGEROUS) |
| `openclaw config set` | Single key | 🟢 | Quick single-value change |
| `openclaw configure` | Interactive wizard | 🟢 | Guided section-by-section update |
| Manual JSON edit | Full file | 🟡 | Complex changes with backup |

## Critical Pitfalls

### Forbidden patterns (common agent mistakes)
- Adding non-existent fields (e.g., `web.braveApiKey` — doesn't exist)
- Modifying `gateway.port` without understanding implications
- Using `config.apply` when `config.patch` suffices (overwrites entire config)
- Putting `token` instead of `botToken` for Telegram/Discord accounts
- Mixing up channel-level vs account-level settings

### Pre-modification checklist
1. Backup: `cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak.$(date +%s)`
2. Read current config: `openclaw gateway call config.get --params '{}'`
3. Validate proposed changes against schema
4. Use `config.patch` (not `config.apply`) for partial changes
5. Include `baseHash` from config.get in patch/apply calls
6. After change: `openclaw doctor` to verify
7. Check logs: `grep -i error /tmp/openclaw/openclaw-gateway.log | tail -20`

### Channel-specific gotchas
- **WhatsApp**: Credentials stored in `~/.openclaw/credentials/whatsapp/<accountId>/`
- **Telegram**: Uses `botToken` (NOT `token`), env var only applies to `default` account
- **Discord**: Uses `botToken`, guild-based group policies
- **Feishu**: App ID + App Secret based authentication
- **Multi-account**: All channels support `accounts` object with per-account overrides

## Environment Variable Substitution

Config supports `${VAR_NAME}` syntax (uppercase only, resolved at load time).
Missing vars cause load failure. Escape with `$${VAR}` for literals.

## Config Includes

`$include` directive for splitting configs:
- Single file: replaces containing object
- Array of files: deep-merged in order
- Nested includes supported (max 10 levels)
- Relative paths resolve from including file
