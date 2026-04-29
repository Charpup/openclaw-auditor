# Audit case 2026-04-27 — F9: systemd unit PATH 引用陈旧 nvm symlink

> **Why this case matters**: auditor 容易把"OpenClaw 配置审计"狭义理解成"openclaw.json 字段审计"。**配置面更宽** — systemd unit / drop-in 的 `Environment=PATH=` 也是配置面，且对 v4.x lazy bundled-deps 模式至关重要。这是 SP4（配置面 ≠ 仅 openclaw.json）的来源。

## 提案上下文

用户场景：v2026.4.11 → v2026.4.24 升级。升级前用户给的提案：

> openclaw.json 不动，npm install -g openclaw@2026.4.24 后直接 systemctl restart 就行吧？

升级当天确实 restart 后 gateway 拒起 — 但症状不在 openclaw.json，而是 systemd unit 里 PATH 引用 `/root/.nvm/current/bin` 这个 symlink 在本机从未建过。

## 实际发生（从 MEMORY F9 段复盘）

journalctl 反复刷：
```
[plugins] acpx failed to stage bundled runtime deps:
  Error: spawnSync npm ENOENT
[plugins] discord failed to stage bundled runtime deps:
  Error: spawnSync npm ENOENT
... (5 个 plugin 全部 ENOENT)
[gateway] ready (0 plugins, ...)
```

直接看像是 npm 没装或者环境变量丢了，但 root cause 是：
- v4.24 改成 lazy bundled-deps 模式：每个 plugin 启动时 spawn `npm install` 去装运行时依赖
- systemd unit 的 `Environment=PATH=` 引用 `/root/.nvm/current/bin`
- 这台机器的 nvm 从未建过 `current` symlink（用户用 `nvm use <ver>` 不持久化）
- spawn 时 `current/bin/npm` 找不到 → ENOENT → 5 个 plugin 全死

修复 = 给 systemd 加 drop-in：
```ini
# /root/.config/systemd/user/openclaw-gateway.service.d/path-fix.conf
[Service]
Environment=PATH=/root/.nvm/versions/node/v22.22.0/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```

## 错误假设链

1. ❌ "openclaw.json 不动 = 升级零风险" — 配置面更宽
2. ❌ "npm 在 shell 能跑就说明系统里有 npm" — systemd 的 PATH ≠ shell 的 PATH
3. ❌ "v4.24 是 patch 升级，不会改启动模式" — patch 升级也可能改启动方式（lazy bundled-deps 是 v4.x 引入的，但具体什么版本 hard-required nvm 路径要看 changelog）

## auditor 应该看到 / 警告的

1. **审 v4.x 升级提案时，systemd unit + drop-in 必看**：
   ```bash
   systemctl --user cat openclaw-gateway
   # 重点看 Environment=PATH=
   # 检查里面引用的每个路径是否真实存在
   ```
2. **检查 nvm symlink**：
   ```bash
   readlink /root/.nvm/current 2>/dev/null || echo "nvm 'current' symlink not set"
   which npm
   command -v npm  # 在 systemd 的 PATH 下能不能找到
   ```
3. **如果 PATH 引用 nvm `current`，建议改用绝对版本号路径**：`/root/.nvm/versions/node/v<X>.<Y>.<Z>/bin`，避免 nvm 升级 node 后路径漂移
4. **预演 lazy install**：
   ```bash
   # 在 systemd 的 PATH 下手动 spawn 一次，验证能找到 npm
   sudo -u <user> env -i PATH=<systemd-path> npm --version
   ```

## 应当给的命令（audit 写回模板填好版）

```bash
# 0. 备份 systemd unit 当前状态
mkdir -p /tmp/openclaw-systemd-bak
systemctl --user cat openclaw-gateway > /tmp/openclaw-systemd-bak/before.unit

# 1. 检查 PATH 是否引用陈旧路径
PATH_LINE=$(systemctl --user show openclaw-gateway -p Environment | tr ' ' '\n' | grep '^PATH=')
echo "current PATH= $PATH_LINE"

# 2. 检查每个路径是否存在 / npm 是否在
for P in $(echo "${PATH_LINE#PATH=}" | tr ':' '\n'); do
  [[ -d "$P" ]] && [[ -x "$P/npm" ]] && echo "OK: $P/npm" || echo "MISSING: $P"
done

# 3. 如果 npm 不在任何路径里，建 drop-in
NODE_VER=$(node --version)   # e.g. v22.22.0
NODE_BIN="/root/.nvm/versions/node/$NODE_VER/bin"
if [[ -x "$NODE_BIN/npm" ]]; then
  mkdir -p /root/.config/systemd/user/openclaw-gateway.service.d
  cat > /root/.config/systemd/user/openclaw-gateway.service.d/path-fix.conf <<EOF
[Service]
Environment=PATH=$NODE_BIN:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
EOF
  systemctl --user daemon-reload
fi

# 4. 重启验证
systemctl --user restart openclaw-gateway
sleep 5
journalctl --user -u openclaw-gateway -n 50 --no-pager | grep -E 'plugins|ready|ENOENT'
```

## 回滚

```bash
rm /root/.config/systemd/user/openclaw-gateway.service.d/path-fix.conf
systemctl --user daemon-reload
systemctl --user restart openclaw-gateway
```

## 这个 case 沉淀为

- `references/symptom-index.md` — "提案改 systemd unit / drop-in" 行
- `references/success-patterns.md` — SP4（配置面 ≠ 仅 openclaw.json）
- `references/audit-checklist.md` — Step (c) 字段路径检查必查 systemd Environment

## 关于 systemd unit 是否"自管理"

OpenClaw 的 base unit（不是 drop-in）由 `openclaw service install` 生成，下次重装可能覆盖。所以**手工改 base unit 不安全**。drop-in 方式（`<service>.d/<name>.conf`）才是稳的，不会被覆盖。

auditor 看到 base unit 有问题时，不要建议直接改 base，改用 drop-in 覆盖。

## 反例：什么时候 PATH 不是问题

如果机器上的 nvm `current` symlink 实际存在并指向有效 node 版本，base unit 的 PATH 引用就 OK。这个场景下 F9 不会触发。判断关键就是 `readlink /root/.nvm/current` 是否返回有效路径。
