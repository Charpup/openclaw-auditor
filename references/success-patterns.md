# OpenClaw 审计 — 成功模式（SP-patterns）

> 失败模式提醒"这种提案要拒"，成功模式给出"这样审就对了"。每个 SP 都对应至少一个真实事件——见 `examples/audit-*.md`。
>
> 与 upgrade-ops 的 `success-patterns.md`（运行时 / 升级 SOP）互补但不重复 — 那边是 S1–S9 关于"怎么不出事"，这边是 SP1–SP6 关于"审计时怎么看才不漏"。

## SP1 — llms.txt-first 研究

**做法**：任何 OpenClaw 审计提案，第一步都是 `bash scripts/fetch-llms-index.sh <topic>` 找当前 doc 页路径，再 `bash scripts/fetch-doc.sh <path>` 拉具体页。

**为什么有效**：OpenClaw 迭代极快（v4.10 → v4.24 之间有过多次 schema 收窄）。任何本地缓存的 schema 表都会 lag。llms.txt 是 upstream 在每个 release 时刷新的索引，是当前 ground truth。

**适用范围**：所有审计开始的第一步；判断字段是否合法、值是否在 enum 内、新版本是否有 breaking change，都靠它。

**反例**：仅靠 `references/schema-quick-ref.md` 给字段名的判断 — 那张表标了"POSSIBLY OUTDATED"，靠它会错过 v4.10 起的 `feishu.renderMode` 收窄（参 `examples/audit-2026-04-12-f4-*`）。

**配套**：`scripts/fetch-llms-index.sh`、`scripts/fetch-doc.sh`。

## SP2 — config.patch over config.apply

**做法**：审到 `config.apply` 提案时，**默认拒绝**或**强制要求**先列出所有现有 per-agent override + baseHash + diff 全审完才放行。日常改字段一律推 `openclaw config set` 或 `config.patch`。

**为什么有效**：`config.apply` 是全量替换，会清掉 per-agent override + plugin 自动写入字段（如 `wizard.*`）。一旦丢失，agent 行为偏离不易归因（F7）。`config.patch` + baseHash 提供 optimistic concurrency，确保审过的 diff 才是被写的 diff。

**适用范围**：所有涉及 `config.apply` / "全量重写 openclaw.json" 的提案。

**反例**：批准了 agent 的 "我重新整理了一份完整 config" 提案 → per-agent model override 全没了，agent 全部回退到 default。

**配套**：审 apply 提案前必跑 `bash scripts/config-snapshot.sh` 抓 `audit-agents-<TS>.json`，这是恢复依据。

## SP3 — Auth profile 优先级 > env vars

**做法**：用户/agent 报"轮换了 API key 还 401" → 立刻怀疑 `~/.openclaw/agents/<id>/agent/auth-profiles.json`，不是 env vars 没生效。

**为什么有效**：OpenClaw auth 优先级链是：profile-specific > profile.priority > env vars。即使 env 改了，如果对应 agent 的 profile 仍持有旧 key，请求会先用 profile 里的旧值。再加上 `usageStats.errorCount` / `cooldownUntil` 字段在 cooldown 期内会进一步阻塞 retry。

**适用范围**：所有 401 / 429 / "key 看上去对但还失败" 类问题。

**反例**：只看 env，忽略 profile，导致用户改了 5 次 env 还 401（参 `examples/audit-2026-04-08-f2-*`）。

**配套**：三连修复 = 改 env + 改对应 agent 的 `auth-profiles.json` + 清 `usageStats.errorCount` / `cooldownUntil`。

## SP4 — 配置面 ≠ 仅 openclaw.json

**做法**：审计任何 OpenClaw 改动时，把以下都视为配置面：
- `~/.openclaw/openclaw.json` — 主 config
- `~/.openclaw/agents/<id>/agent/auth-profiles.json` — 每个 agent 的认证（SP3）
- `~/.openclaw/agents/<id>/agent/SOUL.md` / AGENTS.md — agent 提示
- `/root/.config/systemd/user/openclaw-gateway.service.d/*.conf` — systemd drop-in（PATH / Environment）
- `~/.openclaw/credentials/<channel>/<account>/` — channel 凭据目录
- `~/.openclaw/extensions/*/` — plugin 配置（部分 plugin 自管 JSON）

**为什么有效**：agent 通常只改 openclaw.json；但运行时行为受所有这些文件影响。F9（systemd PATH 引用 nvm `current` symlink 不存在）就是 systemd drop-in 没审到的典型——主 config 里看不出问题，但 lazy npm install 全死。

**适用范围**：任何"为什么配置改了行为没变 / 没生效" / "升级后行为变" 类问题。

**反例**：只看 openclaw.json，把"plugin 启动失败"归因到 plugin bug，实际是 systemd PATH（参 `examples/audit-2026-04-27-f9-*`）。

## SP5 — baseHash 必带

**做法**：任何 `config.patch` / `config.apply` 提案，命令里必须含从 `openclaw gateway call config.get` 拿到的 `baseHash`。审计时检查 — 没带就拒。

**为什么有效**：baseHash 是 OpenClaw 实现的 optimistic concurrency 锁。改之前 gateway 已经被另一个进程修改过，patch 会因为 hash 不匹配被拒，避免无声覆盖。`scripts/config-snapshot.sh` 自动抓 baseHash 写到 `audit-basehash-<TS>.txt`。

**适用范围**：所有 patch / apply 提案。

**反例**：手工写 patch JSON 没带 baseHash → 撞上 plugin/agent 同时改 config 的窗口，覆盖对方改动（少见但很难定位）。

## SP6 — Notion 写回必含 rollback + TODO

**做法**：审计结果写回 Notion 时，**永远**包含两块：(a) 完整 rollback 命令（不只是说"你可以 cp 回去"，要给具体路径 + restart 命令）；(b) 如果是应急临时改，加 TODO-revert 标记 + 目标窗口（"什么时候改回 / 改成什么"）。

**为什么有效**：agent 接到 Notion 指令后会照做，但通常不会主动思考"这个临时改什么时候回滚"。F12 应急关 Discord native commands 至今未回滚（已经一天多了），就是因为审计时没标 TODO。

**适用范围**：所有写回 Notion 的审计意见，特别是应急性改动。

**反例**：临时关一个安全特性"等会儿再开"，结果一周后才想起 — 期间一直跑在不安全状态（参 `examples/audit-2026-04-28-f12-*`）。

**配套**：模板见 `references/audit-checklist.md` Step (e)。

## "新发现成功模式" 怎么沉淀

发现一个"这次审对了"的时刻：
1. 在本文件加 SP（做法 / 为什么 / 适用 / 反例 / 配套）
2. 如果有可自动化的命令，加到 `scripts/`
3. 如果对应一个真实事件，写一个 `examples/audit-<date>-*.md`
4. 必要时更新 `audit-checklist.md`（仅当流程变了，规则变了不用更）

成功模式不像失败模式那么显眼 — 多数时候是"事情没爆"。所以在"这次我多查了一步而避免了一个雷"的时候**主动**记下来。
