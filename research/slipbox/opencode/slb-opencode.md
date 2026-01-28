# OpenCode 深度技术架构调研报告

**OpenCode (sst/opencode)** 是一个基于 TypeScript/Bun 的开源终端 AI 编码代理，采用客户端-服务器架构设计。本报告提供绘制技术架构图所需的全部详细信息。

## 系统整体架构采用分层设计

OpenCode 的核心设计理念是**"TUI 前端只是众多可能客户端之一"**，因此采用严格的客户端-服务器分离。后端服务器基于 **Hono HTTP 框架**运行，默认端口 **4096**，通过 REST API 和 SSE 事件流与多种客户端通信。

**部署模式**支持本地运行（单机）和远程服务器模式。服务器可通过 mDNS 暴露，允许移动端等远程客户端连接控制。核心模块包括 TUI（Go + Bubble Tea）、HTTP Server（Hono）、AI SDK 层（Vercel AI SDK）、Storage 层（文件系统）、Tool 系统、Provider 抽象层、以及 MCP/LSP 集成层。

```
┌─────────────────────────────────────────────────────────────────────────┐
│                            客户端层                                       │
│  ┌─────────┐  ┌───────────┐  ┌───────────┐  ┌──────────┐  ┌─────────┐  │
│  │   TUI   │  │  Desktop  │  │  VS Code  │  │   CLI    │  │  Mobile │  │
│  │(Bubble  │  │  (Tauri + │  │ Extension │  │ (Yargs)  │  │   App   │  │
│  │  Tea)   │  │ SolidJS)  │  │   (ACP)   │  │          │  │         │  │
│  └────┬────┘  └─────┬─────┘  └─────┬─────┘  └────┬─────┘  └────┬────┘  │
│       │             │              │             │              │        │
│       └─────────────┴──────────────┴─────────────┴──────────────┘        │
│                            HTTP/REST + SSE Stream                         │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    OpenCode 后端服务器 (Hono, 端口 4096)                   │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                        核心处理层                                   │  │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐   │  │
│  │  │  Session   │  │ Provider   │  │   Tool     │  │ Permission │   │  │
│  │  │  管理器    │  │  抽象层    │  │   系统     │  │   系统     │   │  │
│  │  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘  └────────────┘   │  │
│  │        │               │               │                          │  │
│  │        └───────────────┴───────────────┘                          │  │
│  │                        │                                          │  │
│  │        ┌───────────────┴───────────────┐                          │  │
│  │        ▼                               ▼                          │  │
│  │  ┌────────────────┐          ┌────────────────────┐               │  │
│  │  │  AI SDK 层     │          │   MCP Client 层    │               │  │
│  │  │ (Vercel AI SDK)│          │ (stdio/HTTP/SSE)   │               │  │
│  │  │  streamText()  │          │                    │               │  │
│  │  └───────┬────────┘          └─────────┬──────────┘               │  │
│  └──────────┼─────────────────────────────┼──────────────────────────┘  │
│             │                             │                              │
│  ┌──────────┴──────────┐    ┌─────────────┴────────────────────────┐   │
│  │    Storage 层       │    │         Event Bus (双总线)            │   │
│  │ (文件系统 + JSON)   │    │   Local Bus ←→ Global Bus → SSE      │   │
│  └─────────────────────┘    └──────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
                    │                           │
        ┌───────────┴─────────┐     ┌───────────┴───────────┐
        ▼                     ▼     ▼                       ▼
┌───────────────────┐  ┌──────────────────┐  ┌────────────────────────┐
│   LLM Providers   │  │   MCP Servers    │  │     LSP Servers        │
│  • Anthropic      │  │  • Local (stdio) │  │  • gopls (Go)          │
│  • OpenAI         │  │  • Remote (HTTP) │  │  • typescript-ls       │
│  • Google         │  │  • OAuth 支持     │  │  • rust-analyzer       │
│  • AWS Bedrock    │  └──────────────────┘  │  • 14+ 语言服务器       │
│  • 75+ providers  │                        └────────────────────────┘
└───────────────────┘
```

---

## packages/ 目录结构与模块职责划分

OpenCode 采用 **Bun workspaces + Turbo** 管理的 monorepo 架构。核心包位于 `packages/` 目录下，每个包有明确的职责边界。

