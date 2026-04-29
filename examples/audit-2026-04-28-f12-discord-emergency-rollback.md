# Audit case 2026-04-28 — F12: Discord deploy rate-limit 应急绕过 + TODO-revert

> **Why this case matters**: 应急修复中 auditor 经常被请来"快速批一个临时改动让生产恢复"。批准本身往往是对的，但**没标 TODO-revert 就会留尾巴**。F12 这次的 `channels.discord.commands.{native,nativeSkills}=false` 改完到现在（撰写时已超 24h）仍没回滚 — 因为当时 audit 没要求加 TODO 标记。这是 SP6（Notion 写回必含 rollback + TODO）的反面教材。

## 提案上下文

事件链 F10（mirror lag）→ F11（共享 node_modules 截断）修完后，F12 暴露：Discord 的 `PUT /applications/<app>/commands` 因为前面累计 6 次 restart 命中 IP/token rate-limit，单次部署耗 125s 以上，超过 OpenClaw 的 `channelConnectGraceMs=120s`，channel 进入 deploy timeout → abort → restart → deploy timeout 死循环。从 Discord 客户端看 bot 一直 offline。

紧急时刻用户的请求：

> Discord 一直起不来，能不能临时关 slash command 部署？我看 channels.discord.commands 下有 native / nativeSkills 字段。

提案合理 — Discord 的 slash command 确实是可选的，关掉就跳过 deploy 直接连 WebSocket。

## auditor 当时**做对了**的部分

1. ✅ 判断改动**确实**能解决问题（关 deploy 跳过 rate-limit 阻塞点）
2. ✅ 给出了正确的命令（`openclaw config set channels.discord.commands.native false` + `nativeSkills false`）
3. ✅ 提醒先 backup（`cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak`）
4. ✅ 给出了即时验证命令（`openclaw channels status` 看 Discord 状态）

## auditor 当时**做错了**的部分

1. ❌ **没加 TODO-revert 标记** — 没说明"什么时候改回 / 改成什么"。
2. ❌ **没建议加 reminder timer** — 系统里没有任何机制提醒"该回滚了"。
3. ❌ **没在 MEMORY / Notion / changelog 任何一处明确标注这是 emergency override**。
4. ❌ **rollback 命令只在脑子里，没写到 Notion** — 哪天想回滚要重新查命令。

## 实际后果（撰写本文档时）

- `~/.openclaw/openclaw.json` 里 `channels.discord.commands.native = false` + `nativeSkills = false` 已经持续 24 小时以上
- Discord rate-limit 窗口（~15-30 分钟）早就过去了
- Galatea 通过 Discord 时**没有 slash command** — 用户用文本 prefix 触发是 fallback，但 / 命令完全没法用
- MEMORY 里有一行 "TODO" 标注，但没有自动机制提醒 — 全靠用户/Claude 偶然想起

## 应该写回的 audit 模板（事后补的）

```markdown
# 🔍 OpenClaw Auditor 审查结果

**提案**：临时关 Discord slash command 部署，绕过 deploy timeout
**风险等级**：🟡 Medium（应急合理但是 security feature 削弱）
**审计时间**：2026-04-28 12:51 CST
**关联失败模式**：F12

## 发现的问题

无 — 提案本身合理。但属于 **emergency override**，必须有回滚计划。

## 建议方案

批准。但加以下条件：

### 执行命令

```bash
# 1. 备份
cp /root/.openclaw/openclaw.json /root/.openclaw/openclaw.json.bak.f12-emergency-$(date +%s)

# 2. 改字段
openclaw config set channels.discord.commands.native false
openclaw config set channels.discord.commands.nativeSkills false

# 3. 重启
systemctl --user restart openclaw-gateway

# 4. 验证
openclaw channels status | grep -i discord
```

### ⚠️ 回滚命令（**必跑**，不是可选）

Discord rate-limit 窗口约 15-30 分钟。窗口过后必须恢复，否则 slash command 永远不可用。

```bash
# 当 Discord rate-limit 窗口过期后（~13:30 CST 之后）
openclaw config unset channels.discord.commands.native       # 或 set true
openclaw config unset channels.discord.commands.nativeSkills # 或 set true
systemctl --user restart openclaw-gateway

# 验证 slash command 部署成功
journalctl --user -u openclaw-gateway -f | grep -E 'deploy-rest|deployed'
```

## TODO（必填，不可省）

- [ ] **2026-04-28 13:30 CST 后**：执行上方"回滚命令"块，确认 deploy 成功（看 journalctl 出 `deploy-rest:put:ok`）
- [ ] 设置 systemd timer 提醒：
  ```bash
  systemd-run --user --on-active=45min --unit=f12-revert-reminder \
    bash -c 'echo "TODO: revert F12 Discord workaround" | tee /tmp/f12-reminder.txt'
  ```
- [ ] 回滚后从本 audit 案例和 MEMORY 移除 TODO 行（标记 closed）
```

## 这个 case 沉淀为

- `references/symptom-index.md` — "应急要 openclaw config set channels.<x>.commands.{native,nativeSkills} false" 行
- `references/success-patterns.md` — SP6（Notion 写回必含 rollback + TODO）
- `references/audit-checklist.md` — Step (e) 强调 emergency override 必须有 TODO-revert + reminder
- SKILL.md "Notion interaction protocol" 段加了"emergency overrides 必须含 TODO-revert" 一条
- SKILL.md "Anti-patterns" 加了"批准应急改不加 TODO-revert" 一条

## 通用模式：怎么判断一个改动需要 TODO-revert

提案如果满足以下任一条，**强制要求 TODO-revert + reminder**：
- 关闭某个 security / functional feature 来绕过临时问题（rate-limit / network outage / upstream bug）
- 把某个超时 / 重试 / 阈值临时调宽来"让事情先走"
- 跳过 validate / doctor / smoke 中的某一项
- 用 forensics-only 的临时数据（test token、mock endpoint）

如果改动是"修一个真实存在的 bug" — 不需要 TODO-revert（应该是永久修）。

## 反例：什么时候不需要 TODO-revert

提案是修永久性配置错误（typo、字段路径错、新 channel 上线）— 改完就好，不存在"过段时间该回滚" 的概念。

## 给上游的反馈

OpenClaw 应该有 **emergency override** 一等公民支持：
1. `openclaw config set --emergency --revert-after=1h <field> <value>` — 自动到时回滚
2. `openclaw config list-emergency` — 列出当前所有未回滚的 emergency override
3. doctor 输出里把 "emergency overrides active" 单独列一段，确保不会被遗忘

如果上游有这个，F12 就不会有"24h 还没回滚"的尾巴。
