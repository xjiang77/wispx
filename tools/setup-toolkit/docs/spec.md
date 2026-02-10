# Claude Code Setup Toolkit — Spec

> 实现级规格文档。Version 2.0。

---

## 1. Overview & 第一性原则

### 配置即代码 (Configuration as Code)
- 所有 agent 配置（rules, permissions, hooks, skills）存储在 git 管理的 toolkit repo
- `make install` 从 toolkit 部署到 `~/.claude/`
- 变更可追踪、可回滚、可 code review

### 一致性保证 (Consistency Guarantee)
- CLAUDE.md 是唯一 source of truth，sync 到 Codex/CodeBuddy
- 所有 agent 遵循相同的行为规则和安全策略
- 跨机器通过 `git clone + make install` 保证一致

### 知识沉淀复用 (Knowledge Capture & Reuse)
- Workflow 知识封装为 skills（agentskills.io 格式）
- Best practices 编码为可执行检查（doctor/audit scripts）
- 项目配置模板化，init-project 一键生成

---

## 2. Architecture

### 数据流

```
toolkit repo (wispx/tools/setup-toolkit/)
    │
    ├── make install
    │   ├── dotclaude/* → ~/.claude/*
    │   ├── skills/* → ~/.claude/skills/*
    │   ├── scripts/* → ~/.claude/scripts/*
    │   └── sed fixup paths
    │
    ├── make sync
    │   ├── ~/.claude/CLAUDE.md → ~/.codex/AGENTS.md
    │   └── ~/.claude/CLAUDE.md → ~/.codebuddy/CLAUDE.md
    │
    └── make doctor / make audit
        └── 检查 ~/.claude/ 的健康状态
```

### 目录结构

```
tools/setup-toolkit/
├── README.md                     # Quick Start + 使用指南
├── Makefile                      # 生命周期入口 (8 targets)
├── dotclaude/                    # → 部署到 ~/.claude/
│   ├── CLAUDE.md                 # 全局行为规则 (< 50 lines)
│   ├── settings.json             # permissions + hooks + plugins
│   ├── statusline-command.sh     # 状态栏脚本
│   ├── hooks/
│   │   ├── notify.sh             # macOS 通知
│   │   └── protect-sensitive.sh  # 敏感文件保护
│   └── templates/
│       ├── CLAUDE.md.tpl         # 项目级 CLAUDE.md 模板
│       ├── AGENTS.md.tpl         # Codex AGENTS.md 模板
│       └── settings.local.json.tpl
├── skills/                       # agentskills.io 格式 skills
│   ├── commit/SKILL.md
│   ├── code-review/SKILL.md
│   ├── tdd/SKILL.md
│   ├── plan/SKILL.md
│   ├── skill-creator/SKILL.md
│   ├── find-skills/SKILL.md
│   ├── skill-reviewer/SKILL.md
│   ├── skill-auditor/SKILL.md
│   └── skill-packager/SKILL.md
├── scripts/
│   ├── install.sh
│   ├── doctor.sh
│   ├── audit.sh
│   ├── init-project.sh
│   └── sync-agents.sh
├── docs/
│   ├── spec.md                   # 本文档
│   └── best-practices.md
└── lib/                          # 第三方参考 (git submodules)
    ├── everything-claude-code/
    └── superpowers/
```

---

## 3. Best Practices 规范

详见 `best-practices.md`。核心规范摘要：

| Element | 规范 | Why |
|---------|------|-----|
| Global CLAUDE.md | < 50 行 (~750 tokens) | 每次会话加载，过长压缩有效 context |
| CLAUDE.md 内容 | 只放跨项目行为规则 | 项目特定内容放 project-level |
| CLAUDE.md 语法 | 祈使句 + headers + bullets | 更直接，更少 tokens，解析效率高 |
| Hooks | < 50 行，timeout < 5s | Hook 同步执行，太慢影响交互 |
| PreToolUse hook | 必须配置 | 安全底线 |
| Permissions allow | 日常开发命令 | 减少确认弹窗 |
| Permissions deny | 破坏性操作 | 安全底线 |
| Skills | 一个 skill 做一件事 | 清晰的职责边界 |
| SKILL.md | < 200 行 ideal | 过长占用 context window |
| MCP | 每项目 < 10 个 | Tool definitions 占用 context |