| 包名 | 路径 | 职责描述 |
|------|------|----------|
| **opencode** | `packages/opencode/` | 核心 CLI 和后端服务器，包含 Agent、Tool、Provider、Session 等核心逻辑 |
| **sdk** | `packages/sdk/js/` | TypeScript SDK，从 OpenAPI 规范自动生成类型安全的客户端 |
| **plugin** | `packages/plugin/` | 插件框架，提供 `Tool.define()` 等扩展 API |
| **ui** | `packages/ui/` | SolidJS 共享 UI 组件库（SessionTurn、MessagePart 等） |
| **app** | `packages/app/` | Web 应用核心（SolidJS + Vite） |
| **desktop** | `packages/desktop/` | 桌面应用（Tauri + SolidJS） |
| **web** | `packages/web/` | 文档网站（Astro + Starlight） |
| **function** | `packages/function/` | Cloudflare Workers API |
| **console** | `packages/console/` | SaaS 管理平台（SolidStart + Drizzle ORM） |

**packages/opencode/src/ 内部结构**：

```
packages/opencode/src/
├── index.ts              # CLI 入口 (Yargs 命令路由)
├── server/
│   └── server.ts         # Hono HTTP + SSE 服务器 (REST API + 事件流)
├── session/
│   ├── index.ts          # Session 命名空间 (生命周期管理)
│   ├── message-v2.ts     # MessageV2 系统 (多 Part 类型支持)
│   ├── prompt.ts         # SessionPrompt.loop() 核心处理循环
│   ├── compaction.ts     # 上下文压缩算法
│   └── summary.ts        # 会话摘要生成
├── provider/
│   ├── provider.ts       # Provider 命名空间 (75+ AI 提供商抽象)
│   ├── models.ts         # Models.dev 数据库集成
│   └── transform.ts      # Provider 特定消息转换
├── tool/
│   ├── tool.ts           # Tool 定义和执行框架
│   ├── registry.ts       # 工具注册中心
│   ├── task.ts           # 子代理任务工具
│   ├── bash.ts           # Shell 命令执行
│   ├── read.ts           # 文件读取
│   ├── write.ts          # 文件写入
│   ├── edit.ts           # 搜索替换编辑
│   └── ...               # grep, glob, webfetch 等
├── agent/
│   └── agent.ts          # Agent 配置和加载
├── config/
│   └── config.ts         # 层级配置系统 (1078 行)
├── storage/
│   └── storage.ts        # 文件系统存储抽象
├── mcp/
│   ├── index.ts          # MCP 客户端管理
│   └── oauth-provider.ts # MCP OAuth 认证
├── lsp/
│   └── index.ts          # LSP 客户端集成 (14+ 语言)
├── permission/
│   └── index.ts          # 权限检查系统
├── plugin/
│   ├── index.ts          # 插件加载器
│   └── codex.ts          # Codex 插件示例
├── bus/
│   ├── index.ts          # 本地事件总线
│   └── global.ts         # 全局事件总线
└── cli/cmd/
    ├── run.ts            # 运行命令
    ├── auth.ts           # 认证命令
    └── tui/              # TUI 组件
```

**构建依赖顺序**：sdk → plugin → opencode → ui → app → desktop

---

## Agent 系统的三层架构

OpenCode 的 Agent 系统分为**内置 Agent**、**自定义 Agent** 和 **Subagent** 三层。Agent 通过 `Agent.Info` 接口定义，支持 Markdown 或 JSON 配置。

### Agent.Info 核心数据结构

```typescript
interface Agent.Info {
  id: string;                              // 唯一标识
  prompt: string;                          // System Prompt
  mode: "primary" | "subagent" | "all";    // 使用模式
  temperature?: number;                    // 采样温度
  topP?: number;                           // Top-P 参数
  color?: string;                          // UI 颜色标识
  permission: {                            // 权限配置
    edit: "ask" | "allow" | "deny";
    bash: Record<string, "ask" | "allow" | "deny">;  // 通配符模式
    webfetch: "ask" | "allow" | "deny";
    external_directory: "ask" | "allow" | "deny";
  };
  model?: { providerID: string; modelID: string };  // 模型覆盖
  tools?: Record<string, boolean>;         // 工具启用/禁用
  steps?: number;                          // 最大执行步数
}
```

### 内置 Agent 配置

