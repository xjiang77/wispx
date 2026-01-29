# OpenCode 架构深度解析

> 基于苏格拉底式探索学习的笔记整理
> 日期：2026-01-28

## 1. 项目概览

### 1.1 项目定位

OpenCode 是一个**开源 AI 编程助手**，定位对标 Claude Code / Cursor / Aider 等工具。

**核心特点：**
- 开源：MIT 协议
- 多 LLM 支持：30+ 提供商
- 多端：CLI (TUI) + Web UI + 桌面应用
- 可扩展：插件系统 + MCP 支持

### 1.2 技术栈

| 层级 | 技术选型 |
|------|----------|
| 运行时 | Bun (TypeScript) |
| TUI | Solid.js + @opentui |
| Web UI | React + Vite |
| 桌面 | Tauri |
| AI SDK | Vercel AI SDK |
| 验证 | Zod |
| 状态 | 事件总线 (BusEvent) |

### 1.3 与 Claude Code 对比

| 方面 | OpenCode | Claude Code |
|------|----------|-------------|
| 语言 | TypeScript (Bun) | TypeScript (Node) |
| TUI | Solid.js + @opentui | Ink (React) |
| LLM | 30+ 提供商可选 | 仅 Anthropic |
| 扩展 | 插件系统 + MCP | MCP + Hooks |
| 架构 | Client-Server 分离 | 一体化 CLI |

**相似之处：**
- 核心循环：用户输入 → 系统提示 → LLM → 工具调用 → 迭代
- 基础工具集：bash、read、edit、grep、glob、web search
- 权限模型：交互式确认 + 规则记忆
- 子 Agent 模式：主 Agent 可以启动子任务

---

## 2. 核心循环分析

### 2.1 主循环流程

```
┌─────────────────────────────────────────────────────────────┐
│                      用户输入                                │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    上下文收集                                │
│  - 系统提示（Agent 提示词、工具定义、项目指令）              │
│  - 消息历史                                                  │
│  - 配置信息（权限规则、MCP 工具）                            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    LLM 调用                                  │
│  - Provider 适配                                             │
│  - Stream 处理                                               │
│  - Token 计数                                                │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    工具执行                                  │
│  - 权限检查                                                  │
│  - 参数验证（Zod）                                           │
│  - 执行 + 截断输出                                           │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    验证 & 迭代                               │
│  - 结果返回 LLM                                              │
│  - 继续对话或完成                                            │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 关键入口点

- **CLI 入口**: `packages/opencode/src/cli/index.ts`
- **TUI 入口**: `packages/app/src/index.tsx`
- **核心逻辑**: `packages/opencode/src/session/`

---

## 3. 模块架构

### 3.1 packages/ 结构

```
packages/
├── opencode/      # 核心逻辑库（无 UI）
│   ├── src/
│   │   ├── agent/      # Agent 定义和管理
│   │   ├── tool/       # 工具系统
│   │   ├── session/    # 会话管理
│   │   ├── provider/   # LLM 提供商抽象
│   │   ├── permission/ # 权限系统
│   │   ├── config/     # 配置管理
│   │   ├── plugin/     # 插件系统
│   │   └── ...
│
├── app/           # TUI 应用（Solid.js + @opentui）
├── console/       # Web 控制台
├── desktop/       # 桌面应用（Tauri）
├── ui/            # 共享 UI 组件
├── sdk/           # 外部 SDK
├── util/          # 通用工具函数
├── web/           # 官网
├── docs/          # 文档
├── plugin/        # 内置插件
├── extensions/    # 编辑器扩展
└── ...
```

### 3.2 核心模块关系图

```
                    ┌─────────────┐
                    │    app/     │  TUI 界面
                    │  (Solid.js) │
                    └──────┬──────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────┐