---

## 4. 组件详细设计

### 4.1 CLAUDE.md

**职责**: 定义所有 coding agent 的跨项目行为规则。

**内容框架**:
- Core Rules (5 条): Action Over Planning, Prove It Works, Pick and Act, No False Completions, One Task Per Session
- Code Style (2 条): 不加 comments/docstrings, 不加不必要的 error handling
- Writing (1 条): 中英文混合

**约束**: ≤ 50 lines, ≤ 750 tokens estimated。

### 4.2 settings.json

**职责**: Claude Code 的 permissions, hooks, plugins, statusLine 配置。

**关键设计决策**:
- 使用 `__HOME__` placeholder，install 时 `sed` 替换为实际 `$HOME`
- Allow list: 60 条日常开发命令（git, npm, go, cargo, python, docker, etc.）
- Deny list: 12 条危险操作（rm, force push, sudo, curl, wget, etc.）
- Hooks: Notification + PreToolUse (sensitive file protection)
- Plugins: document-skills, rust-analyzer-lsp, pyright-lsp

### 4.3 Hooks

**notify.sh**: macOS osascript notification，5 行。
**protect-sensitive.sh**: PreToolUse hook，阻止编辑 .env/.pem/.key/credentials/secret 文件，26 行。

**约束**: 每个 hook ≤ 50 行，timeout ≤ 5s，exit 0 = pass, exit 2 = block。

### 4.4 Templates

**CLAUDE.md.tpl**: 24 行，`{{PROJECT_NAME}}` 占位符。包含 Development (build/test/lint commands), Architecture, Conventions。
**AGENTS.md.tpl**: 9 行，精简版。Codex 格式。
**settings.local.json.tpl**: 6 行，空 permissions 结构。

### 4.5 Skills (9 个)

每个 skill 遵循 agentskills.io spec:

```yaml
---
name: skill-name
description: 触发条件 + 功能描述
allowed-tools:
  - Tool1
  - Tool2
---
```

| Skill | 类型 | 核心功能 |
|-------|------|---------|
| commit | Workflow | Conventional commit，中文描述，review + commit |
| code-review | Workflow | 6 维度系统化 review，结构化 findings |
| tdd | Workflow | RED-GREEN-REFACTOR 循环 |
| plan | Workflow | 需求理解 → 代码探索 → 方案设计 → 任务分解 |
| skill-creator | Lifecycle | 创建/改进 skill，含 eval/benchmark |
| find-skills | Lifecycle | 发现/搜索/安装 skills |
| skill-reviewer | Lifecycle | 单个 skill 质量 review |
| skill-auditor | Lifecycle | 集合级 security/consistency 审计 |
| skill-packager | Lifecycle | 打包为可分发 plugin |

---

## 5. 生命周期管理

### make install

1. 创建 `~/.claude/` 子目录 (hooks, templates, skills, agents, mcp, scripts)
2. 复制 `dotclaude/*` → `~/.claude/`
3. `sed` 替换 `__HOME__` → `$HOME`
4. 合并 `settings.local.json` (如果存在)
5. 复制 `skills/*` → `~/.claude/skills/`
6. 复制 `scripts/*` → `~/.claude/scripts/`
7. `chmod +x` 所有 .sh 文件
8. 调用 `sync-agents.sh all`
9. 调用 `doctor.sh` 验证

**非破坏性**: 不触碰 `~/.claude/settings.local.json`, `~/.claude/hooks.local/`, runtime 数据。

### make update

`git pull --rebase` + `make install`。