| Agent | Mode | Edit | Bash | 用途 |
|-------|------|------|------|------|
| `build` | primary | allow | allow (*) | 默认全功能开发代理 |
| `plan` | primary | deny | 仅 git/ls/grep | 只读分析代理 |
| `general` | subagent | allow | allow (*) | 复杂任务委派 |
| `explorer` | subagent | deny | limited | 代码探索 |
| `title` | subagent | - | - | 标题生成 |
| `compaction` | subagent | - | - | 上下文压缩 |

### 自定义 Agent 定义方式

**Markdown 格式** (`.opencode/agent/*.md`)：
```markdown
---
mode: primary
permission:
  edit: allow
  bash:
    "npm *": allow
    "yarn *": allow
    "*": ask
tools:
  todoread: false
---

你是一个前端开发专家，专注于 React 和 TypeScript...
```

**JSON 格式** (`opencode.json`)：
```json
{
  "agent": {
    "code-reviewer": {
      "mode": "primary",
      "model": "anthropic/claude-sonnet-4-5",
      "permission": { "edit": "deny", "bash": { "*": "ask" } }
    }
  }
}
```

---

## Tool 系统的插件化架构

Tool 系统采用**注册中心模式**，支持内置工具、MCP 动态工具和插件自定义工具三类来源。

### Tool.Info 核心接口

```typescript
interface Tool.Info {
  id: string;                              // 工具唯一标识
  description: string;                     // 描述（供 LLM 理解）
  parameters: z.ZodType;                   // Zod Schema 参数验证
  execute: (params, ctx: Tool.Context) => Promise<Tool.Result>;
}

interface Tool.Context {
  sessionID: string;
  messageID: string;
  abort: AbortSignal;
  metadata: (update: any) => void;         // 流式元数据更新
}

interface Tool.Result {
  title: string;                           // UI 显示标题
  output: string;                          // 返回给 LLM 的输出
  metadata?: any;                          // 结构化数据
  attachments?: FilePart[];                // 图片/PDF 附件
}
```

### 内置工具列表 (ToolRegistry.BUILTIN)

| 工具名 | 源文件 | 功能 |
|--------|--------|------|
| `read` | tool/read.ts | 读取文件，支持行范围、图片/PDF |
| `write` | tool/write.ts | 创建或覆盖整个文件 |
| `edit` | tool/edit.ts | 基于搜索替换的文件编辑 |
| `bash` | tool/bash.ts | Shell 命令执行 |
| `grep` | tool/grep.ts | ripgrep 内容搜索 |
| `glob` | tool/glob.ts | 文件模式匹配 |
| `ls` | tool/ls.ts | 目录列表 |
| `task` | tool/task.ts | 子代理任务委派 |
| `webfetch` | tool/webfetch.ts | HTTP 内容获取 |
| `lsp-diagnostics` | tool/lsp-diagnostics.ts | LSP 诊断 |
| `patch` | tool/patch.ts | 统一差异补丁应用 |

### 工具注册机制

```
┌─────────────────────────────────────────────────────────────┐
│                    ToolRegistry 工具注册                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. 内置工具 (BUILTIN[])                                     │
│     └── 启动时静态注册                                        │
│                                                              │
│  2. MCP 动态工具                                             │
│     └── MCP.list() → convertMcpTool() → dynamicTool()       │
│     └── 工具名前缀: {serverName}_{toolName}                  │
│                                                              │
│  3. 插件工具                                                 │
│     └── ToolRegistry.fromPlugin(pluginTool)                  │
│                                                              │
│  resolveTools() → 根据 Agent 配置过滤 → 返回可用工具 Map     │
└─────────────────────────────────────────────────────────────┘
```

---

## MCP 协议集成实现

OpenCode 实现 **Model Context Protocol (MCP)** 用于扩展外部工具能力，支持 **stdio** 和 **HTTP/SSE** 两种传输方式。

### MCP 服务器配置格式

```json
{
  "mcp": {
    "local-server": {
      "type": "local",
      "command": ["node", "path/to/server.js"],
      "args": ["--option"],
      "environment": { "API_KEY": "xxx" },
      "timeout": 5000,
      "enabled": true
    },
    "remote-server": {
      "type": "remote",
      "url": "https://api.example.com/mcp",
      "headers": { "Authorization": "Bearer xxx" },
      "oauth": true
    }
  }
}
```

### MCP 连接生命周期

