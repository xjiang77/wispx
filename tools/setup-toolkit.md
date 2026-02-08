# Claude Code Setup Toolkit

> `~/.claude/` 作为 git repo，用 Makefile 管理 coding agent 配置的完整生命周期。

## 1. 问题与目标

### 问题
在多台 Mac 间保持一致的 coding agent 配置。`~/.claude/` 下已有零散配置文件（CLAUDE.md、hooks、settings.json），但：
- 没有版本控制，无法跨机器同步
- 没有最佳实践文档
- 没有项目初始化工具
- 不支持 Codex / CodeBuddy 等其他 coding agent 的配置同步

### 目标
把 `~/.claude/` 变成 git repo，用 Makefile 管理完整生命周期（install / update / audit / init-project），同时支持 Claude Code、Codex、CodeBuddy 三个 coding agent。

---

## 2. 实施前状态

### 已有配置（保留并改进）

| 文件 | 内容 | 评估 |
|------|------|------|
| `CLAUDE.md` (17 行) | 5 条行为规则 + code style | 质量高，仅需增加 Writing section |
| `settings.json` (115 行) | 59 条 allow + 12 条 deny + 2 hooks + statusline + 4 plugins | 完整，需修复硬编码路径 |
| `statusline-command.sh` | 显示 model/context%/git | 不改 |
| `hooks/notify.sh` (5 行) | macOS notification | 不改 |
| `hooks/protect-sensitive.sh` (26 行) | 阻止编辑 .env/.pem/.key | 不改 |

### 已有 runtime 目录（需要 gitignore）
`debug/` `file-history/` `history.jsonl` `cache/` `paste-cache/` `session-env/` `shell-snapshots/` `stats-cache.json` `statsig/` `telemetry/` `logs/` `ide/` `plans/` `todos/` `tasks/` `projects/` `plugins/` `backups/` `config/` `usage-data/`

### 特殊情况
- `commands/` 是独立 git repo（有 `.git/`），必须 gitignore 避免嵌套
- `settings.json` 中 hook 路径硬编码了 `/Users/kevinxjiang/`，跨机器需要 fixup

### 跨 Agent 配置现状

| Agent | 全局配置路径 | 项目配置 | 现状 |
|-------|-------------|---------|------|
| Claude Code | `~/.claude/CLAUDE.md` | `CLAUDE.md` + `.claude/` | 已配置 |
| Codex | `~/.codex/AGENTS.md` | `AGENTS.md` | AGENTS.md 为空 |
| CodeBuddy | `~/.codebuddy/` | `CLAUDE.md`（兼容格式） | 无 global instructions |

---

## 3. 最佳实践规范

> 先定规范，再按规范实现。每条规则都说明 WHY。

### CLAUDE.md
| 规则 | 原因 |
|------|------|
| Global < 50 行（~750 tokens） | 每次会话都加载，过长压缩有效 context |
| 只放跨项目的行为规则 | 项目特定内容放 project-level CLAUDE.md |
| 用祈使句（"Run X" not "You should run X"） | 更直接，更少 tokens |
| 不写 persona（"you are..."） | agent 已经知道自己是什么，浪费 tokens |
| 不重复 agent 默认行为 | "think step by step" 等 agent 已经会做 |
| 用 headers + bullets 结构化 | agent 解析效率最高 |
| 避免 agent-specific 语法 | 保证 Codex/CodeBuddy 也能读 |

### Hooks
| 规则 | 原因 |
|------|------|
| 脚本 < 50 行，timeout < 5s | Hook 同步执行，太慢影响交互体验 |
| PreToolUse 用于 safety gates | 阻止危险操作是最高优先级 |
| Exit 0 = 通过, Exit 2 = 阻止 | Claude Code hook protocol |
| 脚本必须幂等 | 多次执行结果一致 |
| 只保留真正需要的 hooks | 每个 hook 都有调用 overhead |

### Permissions
| 规则 | 原因 |
|------|------|
| Allow: 日常开发命令 | 减少确认弹窗，提高效率 |
| Deny: 破坏性操作 | 安全底线，防止误操作 |
| 缺失的命令弹确认框 | 安全默认行为 |
| Project-level 可覆盖 | 特定项目有特殊需求时用 settings.local.json |

### Skills & MCP
| 规则 | 原因 |
|------|------|
| 一个 skill 做一件事，< 200 行 | 清晰职责 + 控制 context 占用 |
| 每项目 < 10 个 MCP | Tool definitions 占用 context |
| 优先用内置工具 | 不额外占用 context |

---

## 4. 目录结构设计

