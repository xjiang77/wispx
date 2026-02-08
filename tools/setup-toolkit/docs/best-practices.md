# Coding Agent 配置最佳实践

> 适用于 Claude Code / Codex / CodeBuddy。每条规则都说明 WHY。

---

## CLAUDE.md (Global Instructions)

| 规则 | 原因 |
|------|------|
| Global < 50 行（~750 tokens） | 每次会话都加载，过长压缩有效 context |
| 只放跨项目的行为规则 | 项目特定内容放 project-level CLAUDE.md |
| 用祈使句（"Run X" not "You should run X"） | 更直接，更少 tokens |
| 不写 persona（"you are..."） | agent 已经知道自己是什么，浪费 tokens |
| 不重复 agent 默认行为 | "think step by step" 等 agent 已经会做 |
| 用 headers + bullets 结构化 | agent 解析效率最高 |
| 避免 agent-specific 语法 | 保证 Codex/CodeBuddy 也能读 |

---

## Hooks

| 规则 | 原因 |
|------|------|
| 脚本 < 50 行，timeout < 5s | Hook 同步执行，太慢影响交互体验 |
| PreToolUse 用于 safety gates | 阻止危险操作是最高优先级 |
| Exit 0 = 通过, Exit 2 = 阻止 | Claude Code hook protocol |
| 脚本必须幂等 | 多次执行结果一致 |
| 只保留真正需要的 hooks | 每个 hook 都有调用 overhead |

---

## Permissions (settings.json)

| 规则 | 原因 |
|------|------|
| Allow: 日常开发命令（git/npm/go/cargo/python/docker） | 减少确认弹窗，提高效率 |
| Deny: 破坏性操作（rm -rf/force push/sudo/curl/wget） | 安全底线，防止误操作 |
| 缺失的命令弹确认框 | 安全默认行为 |
| Project-level 可覆盖 | 特定项目有特殊需求时用 `.claude/settings.local.json` |

### 必须 Deny 的操作

| 操作 | 原因 |
|------|------|
| `rm -rf` | 不可逆删除 |
| `sudo` | 权限提升 |
| `git push --force` | 覆盖远程历史 |
| `git reset --hard` | 丢弃未提交变更 |
| `curl` / `wget` | 防止下载执行恶意代码 |
| `dd` | 低级磁盘操作 |
| `chmod 777` | 过度权限 |

---

## Skills

| 规则 | 原因 |
|------|------|
| 一个 skill 做一件事 | 清晰的职责边界 |
| SKILL.md < 200 行 (ideal) | 过长占用 context window |
| 用 allowed-tools 限制 | 最小权限原则 |
| 不要同时启用太多 skill/plugin | 200k context 可能被压缩到 70k |

### agentskills.io 格式要求

```yaml
---
name: kebab-case-name           # 必须
description: 具体触发条件和功能  # 必须，要够 "pushy"
allowed-tools:                   # 推荐
  - ToolName
---

# Skill Name

[Instructions in markdown]
```

**description 写法**:
- 列出具体的触发词和场景
- 比如不要只写 "helps with commits"，而是 "Use when the user asks to commit, save changes, or says 'commit this'"
- 稍微 "pushy" 一点，确保 agent 在相关场景会触发

### Skill 目录结构

```
skill-name/
├── SKILL.md              # 必须：主指令
├── scripts/              # 可选：确定性任务的脚本
├── references/           # 可选：按需加载的文档
└── assets/               # 可选：输出模板等资源
```

**不要包含**: README.md, CHANGELOG.md, INSTALLATION_GUIDE.md — skills 是给 agent 用的，不是给人 onboarding 的。

---

## MCP

| 规则 | 原因 |
|------|------|
| 每个项目只启用 < 10 个 MCP | Tool definitions 占用 context |
| 用 project-level disabledMcpServers | 全局安装、项目级禁用 |
| 优先用内置工具 | 内置工具不额外占用 context |

---

## 跨 Agent 同步

| Agent | 全局配置 | 项目配置 | 同步方式 |
|-------|---------|---------|---------|
| Claude Code | `~/.claude/CLAUDE.md` | `CLAUDE.md` | 原生 |
| Codex | `~/.codex/AGENTS.md` | `AGENTS.md` | `make sync` 从 CLAUDE.md 生成 |
| CodeBuddy | `~/.codebuddy/CLAUDE.md` | `CLAUDE.md` | `make sync` 从 CLAUDE.md 复制 |

**CLAUDE.md 是唯一 source of truth**，其他 agent 的配置由 `make sync` 自动生成。

### 兼容性注意事项

- CLAUDE.md 内容避免 Claude Code-specific 语法（如 tool names）
- AGENTS.md 会自动添加 "auto-generated" 注释头
- 行为规则应该是 agent-agnostic 的（"Run tests" not "Use the Bash tool to run tests"）

---

## Local Override 使用指南

### 什么时候用 Local Override

- 公司机器需要额外的 deny 规则
- 个人机器需要允许额外的命令（如 brew, apt）
- 不同 OS 需要不同的 hooks

### 文件优先级

```
settings.json (base, managed by toolkit)
  ↓ merge
settings.local.json (local overrides, not touched by install)
  ↓ merge
.claude/settings.local.json (project-level)
```

### 示例

```json
// ~/.claude/settings.local.json
{
  "permissions": {
    "allow": [
      "Bash(brew *)",
      "Bash(terraform *)"
    ],
    "deny": []
  }
}
```