```
1. 配置加载 → 读取 opencode.json mcp 配置
       │
       ▼
2. 传输层创建
   ├── Local: StdioClientTransport (spawn process)
   └── Remote: StreamableHTTPClientTransport / SSEClientTransport
       │
       ▼
3. OAuth 认证 (Remote only)
   ├── McpOAuthProvider: PKCE + 动态客户端注册
   └── Callback: http://127.0.0.1:19876/mcp/oauth/callback
       │
       ▼
4. 能力发现
   ├── client.listTools()     → 获取可用工具
   ├── client.listPrompts()   → 获取提示模板
   └── client.listResources() → 获取资源列表
       │
       ▼
5. 动态注册
   ├── convertMcpTool() → dynamicTool() 包装
   └── Bus.publish(MCP.ToolsChanged) → 通知客户端
       │
       ▼
6. 状态: connected | disabled | failed | needs_auth
```

---

## Provider 抽象层支持 75+ AI 提供商

Provider 层通过 **Vercel AI SDK** 实现统一接口，支持运行时动态加载提供商 SDK。

### 支持的主要 AI SDK 包

```typescript
// 内置支持
@ai-sdk/anthropic      // Anthropic Claude
@ai-sdk/openai         // OpenAI GPT
@ai-sdk/google         // Google Gemini
@ai-sdk/google-vertex  // Vertex AI
@ai-sdk/amazon-bedrock // AWS Bedrock
@ai-sdk/azure          // Azure OpenAI
@ai-sdk/openai-compatible  // Ollama、LM Studio 等
@openrouter/ai-sdk-provider // OpenRouter
// ... 75+ providers via models.dev
```

### Provider 配置 Schema

```typescript
Config.Provider = z.object({
  disabled: z.boolean().optional(),
  apiKey: z.string().optional(),        // 或 "{env:ANTHROPIC_API_KEY}"
  baseURL: z.string().optional(),
  timeout: z.number().optional(),
  models: z.record(z.object({
    disabled: z.boolean().optional(),
    alias: z.string().optional(),
    limit: z.object({
      context: z.number().optional(),
      output: z.number().optional()
    }).optional()
  })).optional()
});
```

### ProviderTransform 消息转换

不同 Provider 有特定的消息格式要求，`ProviderTransform` 负责规范化：

- **Anthropic**: 工具 ID 清理为纯字母数字，提示缓存控制
- **Mistral**: 工具 ID 规范化为 9 个字母数字
- **通用**: 缓存控制头应用、输出 token 限制计算

---

## 用户输入到 AI 响应的完整流程

核心处理循环位于 `SessionPrompt.loop()`，实现可重入的多轮对话处理。

