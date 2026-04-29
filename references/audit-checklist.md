# OpenClaw 审计 — 5 步实操 Checklist + Notion 写回模板

> 用法：用户分享 Notion 页面（含 Galatea agent 提案）或粘贴一段 `openclaw.json` 改动诉求，按本 checklist 逐项做完，最后用底部模板把审计结果写回 Notion。

## Step (a) — 拉 llms.txt 并定位相关页

**永远从这里开始。** 本地 references 可能滞后。

```bash
# 1. 全量索引（识别该提案涉及哪些 doc 节）
bash scripts/fetch-llms-index.sh

# 2. 关键词过滤（按提案涉及的 schema 节点 / channel / 命令）
bash scripts/fetch-llms-index.sh channels.feishu
bash scripts/fetch-llms-index.sh auth.profiles
bash scripts/fetch-llms-index.sh gateway.bind

# 3. 拉具体页（路径来自 llms.txt 命中行）
bash scripts/fetch-doc.sh gateway/configuration
bash scripts/fetch-doc.sh cli/config
```

**判定**：拉到的 markdown 页里是否有提案改动涉及的字段？字段值的合法范围与提案一致？记下出处行号 / 段落，后面写回 Notion 要引用。

## Step (b) — 抓当前配置基线 + baseHash

```bash
bash scripts/config-snapshot.sh
```

输出：
- `~/.openclaw/openclaw.json.bak.<TS>` — 完整备份
- `~/.openclaw/upgrade-logs/audit-snapshot-pretty-<TS>.json` — 排序后的 pretty JSON（diff 用）
- `~/.openclaw/upgrade-logs/audit-basehash-<TS>.txt` — 含 `baseHash`，**任何 `config.patch` / `config.apply` 都必须带这个 hash**
- `~/.openclaw/upgrade-logs/audit-agents-<TS>.json` — per-agent override 快照（catch F7）

**判定**：提案改动的字段在当前 config 里的值是什么？有没有 per-agent 覆盖会被这次改动影响？

## Step (c) — 对比 schema + 字段路径检查

把提案的 diff 与 Step (a) 拉到的当前 schema 比对，重点查：

| 检查项 | 怎么查 |
|---|---|
| 字段路径是否存在 | llms.txt 命中页里 ⌘F 字段名（注意 dot.path 全写）|
| 字段值是否在合法 enum / 类型范围 | 新版 zod schema 常见 `.enum([...])` `.literal()` `.refine()` |
| 是否引入旧版才允许、新版已收窄的值 | F4 模式 — 见 `examples/audit-2026-04-12-f4-*` |
| 是否 typo（如 `token` vs `botToken`） | symptom-index.md 列了 Galatea 高频 typo |
| 是否漏掉强相关字段（如改 `gateway.bind` 没改 `gateway.controlUi.allowedOrigins`） | F1 网络级联 — `references/symptom-index.md` 有清单 |
| 是否同时影响 systemd unit / drop-in / `auth-profiles.json` | 配置面 ≠ 仅 openclaw.json |

**关键问句**：
- 如果这次改动 100% 按字面应用，啥情况下 gateway 会拒启动？
- 啥情况下 gateway 启动了但行为不符提案预期？
- 哪些 per-agent override 会被无声覆盖？

## Step (d) — 风险分级评分卡

给整个提案打一个风险等级。**取最高的那一项**。

| 维度 | 🟢 Low | 🟡 Medium | 🔴 High |
|---|---|---|---|
| 改动范围 | workspace 文件 / SOUL.md / AGENTS.md / skills 安装 | 单 channel / model / tool 设置 | gateway / auth / sandbox / secrets / `config.apply` |
| 可逆性 | git revert 即可 | `openclaw config set` 一行回滚 | 需要 backup + restart |
| 影响半径 | 单 agent | 多 agent / 单 channel | 全 gateway / 所有 channel |
| 失败模式关联 | 无 | F2 / F4 / F7 之一 | F1 / F3 / 任何含 secrets / auth |
| 是否首次 | 已有先例 | 类似先例 | 新模式 |

**🔴 一律要求**：backup（Step b）+ baseHash + 明确 rollback 命令 + 改动后立即 `openclaw doctor`

**🟡 要求**：backup + 至少 `openclaw config validate` dry-run

**🟢 可直接执行**，但仍建议 backup（成本极低）

## Step (e) — 写回 Notion

把审计结果写回 Notion 用以下模板（直接 copy-paste，按提案改字段）：

```markdown
# 🔍 OpenClaw Auditor 审查结果

**提案**：<一句话概括 agent 想做什么>
**风险等级**：🟢 / 🟡 / 🔴 <一句话理由>
**审计时间**：<YYYY-MM-DD HH:MM TZ>
**当前 baseHash**：`<from audit-basehash-<TS>.txt>`
**关联失败模式**：<F1-F12 的相关编号，或"无">

## 发现的问题

1. <字段 / 命令 / 路径> — <问题描述>
   - 出处：[docs.openclaw.ai/<path> §<段>](https://docs.openclaw.ai/<path>)
   - 后果：<gateway 拒启动 / 静默 override 丢失 / channel 行为偏离 / ...>

## 建议方案

<比提案更安全的等价做法。如果提案本身 OK，就写"提案 OK，按下方命令执行即可"。>

### 执行命令（按顺序）

```bash
# 1. 备份
bash ~/.claude/skills/openclaw-auditor/scripts/config-snapshot.sh

# 2. 改动（patch 优先，apply 仅在必要时）
openclaw config set <dotpath> <value>
# 或：
openclaw gateway call config.patch --params '{"baseHash":"<HASH>","patch":{...}}'

# 3. 立刻验证
openclaw config validate
openclaw doctor

# 4. 重启（如果改动需要 — 一般 channel 设置需要）
systemctl --user restart openclaw-gateway
```

### 回滚命令（如果改后行为不符）

```bash
# 完全回到改前
cp ~/.openclaw/openclaw.json.bak.<TS> ~/.openclaw/openclaw.json
systemctl --user restart openclaw-gateway

# 或按字段反向 set
openclaw config set <dotpath> <old-value>
```

## TODO（如有）

- [ ] <如果是应急临时改，记 TODO-revert 标记 + 目标窗口，例如 "2026-04-29 12:00 后改回 native=true"> 
- [ ] <如果发现新失败模式，按 SKILL.md "Compounding" 沉淀>

## 参考

- llms.txt 命中页：<list>
- 相关 audit 案例：`examples/audit-<YYYY-MM-DD>-*.md`
- runbook §2 F-mode 表：`~/claude_code_workspace/knowledge-base/openclaw/upgrade-runbook.md`
```

## 写回 Notion 的注意事项

- 命令一定要 copy-paste 可执行（包括正确的 quoting / heredoc）
- baseHash 必须填具体值，不要留 `<HASH>` 占位（agent 不会自己去找）
- rollback 命令必须给 — 没给就等于没审计
- 如果是 🔴 High 风险，标题加 ⚠️，正文顶部第一句明示"审计意见：建议拒绝 / 建议修改后再执行"
- 应急临时改动的 TODO-revert 必须写清楚"什么时候改回 / 改回成什么"，不然 F12 那种"忘了回滚"的情况会重演
