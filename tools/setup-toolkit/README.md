# Claude Code Setup Toolkit

完整但精简的 `~/.claude/` 配置管理 toolkit。一键安装、跨机器同步、跨 agent 复用。

## 核心原则

- **配置即代码**: 所有 agent 配置存储在 git，`make install` 部署到 `~/.claude/`
- **一致性保证**: CLAUDE.md 是唯一 source of truth，sync 到 Codex/CodeBuddy
- **知识沉淀复用**: Workflow 封装为 skills，best practices 编码为可执行检查

## Quick Start

```bash
# Clone repo (如果还没有)
git clone <repo-url> wispx

# Install
cd wispx/tools/setup-toolkit
make install

# Verify
make doctor    # 15 项诊断检查
make audit     # 18+ 项最佳实践检查
```

## 包含内容

### 配置文件 (dotclaude/)

| 文件 | 说明 |
|------|------|
| `CLAUDE.md` | 全局行为规则 (5 Core Rules, < 50 lines) |
| `settings.json` | Permissions (60 allow + 12 deny), hooks, plugins |
| `statusline-command.sh` | 状态栏：model / context% / path (branch status) |
| `hooks/notify.sh` | macOS 完成通知 |
| `hooks/protect-sensitive.sh` | 阻止编辑 .env/.pem/.key/credentials |
| `templates/*.tpl` | 项目初始化模板 |

### Skills (9 个)

| Skill | 类型 | 触发场景 |
|-------|------|---------|
| `commit` | Workflow | "commit this", "save changes" |
| `code-review` | Workflow | "review this code", "review PR" |
| `tdd` | Workflow | "TDD this", "write failing test first" |
| `plan` | Workflow | "plan this", "how should we implement" |
| `skill-creator` | Lifecycle | 创建/改进 skills |
| `find-skills` | Lifecycle | 发现/搜索 skills |
| `skill-reviewer` | Lifecycle | Review skill 质量 |
| `skill-auditor` | Lifecycle | 审计 skill 安全/一致性 |
| `skill-packager` | Lifecycle | 打包为可分发 plugin |

## Makefile Targets

```
make help           显示所有 targets
make install        安装到 ~/.claude/ (非破坏性)
make update         git pull + install
make doctor         诊断常见问题 (15 checks)
make audit          最佳实践检查 (18+ checks)
make list           列出已安装的 hooks/skills/plugins/permissions
make init-project   初始化项目配置 (P=<path>)
make sync           同步到 Codex + CodeBuddy
make fetch-libs     拉取第三方参考库 (git submodules)
```

## 项目初始化

```bash
make init-project P=/path/to/my-project
```

生成:
- `CLAUDE.md` — 项目级行为规则 + 开发命令
- `AGENTS.md` — Codex 项目配置
- `.claude/settings.local.json` — 项目级 permissions

## 跨机器同步

```bash
# 新机器上
git clone <repo> && cd wispx/tools/setup-toolkit && make install
```

## 跨 Agent 同步

```bash
make sync    # CLAUDE.md → ~/.codex/AGENTS.md + ~/.codebuddy/CLAUDE.md
```

## Local Override

本机特定配置不会被 `make install` 覆盖:

- `~/.claude/settings.local.json` — 本机额外 permissions
- `~/.claude/hooks.local/` — 本机额外 hooks

## 目录结构

```
tools/setup-toolkit/
├── Makefile                      # 生命周期入口
├── dotclaude/                    # → ~/.claude/
│   ├── CLAUDE.md
│   ├── settings.json
│   ├── statusline-command.sh
│   ├── hooks/
│   └── templates/
├── skills/                       # 9 个 agentskills.io 格式 skills
├── scripts/                      # install/doctor/audit/init-project/sync
├── docs/
│   ├── spec.md                   # 实现级规格文档
│   └── best-practices.md         # 最佳实践 + rationale
└── lib/                          # 第三方参考 (git submodules)
```

## 文档

- [Spec](docs/spec.md) — 实现级规格文档
- [Best Practices](docs/best-practices.md) — 配置最佳实践 + WHY