```
┌──────────────────────────────────────────────────────────────────────┐
│                    用户输入处理完整流程                                │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  [用户输入]                                                           │
│       │                                                               │
│       ▼                                                               │
│  HTTP POST /session/{id}/message                                      │
│  Body: { parts: [{type: "text", text: "..."}], agent: "build" }      │
│       │                                                               │
│       ▼                                                               │
│  SessionPrompt.prompt()                                               │
│  ├── 创建 User Message → Storage.put()                               │
│  ├── Bus.publish(MessageV2.Event.Created)                            │
│  └── 调用 SessionPrompt.loop()                                        │
│       │                                                               │
│       ▼                                                               │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │              SessionPrompt.loop() 主循环                         │ │
│  │                                                                   │ │
│  │  while (true) {                                                  │ │
│  │    1. 获取消息列表 → MessageV2.list(sessionID)                   │ │
│  │                                                                   │ │
│  │    2. 检测上下文溢出 → SessionCompaction.isOverflow()            │ │
│  │       └── 触发压缩 → Compaction Agent → 生成摘要消息              │ │
│  │                                                                   │ │
│  │    3. 解析系统提示 → resolveSystemPrompt(agent)                  │ │
│  │       └── Agent.prompt + Environment + Custom Instructions       │ │
│  │                                                                   │ │
│  │    4. 解析工具集 → resolveTools(agent, provider)                 │ │
│  │       └── BUILTIN + MCP.list() + Plugin.tools                    │ │
│  │       └── 根据 agent.tools 配置过滤                               │ │
│  │                                                                   │ │
│  │    5. 获取 AI 模型 → Provider.getLanguage(providerID, modelID)   │ │
│  │                                                                   │ │
│  │    6. 调用 AI SDK                                                 │ │
│  │       const response = await streamText({                        │ │
│  │         model: wrapLanguageModel(model),                         │ │
│  │         messages: preparedMessages,                              │ │
│  │         tools: resolvedTools,                                    │ │
│  │         temperature: agent.temperature,                          │ │
│  │         maxOutputTokens: ProviderTransform.maxOutputTokens(),    │ │
│  │         abortSignal: abortController.signal                      │ │
│  │       });                                                        │ │
│  │                                                                   │ │
│  │    7. 流式处理响应 → SessionProcessor.process()                  │ │
│  │       └── 创建 Assistant Message                                 │ │
│  │       └── 流式更新 TextPart (delta)                              │ │
│  │       └── Bus.publish(MessageV2.Event.PartUpdated)               │ │
│  │                                                                   │ │
│  │    8. 处理工具调用 (若有)                                         │ │
│  │       for (toolCall of response.toolCalls) {                     │ │
│  │         → Permission.ask() 权限检查                               │ │
│  │         → Tool.execute() 执行工具                                 │ │
│  │         → 更新 ToolPart (running → completed)                    │ │
│  │       }                                                          │ │
│  │                                                                   │ │
│  │    9. 检查退出条件                                                │ │
│  │       if (finish === "stop" || "length" || error) break;         │ │
│  │       if (finish === "tool_use") continue; // 继续循环            │ │
│  │  }                                                               │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│       │                                                               │
│       ▼                                                               │
│  返回处理结果 → SSE 事件流通知客户端                                    │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 工具调用执行流程与权限检查

工具执行遵循严格的生命周期：**pending → running → completed/error**。

### 工具执行完整流程

```
┌──────────────────────────────────────────────────────────────────────┐
│                      工具调用完整生命周期                              │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  LLM 返回 tool_calls: [{ name: "bash", args: { command: "ls -la" }}]│
│       │                                                               │
│       ▼                                                               │
│  1. 创建 ToolPart (state: "pending")                                 │
│     Bus.publish(MessageV2.Event.PartUpdated)                         │
│       │                                                               │
│       ▼                                                               │
│  2. Plugin Hook: tool.execute.before (可选)                          │
│     └── 日志、验证、自定义逻辑                                         │
│       │                                                               │
│       ▼                                                               │
│  3. Permission.ask() 权限检查                                         │
│     ┌────────────────────────────────────────────────────────────┐  │
│     │  Wildcard 模式匹配:                                         │  │
│     │  agent.permission.bash["git *"] === "allow"                 │  │
│     │  agent.permission.bash["rm *"] === "deny"                   │  │
│     │  agent.permission.bash["*"] === "ask"                       │  │
│     │                                                             │  │
│     │  匹配结果:                                                   │  │
│     │  ├── "allow" → 自动批准                                     │  │
│     │  ├── "deny"  → 抛出 Permission.RejectedError               │  │
│     │  └── "ask"   → 阻塞等待用户响应                             │  │
│     │               Bus.publish(permission.asked) → SSE → TUI    │  │
│     │               用户选择: once | always | reject              │  │
│     │               Permission.respond() → 继续或拒绝              │  │
│     └────────────────────────────────────────────────────────────┘  │
│       │                                                               │
│       ▼                                                               │
│  4. 工具执行 (state: "running")                                      │
│     ├── BashTool    → child_process.spawn()                         │
│     ├── EditTool    → fs.readFile() + search/replace + fs.writeFile()│
│     ├── ReadTool    → fs.readFile() + 行范围截取                     │
│     ├── GrepTool    → ripgrep subprocess                             │
│     ├── MCP Tool    → client.callTool({ name, arguments })          │
│     └── ctx.metadata() → 流式更新执行状态                            │
│       │                                                               │
│       ▼                                                               │
│  5. Plugin Hook: tool.execute.after (可选)                           │
│     └── 后处理、格式化、日志                                          │
│       │                                                               │
│       ▼                                                               │
│  6. 结果返回 (state: "completed" | "error")                          │
│     ToolPart.output = Tool.Result.output                            │
│     Bus.publish(MessageV2.Event.PartUpdated)                        │
│       │                                                               │
│       ▼                                                               │
│  7. 继续 SessionPrompt.loop() → 下一轮 AI 调用                       │
└──────────────────────────────────────────────────────────────────────┘
```

### 权限类型和配置

| 权限类型 | 适用工具 | 配置键 |
|---------|---------|--------|
| `bash` | BashTool | `agent.permission.bash` |
| `edit` | EditTool, WriteTool, PatchTool | `agent.permission.edit` |
| `external_directory` | 所有文件操作 | `agent.permission.external_directory` |
| `webfetch` | WebFetchTool | `config.permission.webfetch` |

---

## 数据流和 SSE 流式响应机制

OpenCode 使用**双总线事件系统**实现实时状态同步：Local Bus（实例级）和 Global Bus（跨实例）。

### SSE 事件流架构

```
┌─────────────────────────────────────────────────────────────────────┐
│                        SSE 事件流架构                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  [AI SDK streamText()]                                              │
│       │ 流式 chunks                                                  │
│       ▼                                                              │
│  [SessionProcessor.process()]                                        │
│       │ 解析 chunks → 更新 MessageV2.Part                           │
│       ▼                                                              │
│  [Bus.publish(MessageV2.Event.PartUpdated)]                         │
│       │ 本地事件                                                      │
│       ▼                                                              │
│  [GlobalBus.publish()] → [SSE Endpoint: GET /event]                 │
│                               │                                      │
│       ┌───────────────────────┼───────────────────────┐             │
│       ▼                       ▼                       ▼             │
│   [TUI Client]          [Desktop Client]       [VS Code]           │
│   EventSource           EventSource            ACP Protocol        │
│                                                                      │
│  SSE 数据格式:                                                       │
│  event: message.part.updated                                        │
│  data: {                                                            │
│    "sessionID": "ses_xxx",                                          │
│    "messageID": "msg_xxx",                                          │
│    "part": {                                                        │
│      "type": "text",                                                │
│      "delta": "增量文本...",   // 本次新增                           │
│      "text": "累计文本..."     // 完整内容                           │
│    }                                                                │
│  }                                                                  │
└─────────────────────────────────────────────────────────────────────┘
```

### 主要 SSE 事件类型

| 事件名 | 触发时机 | 载荷 |
|--------|---------|------|
| `session.created/updated/deleted` | Session 生命周期 | Session.Info |
| `message.created/updated` | Message 变更 | MessageV2.Info |
| `message.part.created/updated` | Part 更新（含增量） | { part, delta? } |
| `permission.asked/replied` | 权限请求/响应 | Permission.Info |
| `mcp.tools_changed` | MCP 工具列表变化 | { serverName } |

---

## 数据模型与存储结构

OpenCode 采用**文件系统存储**（非 SQLite），使用层次化键路径组织数据。

### 存储位置

| 类型 | 路径 |
|------|------|
| 全局数据 | `~/.local/share/opencode/` |
| 认证信息 | `~/.local/share/opencode/auth.json` |
| 全局配置 | `~/.config/opencode/opencode.json` |
| 项目数据 | `{project}/.opencode/` |

### Session 数据结构

```typescript
interface Session.Info {
  id: string;              // "ses_{uuid}" 降序标识符
  parentID?: string;       // 父 Session ID（子任务场景）
  projectID: string;       // 所属项目
  directory: string;       // 工作目录
  title: string;           // 显示标题
  agent: string;           // 使用的 Agent
  version: string;         // OpenCode 版本
  share?: { url: string }; // 分享链接
  time: {
    created: number;       // 创建时间戳
    updated: number;       // 更新时间戳
    compacting?: number;   // 压缩开始时间
  };
  summary?: {              // 文件变更摘要
    additions: number;
    deletions: number;
    files: string[];
    diffs: FileDiff[];
  };
}
```

### MessageV2 数据结构

```typescript
// Assistant Message
interface AssistantMessage {
  id: string;              // 消息 ID
  sessionID: string;       // 所属 Session
  parentID: string;        // 父消息 ID（User Message）
  role: "assistant";
  agent?: string;          // Agent 名称（如 "compaction"）
  summary?: boolean;       // 是否为摘要消息
  
