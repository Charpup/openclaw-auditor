---
name: openclaw-auditor
description: >
  Audit OpenClaw agent proposals and troubleshoot OpenClaw configuration issues.
  Trigger when: (1) user shares a Notion page containing an OpenClaw agent's proposal for review/audit,
  (2) user asks about OpenClaw configuration, troubleshooting, or architecture,
  (3) user mentions OpenClaw, Galatea (agent name), openclaw.json, or Gateway issues,
  (4) user asks to review or fix broken channel integrations (Discord, Feishu, Telegram, WhatsApp, etc.),
  (5) user references config.apply, config.patch, openclaw doctor, or any OpenClaw CLI command.
  This skill is for Claude (claude.ai) acting as an external auditor for OpenClaw agent outputs,
  using Notion as the communication bridge between Claude and the OpenClaw agent.
---

# OpenClaw Auditor

## Purpose

Act as a safety net and quality auditor for OpenClaw agent (Galatea) operations. The agent has
high operational privileges but limited schema awareness, frequently breaking its own configuration.
Claude reviews agent proposals, catches errors before execution, and provides better alternatives.

## Research Workflow

When encountering an OpenClaw problem, follow this priority order:

### 1. Check local references first
- Read `references/schema-quick-ref.md` for config node overview and common pitfalls
- Read `references/resources.md` for the full resource index

### 2. Fetch official documentation
- Primary: `https://docs.openclaw.ai/gateway/configuration`
- Config examples: `https://docs.openclaw.ai/gateway/configuration-examples`
- Troubleshooting: `https://docs.openclaw.ai/gateway/troubleshooting`
- Doctor: `https://docs.openclaw.ai/gateway/doctor`
- Use `web_fetch` on these URLs to get the latest information

### 3. Search GitHub Issues and Discussions
- Issues: `https://github.com/openclaw/openclaw/issues` — search for error messages or symptoms
- Discussions: `https://github.com/openclaw/openclaw/discussions` — search for community solutions
- Use `web_search` with queries like: `site:github.com/openclaw/openclaw/issues <error_keyword>`

### 4. Check ClawHub for existing skills
- Registry: `https://clawhub.ai/skills`
- Awesome list: `https://github.com/VoltAgent/awesome-openclaw-skills`
- Search before building custom solutions to avoid reinventing the wheel

### 5. Check the config-validator skill
- Schema reference: `https://github.com/Charpup/openclaw-config-validator`
- Contains complete schema docs for OpenClaw 2026.2.1+ (22 top-level nodes)
- Includes validation scripts and forbidden fields list

## Audit Process

When reviewing an agent proposal from a Notion page:

1. **Read the Notion page** — understand what the agent proposes to do and why
2. **Identify risk level** — categorize the proposed changes:
   - 🟢 Low risk: workspace files, SOUL.md, AGENTS.md, skill installation
   - 🟡 Medium risk: channel config, model settings, tool policies
   - 🔴 High risk: gateway settings, auth config, config.apply (full replace), sandbox settings
3. **Validate against schema** — check proposed config changes against known schema structure
4. **Research if needed** — follow the research workflow above for unfamiliar areas
5. **Write audit result back to Notion** — include:
   - Risk assessment
   - Issues found (if any)
   - Recommended approach (if different from proposal)
   - Relevant documentation links
   - Specific commands or config snippets ready for execution

## Key Safety Rules

- `config.apply` replaces the ENTIRE config. Prefer `config.patch` for partial updates.
- Always recommend `cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak` before changes.
- `openclaw doctor` is the first diagnostic step for any startup failure.
- Gateway refuses to start on invalid config — only diagnostic commands work in this state.
- Never add fields that don't exist in the schema (common agent mistake).
- Channel account keys vary: WhatsApp uses credential dirs, Telegram/Discord use `botToken`.

## Notion Interaction Protocol

- Notion is the bridge between Claude and the OpenClaw agent
- User provides Notion page links; read via Notion MCP tools
- Write audit results and instructions back to the same or linked Notion pages
- If context on a Notion page is insufficient, ask the user to request more detail from the agent
- Keep instructions to the agent action-oriented and executable
