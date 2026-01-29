# AgentStudio 的 Claude Code 集成分析

> 分析文档生成时间: 2026-01-29
> 分支: feat/codebuddy-support
> 版本: v0.3.2

## 目录

1. [概述](#概述)
2. [SDK 集成架构](#sdk-集成架构)
3. [多 SDK 引擎支持](#多-sdk-引擎支持)
4. [Claude Code Agent 配置](#claude-code-agent-配置)
5. [工具系统集成](#工具系统集成)
6. [会话管理机制](#会话管理机制)
7. [配置解析流程](#配置解析流程)
8. [MCP 服务器集成](#mcp-服务器集成)
9. [权限模式](#权限模式)
10. [扩展 CodeBuddy 支持的建议](#扩展-codebuddy-支持的建议)

---

## 概述

AgentStudio 是一个基于 **@anthropic-ai/claude-agent-sdk** (v0.1.62) 构建的 AI Agent 平台。项目通过深度集成 Claude Code SDK 来提供强大的 AI 辅助编程能力。

### 核心集成特性

- ✅ **原生 SDK 集成**: 使用 `query()` API 和 `Options` 配置
- ✅ **多引擎支持**: 支持 `claude-code`、`claude-internal`、`code-buddy` (规划中)
- ✅ **24+ 工具组件**: 完整的 SDK 工具可视化
- ✅ **流式会话**: Streaming Input Mode 持久化对话
- ✅ **预设系统提示词**: `preset: 'claude_code'` 官方配置
- ✅ **MCP 协议**: 原生支持 Model Context Protocol
- ✅ **灵活权限模式**: 4 种权限级别适配不同场景

---

## SDK 集成架构

### 2.1 核心依赖

**位置**: `backend/package.json:27-33`

```json
{
  "dependencies": {
    "@anthropic-ai/claude-agent-sdk": "^0.1.62",
    "@ai-sdk/anthropic": "^1.0.5",
    "@ai-sdk/openai": "^1.0.7",
    "ai": "^5.0.22"
  }
}
```

### 2.2 主要 SDK 使用点

| 文件 | 导入内容 | 用途 |
|------|---------|------|
| `claudeSession.ts:1` | `query, Options` | 创建 Claude 会话 |
| `claudeUtils.ts:8` | `Options` | 构建查询选项 |
| `sessionManager.ts:1` | `Options` | 会话管理器配置 |
| `agents.ts:3-8` | `SDKMessage, SDKSystemMessage, ...` | 消息类型定义 |
| `agentStorage.ts:4` | `Options, query` | Agent 存储验证 |

### 2.3 SDK 集成流程图

```
用户请求
    │
    ▼
buildQueryOptions()
    │
    ├─ 解析 systemPrompt (preset: claude_code)
    ├─ 构建 allowedTools 列表
    ├─ 设置 permissionMode
    ├─ 配置 env (API keys, proxy)
    ├─ 集成 mcpServers
    └─ 返回 Options 对象
    │
    ▼
ClaudeSession.constructor()
    │
    ├─ 保存 Options
    ├─ 初始化 MessageQueue
    └─ 调用 initializeClaudeStream()
        │
        ▼
    query({
        prompt: messageQueue,  // AsyncIterable
        options: queryOptions
    })
    │
    ▼
持续 SSE 流式响应
```

---

## 多 SDK 引擎支持

### 3.1 SDK 引擎配置

**位置**: `backend/src/config/sdkConfig.ts`

AgentStudio 设计了灵活的多 SDK 引擎支持系统，允许切换不同的 Agent SDK 实现。

```typescript
// SDK Engine Configuration
export const SDK_ENGINE = process.env.AGENT_SDK || 'claude-code';

export type SdkEngine = 'claude-code' | 'claude-internal' | 'code-buddy';

// SDK directory name mapping
const SDK_DIR_MAP: Record<SdkEngine, string> = {
  'claude-code': '.claude',
  'claude-internal': '.claude-internal',
  'code-buddy': '.codebuddy' // Not yet supported
};
```

### 3.2 支持的引擎

| 引擎 | 目录 | 配置文件位置 | 状态 |
|------|------|-------------|------|
| `claude-code` | `~/.claude` | `~/.claude.json` | ✅ **默认** |
| `claude-internal` | `~/.claude-internal` | `~/.claude-internal/.claude.json` | ✅ 支持 |
| `code-buddy` | `~/.codebuddy` | `~/.codebuddy/.claude.json` (推测) | ⚠️ **规划中** |

### 3.3 引擎切换方式

**方式 1: 环境变量**
```bash
export AGENT_SDK=claude-internal
pnpm run dev:backend
```

**方式 2: 命令行参数**
```bash
pnpm --filter agentstudio-backend run start -- --sdk=claude-internal
```

### 3.4 引擎验证逻辑

**位置**: `backend/src/config/sdkConfig.ts:24-30`

```typescript
const VALID_ENGINES: SdkEngine[] = ['claude-code', 'claude-internal'];
if (!VALID_ENGINES.includes(SDK_ENGINE as SdkEngine)) {
  console.warn(`⚠️  Invalid AGENT_SDK="${SDK_ENGINE}", falling back to "claude-code"`);
  console.warn(`⚠️  Supported engines: ${VALID_ENGINES.join(', ')}`);
  process.env.AGENT_SDK = 'claude-code';
}
```

**关键点**:
- 目前 `code-buddy` 在 `SDK_DIR_MAP` 中定义但**不在** `VALID_ENGINES` 列表
- 如果指定 `code-buddy`，会**自动回退**到 `claude-code`
- 要支持 CodeBuddy，需要将其添加到 `VALID_ENGINES`

### 3.5 路径解析函数

**位置**: `backend/src/config/sdkConfig.ts:42-115`

```typescript
// 获取 SDK 目录名称
export function getSdkDirName(): string {
  return SDK_DIR_MAP[SDK_ENGINE as SdkEngine];
}

// 获取 SDK 完整路径 (e.g., ~/.claude, ~/.codebuddy)
export function getSdkDir(): string {
  return path.join(os.homedir(), getSdkDirName());
}

// 获取项目目录 (e.g., ~/.claude/projects)
export function getProjectsDir(): string {
  return path.join(getSdkDir(), 'projects');
}

// 获取配置文件路径
export function getSdkConfigPath(): string {
  if (SDK_ENGINE === 'claude-code') {
    // Claude Code 在 home 目录: ~/.claude.json
    return path.join(os.homedir(), '.claude.json');
  } else {
    // 其他引擎在 SDK 目录内: ~/.claude-internal/.claude.json
    return path.join(getSdkDir(), '.claude.json');
  }
}

// 其他目录
export function getPluginsDir(): string { /* ... */ }
export function getCommandsDir(): string { /* ... */ }
export function getAgentsDir(): string { /* ... */ }
export function getSkillsDir(): string { /* ... */ }
export function getHooksDir(): string { /* ... */ }
export function getMcpDir(): string { /* ... */ }
```

**架构优势**:
- 统一的路径解析接口
- 自动适配不同 SDK 引擎
- 支持新引擎只需修改 `SDK_DIR_MAP`

---

## Claude Code Agent 配置

### 4.1 内置 Agent 定义

**位置**: `backend/src/types/agents.ts:122-161`

```typescript
export const BUILTIN_AGENTS: Partial<AgentConfig>[] = [
  {
    id: 'claude-code',
    name: 'Claude Code',
    description: 'Claude Code 系统默认助手，基于 Claude Code SDK 的全功能开发助手',

    // 核心: 使用预设系统提示词
    systemPrompt: {
      type: 'preset',
      preset: 'claude_code'
    },

    permissionMode: 'acceptEdits',
    maxTurns: undefined, // 不限制轮次

    // 完整的工具列表
    allowedTools: [
      { name: 'Write', enabled: true },
      { name: 'Read', enabled: true },
      { name: 'Edit', enabled: true },
      { name: 'Glob', enabled: true },
      { name: 'Bash', enabled: true },
      { name: 'Task', enabled: true },
      { name: 'WebFetch', enabled: true },
      { name: 'WebSearch', enabled: true },
      { name: 'TodoWrite', enabled: true },
      { name: 'NotebookEdit', enabled: true },
      { name: 'KillShell', enabled: true },
      { name: 'BashOutput', enabled: true },
      { name: 'SlashCommand', enabled: true },
      { name: 'ExitPlanMode', enabled: true },
      { name: 'Skill', enabled: true }
      // AskUserQuestion 通过内置 MCP server 自动提供
    ],

    ui: {
      icon: '🔧',
      headerTitle: 'Claude Code',
      headerDescription: '基于 Claude Code SDK 的系统默认助手'
    },

    author: 'AgentStudio System',
    tags: ['development', 'code', 'system'],
    enabled: true,
    source: 'local'
  }
];
```

### 4.2 系统提示词类型

**位置**: `backend/src/types/agents.ts:14-21`

```typescript
// 预设提示词结构
export interface PresetSystemPrompt {
  type: 'preset';
  preset: 'claude_code'; // 固定为 claude_code
  append?: string;       // 可选的追加内容
}

// 系统提示词联合类型
export type SystemPrompt = string | PresetSystemPrompt;
```

**两种使用方式**:

1. **完全自定义提示词** (字符串)
```typescript
systemPrompt: "You are a helpful coding assistant..."
```

2. **预设提示词 + 追加** (推荐)
```typescript
systemPrompt: {
  type: 'preset',
  preset: 'claude_code',
  append: '你是一个专注于 React 开发的助手。'
}
```

**优势**: 预设模式使用 Claude Code SDK 官方优化的系统提示词，保证最佳效果。

### 4.3 Agent 配置验证

**位置**: `backend/src/routes/agents.ts:47-56`

```typescript
const PresetSystemPromptSchema = z.object({
  type: z.literal('preset'),
  preset: z.literal('claude_code'),
  append: z.string().optional()
});

const SystemPromptSchema = z.union([
  z.string().min(1),
  PresetSystemPromptSchema
]);
```

使用 Zod 进行运行时验证，确保配置正确。

---

## 工具系统集成

### 5.1 工具组件总览

AgentStudio 为 Claude Code SDK 的每个工具提供了专用的可视化组件。

**位置**: `frontend/src/components/tools/`

**统计**: 24+ 专用工具组件

### 5.2 工具渲染器

**位置**: `frontend/src/components/tools/ToolRenderer.tsx:1-100`

```typescript
export const ToolRenderer: React.FC<ToolRendererProps> = ({
  execution,
  onAskUserQuestionSubmit
}) => {
  // MCP 工具检测
  const mcpToolInfo = parseMcpToolName(execution.toolName);
  if (mcpToolInfo) {
    // 特殊处理 AskUserQuestion
    if (mcpToolInfo.serverName === 'ask-user-question') {
      return <AskUserQuestionTool execution={execution} />;
    }

    // 自定义 MCP 工具
    const CustomComponent = CUSTOM_MCP_TOOLS[customToolKey];
    if (CustomComponent) {
      return <CustomComponent execution={execution} />;
    }

    return <McpTool execution={execution} />;
  }

  // 标准工具映射
  switch (execution.toolName) {
    case 'Task': return <TaskTool execution={execution} />;
    case 'Bash': return <BashTool execution={execution} />;
    case 'Read': return <ReadTool execution={execution} />;
    case 'Write': return <WriteTool execution={execution} />;
    case 'Edit': return <EditTool execution={execution} />;
    // ... 20+ 更多工具
  }
};
```

### 5.3 完整工具列表

| 工具名称 | 组件 | 功能 |
|---------|------|------|
| Task | TaskTool | 子任务执行 |
| Bash | BashTool | Shell 命令 |
| BashOutput | BashOutputTool | 命令输出查看 |
| KillBash | KillBashTool | 终止进程 |
| Glob | GlobTool | 文件匹配 |
| Grep | GrepTool | 代码搜索 |
| LS | LSTool | 目录列表 |
| Read | ReadTool | 文件读取 |
| Write | WriteTool | 文件写入 |
| Edit | EditTool | 文件编辑 |
| MultiEdit | MultiEditTool | 批量编辑 |
| NotebookRead | NotebookReadTool | Notebook 读取 |
| NotebookEdit | NotebookEditTool | Notebook 编辑 |
| WebFetch | WebFetchTool | 网页抓取 |
| WebSearch | WebSearchTool | 网络搜索 |
| TodoWrite | TodoWriteTool | 任务列表 |
| ExitPlanMode | ExitPlanModeTool | 退出计划模式 |
| AskUserQuestion | AskUserQuestionTool | 用户交互 |
| Skill | SkillTool | 技能执行 |
| TimeMachine | TimeMachineTool | 时间机器 |
| ListMcpResources | ListMcpResourcesTool | MCP 资源列表 |
| ReadMcpResource | ReadMcpResourceTool | MCP 资源读取 |
| A2ACall | A2ACallTool | A2A Agent 调用 |
| mcp__* | McpTool | 通用 MCP 工具 |

### 5.4 工具类型定义

**位置**: `frontend/src/components/tools/sdk-types.ts`

```typescript
// 从 Claude Agent SDK 导入的类型
import type {
  ToolExecution,
  ToolExecutionCompleted,
  ToolExecutionError,
  ToolExecutionFailed,
  // ... 更多类型
} from '@anthropic-ai/claude-agent-sdk';

// 基础工具执行类型
export type BaseToolExecution =
  | ToolExecutionCompleted
  | ToolExecutionError
  | ToolExecutionFailed;
```

**前端类型同步**: 前端直接使用 SDK 的 TypeScript 类型，保证类型一致性。

---

## 会话管理机制

### 6.1 ClaudeSession 核心实现

**位置**: `backend/src/services/claudeSession.ts:1-150`

```typescript
export class ClaudeSession {
  private agentId: string;
  private claudeSessionId: string | null = null;
  private messageQueue: MessageQueue;
  private queryObject: any | null = null;
  private options: Options;

  constructor(agentId: string, options: Options, resumeSessionId?: string) {
    this.agentId = agentId;
    this.options = { ...options };
    this.messageQueue = new MessageQueue();
    this.resumeSessionId = resumeSessionId || null;

    // 立即初始化 Claude 流（Streaming Input Mode）
    this.initializeClaudeStream();
  }

  private initializeClaudeStream(): void {
    const queryOptions = { ...this.options };

    // 如果有 resumeSessionId，添加到 options 中
    if (this.resumeSessionId) {
      queryOptions.resume = this.resumeSessionId;
    }

    // 核心: 使用 Streaming Input Mode
    this.queryObject = query({
      prompt: this.messageQueue,  // AsyncIterable
      options: queryOptions
    });

    this.queryStream = this.queryObject;
    this.isInitialized = true;

    // 后台运行，持续监听 messageQueue
    this.runBackgroundLoop();
  }
}
```

### 6.2 Streaming Input Mode

**核心概念**: 一次构造 `query()`，通过 `AsyncIterable` 持续提供用户输入。

```
┌─────────────────────────────────────────────────┐
│           Streaming Input Mode                  │
└─────────────────────────────────────────────────┘

构造时:
  query({
    prompt: messageQueue,  // AsyncIterable<Message>
    options: { ... }
  })
        │
        ▼
    持久化运行
        │
        ├───> 等待 messageQueue.push(message)
        │
        ├───> 处理消息
        │
        ├───> 流式返回响应 (SSE)
        │
        └───> 继续等待下一条消息
```

**优势**:
- ✅ 会话持久化，无需重新初始化
- ✅ 上下文保留，多轮对话流畅
- ✅ 性能优化，减少 SDK 开销

### 6.3 SessionManager 索引

**位置**: `backend/src/services/sessionManager.ts:24-38`

```typescript
export class SessionManager {
  // 主索引: sessionId -> ClaudeSession
  private sessions: Map<string, ClaudeSession> = new Map();

  // 辅助索引: agentId -> Set<sessionId>
  private agentSessions: Map<string, Set<string>> = new Map();

  // 临时会话: tempKey -> ClaudeSession (等待 sessionId 确认)
  private tempSessions: Map<string, ClaudeSession> = new Map();

  // 心跳记录: sessionId -> lastHeartbeatTime
  private sessionHeartbeats: Map<string, number> = new Map();

  // 配置快照: sessionId -> SessionConfigSnapshot
  private sessionConfigs: Map<string, SessionConfigSnapshot> = new Map();
}
```

**配置快照机制**:

```typescript
export interface SessionConfigSnapshot {
  model?: string;
  claudeVersionId?: string;
  permissionMode?: string;
  mcpTools?: string[];
  allowedTools?: string[];
}
```

当以下配置变化时，自动创建新会话:
- AI 模型切换
- Claude 版本变更
- 权限模式调整
- 工具列表修改

---

## 配置解析流程

### 7.1 buildQueryOptions 函数

**位置**: `backend/src/utils/claudeUtils.ts:158-376`

这是 AgentStudio 构建 Claude SDK `Options` 的核心函数。

```typescript
export async function buildQueryOptions(
  agent: any,
  projectPath?: string,
  mcpTools?: string[],
  permissionMode?: string,
  model?: string,
  claudeVersion?: string,
  defaultEnv?: Record<string, string>,
  userEnv?: Record<string, string>,
  sessionIdForAskUser?: string,
  agentIdForAskUser?: string,
  a2aStreamEnabled?: boolean
): Promise<BuildQueryOptionsResult>
```

### 7.2 配置解析优先级

```
┌─────────────────────────────────────────────────────────────┐
│              配置解析优先级链                                │
└─────────────────────────────────────────────────────────────┘

工作目录 (cwd):
  projectPath > agent.workingDirectory > process.cwd()

权限模式 (permissionMode):
  request > agent.permissionMode > 'default'

允许的工具 (allowedTools):
  agent.allowedTools (enabled=true) + mcpTools

模型 (model):
  channelModel > projectConfig > providerFirstModel > 'sonnet'

环境变量 (env):
  userEnv > environmentVariables > process.env

Claude 版本 (provider):
  channelProviderId > agent.claudeVersionId > projectDefault > systemDefault
```

### 7.3 环境变量合并

**位置**: `backend/src/utils/claudeUtils.ts:276-313`

```typescript
// 合并环境变量
queryOptions.env = { ...process.env, ...environmentVariables, ...userEnv };

// 代理变量标准化
const proxyNormalizations = [
  ['HTTP_PROXY', 'http_proxy'],
  ['HTTPS_PROXY', 'https_proxy'],
  ['NO_PROXY', 'no_proxy'],
  ['ALL_PROXY', 'all_proxy']
];

for (const [upper, lower] of proxyNormalizations) {
  if (environmentVariables[upper] && !environmentVariables[lower]) {
    queryOptions.env[lower] = environmentVariables[upper];
  } else if (environmentVariables[lower] && !environmentVariables[upper]) {
    queryOptions.env[upper] = environmentVariables[lower];
  }
}
```

**关键点**:
- 大小写代理变量双向同步
- 确保代理配置生效
- 支持不同客户端库的代理检查方式

### 7.4 SDK 可执行文件选择

**位置**: `backend/src/utils/claudeUtils.ts:200-259`

```typescript
let executablePath: string | null = null;

// 使用 unified config resolver
const resolvedConfig = await resolveConfig({
  channelProviderId: claudeVersion,
  channelModel: model,
  agent: { claudeVersionId: agent.claudeVersionId },
  projectPath,
});

// 只有在版本配置中明确指定时才使用自定义路径
if (resolvedConfig.provider?.executablePath) {
  executablePath = resolvedConfig.provider.executablePath.trim();
  console.log(`🎯 Using custom path: ${executablePath}`);
} else {
  console.log(`📦 Using SDK bundled CLI`);
}
```

**默认行为**: 不指定 `pathToClaudeCodeExecutable`，SDK 自动使用内置 CLI。

**优势**:
- ✅ SDK 版本兼容性保证
- ✅ 无需系统安装 Claude CLI
- ✅ 简化部署流程

---

## MCP 服务器集成

### 8.1 MCP 配置读取

**位置**: `backend/src/utils/claudeUtils.ts:73-83`

```typescript
export function readMcpConfig(): { mcpServers: Record<string, any> } {
  if (fs.existsSync(MCP_SERVER_CONFIG_FILE)) {
    try {
      return JSON.parse(fs.readFileSync(MCP_SERVER_CONFIG_FILE, 'utf-8'));
    } catch (error) {
      console.error('Failed to parse MCP configuration:', error);
      return { mcpServers: {} };
    }
  }
  return { mcpServers: {} };
}
```

### 8.2 MCP 工具解析

**位置**: `backend/src/utils/claudeUtils.ts:316-359`

```typescript
if (mcpTools && mcpTools.length > 0) {
  const mcpConfigContent = readMcpConfig();

  // 从工具名提取服务器名
  // 格式: mcp__serverName__toolName
  const serverNames = new Set<string>();
  for (const tool of mcpTools) {
    const parts = tool.split('__');
    if (parts.length >= 2 && parts[0] === 'mcp') {
      serverNames.add(parts[1]);
    }
  }

  // 构建 mcpServers 配置
  const mcpServers: Record<string, any> = {};
  for (const serverName of serverNames) {
    const serverConfig = mcpConfigContent.mcpServers?.[serverName];
    if (serverConfig && serverConfig.status === 'active') {
      if (serverConfig.type === 'http') {
        mcpServers[serverName] = {
          type: 'http',
          url: serverConfig.url,
          headers: serverConfig.headers || {}
        };
      } else if (serverConfig.type === 'stdio') {
        mcpServers[serverName] = {
          type: 'stdio',
          command: serverConfig.command,
          args: serverConfig.args || [],
          env: serverConfig.env || {}
        };
      }
    }
  }

  if (Object.keys(mcpServers).length > 0) {
    queryOptions.mcpServers = mcpServers;
  }
}
```

### 8.3 内置 MCP 服务器

**位置**: `backend/src/utils/claudeUtils.ts:361-374`

```typescript
// 1. A2A SDK MCP Server
await integrateA2AMcpServer(queryOptions, currentProjectId, a2aStreamEnabled ?? false);

// 2. AskUserQuestion SDK MCP Server
let askUserSessionRef: SessionRef | null = null;
if (sessionIdForAskUser && agentIdForAskUser) {
  const integration = await integrateAskUserQuestionMcpServer(
    queryOptions,
    sessionIdForAskUser,
    agentIdForAskUser
  );
  askUserSessionRef = integration.sessionRef;
}
```

**两个内置 MCP 服务器**:

1. **A2A MCP Server** - 提供 `callExternalAgent()` 工具
2. **AskUserQuestion MCP Server** - 提供 `ask_user_question()` 工具

---

## 权限模式

### 9.1 四种权限模式

**位置**: `backend/src/types/agents.ts:32`

```typescript
export interface AgentConfig {
  permissionMode: PermissionMode;  // 使用 SDK 类型
}
```

**从 Claude Agent SDK 导入**:
```typescript
import type { PermissionMode } from '@anthropic-ai/claude-agent-sdk';
```

| 模式 | 说明 | 使用场景 |
|------|------|----------|
| `default` | 所有操作需用户确认 | 高安全要求 |
| `acceptEdits` | 自动接受文件编辑 | **开发助手 (推荐)** |
| `bypassPermissions` | 完全绕过权限 | 自动化任务、定时任务 |
| `plan` | 计划模式，只读 | 架构设计、代码审查 |

### 9.2 权限优先级

**位置**: `backend/src/utils/claudeUtils.ts:179-185`

```typescript
// Determine permission mode: request > agent config > default
let finalPermissionMode = 'default';
if (permissionMode) {
  finalPermissionMode = permissionMode;
} else if (agent.permissionMode) {
  finalPermissionMode = agent.permissionMode;
}
```

**优先级**:
```
请求参数 > Agent 配置 > 默认值 'default'
```

### 9.3 工具级权限

**位置**: `backend/src/types/agents.ts:4-12`

```typescript
export interface AgentTool {
  name: string;
  enabled: boolean;
  permissions?: {
    requireConfirmation?: boolean;  // 是否需要确认
    allowedPaths?: string[];         // 允许的路径
    blockedPaths?: string[];         // 禁止的路径
  };
}
```

**示例**:
```typescript
{
  name: 'Bash',
  enabled: true,
  permissions: {
    requireConfirmation: true,
    allowedPaths: ['/home/user/project'],
    blockedPaths: ['/etc', '/var']
  }
}
```

---

## 扩展 CodeBuddy 支持的建议

基于对现有 Claude Code 集成的分析，以下是支持 CodeBuddy 的具体步骤：

### 10.1 配置修改

**步骤 1: 启用 CodeBuddy 引擎**

**文件**: `backend/src/config/sdkConfig.ts:25`

```diff
- const VALID_ENGINES: SdkEngine[] = ['claude-code', 'claude-internal'];
+ const VALID_ENGINES: SdkEngine[] = ['claude-code', 'claude-internal', 'code-buddy'];
```

**步骤 2: 配置文件路径映射**

**文件**: `backend/src/config/sdkConfig.ts:65-73`

```diff
export function getSdkConfigPath(): string {
  if (SDK_ENGINE === 'claude-code') {
    return path.join(os.homedir(), '.claude.json');
+ } else if (SDK_ENGINE === 'code-buddy') {
+   // CodeBuddy 配置路径（需确认实际路径）
+   return path.join(getSdkDir(), '.codebuddy.json');
  } else {
    return path.join(getSdkDir(), '.claude.json');
  }
}
```

### 10.2 预设提示词支持

**步骤 3: 扩展系统提示词类型**

**文件**: `backend/src/types/agents.ts:14-21`

```diff
export interface PresetSystemPrompt {
  type: 'preset';
- preset: 'claude_code'; // 固定为 claude_code
+ preset: 'claude_code' | 'code_buddy'; // 支持多种预设
  append?: string;
}
```

**步骤 4: 添加 CodeBuddy Agent**

**文件**: `backend/src/types/agents.ts:122`

```typescript
export const BUILTIN_AGENTS: Partial<AgentConfig>[] = [
  {
    id: 'claude-code',
    // ... 现有配置
  },
  // 新增 CodeBuddy Agent
  {
    id: 'code-buddy',
    name: 'Code Buddy',
    description: 'Code Buddy AI 助手，专注于代码理解和重构',
    systemPrompt: {
      type: 'preset',
      preset: 'code_buddy'
    },
    permissionMode: 'acceptEdits',
    maxTurns: undefined,
    allowedTools: [
      // 根据 CodeBuddy SDK 支持的工具列表
      { name: 'Read', enabled: true },
      { name: 'Write', enabled: true },
      { name: 'Edit', enabled: true },
      // ... 其他工具
    ],
    ui: {
      icon: '🤖',
      headerTitle: 'Code Buddy',
      headerDescription: 'Code Buddy AI 代码助手'
    },
    author: 'AgentStudio System',
    tags: ['development', 'code', 'refactoring'],
    enabled: true,
    source: 'local'
  }
];
```

### 10.3 Schema 验证更新

**步骤 5: 更新 Zod Schema**

**文件**: `backend/src/routes/agents.ts:48-52`

```diff
const PresetSystemPromptSchema = z.object({
  type: z.literal('preset'),
- preset: z.literal('claude_code'),
+ preset: z.enum(['claude_code', 'code_buddy']),
  append: z.string().optional()
});
```

**文件**: `frontend/src/types/agents.ts` (同步修改)

### 10.4 前端显示更新

**步骤 6: 系统提示词编辑器**

**文件**: `frontend/src/components/SystemPromptEditor.tsx:25-32`

```diff
+ const presetOptions = [
+   { value: 'claude_code', label: 'Claude Code' },
+   { value: 'code_buddy', label: 'Code Buddy' }
+ ];

  // 切换到预设模式时，使用默认预设
  const handleModeChange = (mode: 'custom' | 'preset') => {
    setMode(mode);
    if (mode === 'preset') {
-     onChange({ type: 'preset', preset: 'claude_code' });
+     onChange({ type: 'preset', preset: presetOptions[0].value });
    }
  };
```

### 10.5 SDK 兼容性检查

**步骤 7: 验证 SDK API 兼容性**

AgentStudio 使用的核心 SDK API:
```typescript
import { query, Options } from '@anthropic-ai/claude-agent-sdk';
```

**需要验证 CodeBuddy SDK 是否提供**:
1. ✅ `query()` 函数
2. ✅ `Options` 接口
3. ✅ Streaming Input Mode
4. ✅ MCP 协议支持
5. ✅ 相同的工具名称 (Read, Write, Edit, Bash, etc.)

**如果 CodeBuddy SDK API 不同**，需要创建适配层:

```typescript
// backend/src/adapters/codeBuddyAdapter.ts
import * as CodeBuddySDK from '@codebuddy/sdk'; // 假设的 SDK

export function adaptCodeBuddyQuery(options: Options) {
  // 将 AgentStudio Options 转换为 CodeBuddy 配置
  const codeBuddyOptions = {
    // ... 映射逻辑
  };

  return CodeBuddySDK.createSession(codeBuddyOptions);
}
```

### 10.6 环境变量配置

**步骤 8: 支持 CodeBuddy API Keys**

**文件**: `backend/src/utils/claudeUtils.ts:115-118`

```diff
const hasApiKey = defaultVersion.environmentVariables.ANTHROPIC_API_KEY ||
  defaultVersion.environmentVariables.OPENAI_API_KEY ||
- defaultVersion.environmentVariables.ANTHROPIC_AUTH_TOKEN;
+ defaultVersion.environmentVariables.ANTHROPIC_AUTH_TOKEN ||
+ defaultVersion.environmentVariables.CODEBUDDY_API_KEY;
```

### 10.7 测试清单

**步骤 9: 测试验证**

- [ ] 切换到 CodeBuddy 引擎 (`AGENT_SDK=code-buddy`)
- [ ] 验证目录创建 (`~/.codebuddy/`)
- [ ] 测试会话创建和持久化
- [ ] 验证工具调用 (Read, Write, Edit, Bash)
- [ ] 测试 MCP 服务器集成
- [ ] 验证前端工具组件渲染
- [ ] 测试权限模式
- [ ] 验证多轮对话

### 10.8 文档更新

**步骤 10: 更新文档**

**文件**: `CLAUDE.md`

```markdown
## Agent SDK Configuration

AgentStudio supports multiple Agent SDK engines:

- **claude-code** (default): Claude Code official SDK
- **claude-internal**: Claude Internal SDK for testing
- **code-buddy**: Code Buddy AI SDK

To use Code Buddy:

```bash
export AGENT_SDK=code-buddy
pnpm run dev:backend
```

Or via command line:

```bash
pnpm --filter agentstudio-backend run start -- --sdk=code-buddy
```
```

---

## 总结

### 核心集成点

1. **SDK 依赖**: `@anthropic-ai/claude-agent-sdk@0.1.62`
2. **多引擎架构**: 通过 `sdkConfig.ts` 支持引擎切换
3. **预设提示词**: `preset: 'claude_code'` 官方优化
4. **24+ 工具组件**: 完整的 SDK 工具可视化
5. **Streaming Input Mode**: 持久化会话，高性能
6. **MCP 集成**: 原生支持 Model Context Protocol
7. **灵活权限**: 4 种权限模式适配不同场景

### CodeBuddy 支持路线图

```
阶段 1: 配置层 (1-2 天)
  ├─ 启用 code-buddy 引擎
  ├─ 配置文件路径映射
  └─ 环境变量支持

阶段 2: 类型层 (1 天)
  ├─ 扩展 PresetSystemPrompt
  ├─ 更新 Zod Schema
  └─ 添加内置 Agent

阶段 3: 适配层 (2-3 天)
  ├─ SDK API 兼容性检查
  ├─ 必要时创建适配器
  └─ 工具名称映射

阶段 4: 测试层 (2-3 天)
  ├─ 单元测试
  ├─ 集成测试
  └─ E2E 测试

阶段 5: 文档层 (1 天)
  ├─ 更新 CLAUDE.md
  ├─ API 文档
  └─ 迁移指南

总计: 7-10 天
```

### 关键风险

1. **SDK API 兼容性**: CodeBuddy SDK 可能与 Claude Agent SDK API 不完全兼容
2. **工具名称差异**: 工具名称可能不同，需要映射层
3. **配置文件格式**: `.codebuddy.json` 格式可能与 `.claude.json` 不同
4. **MCP 协议支持**: 需要验证 CodeBuddy 是否支持 MCP

### 建议

1. **优先验证 SDK 兼容性**: 先确认 CodeBuddy SDK 的 API 签名
2. **创建适配层**: 如果 API 不兼容，通过适配器模式隔离差异
3. **增量测试**: 每个阶段完成后进行测试验证
4. **保持向后兼容**: 确保现有 Claude Code 功能不受影响

---

**文档结束**

> 下一步: 开始实施 CodeBuddy 支持
> 分支: feat/codebuddy-support