  // 模型信息
  modelID: string;
  providerID: string;
  
  // Token 统计
  tokens: {
    input: number;
    output: number;
    reasoning: number;
    cache: { read: number; write: number };
  };
  
  cost: number;            // 费用（美元）
  system: string[];        // 系统提示列表
  finish?: "stop" | "length" | "tool_use" | "error";
  error?: { data: ProviderAuthErrorData | UnknownErrorData };
  
  time: { created: number; updated: number };
}
```

### Part 联合类型

```typescript
type Part = TextPart | ToolPart | FilePart | ReasoningPart 
          | SnapshotPart | CompactionPart | AgentPart;

// TextPart - 文本内容
interface TextPart {
  id: string;
  messageID: string;
  sessionID: string;
  type: "text";
  text: string;
}

// ToolPart - 工具调用
interface ToolPart {
  id: string;
  messageID: string;
  sessionID: string;
  type: "tool";
  name: string;              // 工具名称
  state: {
    status: "pending" | "running" | "completed" | "error";
    input: Record<string, any>;
    output?: string;
    time: {
      created: number;
      started?: number;
      completed?: number;
      compacted?: number;    // 压缩时间戳（用于剪枝）
    };
  };
}

// FilePart - 文件/图片
interface FilePart {
  id: string;
  type: "file";
  mime: string;
  url: string;               // data:${mime};base64,...
}

