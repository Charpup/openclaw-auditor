# 🔍 OpenClaw Auditor

> **A Claude Code Skill for static audit of [OpenClaw](https://github.com/openclaw/openclaw) configuration and agent proposals.** llms.txt-first research, F1–F12 failure-mode index, and a real-world audit case library.

[![Claude Code Skill](https://img.shields.io/badge/Claude%20Code-Skill-D97757?logo=anthropic&logoColor=white)](https://docs.claude.com/en/docs/claude-code/skills)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](./LICENSE)
[![Latest Release](https://img.shields.io/github/v/release/Charpup/openclaw-auditor?include_prereleases&label=release)](https://github.com/Charpup/openclaw-auditor/releases)
[![Last Commit](https://img.shields.io/github/last-commit/Charpup/openclaw-auditor)](https://github.com/Charpup/openclaw-auditor/commits/main)
[![Target: OpenClaw v2026.4.24+](https://img.shields.io/badge/OpenClaw-v2026.4.24%2B-blue)](https://docs.openclaw.ai)
[![Skill Format](https://img.shields.io/badge/skill--creator-standard-purple)](https://github.com/anthropics/skills)

---

## What it does

OpenClaw agents (e.g. Galatea) hold high operational privileges but have limited schema awareness — they routinely propose changes that will break their own gateway, lose per-agent overrides, or rotate keys in the wrong place. This skill makes Claude an external auditor that:

- **Reviews proposals** before they're applied (catches schema violations, forbidden patterns, scope creep)
- **Researches live** via `docs.openclaw.ai/llms.txt` — never trusts stale local field tables
- **Runs through a 5-step checklist** (research → snapshot → schema diff → risk score → Notion writeback)
- **Indexes prior incidents** into a symptom-based lookup (`config validate FAILED: …` → which F-mode → one-line fix)
- **Carries case studies** of real audits (F2, F4, F9, F12) so future-Claude inherits the *reasoning*, not just the rules

Designed to pair with [`openclaw-upgrade-ops`](https://github.com/Charpup/openclaw-upgrade-ops) (orchestration / live incident response). This skill = *static review*, that one = *active operations*.

## Install

```bash
git clone https://github.com/Charpup/openclaw-auditor ~/.claude/skills/openclaw-auditor
```

Claude Code auto-discovers skills under `~/.claude/skills/`. The skill triggers on keywords like `OpenClaw`, `openclaw.json`, `config.apply`, `Galatea`, `openclaw doctor`, "audit OpenClaw config", "agent proposal review", etc.

**Requires** on the host: `curl`, `jq`. Optional: `openclaw` CLI (for `config-snapshot.sh` to extract `baseHash`); Python 3 + PyYAML (for `scripts/quick_validate.py`, install via `pip install pyyaml`).

`scripts/config-snapshot.sh` honors `OPENCLAW_HOME` (default `$HOME/.openclaw`) and `LOG_DIR` (default `$OPENCLAW_HOME/upgrade-logs`) — so non-root installs work out of the box.

## What's inside

```
openclaw-auditor/
├── SKILL.md                                    # Skill entry — router-style, llms.txt-first
├── references/
│   ├── symptom-index.md                        # User-described symptoms → F-mode → 1-line fix
│   ├── audit-checklist.md                      # 5-step framework + Notion writeback template
│   ├── success-patterns.md                     # SP1–SP6 (rule + why + when + counter-example)
│   ├── schema-quick-ref.md                     # Top-level node risk table (stable rules only)
│   └── resources.md                            # Doc URLs, fetching protocol cheat sheet
├── examples/                                   # Real audit cases (timeline + wrong assumptions + lessons)
│   ├── audit-2026-04-08-f2-auth-profile-precedence.md
│   ├── audit-2026-04-12-f4-feishu-rendermode-schema.md
│   ├── audit-2026-04-27-f9-systemd-path-stale.md
│   └── audit-2026-04-28-f12-discord-emergency-rollback.md
├── scripts/
│   ├── fetch-llms-index.sh                     # Default first action — index of all current docs
│   ├── fetch-doc.sh                            # Fetch a doc page as clean Markdown
│   ├── config-snapshot.sh                      # Backup + baseHash + per-agent overrides snapshot
│   └── quick_validate.py                       # SKILL.md frontmatter validator
└── evals/
    └── evals.json                              # 6 test cases (groupPolicy, doctor, scope, F4, F2, config.apply trap)
```

Layout follows the [skill-creator standard](https://github.com/anthropics/skills/tree/main/skill-creator).

## Quick example

When a user shares a Notion page with a Galatea proposal like *"I'll set `channels.feishu.renderMode = 'invoice'` so Feishu messages render as invoice cards"*, the skill will:

1. `bash scripts/fetch-llms-index.sh feishu` → list current Feishu doc pages
2. `bash scripts/fetch-doc.sh gateway/configuration` → read live schema; identify `renderMode` is now restricted to `auto/raw/card`
3. Reject the proposal, suggest `card` instead, write back to Notion with: risk level + explanation + ready-to-run `openclaw config set ...` command + rollback command
4. Reference [`examples/audit-2026-04-12-f4-feishu-rendermode-schema.md`](./examples/audit-2026-04-12-f4-feishu-rendermode-schema.md) for the precedent

See [`references/audit-checklist.md`](./references/audit-checklist.md) for the full 5-step framework and the Notion writeback template.

## Companion skill

[`openclaw-upgrade-ops`](https://github.com/Charpup/openclaw-upgrade-ops) — orchestration of OpenClaw npm upgrades, post-upgrade smoke tests, and live incident response (F1–F12 lookup, recipes, scripts). The two skills cross-reference and share the authoritative failure-mode runbook.

| Concern | This skill (auditor) | upgrade-ops |
|---|---|---|
| Static review of a config proposal | ✅ | ❌ |
| Active version upgrade orchestration | ❌ | ✅ |
| Post-upgrade smoke test (T1–T10) | ❌ | ✅ |
| Symptom → F-mode lookup | ✅ (audit angle) | ✅ (runtime angle) |
| Incident case studies | ✅ (audit angle) | ✅ (ops angle) |

The **authoritative F1–F12 failure-mode taxonomy** lives in a runbook outside both skills (the operator's local `knowledge-base/openclaw/upgrade-runbook.md`); each skill cross-references it from its own angle — this skill organizes runbook content for review-time risk classification, upgrade-ops organizes the same content for fast symptom-driven access during live incidents. When a new failure mode is discovered, both skills get updated together (see each repo's "Compounding the skill" section).

**See also (paired case studies)** — every audit case here has an ops-side counterpart in `openclaw-upgrade-ops/examples/`, so you can read both perspectives on the same incident:

| F-mode | This skill (audit perspective) | upgrade-ops (ops perspective) |
|---|---|---|
| F4 | [`audit-2026-04-12-f4-feishu-rendermode-schema.md`](./examples/audit-2026-04-12-f4-feishu-rendermode-schema.md) | [`incident-2026-04-12-f4-schema-renderMode.md`](https://github.com/Charpup/openclaw-upgrade-ops/blob/main/examples/incident-2026-04-12-f4-schema-renderMode.md) |
| F9 | [`audit-2026-04-27-f9-systemd-path-stale.md`](./examples/audit-2026-04-27-f9-systemd-path-stale.md) | [`incident-2026-04-27-v4.24-upgrade-f9.md`](https://github.com/Charpup/openclaw-upgrade-ops/blob/main/examples/incident-2026-04-27-v4.24-upgrade-f9.md) |
| F12 | [`audit-2026-04-28-f12-discord-emergency-rollback.md`](./examples/audit-2026-04-28-f12-discord-emergency-rollback.md) | [`incident-2026-04-28-f10-f11-f12-chain.md`](https://github.com/Charpup/openclaw-upgrade-ops/blob/main/examples/incident-2026-04-28-f10-f11-f12-chain.md) |

When in doubt about which skill to invoke: are you *reviewing* a proposed change before it's applied? this skill. Are you *executing* a change (or already mid-incident)? upgrade-ops.

## Compounding the skill

When a new audit-relevant pattern surfaces (a class of mistake, a precedence rule, a schema breaking change), update in this order:

1. Add a row to `references/symptom-index.md`
2. Add an SP entry to `references/success-patterns.md` if it's a positive rule
3. Write a case study in `examples/audit-<YYYY-MM-DD>-<short-name>.md`
4. Add an eval row in `evals/evals.json` if precedence affects existing test cases
5. Update `references/audit-checklist.md` only when the *process* changes

Full guidelines in [`SKILL.md` § "Compounding the skill"](./SKILL.md).

## Contributing

Issues and PRs welcome. For a new failure pattern, please include:
- The literal symptom (error string, log line, or user-described behavior)
- A short timeline of the wrong-then-right diagnosis path
- The sustained fix + rollback command

## License

[MIT](./LICENSE) © 2026 Charpup