```
~/.claude/                           # git repo root
├── .gitignore                       # 排除 runtime 数据
├── Makefile                         # 工具入口
├── README.md                        # 使用说明
├── CLAUDE.md                        # 全局行为规则 (source of truth)
├── settings.json                    # permissions + hooks + plugins
├── statusline-command.sh            # status line display
├── hooks/
│   ├── notify.sh                    # macOS notification on wait
│   └── protect-sensitive.sh         # Block edits to .env/.pem/.key
├── scripts/
│   ├── doctor.sh                    # 诊断常见问题
│   ├── audit.sh                     # 检查最佳实践合规
│   ├── init-project.sh              # 初始化项目级配置
│   └── sync-agents.sh              # 跨 agent 同步
├── templates/
│   ├── CLAUDE.md.tpl                # 项目 CLAUDE.md 模板
│   ├── AGENTS.md.tpl                # Codex AGENTS.md 模板
│   └── settings.local.json.tpl      # 项目 .claude/ 设置模板
├── docs/
│   └── best-practices.md            # 配置最佳实践
├── skills/.gitkeep
├── agents/.gitkeep
└── mcp/.gitkeep
```

---

## 5. Makefile 设计

| Target | 功能 |
|--------|------|
| `make help` | 显示所有可用 targets |
| `make install` | 首次安装：chmod scripts → mkdir 保留目录 → sed fixup 硬编码路径 → sync agents → doctor → 提示 alias |
| `make update` | `git pull --rebase` + `make install` |
| `make doctor` | 诊断：CLI tools / config files / hooks / safety / context budget |
| `make audit` | 最佳实践审计：token count / anti-patterns / deny list / hooks / hardcoded paths |
| `make list` | 列出 hooks / skills / MCP / plugins / permissions 统计 |
| `make init-project P=<path>` | 初始化项目配置（CLAUDE.md + AGENTS.md + .claude/settings.local.json） |
| `make audit-project P=<path>` | 审计项目级配置 |
| `make sync` | 同步 CLAUDE.md → Codex + CodeBuddy |
| `make install-codex` | 单独同步到 Codex |
| `make install-codebuddy` | 单独同步到 CodeBuddy |

### `make install` 关键逻辑
1. `chmod +x` 所有 `.sh` 文件
2. `mkdir -p skills agents mcp`
3. `sed` 替换 settings.json 中硬编码 home 路径为当前 `$HOME`
4. 调用 `make sync`（同步 Codex + CodeBuddy）
5. 调用 `make doctor`（验证安装结果）
6. 检测 `cc-make` alias 是否已配置，未配置则提示用户添加

### `make doctor` 检查项（5 categories, 15 checks）
- **CLI Tools**: `claude` / `jq` / `git`（必需）; `codex` / `codebuddy`（可选）
- **Config Files**: CLAUDE.md 存在 / settings.json 存在且合法 JSON
- **Hooks**: 每个 hook 可执行 / PreToolUse 已配置
- **Safety**: `rm -rf` / `sudo` / `git push --force` 已 deny
- **Context Budget**: CLAUDE.md ≤ 50 行

### `make audit` 检查项（6 categories, 18 checks）
- **CLAUDE.md**: 行数 × 15 估算 token / 5 个 anti-pattern 检测
- **settings.json**: 5 个必需 deny / PreToolUse hook / 外部用户硬编码路径 / allow+deny 统计
- **Hooks**: 每个 hook 行数 ≤ 50 / 总 hook 数

### `make init-project P=<path>` 逻辑
1. 检查目录存在，提取 `PROJECT_NAME`
2. 如果 `CLAUDE.md` 不存在 → 从 `CLAUDE.md.tpl` 生成（sed 替换 `{{PROJECT_NAME}}`）
3. 如果 `AGENTS.md` 不存在 → 从 `AGENTS.md.tpl` 生成
4. 如果 `.claude/` 不存在 → mkdir + 复制 `settings.local.json.tpl`
5. **不覆盖已有文件**

---

## 6. 跨 Agent 同步策略

**核心思路**: `~/.claude/CLAUDE.md` 是唯一 source of truth。

| Agent | 全局路径 | 同步方式 |
|-------|---------|---------|
| Claude Code | `~/.claude/CLAUDE.md` | 原生（不需同步） |
| Codex | `~/.codex/AGENTS.md` | 添加 auto-generated header + 复制内容 |
| CodeBuddy | `~/.codebuddy/CLAUDE.md` | 直接复制（兼容 Claude 格式） |

`scripts/sync-agents.sh` 支持参数：`codex` / `codebuddy` / `all`（默认）

---

## 7. 文件变更详情

### 新建文件（11 个）