// CompactionPart - 压缩标记
interface CompactionPart {
  id: string;
  type: "compaction";
  state: {
    status: "pending" | "completed";
    auto: boolean;
  };
}
```

---

## 上下文管理与 Compaction 流程

当对话上下文接近模型 token 限制时，自动触发 **Compaction（压缩）** 流程。

### 溢出检测算法

```typescript
function isOverflow(tokens: TokenUsage, model: Model): boolean {
  if (config.compaction?.auto === false) return false;
  if (model.context === 0) return false;
  
  const total = tokens.input + tokens.cache.read + tokens.output;
  const available = model.context - Math.min(model.limit.output, OUTPUT_TOKEN_MAX);
  // OUTPUT_TOKEN_MAX = 32000
  
  return total >= available;
}
```

### Compaction 流程

```
1. 检测溢出 → isOverflow() === true
       │
       ▼
2. 创建 CompactionPart (status: "pending")
       │
       ▼
3. 调用 Compaction Agent
   └── 使用 small_model 生成摘要
       │
       ▼
4. 创建 Summary Message (summary: true)
   └── 包含压缩后的上下文摘要
       │
       ▼
5. Pruning（可选）
   ├── 保护最近 40k tokens
   ├── 标记旧工具输出 (compacted: timestamp)
   └── 仅当释放 > 20k tokens 时执行
       │
       ▼
6. 发布事件 session.compacted
   └── 可选注入继续提示 (auto-continue)