### make doctor (15 checks)

| # | Check | Type |
|---|-------|------|
| 1-3 | claude/jq/git installed | FAIL |
| 4-5 | codex/codebuddy installed | WARN |
| 6-7 | CLAUDE.md/settings.json exists | FAIL |
| 8 | settings.json valid JSON | FAIL |
| 9-10 | hooks executable | FAIL |
| 11 | PreToolUse configured | WARN |
| 12-14 | rm -rf/sudo/force push denied | WARN |
| 15 | CLAUDE.md ≤ 50 lines | WARN |

### make audit (18+ checks)

| # | Check | Type |
|---|-------|------|
| 1 | CLAUDE.md line count + token estimate | PASS/WARN |
| 2-6 | Anti-patterns (you are, step by step, etc.) | PASS/WARN |
| 7-11 | Required deny patterns | PASS/WARN |
| 12 | PreToolUse hook configured | PASS/WARN |
| 13 | No foreign hardcoded paths | PASS/WARN |
| 14-15 | Allow/Deny list counts | PASS |
| 16-17 | Hook line counts | PASS/WARN |
| 18 | Total hooks count | PASS |
| 19+ | Skills frontmatter validation | PASS/WARN |

### make init-project P=<path>

1. 从 CLAUDE.md.tpl 生成 `$P/CLAUDE.md` (sed {{PROJECT_NAME}})
2. 从 AGENTS.md.tpl 生成 `$P/AGENTS.md`
3. 从 settings.local.json.tpl 生成 `$P/.claude/settings.local.json`
4. 所有操作非破坏性（已存在则 skip）

### make sync

CLAUDE.md → `~/.codex/AGENTS.md` (with auto-generated header) + `~/.codebuddy/CLAUDE.md` (direct copy)。

---

## 6. 跨 Agent 复用策略

| Agent | 全局配置 | 项目配置 | 同步方式 |
|-------|---------|---------|---------|
| Claude Code | `~/.claude/CLAUDE.md` | `CLAUDE.md` | 原生 |
| Codex | `~/.codex/AGENTS.md` | `AGENTS.md` | `make sync` 生成 |
| CodeBuddy | `~/.codebuddy/CLAUDE.md` | `CLAUDE.md` | `make sync` 复制 |

**CLAUDE.md 是唯一 source of truth。**

Skills 使用 agentskills.io 格式，理论上可被任何支持该格式的 agent 使用。

---

## 7. Per-machine Customization

### Local Override 文件

| 文件 | 用途 | install 行为 |
|------|------|------------|
| `~/.claude/settings.local.json` | 本机额外 permissions | 不覆盖 |
| `~/.claude/hooks.local/` | 本机额外 hooks | 不触碰 |
| `~/.claude/CLAUDE.local.md` | 本机额外规则 | 不触碰 |

### settings.json 路径处理

- Toolkit repo 中使用 `__HOME__` placeholder
- `install.sh` 通过 `sed` 替换为当前 `$HOME`
- Audit 检查：只对**其他用户**的 hardcoded paths 发出警告

---

## 8. 第三方 Lib 管理

使用 git submodules，仅用于参考研究，不是 install 依赖。

```
lib/
├── everything-claude-code/  # github.com/affaan-m/everything-claude-code
└── superpowers/             # github.com/obra/superpowers
```

`make fetch-libs` = `git submodule update --init --recursive`

---

## 9. 使用指南

### 安装

```bash
cd wispx/tools/setup-toolkit
make install
```

### 日常使用

```bash
make doctor          # 诊断问题
make audit           # 检查最佳实践
make list            # 查看已安装组件
make sync            # 同步到其他 agents
```

### 项目初始化

```bash
make init-project P=/path/to/project
```

### 跨机器同步

```bash
# 新机器
git clone <repo> wispx
cd wispx/tools/setup-toolkit
make install
```

### 更新

```bash
make update          # git pull + install
```