| 文件 | 行数 | 说明 |
|------|------|------|
| `.gitignore` | 27 | 排除 21 个 runtime 目录 + `commands/` 嵌套 git + `.DS_Store` |
| `Makefile` | 75 | 11 个 targets，self-documenting（`make help`） |
| `README.md` | 70 | Quick Start + Commands + Directory Structure + Cross-Agent Sync |
| `docs/best-practices.md` | 73 | 6 大类最佳实践（CLAUDE.md / Hooks / Permissions / Skills / MCP / Sync） |
| `scripts/doctor.sh` | 71 | 5 categories, 15 checks, exit 0/1 |
| `scripts/audit.sh` | 85 | 3 categories, 18 checks, exit 0/1 |
| `scripts/init-project.sh` | 40 | 3 个文件生成，不覆盖已有 |
| `scripts/sync-agents.sh` | 44 | 2 个 sync 函数（codex + codebuddy），支持单独/全部 |
| `templates/CLAUDE.md.tpl` | 24 | 项目 CLAUDE.md 模板，含 `{{PROJECT_NAME}}` 占位符 |
| `templates/AGENTS.md.tpl` | 9 | Codex AGENTS.md 模板 |
| `templates/settings.local.json.tpl` | 6 | 空 permissions 模板 |

### 修改文件（1 个）

| 文件 | 变更 | 行数变化 |
|------|------|---------|
| `CLAUDE.md` | 新增 `## Writing` section | 17 → 20 行（+3 行） |

### 未修改但纳入版本控制的文件（4 个）
| 文件 | 行数 |
|------|------|
| `settings.json` | 115 |
| `statusline-command.sh` | 36 |
| `hooks/notify.sh` | 5 |
| `hooks/protect-sensitive.sh` | 26 |

### 总计
- **19 files committed, 726 insertions**
- Initial commit: `055fbe2` — `feat: 初始化 Claude Code Setup Toolkit`

---

## 8. 实施过程

### Step 1: 环境评估
- 确认 `~/.claude/` 不是 git repo
- 盘点现有文件和 runtime 目录
- 确认 `commands/` 是独立 git repo，需 gitignore
- 确认 settings.json 中 3 处硬编码路径

### Step 2: 创建 .gitignore
- 排除 21 个 runtime 目录 / `commands/` / `.DS_Store`

### Step 3: 并行创建所有新文件（10 个）
- `docs/best-practices.md` — 最佳实践文档
- `scripts/doctor.sh` — 诊断脚本
- `scripts/audit.sh` — 审计脚本
- `scripts/init-project.sh` — 项目初始化
- `scripts/sync-agents.sh` — 跨 agent 同步
- `templates/CLAUDE.md.tpl` — 项目 CLAUDE.md 模板
- `templates/AGENTS.md.tpl` — Codex AGENTS.md 模板
- `templates/settings.local.json.tpl` — 项目设置模板
- `Makefile` — 11 个 targets
- `README.md` — 使用说明

### Step 4: 修改 CLAUDE.md
- 添加 `## Writing` section（+3 行）

### Step 5: .gitkeep + chmod + git init
- `touch skills/.gitkeep agents/.gitkeep mcp/.gitkeep`
- `chmod +x` 所有 `.sh` 文件
- `git init && git add -A`

### Step 6: Bug fix — bash arithmetic with `set -e`
**问题**: `((PASS++))` 在 PASS=0 时返回 exit code 1（bash 把 0 视为 false），`set -e` 导致脚本提前退出。

**修复**: 改用 `PASS=$((PASS + 1))` 替代 `((PASS++))`，影响 `doctor.sh` 和 `audit.sh`。

### Step 7: Bug fix — audit.sh hardcoded path check
**问题**: `grep '/Users/[^/]*/'` 在当前机器上总是匹配（因为 `$HOME` 就是 `/Users/kevinxjiang/`），导致 audit 永远 warn。

**修复**: 改为只 warn 当路径属于**其他用户**时：
```bash
other_user_paths=$(grep -oE '/Users/[^/]+/' settings.json | grep -v "$HOME/" || true)
```

### Step 8: 验证
- `make doctor` — **15 passed, 0 warnings, 0 failures**
- `make audit` — **18 passed, 0 warnings**
- `make install` — 路径 fixup ✓, sync ✓, doctor ✓
- `make init-project P=/tmp/test-project` — 生成 3 个文件 ✓
- `make sync` — 同步到 `~/.codex/AGENTS.md` + `~/.codebuddy/CLAUDE.md` ✓
- `make list` — 正确显示 hooks/plugins/permissions ✓

### Step 9: Initial commit
```
055fbe2 feat: 初始化 Claude Code Setup Toolkit
19 files changed, 726 insertions(+)
```

---

## 9. 验证结果

