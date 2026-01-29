# OpenCode 关键文件速查表

> 按模块分类的关键文件路径，便于后续源码学习

## 基础路径

```
/Users/kevinxjiang/Workspace/agent-wisp/research/source/opencode-dev/
```

---

## 1. 核心模块 (packages/opencode/src/)

### 1.1 Agent 系统

| 文件 | 说明 |
|------|------|
| `agent/agent.ts` | Agent 定义、内置 Agent 配置 |
| `agent/prompt/compaction.txt` | 上下文压缩提示词 |
| `agent/prompt/explore.txt` | explore Agent 提示词 |
| `agent/prompt/summary.txt` | 摘要生成提示词 |
| `agent/prompt/title.txt` | 标题生成提示词 |
| `agent/generate.txt` | Agent 生成提示词 |

### 1.2 Tool 系统

| 文件 | 说明 |
|------|------|
| `tool/tool.ts` | Tool.define() 核心实现 |
| `tool/truncation.ts` | 输出截断逻辑 |
| `tool/tools/` | 内置工具实现目录 |
| `tool/tools/bash.ts` | Bash 工具 |
| `tool/tools/read.ts` | 文件读取工具 |
| `tool/tools/edit.ts` | 文件编辑工具 |
| `tool/tools/grep.ts` | 代码搜索工具 |
| `tool/tools/glob.ts` | 文件匹配工具 |

### 1.3 Session/上下文管理

| 文件 | 说明 |
|------|------|
| `session/session.ts` | Session 数据结构和 CRUD |
| `session/message-v2.ts` | 消息数据结构 |
| `session/processor.ts` | 消息处理流水线 |
| `session/system.ts` | 系统提示构建 |
| `session/llm.ts` | LLM 调用封装 |
| `session/prompt.ts` | 提示词模板 |

### 1.4 Provider 抽象

| 文件 | 说明 |
|------|------|
| `provider/provider.ts` | Provider 接口定义 |
| `provider/transform.ts` | 消息格式转换 |
| `provider/providers/` | 具体 Provider 实现 |
| `provider/providers/anthropic.ts` | Anthropic 适配器 |
| `provider/providers/openai.ts` | OpenAI 适配器 |

### 1.5 权限系统

| 文件 | 说明 |
|------|------|
| `permission/next.ts` | 权限规则解析和匹配 |
| `permission/permission.ts` | 权限检查逻辑 |

### 1.6 配置管理

| 文件 | 说明 |
|------|------|
| `config/config.ts` | 配置加载和解析 |
| `config/schema.ts` | 配置 Schema 定义 |

### 1.7 事件系统

| 文件 | 说明 |
|------|------|
| `bus/bus.ts` | 事件总线实现 |
| `bus/bus-event.ts` | 事件定义 |

### 1.8 插件系统

| 文件 | 说明 |
|------|------|
| `plugin/index.ts` | 插件加载和管理 |
| `plugin/mcp.ts` | MCP 集成 |

### 1.9 其他核心

| 文件 | 说明 |
|------|------|
| `storage/storage.ts` | 数据持久化 |
| `id/id.ts` | ID 生成（Identifier） |
| `snapshot/` | 文件快照和 diff |
| `auth/` | 认证管理 |

---

## 2. TUI 应用 (packages/app/src/)

| 文件 | 说明 |
|------|------|
| `index.tsx` | TUI 入口 |
| `components/` | Solid.js 组件 |
| `hooks/` | 状态 Hooks |

---

## 3. CLI 入口 (packages/opencode/src/cli/)

| 文件 | 说明 |
|------|------|
| `index.ts` | CLI 主入口 |
| `commands/` | 子命令实现 |

---

## 4. 共享 UI (packages/ui/)

| 文件 | 说明 |
|------|------|
| `src/` | 共享组件库 |

---

## 5. 项目配置

| 文件 | 说明 |
|------|------|
| `.opencode/instructions.md` | 项目级指令 |
| `.opencode/config.json` | 项目配置 |
| `package.json` | 依赖和脚本 |
| `turbo.json` | Monorepo 配置 |

---

## 6. 文档和规范

| 文件 | 说明 |
|------|------|
| `AGENTS.md` | Agent 使用指南 |
| `CONTRIBUTING.md` | 贡献指南 |
| `specs/` | 规范文档目录 |

---

## 按学习优先级排序

### 高优先级（核心逻辑）

1. `session/session.ts` - 理解会话管理
2. `session/message-v2.ts` - 理解消息结构
3. `agent/agent.ts` - 理解 Agent 系统
4. `tool/tool.ts` - 理解工具系统
5. `permission/next.ts` - 理解权限系统

### 中优先级（上下文管理）

6. `session/processor.ts` - 消息处理流水线
7. `session/llm.ts` - LLM 调用封装
8. `session/system.ts` - 系统提示构建
9. `tool/truncation.ts` - 输出截断

### 低优先级（扩展功能）

10. `provider/` - Provider 抽象
11. `plugin/` - 插件系统
12. `bus/` - 事件总线
