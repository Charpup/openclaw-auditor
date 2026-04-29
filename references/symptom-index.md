# OpenClaw 审计 — 按症状速查

> 用法：审计场景下用户/agent 描述了症状（错误信息、行为异常），⌘F 搜本文件找对应的失败类别 + 一句话因 + 一句话治。详细背景与修复在 `~/claude_code_workspace/knowledge-base/openclaw/upgrade-runbook.md` §2，案例叙事在本 skill 的 `examples/`。
>
> 这是 **审计视角**（pre-change / 提案审查），与 upgrade-ops 的 `references/symptom-index.md`（运行时 / 日志症状）互补，但不重复 — upgrade-ops 索引"日志里看到的字面 string"，本表索引"用户在提案/咨询时描述的症状"。

## 一眼速查表（按"用户描述的症状"反查）

| 用户描述 / 症状 | 失败类别 | 一句话因 | 审计应给的一句话 |
|---|---|---|---|
| `openclaw config validate` 报 `invalid_enum_value` / `unrecognized_keys` / `invalid_type` 引用某字段 | **F4** schema breaking | 跨过含 zod schema 收窄的版本 | 让用户先 `bash scripts/fetch-doc.sh gateway/configuration` 看新 schema，再改字段而不是改 schema 源码 |
| "我已经 export 了新的 API key 为什么还 401" | **F2** auth-profile 优先级 | `~/.openclaw/agents/<id>/agent/auth-profiles.json` 优先级 > env vars，且 `usageStats.errorCount` / `cooldownUntil` 仍生效 | 三连：改 env + 改对应 agent 的 `auth-profiles.json` + 清 `usageStats` 字段 |
| "升级后某个 agent 的 model override 没了" | **F7** override 静默丢失 | `config.apply` 全量替换或某 plugin 操作没保留 `agents.<id>.overrides` | 操作前 `bash scripts/config-snapshot.sh` 抓 per-agent 快照；恢复时用 `openclaw config set agents.<id>.<dotpath>` |
| 提案要 `openclaw config.apply` 一份"完整新配置" | **F7 高危**（pre-emptive） | apply 是全量替换，会清掉所有 per-agent override + plugin 自动写入字段 | 拒绝 apply；改用 `config.patch` + 先 list 当前所有 override 字段；如果必须 apply 则强制要求 baseHash + diff 审计 |
| 提案改 `gateway.bind` / `tailscale.mode` / `gateway.controlUi.allowedOrigins` 之一 | **F1** 网络字段级联 | 三个字段强耦合，改一个不联动会让 gateway crash-loop | 必须三字段同改 + `openclaw config validate --dry-run`，并审计 origins 列表是否覆盖新 bind |
| 提案给 Telegram/Discord 加 account 但用 `token` 字段 | schema misuse | 应是 `botToken`，旧字段名是常见 Galatea 错误 | 直接改正字段名；额外检查是否还混了 channel 级 vs account 级设置 |
| 提案给 channel.feishu 设 `renderMode: "markdown"` | **F4** 已收窄 | v4.10 起收窄到 `auto/raw/card`，旧 `markdown` 不再合法 | 推 `auto`；并提醒：channel 字段值也要走 llms.txt 当前 schema 比对 |
| 提案改 `auth.profileOrder` 或 `auth.profiles.<id>.priority` | 🔴 高风险 | auth profile 顺序直接决定哪个 key 被先用；改错会让所有 agent 走错 provider | 要求先 dump 当前 profileOrder + 列出 affected agents；不批准没有 backup 的改动 |
| 提案改 `secrets.providers` / `secrets.defaults` | 🔴 高风险 | secrets 节点掌控凭据存储后端，错配可能让所有 credential 不可读 | 强制 backup（`scripts/config-snapshot.sh`）+ 验证新 provider binary 是否实际可用 |
| 提案在 `~/.openclaw/openclaw.json` 加 `web.braveApiKey` / `tools.web.*` 之类 | 字段不存在 | Galatea 常见错觉 — 看到 web search 行为就以为有对应配置节点 | 直接拒；llms.txt 找不到的字段一律不加；引导走 `tools.exec` + plugin |
| "某个 channel 在新版本里行为变了，需要在 openclaw.json 加新字段" | 待定（可能 F4 反向 / plugin 配置） | channel 行为变化通常来自 plugin 而非主 schema；新字段要么在 `plugins.<name>` 下要么在 `channels.<name>.accounts.<id>` 下 | 拉 llms.txt + plugin README，确认字段路径再改 |
| 应急要 `openclaw config set channels.<x>.commands.{native,nativeSkills} false` | 应急合理但需标记 | 临时关 slash command 部署绕过 rate-limit | 批准但要求加 TODO-revert 注释 + 目标重启窗口（参 `examples/audit-2026-04-28-f12-*`） |
| 提案改 systemd unit 或加 drop-in（`/root/.config/systemd/user/openclaw-gateway.service.d/*.conf`） | systemd PATH/env 也是配置面 | 不在 openclaw.json 里，但行为影响 gateway lazy npm install（参 F9） | 同步审计 `Environment=PATH=` 是否引用稳定 symlink；nvm `current` 不存在的话用绝对版本号路径 |
| "agent 在 plan-mode 还是改了 openclaw.json" | **F8** 子代理逃逸 | plan-mode 限制只对 human session 生效，subagent 默认无视 | 给 subagent prompt 显式禁 OpenClaw 写命令；任务前后 `git diff openclaw.json`（如果在 git 里） |
| 提案禁用 `tools.exec.timeoutSec` 或调成 0 | **F3** 风险倍增 | timeout 路径不发 SIGKILL；超时进程 reparent 到 init 后 pkill 抓不到，吃内存 | 不批；要求保留 timeout + 配合 kill-tree patch（参 upgrade-runbook §2 F3） |
| `config validate` 报 "required" 类错误（缺字段）而非字段值错 | plugin install/uninstall 副作用 | 不是 schema breaking；某 plugin 卸载后字段没清，或新 plugin 装了但配置没补 | 补齐缺字段 / 重装 plugin；不要改 schema |

## 当用户描述不在表里

1. 让用户先跑 `openclaw config validate` 拿确切错误
2. `bash scripts/fetch-llms-index.sh <topic>` 找当前 schema 的相关页
3. ⌘F 搜 upgrade-runbook §2 失败模式表里是否有类似表述
4. 看 `examples/audit-*.md` 是否有相似审计案例
5. 如果是新模式，按 SKILL.md "Compounding the skill" 沉淀（这里加一行 + 写一个 example）

## 不要做的事

- ❌ 不查 llms.txt 就用本地 `references/schema-quick-ref.md` 的字段名做判断 — 它可能已经过时
- ❌ 看到 `config.apply` 提案就批 — 必须先 list 现有 override + 强制 baseHash
- ❌ 只审 `openclaw.json` — auth-profiles.json / systemd drop-in / plugin 配置都是配置面
- ❌ 给应急临时改批准时不加 TODO-revert 标记（F12 后续 TODO 至今未回滚就因这个）
- ❌ 给提案打绿灯不附 rollback 命令 — 用户实际操作时不知道怎么回退
