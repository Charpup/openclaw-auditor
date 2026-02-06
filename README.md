# 🦞 OpenClaw Auditor

> **Claude-side audit skill for reviewing OpenClaw agent proposals and troubleshooting configuration issues**

A safety net and quality auditor for [OpenClaw](https://github.com/openclaw/openclaw) agent operations. This skill enables Claude (claude.ai) to act as an external auditor for OpenClaw agents, catching configuration errors before execution and providing better alternatives.

## 🎯 Purpose

OpenClaw agents have high operational privileges but limited schema awareness, frequently breaking their own configuration. This skill provides:

- **Proposal Review**: Audit agent-generated configuration changes before execution
- **Error Prevention**: Catch schema violations and dangerous operations
- **Best Practices**: Recommend safer alternatives and proper approaches
- **Troubleshooting**: Diagnose and fix broken OpenClaw configurations

## 🔧 Use Cases

This skill triggers when:

1. 📄 User shares a Notion page containing an OpenClaw agent's proposal for review/audit
2. ⚙️ User asks about OpenClaw configuration, troubleshooting, or architecture
3. 🦞 User mentions OpenClaw, Galatea (agent name), `openclaw.json`, or Gateway issues
4. 🔌 User asks to review or fix broken channel integrations (Discord, Feishu, Telegram, WhatsApp, etc.)
5. 🛠️ User references `config.apply`, `config.patch`, `openclaw doctor`, or any OpenClaw CLI command

## 📚 What's Inside

### Core Files

- **[`SKILL.md`](./SKILL.md)** - Main skill instructions for Claude
  - Audit process workflow
  - Research methodology
  - Safety rules and best practices
  - Notion interaction protocol

### Reference Materials

- **[`references/schema-quick-ref.md`](./references/schema-quick-ref.md)** - Quick reference guide
  - 22 top-level config nodes overview
  - Config modification methods comparison
  - Critical pitfalls and forbidden patterns
  - Pre-modification checklist

- **[`references/resources.md`](./references/resources.md)** - Resource index
  - Official documentation links
  - Community resources
  - Skills ecosystem
  - Search strategies

## 🚀 How to Use

### For Claude Users (claude.ai)

1. **Install the skill** in your Claude environment
2. **Share a Notion page** containing your OpenClaw agent's proposal
3. **Ask Claude to audit** the proposal using this skill
4. **Review the audit results** and recommendations
5. **Execute approved changes** with confidence

### For OpenClaw Agents

This skill is designed to work **alongside** your OpenClaw agent (e.g., Galatea) via Notion as a communication bridge:

1. Agent generates a proposal and writes it to Notion
2. User shares the Notion page with Claude
3. Claude audits the proposal using this skill
4. Claude writes audit results back to Notion
5. Agent reads the audit and adjusts approach if needed

## 🛡️ Key Safety Rules

- ⚠️ `config.apply` replaces the ENTIRE config. Prefer `config.patch` for partial updates
- 💾 Always backup before changes: `cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak`
- 🩺 `openclaw doctor` is the first diagnostic step for any startup failure
- 🚫 Never add fields that don't exist in the schema (common agent mistake)
- 🔑 Channel account keys vary: WhatsApp uses credential dirs, Telegram/Discord use `botToken`

## 📖 Research Workflow

When encountering an OpenClaw problem, the skill follows this priority order:

1. **Check local references first** - Quick reference and resources index
2. **Fetch official documentation** - Latest docs from docs.openclaw.ai
3. **Search GitHub Issues and Discussions** - Community solutions
4. **Check ClawHub** - Existing skills to avoid reinventing the wheel
5. **Consult config-validator skill** - Complete schema validation

## 🎨 Risk Assessment

The skill categorizes proposed changes by risk level:

- 🟢 **Low risk**: workspace files, SOUL.md, AGENTS.md, skill installation
- 🟡 **Medium risk**: channel config, model settings, tool policies
- 🔴 **High risk**: gateway settings, auth config, `config.apply`, sandbox settings

## 🤝 Integration with OpenClaw Ecosystem

This skill complements:

- **[openclaw-config-validator](https://github.com/Charpup/openclaw-config-validator)** - Schema validation and docs
- **[OpenClaw Gateway](https://github.com/openclaw/openclaw)** - The core OpenClaw project
- **[ClawHub](https://clawhub.ai/skills)** - Skills registry

## 📦 Installation

### As a Claude Skill

```bash
# Copy SKILL.md to your Claude skills directory
cp SKILL.md ~/.claude/skills/openclaw-auditor/

# Or use the ClawHub installer (if available)
clawhub install openclaw-auditor
```

### As a Reference

Simply bookmark this repository and reference it when working with OpenClaw configurations.

## 🔗 Related Resources

- **OpenClaw Documentation**: https://docs.openclaw.ai
- **OpenClaw GitHub**: https://github.com/openclaw/openclaw
- **ClawHub Skills**: https://clawhub.ai/skills
- **Config Validator**: https://github.com/Charpup/openclaw-config-validator

## 👤 Author

**Charpup** - Working with Galatea 🦞🜁 (OpenClaw agent)

## 📄 License

This skill is provided as-is for use with Claude and OpenClaw agents.

---

<div align="center">

**Built for the OpenClaw ecosystem** 🦞

*Helping agents help themselves (safely)*

</div>