```

### 消息过滤逻辑

```typescript
function filterCompacted(messages: Message[]): Message[] {
  // 1. 找到最后一个 summary: true 的消息
  // 2. 丢弃之前的所有消息
  // 3. 过滤 time.compacted 已设置的 tool parts
  // 4. 返回过滤后的消息流
}
```

---

## opencode.json 完整配置 Schema

```json
{
  "$schema": "https://opencode.ai/config.json",
  
  "theme": "opencode",
  "model": "anthropic/claude-sonnet-4-5",
  "small_model": "anthropic/claude-haiku-4-5",
  "autoupdate": true,
  "default_agent": "build",
  
  "tui": {
    "scroll_speed": 3,
    "scroll_acceleration": { "enabled": true },
    "diff_style": "auto"
  },
  
  "server": {
    "port": 4096,
    "hostname": "0.0.0.0",
    "mdns": true,
    "cors": ["http://localhost:5173"]
  },
  
  "tools": {
    "write": false,
    "bash": false
  },
  
  "permission": {
    "edit": "ask",
    "bash": "ask",
    "webfetch": "deny",
    "doom_loop": "deny",
    "external_directory": "deny"
  },
  
  "compaction": {
    "auto": true,
    "prune": true
  },
  
  "watcher": {
    "ignore": ["node_modules/**", "dist/**", ".git/**"]
  },
  
  "provider": {
    "anthropic": {
      "options": {
        "timeout": 600000,
        "apiKey": "{env:ANTHROPIC_API_KEY}"
      }
    }
  },
  
  "agent": {
    "code-reviewer": {
      "description": "代码审查 Agent",
      "model": "anthropic/claude-sonnet-4-5",
      "permission": { "edit": "deny" }
    }
  },
  
  "mcp": {
    "local-server": {
      "type": "local",
      "command": ["node", "server.js"]
    }
  },
  
  "plugin": ["opencode-helicone-session"],
  
  "instructions": ["CONTRIBUTING.md", "docs/*.md"],
  
  "disabled_providers": ["openai"],
  "enabled_providers": ["anthropic"],
  
  "experimental": {}
}
```

---

## HTTP API 端点参考

| 端点 | 方法 | 描述 |
|------|------|------|
| `/session` | GET | 获取所有会话列表 |
| `/session/{id}` | GET | 获取特定会话详情 |
| `/session/{id}/message` | POST | 发送消息（触发处理循环） |
| `/session/{id}/messages` | GET | 获取会话消息列表 |
| `/session/{id}/abort` | POST | 中止当前处理 |
| `/event` | GET | SSE 事件流订阅 |
| `/config` | GET | 获取当前配置 |
| `/mcp/status` | GET | MCP 服务器状态 |
| `/mcp/add` | POST | 添加 MCP 服务器 |
| `/mcp/{name}/connect` | POST | 连接 MCP 服务器 |
| `/pty` | POST | 创建 PTY 会话 |
| `/pty/{id}/ws` | WebSocket | PTY 双向通信 |
| `/permission/{id}/respond` | POST | 响应权限请求 |

---

## 技术栈汇总

| 层级 | 技术选型 |
|------|----------|
| **运行时** | Bun |
| **HTTP 服务器** | Hono |
| **AI SDK** | Vercel AI SDK + 75+ 提供商适配器 |
| **存储** | 文件系统 (JSON) + XDG 目录标准 |
| **LSP 客户端** | vscode-jsonrpc |
| **TUI** | Go + Bubble Tea |
| **Web 前端** | Astro + Starlight / SolidJS + Vite |
| **桌面应用** | Tauri + SolidJS |
| **云部署** | SST v3 + Cloudflare Workers/Pages |
| **数据库 (Console)** | PostgreSQL (PlanetScale) + Drizzle ORM |
| **认证** | OpenAuth.js |
| **IDE 协议** | ACP (Agent Client Protocol) |

---

## 数据关系总图

```
┌─────────────────────────────────────────────────────────────────────┐
│                         数据关系模型                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────┐     1:N     ┌──────────────┐     1:N              │
│  │   Session    │ ──────────→ │   Message    │ ──────────┐         │
│  │              │             │              │           │          │
│  │ • id         │             │ • id         │           ▼          │
│  │ • parentID ──┼─────────┐   │ • sessionID  │     ┌──────────┐    │
│  │ • title      │         │   │ • role       │     │   Part   │    │
│  │ • agent      │         │   │ • tokens     │     │          │    │
│  │ • time       │         │   │ • cost       │     │ • TextPart│   │
│  │ • share      │         │   │ • summary    │     │ • ToolPart│   │
│  └──────────────┘         │   └──────────────┘     │ • FilePart│   │
│         ↑                 │                         └──────────┘    │
│         │ parentID        │                                         │
│         │                 ▼                                         │
│  ┌──────────────┐  ┌──────────────┐                                │
│  │Child Session │  │ Permission   │                                │
│  │  (Subagent)  │  │   .Info      │                                │
│  │              │  │              │                                │
│  │ 独立消息流    │  │ • pattern    │                                │
│  │ 结果返回父级  │  │ • response   │                                │
│  └──────────────┘  └──────────────┘                                │
│                                                                      │
├─────────────────────────────────────────────────────────────────────┤
│                         配置层                                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────┐    merge    ┌─────────────┐                       │
│  │opencode.json│ ──────────→ │Config.Info  │                       │
│  │             │             │             │                       │
│  │ • theme     │             │ • agent{}   │                       │
│  │ • model     │             │ • provider{}│                       │
│  │ • permission│             │ • mcp{}     │                       │
│  │ • agent     │             │ • tools{}   │                       │
│  └─────────────┘             └─────────────┘                       │
│                                     │                               │
│        ┌────────────────────────────┼────────────────┐             │
│        ▼                            ▼                ▼             │
│  ┌───────────┐           ┌──────────────┐    ┌───────────┐        │
│  │Config.Agent│           │Config.Provider│   │Config.MCP │        │
│  │           │           │              │    │           │        │
│  │• permission│           │• options     │    │• servers  │        │
│  │• model    │           │• models      │    │• tools    │        │
│  │• prompt   │           │• apiKey      │    │           │        │
│  └───────────┘           └──────────────┘    └───────────┘        │
└─────────────────────────────────────────────────────────────────────┘
```

---

本报告涵盖了绘制 OpenCode 技术架构图所需的全部关键信息，包括系统整体架构、模块划分、核心组件实现、数据流和通信协议、数据模型和存储结构。所有信息均来自 DeepWiki 文档分析、GitHub 源码和官方文档。