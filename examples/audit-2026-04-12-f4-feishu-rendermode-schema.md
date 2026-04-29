# Audit case 2026-04-12 — F4: Feishu renderMode 跨版本 schema 收窄

> **Why this case matters**: 跨版本升级的 schema 收窄是 OpenClaw 配置层最锐利的雷。zod `.strict()` 不接受向后兼容字段，`config validate` 直接拒启动。auditor 必须**对每个字段值**都走一次 llms.txt 比对，不能假设旧版允许的值现在还允许 — 这是 SP1（llms.txt-first）的核心来源。

## 提案上下文

用户场景：从 v2026.4.2 跨升到 v2026.4.11，跨过几个 minor patch。升级前用户给出的提案：

> 配置不变，直接 `npm install -g openclaw@2026.4.11` + restart 就行吧？我们 feishu channel 的 renderMode 一直是 "markdown"，用了好久了。

提案听起来非常合理 — "配置不变" 是最低风险的升级路径。但 v4.10 起 `feishu.renderMode` 用 zod `.enum(['auto', 'raw', 'card']).strict()` 校验，旧的 `markdown` 值在新版被直接拒绝。

## 实际发生（从 incident 复盘）

| 时间 | 事件 |
|---|---|
| 升级 | `npm install -g openclaw@2026.4.11` 成功 |
| 启动 | gateway 拒启动，`openclaw config validate` 报 `feishu.renderMode: invalid_enum_value`，期望 `auto/raw/card`，实际 `markdown` |
| 修复 | 编辑 `openclaw.json` 把 `feishu.renderMode: "markdown"` 改 `"auto"`，再 validate → start |

## 错误假设链

1. ❌ "config 跨版本兼容" — zod `.strict()` 不兼容
2. ❌ "minor patch 不会改 schema" — v4.10 是 minor patch，照样收窄了 enum
3. ❌ "字段名没变就 OK" — 字段名不变但**值的合法范围**收窄了

## auditor 应该看到 / 警告的

1. **跨多版本升级前必看 changelog**（`gh release list -R openclaw/openclaw` 或 `npm view openclaw@<version> --json`）
2. **对所有 channel / model / tool 字段**都跑一次 schema 比对：
   ```bash
   bash scripts/fetch-llms-index.sh feishu
   bash scripts/fetch-doc.sh gateway/configuration   # 找 feishu 节
   # 或更精确：
   curl -s https://raw.githubusercontent.com/Charpup/openclaw-config-validator/main/schema.json \
     | jq '.properties.channels.properties.feishu.properties.renderMode'
   ```
3. **`config validate --dry-run` 在升级前跑**（如果新版 CLI 已经装上但还没切换）：
   ```bash
   # 临时装新版到隔离目录
   npm install --prefix /tmp/openclaw-test openclaw@2026.4.11
   /tmp/openclaw-test/node_modules/.bin/openclaw config validate
   ```
4. **生成字段 diff 报告**：列出所有当前 openclaw.json 用到的字段值，对照新版 schema 检查每个值是否仍在 enum 内

## 应当给的命令（audit 写回模板填好版）

```bash
# 0. 备份
bash ~/.claude/skills/openclaw-auditor/scripts/config-snapshot.sh

# 1. 拉新版 schema（升级前）
bash scripts/fetch-doc.sh gateway/configuration > /tmp/new-schema.md

# 2. 列出当前所有字段值（关注 enum 字段）
jq '
  .channels // {} | to_entries[] | {channel: .key, fields: .value}
' ~/.openclaw/openclaw.json

# 3. 对照新 schema，找出收窄的字段（人工或脚本）
#    对 feishu.renderMode 这种 enum 字段尤其要查
grep -A5 -i 'renderMode' /tmp/new-schema.md

# 4. 提前修字段（在升级前就改）
openclaw config set channels.feishu.renderMode auto
openclaw config validate    # 当前版本应该 OK

# 5. 升级
npm install -g openclaw@2026.4.11

# 6. 立刻验证
openclaw config validate
openclaw doctor
```

## 回滚

```bash
# 完全回到改前
cp /root/.openclaw/openclaw.json.bak.<TS> /root/.openclaw/openclaw.json
npm install -g openclaw@2026.4.2   # 回原版本
systemctl --user restart openclaw-gateway
```

## 这个 case 沉淀为

- `references/symptom-index.md` — "config validate 报 invalid_enum_value 引用某字段" → F4
- `references/success-patterns.md` — SP1（llms.txt-first 研究）
- `references/audit-checklist.md` — Step (c) 字段路径检查必查 enum 收窄

## 通用判定：是否 schema breaking

满足以下三条 = F4：
1. `openclaw config validate` 非 0 退出
2. 错误信息里有 `invalid_enum_value` / `invalid_type` / `unrecognized_keys` 等 zod 关键字
3. 错误信息引用具体字段路径

修法是**改字段值**，不要改 schema 源码（会被下次升级覆盖）。

## 反例

如果 `config validate` 是因为缺字段（"required" 类错误）而不是字段值错，那是 plugin 安装/卸载的副作用，不是 schema breaking。修法是补齐字段或重装 plugin，不是改值。

## 给上游的反馈（如果将来 PR 回 OpenClaw repo）

1. **changelog 标 BREAKING**：v4.10 的 `feishu.renderMode` 收窄如果在 release notes 第一条写明 BREAKING + 给 migration 命令（`openclaw config set channels.feishu.renderMode auto`），用户根本不会撞墙
2. **`config validate` 在升级安装阶段 hook**：npm postinstall 跑一遍 validate，发现 schema 不兼容直接 abort 升级 + 提示 migration 步骤