│                     opencode/                             │
│  ┌─────────┐  ┌─────────┐  ┌───────────┐  ┌──────────┐  │
│  │ session │◄─│  agent  │──│   tool    │──│permission│  │
│  └────┬────┘  └────┬────┘  └─────┬─────┘  └──────────┘  │
│       │            │             │                       │
│       ▼            ▼             ▼                       │
│  ┌─────────┐  ┌─────────┐  ┌───────────┐               │
│  │message-v2│ │ provider │  │   bus     │               │
│  └─────────┘  └─────────┘  └───────────┘               │
└──────────────────────────────────────────────────────────┘
```

---

## 4. Agent/Tool 系统深度解析

### 4.1 Tool.define() 装饰器模式

**文件**: `packages/opencode/src/tool/tool.ts`

```typescript
export function define<Parameters extends z.ZodType, Result extends Metadata>(
  id: string,
  init: Info<Parameters, Result>["init"] | Awaited<ReturnType<Info<Parameters, Result>["init"]>>,
): Info<Parameters, Result> {
  return {
    id,
    init: async (initCtx) => {
      const toolInfo = init instanceof Function ? await init(initCtx) : init

      // 保存原始 execute
      const execute = toolInfo.execute

      // 包装新的 execute（装饰器模式）
      toolInfo.execute = async (args, ctx) => {
        // 1. 参数验证（前置处理）
        try {
          toolInfo.parameters.parse(args)
        } catch (error) {
          throw new Error(`The ${id} tool was called with invalid arguments...`)
        }

        // 2. 执行原始逻辑
        const result = await execute(args, ctx)

        // 3. 输出截断（后置处理）
        const truncated = await Truncate.output(result.output, {}, initCtx?.agent)
        return {
          ...result,
          output: truncated.content,
          metadata: { ...result.metadata, truncated: truncated.truncated }
        }
      }
      return toolInfo
    },
  }
}
```

**设计优点**：工具开发者只需实现核心逻辑，验证和截断由框架统一处理。

### 4.2 Tool 接口定义

```typescript
export interface Info<Parameters extends z.ZodType, M extends Metadata> {
  id: string
  init: (ctx?: InitContext) => Promise<{
    description: string
    parameters: Parameters
    execute(args: z.infer<Parameters>, ctx: Context): Promise<{
      title: string
      metadata: M
      output: string
      attachments?: MessageV2.FilePart[]
    }>
  }>
}
```

### 4.3 Agent 定义

**文件**: `packages/opencode/src/agent/agent.ts`

```typescript
export const Info = z.object({
  name: z.string(),
  description: z.string().optional(),
  mode: z.enum(["subagent", "primary", "all"]),
  native: z.boolean().optional(),
  hidden: z.boolean().optional(),
  topP: z.number().optional(),
  temperature: z.number().optional(),
  color: z.string().optional(),
  permission: PermissionNext.Ruleset,
  model: z.object({
    modelID: z.string(),
    providerID: z.string(),
  }).optional(),
  prompt: z.string().optional(),
  options: z.record(z.string(), z.any()),
  steps: z.number().int().positive().optional(),
})
```

### 4.4 内置 Agent 分类

| Agent | 模式 | 用途 |
|-------|------|------|
| `build` | primary | 默认 Agent，全功能开发 |
| `plan` | primary | 只读分析，禁止编辑 |
| `general` | subagent | 通用子任务执行 |
| `explore` | subagent | 快速代码探索 |
| `compaction` | primary (hidden) | 上下文压缩 |
| `title` | primary (hidden) | 生成会话标题 |
| `summary` | primary (hidden) | 生成摘要 |

### 4.5 Agent 权限配置示例

```typescript
// build agent - 全功能
build: {
  permission: PermissionNext.merge(
    defaults,
    PermissionNext.fromConfig({
      question: "allow",
      plan_enter: "allow",
    }),
    user,
  ),
  mode: "primary",
}

// explore agent - 只读
explore: {
  permission: PermissionNext.merge(
    defaults,
    PermissionNext.fromConfig({
      "*": "deny",
      grep: "allow",
      glob: "allow",
      list: "allow",
      bash: "allow",
      read: "allow",
      // ...
    }),
    user,
  ),
  mode: "subagent",
}
```

---

## 5. Session/上下文管理深度解析

### 5.1 Session 数据结构

**文件**: `packages/opencode/src/session/session.ts`

```typescript
export const Info = z.object({
  id: Identifier.schema("session"),
  slug: z.string(),
  projectID: z.string(),
  directory: z.string(),
  parentID: Identifier.schema("session").optional(),  // 父子关系
  summary: z.object({
    additions: z.number(),
    deletions: z.number(),
    files: z.number(),
    diffs: Snapshot.FileDiff.array().optional(),
  }).optional(),
  share: z.object({ url: z.string() }).optional(),
  title: z.string(),
  version: z.string(),
  time: z.object({
    created: z.number(),
    updated: z.number(),
    compacting: z.number().optional(),
    archived: z.number().optional(),
  }),
  permission: PermissionNext.Ruleset.optional(),
  revert: z.object({
    messageID: z.string(),
    partID: z.string().optional(),
    snapshot: z.string().optional(),
    diff: z.string().optional(),
  }).optional(),
})
```

### 5.2 父子会话关系

```typescript
// 创建子会话
export async function createNext(input: {
  parentID?: string  // 指定父会话
  directory: string
  // ...
}) {
  const result: Info = {
    parentID: input.parentID,
    title: createDefaultTitle(!!input.parentID),
    // ...
  }
}

