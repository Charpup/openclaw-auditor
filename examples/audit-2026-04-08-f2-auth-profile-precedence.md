# Audit case 2026-04-08 — F2: 轮换 API key 后仍 401

> **Why this case matters**: 用户看似做了完整的 key 轮换（改 env、重启 gateway），但实际上 `~/.openclaw/agents/<id>/agent/auth-profiles.json` 才是真正生效的源。**auth profile 优先级 > env vars**，且 `usageStats.errorCount` / `cooldownUntil` 字段还会让 cooldown 期内的旧失败状态继续阻塞 retry。这是 audit 时**最容易看漏**的精度损失，也是 SP3 的来源。

## 提案上下文（如果当时 auditor 被请进来）

用户场景：某 model provider 的 API key 因为额度用完被 rotate 了。用户的提案：

> 我已经把新的 key export 到 ANTHROPIC_API_KEY，systemctl restart gateway 也做了。Galatea 用 anthropic provider 还是 401，看上去 env 没生效。我准备 `openclaw config set models.anthropic.apiKey ${ANTHROPIC_API_KEY}` 直接写到 openclaw.json，可以吗？

提案听上去合理。但如果 auditor 直接批准这个 `config set`，仍然不会修好 — 因为问题不在 env / openclaw.json，问题在 agent 自己的 `auth-profiles.json`。

## 实际情况（从 MEMORY F2 行复盘）

OpenClaw 的 auth 优先级链：
```
agent/auth-profiles.json  >  global auth.profileOrder + auth.profiles  >  env vars
```

- `~/.openclaw/agents/<id>/agent/auth-profiles.json` 是每个 agent 自管理的认证档案，里面持有 provider key 的实际值
- 即使 env 改了，如果这里旧 key 还在，请求仍然带旧 key
- 此外 `usageStats.errorCount` 和 `cooldownUntil` 字段在 cooldown 期内会让 OpenClaw 主动跳过该 profile，即使 key 已经修对，也要等 cooldown 过期或手工清才行
- `models.anthropic.apiKey` 在 openclaw.json 顶层只是默认值，被 agent profile 覆盖

## 错误假设链（auditor 预审时容易踩的）

1. ❌ "用户已经 export 新 key，那 env 一定生效" — 不一定，profile 优先级更高
2. ❌ "改 openclaw.json 顶层 `models.<provider>.apiKey` 应该就够" — 仍然被 agent profile 覆盖
3. ❌ "重启 gateway 就会重新读 key" — 重启会重读 profile 文件，但 cooldown 状态在 profile 里持久化，重启不会清

## auditor 应该看到 / 警告的（如果当时被请进来）

1. **询问 affected agent ID**：用户说 "Galatea"，但宿主机有 `main` 和 `needy-angel` 两个 agent 实例。先 `ls ~/.openclaw/agents/` 列出来。
2. **检查每个相关 agent 的 auth-profiles.json**：
   ```bash
   jq '.profiles[] | select(.provider=="anthropic")' \
     ~/.openclaw/agents/main/agent/auth-profiles.json
   jq '.profiles[] | select(.provider=="anthropic")' \
     ~/.openclaw/agents/needy-angel/agent/auth-profiles.json
   ```
3. **三处必须同步改**（这是 SP3 的核心）：
   - env：`export ANTHROPIC_API_KEY=<new>`（持久化要写 `~/.bashrc` / systemd unit）
   - 每个 affected agent 的 `auth-profiles.json` 里对应 profile 的 `apiKey` 字段
   - 同 profile 的 `usageStats.errorCount = 0`，`cooldownUntil = null`
4. **不需要改 openclaw.json 顶层** — 那只是 fallback，主路径不走它

## 应当给的命令（audit 写回模板填好版）

```bash
# 1. 备份（auditor 永远先建议备份）
bash ~/.claude/skills/openclaw-auditor/scripts/config-snapshot.sh
# 还要备份 per-agent profiles（snapshot 脚本不覆盖）
cp -a ~/.openclaw/agents ~/.openclaw/agents.bak.$(date +%s)

# 2. 改 env（已做）
export ANTHROPIC_API_KEY=<new>

# 3. 改每个 affected agent 的 profile
for AGENT in main needy-angel; do
  PROFILE=~/.openclaw/agents/$AGENT/agent/auth-profiles.json
  jq --arg k "$ANTHROPIC_API_KEY" '
    .profiles |= map(
      if .provider == "anthropic" then
        .apiKey = $k
        | .usageStats = (.usageStats // {})
        | .usageStats.errorCount = 0
        | .usageStats.cooldownUntil = null
      else . end
    )
  ' "$PROFILE" > "$PROFILE.new" && mv "$PROFILE.new" "$PROFILE"
done

# 4. 重启 gateway 让 profile 重新加载
systemctl --user restart openclaw-gateway

# 5. 验证：在 Galatea 触发一个会用 anthropic 的小调用，看是否还 401
```

## 回滚

```bash
# 恢复 profiles
rm -rf ~/.openclaw/agents
mv ~/.openclaw/agents.bak.<TS> ~/.openclaw/agents
systemctl --user restart openclaw-gateway
```

## 这个 case 沉淀为

- `references/symptom-index.md` — "已经 export 了新的 API key 为什么还 401" 行
- `references/success-patterns.md` — SP3（Auth profile 优先级 > env vars）
- `references/audit-checklist.md` — Step (b) 强调 per-agent overrides snapshot

## 反例：什么时候改 env / openclaw.json 是够的

如果 agent 的 `auth-profiles.json` 里**没有**对应 provider 的 profile（比如某个新 provider 用户从未配置过），那就走 `auth.profileOrder` + env 的 fallback，env 改完 restart 就行。

判断标准：先 `jq '.profiles[].provider' ~/.openclaw/agents/<id>/agent/auth-profiles.json` 看 provider 列表。