### `make doctor` 输出
```
=== CLI Tools ===
  ✓ claude installed
  ✓ jq installed
  ✓ git installed
  ✓ codex installed (optional)
  ✓ codebuddy installed (optional)
=== Config Files ===
  ✓ CLAUDE.md exists
  ✓ settings.json exists
  ✓ settings.json is valid JSON
=== Hooks ===
  ✓ notify.sh is executable
  ✓ protect-sensitive.sh is executable
  ✓ PreToolUse hook configured
=== Safety ===
  ✓ "rm -rf" is denied
  ✓ "sudo" is denied
  ✓ "git push --force" is denied
=== Context Budget ===
  ✓ CLAUDE.md is 20 lines (≤50)
=== Summary ===
  15 passed, 0 warnings, 0 failures
```

### `make audit` 输出
```
=== CLAUDE.md Audit ===
  ✓ 20 lines (~300 tokens)
  ✓ No anti-pattern: "you are"
  ✓ No anti-pattern: "step by step"
  ✓ No anti-pattern: "be careful"
  ✓ No anti-pattern: "please always"
  ✓ No anti-pattern: "remember to"
=== settings.json Audit ===
  ✓ Deny: "rm -rf"
  ✓ Deny: "sudo"
  ✓ Deny: "git push --force"
  ✓ Deny: "git push -f"
  ✓ Deny: "git reset --hard"
  ✓ PreToolUse hook configured
  ✓ No foreign hardcoded home paths
  ✓ Allow list: 59 rules
  ✓ Deny list: 12 rules
=== Hooks Audit ===
  ✓ notify.sh: 5 lines
  ✓ protect-sensitive.sh: 26 lines
  ✓ Total hooks: 2
=== Summary ===
  18 passed, 0 warnings
```

### `make list` 输出
```
=== Hooks ===
notify.sh
protect-sensitive.sh
=== Skills ===
  (none)
=== MCP ===
  (none)
=== Plugins ===
  ✓ document-skills@anthropic-agent-skills
  ✓ rust-analyzer-lsp@claude-plugins-official
  ✓ pyright-lsp@claude-plugins-official
  ✗ code-simplifier@claude-plugins-official
=== Permissions ===
Allow: 59 rules
Deny:  12 rules
```

---

## 10. 跨机器使用方式

### 新机器首次安装
```bash
# 1. Clone repo
git clone <remote-url> ~/.claude

# 2. 安装（自动 fixup 路径 + sync agents + 验证）
cd ~/.claude && make install
```

### 日常更新
```bash
cd ~/.claude && make update
```

### 初始化新项目
```bash
make init-project P=~/workspace/my-project
```

### 健康检查
```bash
make doctor  # 诊断
make audit   # 最佳实践审计
```

---

## 11. 实施中发现的问题和修复

| 问题 | 原因 | 修复 |
|------|------|------|
| `((PASS++))` 导致 `set -e` 下脚本崩溃 | bash 中 `((0++))` 返回 exit 1 | 改用 `PASS=$((PASS + 1))` |
| `make audit` 总是 warn hardcoded path | grep 匹配当前用户的 $HOME 也算匹配 | 改为只检测**其他用户**的路径 |

### 教训
- bash 的 `(( ))` arithmetic 在 `set -e` 模式下容易出 bug，表达式结果为 0 时返回非零 exit code
- 自检逻辑要考虑"当前机器上运行"的场景，不只是"跨机器运行"的场景

---

## 12. cc-make Alias 支持

### 动机
`make` 命令需要在 `~/.claude/` 目录下执行，日常使用不方便。添加 `cc-make` alias 允许在任意目录下调用 toolkit。

### 改动

**Makefile** — `make install` 结尾新增 alias 检测：
```makefile
@# Suggest alias if not configured
@if ! grep -q "alias cc-make=" ~/.zshrc 2>/dev/null && ! grep -q "alias cc-make=" ~/.bashrc 2>/dev/null; then \
    echo ""; \
    echo "💡 Add this alias to use cc-make from anywhere:"; \
    echo "   echo \"alias cc-make='make -C ~/.claude'\" >> ~/.zshrc && source ~/.zshrc"; \
fi
```

**README.md** — Quick Start 新增 alias 使用说明：
```bash
# 添加 alias，任意目录下都能用 cc-make
echo "alias cc-make='make -C ~/.claude'" >> ~/.zshrc
source ~/.zshrc
```

使用示例：
```bash
cc-make doctor
cc-make audit
cc-make init-project P=~/my-project
```

### 设计决策
- **不自动修改 shell rc** — 只提示，让用户自己决定是否添加
- **同时检查 `.zshrc` 和 `.bashrc`** — 兼容两种 shell
- **alias 而非 symlink** — 更简单，用户可以自行决定命名