// 查询子会话
export const children = fn(Identifier.schema("session"), async (parentID) => {
  // 遍历所有会话，过滤 parentID 匹配的
})
```

### 5.3 上下文管理五层策略

```
┌─────────────────────────────────────────────────────────────────┐
│                    上下文来源                                    │
├─────────────────────────────────────────────────────────────────┤
│ 1. 系统提示 (静态)                                               │
│    - Agent 提示词                                                │
│    - 工具定义和说明                                               │
│    - 项目指令 (.opencode/instructions.md)                        │
│                                                                 │
│ 2. 消息历史 (动态)                                               │
│    - 用户消息                                                    │
│    - AI 响应                                                     │
│    - 工具调用和结果                                               │
│                                                                 │
│ 3. 配置信息 (半静态)                                             │
│    - 权限规则                                                    │
│    - MCP 工具                                                    │
│    - 用户偏好                                                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    优化策略                                      │
├─────────────────────────────────────────────────────────────────┤
│ 1. Prompt Caching (系统提示层)                                   │
│    - 保持 header 稳定，利用 LLM 缓存                              │
│                                                                 │
│ 2. Prune (工具输出层)                                            │
│    - 保留最近 40K tokens 的工具输出                               │
│    - 更早的输出被标记为 compacted                                 │
│                                                                 │
│ 3. Compaction (消息历史层)                                       │
│    - 当上下文溢出时，LLM 生成摘要                                 │
│    - 摘要替代原始历史继续对话                                     │
│                                                                 │
│ 4. 按需获取 (工具层)                                             │
│    - AI 主动调用 read/grep/glob 获取需要的信息                    │
│    - 避免预加载所有可能需要的内容                                 │
│                                                                 │
│ 5. 子 Agent 隔离 (会话层)                                        │
│    - 子 Agent 有独立的上下文                                      │
│    - 结果返回时只传递核心信息                                     │
└─────────────────────────────────────────────────────────────────┘
```

### 5.4 关键上下文文件

| 文件 | 职责 |
|------|------|
| `session/message-v2.ts` | 消息数据结构和序列化 |
| `session/processor.ts` | 消息处理流水线 |
| `session/system.ts` | 系统提示构建 |
| `session/llm.ts` | LLM 调用封装 |
| `agent/prompt/compaction.txt` | 压缩提示词模板 |

---

## 6. Provider 抽象层

### 6.1 多 LLM 支持架构

**文件**: `packages/opencode/src/provider/`

```
provider/
├── provider.ts     # 提供商抽象接口
├── transform.ts    # 消息格式转换
├── providers/      # 具体提供商实现
│   ├── anthropic.ts
│   ├── openai.ts
│   ├── google.ts
│   └── ...
```

### 6.2 适配器模式

```typescript
// LLM 调用封装（session/llm.ts）
export async function stream(input: StreamInput) {
  const [language, cfg, provider, auth] = await Promise.all([
    Provider.getLanguage(input.model),
    Config.get(),
    Provider.getProvider(input.model.providerID),
    Auth.get(input.model.providerID),
  ])

  // 使用 Vercel AI SDK 的 streamText
  const result = streamText({
    model: language,
    system: system.join("\n"),
    messages: input.messages,
    tools: input.tools,
    // ...
  })
}
```

### 6.3 Transform 层

`ProviderTransform` 负责将内部消息格式转换为各提供商的格式：

```typescript
await Plugin.trigger(
  "experimental.chat.system.transform",
  { sessionID: input.sessionID, model: input.model },
  { system },
)
```

---

## 7. 权限系统

### 7.1 规则结构

**文件**: `packages/opencode/src/permission/next.ts`

```typescript
// 权限规则示例
{
  "*": "allow",               // 默认允许大多数操作
  "read": {
    "*.env": "ask",           // 读取 .env 文件需要询问
    "*.env.*": "ask"
  },
  "edit": {
    "/etc/*": "deny"          // 禁止编辑系统文件
  }
}
```

### 7.2 权限操作类型

| 操作 | 说明 |
|------|------|
| `allow` | 允许执行 |
| `deny` | 拒绝执行 |
| `ask` | 询问用户确认 |

### 7.3 默认安全原则

```typescript
const defaults = PermissionNext.fromConfig({
  "*": "allow",
  doom_loop: "ask",
  external_directory: {
    "*": "ask",
    [Truncate.DIR]: "allow",
  },
  question: "deny",
  plan_enter: "deny",
  plan_exit: "deny",
  read: {
    "*": "allow",
    "*.env": "ask",
    "*.env.*": "ask",
    "*.env.example": "allow",
  },
})
```

### 7.4 权限合并机制

```typescript
// 权限优先级：用户配置 > Agent 配置 > 默认配置
permission: PermissionNext.merge(
  defaults,      // 默认规则
  agentConfig,   // Agent 特定规则
  user,          // 用户自定义规则
)
```

---

## 8. 设计模式总结

| 模式 | 应用场景 |
|------|----------|
| **装饰器模式** | Tool.define() 包装验证和截断 |
| **适配器模式** | Provider 层抽象多 LLM |
| **事件总线** | Bus/BusEvent 解耦组件通信 |
| **策略模式** | Agent 权限配置 |
| **工厂模式** | Session.create() 创建会话 |

---

## 9. 关键洞察

1. **上下文管理是核心难点**：五层策略（缓存、剪枝、压缩、按需、隔离）是实用的解决方案

2. **安全第一设计**：默认 deny 敏感操作，显式 allow 安全操作

3. **可扩展性**：插件系统 + MCP + 事件总线提供多种扩展点

4. **分层清晰**：opencode 核心无 UI 依赖，UI 层可独立替换

5. **工具标准化**：Zod 验证 + 统一截断，开发者只关注核心逻辑
