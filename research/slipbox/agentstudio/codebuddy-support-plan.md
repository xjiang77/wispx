# AgentStudio CodeBuddy 支持方案

> 文档生成时间: 2026-01-29
> 分支: feat/codebuddy-support
> 版本: v0.3.2

## 目录

1. [概述](#概述)
2. [数据结构对比分析](#数据结构对比分析)
3. [兼容性策略](#兼容性策略)
4. [实施方案](#实施方案)
5. [数据适配层设计](#数据适配层设计)
6. [测试计划](#测试计划)
7. [部署与迁移](#部署与迁移)

---

## 概述

### 背景

- **CodeBuddy SDK**: 与 Claude Agent SDK 接口协议兼容
- **本地数据**: **不兼容** Claude Code 的本地数据结构
- **目标**: AgentStudio 同时支持 Claude Code 和 CodeBuddy 引擎

### 核心挑战

虽然 SDK 接口兼容，但两者的本地数据存储结构存在显著差异：
- 配置文件位置和格式
- 会话历史存储方式
- 项目路径编码方式
- 插件系统结构

### 方案概览

```
┌─────────────────────────────────────────────────────────────┐
│                AgentStudio 双引擎架构                        │
└─────────────────────────────────────────────────────────────┘

用户请求
    │
    ▼
引擎检测 (AGENT_SDK)
    │
    ├─────> claude-code
    │         │
    │         ├─ ~/.claude/
    │         ├─ ~/.claude.json
    │         └─ ClaudeDataAdapter
    │
    └─────> code-buddy
              │
              ├─ ~/.codebuddy/
              ├─ ~/.codebuddy/settings.json
              └─ CodeBuddyDataAdapter
                    │
                    ▼
            统一数据接口层
                    │
                    ▼
            SessionManager / ProjectMetadata
```

---

## 数据结构对比分析

### 2.1 目录结构对比

#### Claude Code (~/.claude/)

```
~/.claude/
├── .claude.json                          # 全局配置（根目录）
├── settings.json                         # 用户设置
├── stats-cache.json                      # 统计缓存
├── ide/                                  # IDE 集成
├── tasks/                                # 任务队列
│   └── {taskId}/                        # 任务实例
├── cache/                                # 缓存目录
├── plans/                                # 计划模式
├── plugins/                              # 插件系统
│   ├── cache/                           # 插件缓存
│   │   ├── claude-hud/
│   │   ├── obsidian-skills/
│   │   └── claude-code-plugins/
│   └── marketplaces/                    # 插件市场
│       ├── claude-hud/
│       ├── obsidian-skills/
│       └── claude-code-plugins/
└── projects/                             # 项目会话
    └── -{path-with-dashes}/             # 路径编码：/ → -
        ├── {sessionId}/                 # 会话目录
        │   └── tool-results/            # 工具结果
        └── {sessionId}/
```

**关键特征**:
- ✅ 配置文件在根目录 `~/.claude.json`
- ✅ 项目路径编码: `/Users/foo/bar` → `-Users-foo-bar`
- ✅ 会话存储为目录: `{sessionId}/`
- ✅ 插件分 `cache/` 和 `marketplaces/`

#### CodeBuddy (~/.codebuddy/)

```
~/.codebuddy/
├── settings.json                         # 用户设置（SDK 内）
├── user-state.json                       # 用户状态
├── mcp.json                              # MCP 配置
├── local_storage/                        # 本地存储
│   └── entry_{hash}.info                # 哈希命名的条目
├── bin/                                  # 可执行文件
│   └── buddycn -> /Applications/...     # 符号链接
├── plans/                                # 计划模式
├── plugins/                              # 插件系统
│   └── marketplaces/                    # 插件市场
│       └── codebuddy-plugins-official/
├── projects/                             # 项目会话
│   └── {path-without-dashes}/           # 路径编码：保持原样
│       └── {sessionId}.jsonl            # JSONL 格式
├── logs/                                 # 日志目录
│   └── {date}/                          # 按日期分类
└── skills/                               # 技能目录（内置）
    ├── algorithmic-art/
    ├── doc-coauthoring/
    ├── pdf/
    └── pptx/
```

**关键特征**:
- ✅ 配置文件在 SDK 目录内 `~/.codebuddy/settings.json`
- ✅ 项目路径编码: `Users-foo-bar` (无前导 `-`)
- ✅ 会话存储为文件: `{sessionId}.jsonl`
- ✅ 内置 `skills/` 目录
- ✅ 独立 `logs/` 目录
- ✅ `local_storage/` 哈希存储

### 2.2 配置文件对比

#### Claude Code (~/.claude.json)

```json
{
  "numStartups": 360,
  "installMethod": "native",
  "autoUpdates": false,
  "hasSeenTasksHint": true,
  "customApiKeyResponses": {
    "approved": [],
    "rejected": ["efbd87780c87e39a66a4"]
  },
  "tipsHistory": {
    "new-user-warmup": 7,
    "memory-command": 346,
    "theme-command": 355,
    ...
  }
}
```

**特点**:
- 根目录配置，大文件（59KB）
- 包含 `tipsHistory` 详细记录
- `customApiKeyResponses` 审批历史

#### Claude Code (settings.json)

```json
{
  "env": {
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"
  },
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/claude-hud-wrapper.sh"
  },
  "enabledPlugins": {
    "document-skills@anthropic-agent-skills": true,
    "frontend-design@claude-code-plugins": true,
    ...
  },
  "alwaysThinkingEnabled": true
}
```

#### CodeBuddy (settings.json)

```json
{
  "env": {},
  "model": "claude-opus-4.5",
  "alwaysThinkingEnabled": false,
  "trustedDirectories": [
    "/Users/kevinxjiang/IdeaProjects/data-query-server",
    "/Users/kevinxjiang/Workspace/agentstudio",
    ...
  ],
  "statusLine": {
    "type": "command",
    "command": "bash ~/.codebuddy/statusline-command.sh"
  },
  "enabledPlugins": {
    "gopls-lsp@codebuddy-plugins-official": true
  }
}
```

**差异**:
| 字段 | Claude Code | CodeBuddy |
|------|-------------|-----------|
| 位置 | `~/.claude/settings.json` | `~/.codebuddy/settings.json` |
| `model` | ❌ 不存在 | ✅ `"claude-opus-4.5"` |
| `trustedDirectories` | ❌ 不存在 | ✅ 数组 |
| `enabledPlugins` | ✅ 丰富 | ✅ 简单 |

#### CodeBuddy (user-state.json)

```json
{
  "numStartups": 103,
  "memoryUsageCount": 1,
  "promptQueueUseCount": 0,
  "sessionsSinceLastTip": 9,
  "tipShowHistory": {
    "new-user-warmup": {
      "count": 1,
      "lastShown": 1760081091363
    },
    "plan-mode-for-complex-tasks": {
      "count": 3,
      "lastShown": 1768462878066
    },
    ...
  },
  "lastTipShown": "prompt-queue",
  "lastPlanModeUse": 1768464171930
}
```

**特点**:
- 类似 Claude Code 的 `.claude.json` 但结构更清晰
- 提示历史结构化 (对象而非计数)

### 2.3 会话存储对比

#### Claude Code 会话格式

```
~/.claude/projects/-Users-foo-bar/
├── c2b2f632-cccd-4658-8dd4-03b825589c35/
│   └── tool-results/
│       ├── result1.json
│       └── result2.json
└── f5dacb87-c085-4624-a95d-ef5643e43fa6/
    └── tool-results/
```

**特点**:
- 会话 = 目录
- 工具结果单独存储
- 需要 SDK 内部管理消息历史

#### CodeBuddy 会话格式

```
~/.codebuddy/projects/Users-foo-bar/
└── 3bdfa152-2f2a-45a9-8727-317766854dc0.jsonl
```

**内容示例** (JSONL):
```jsonl
{"id":"1d9d8dee-224a-4083-9565-151561b7d6db","timestamp":1769663745912,"type":"message","role":"user","content":[{"type":"input_text","text":"Caveat: The messages..."}],"providerData":{"skipRun":true},"sessionId":"3bdfa152-2f2a-45a9-8727-317766854dc0","cwd":"/Users/kevinxjiang/Workspace/agentstudio"}
{"id":"a9be335d-fc3a-4ece-9fe5-d25f55fdebe6","parentId":"1d9d8dee-224a-4083-9565-151561b7d6db","timestamp":1769663745927,"type":"message","role":"user","content":[{"type":"input_text","text":"<command-name>/doctor</command-name>"}],"providerData":{"skipRun":true},"sessionId":"3bdfa152-2f2a-45a9-8727-317766854dc0","cwd":"/Users/kevinxjiang/Workspace/agentstudio"}
```

**特点**:
- 会话 = JSONL 文件
- 每行一条消息
- 包含完整元数据 (`id`, `parentId`, `timestamp`, `cwd`)
- 可直接读取和解析

### 2.4 MCP 配置对比

#### Claude Code

位置: `~/.config/agentstudio/mcp-server-config.json` (AgentStudio 管理)

```json
{
  "mcpServers": {
    "serverName": {
      "type": "stdio",
      "command": "node",
      "args": ["/path/to/server.js"],
      "env": {},
      "status": "active"
    }
  }
}
```

#### CodeBuddy

位置: `~/.codebuddy/mcp.json`

```json
{
  "mcpServers": {
    "mcp-luopan-ck-dev": {
      "type": "sse",
      "url": "http://11.151.200.57:8081/clickhouse-tools/sse",
      "headers": {
        "rtx": "kevinxjiang"
      },
      "disabled": false
    }
  }
}
```

**差异**:
| 字段 | Claude Code | CodeBuddy |
|------|-------------|-----------|
| 位置 | AgentStudio 管理 | `~/.codebuddy/mcp.json` |
| `status` | ✅ `"active"` | ❌ 改为 `disabled` (反向逻辑) |
| SSE 支持 | ✅ | ✅ |
| HTTP 支持 | ✅ | ✅ (推测) |

### 2.5 路径编码差异

| 引擎 | 原始路径 | 编码后 |
|------|---------|--------|
| Claude Code | `/Users/kevinxjiang/Workspace/agentstudio` | `-Users-kevinxjiang-Workspace-agentstudio` |
| CodeBuddy | `/Users/kevinxjiang/Workspace/agentstudio` | `Users-kevinxjiang-Workspace-agentstudio` |

**关键差异**: Claude Code 有前导 `-`，CodeBuddy 没有。

---

## 兼容性策略

### 3.1 策略选择

基于数据结构差异，采用 **数据适配层模式**：

```
┌─────────────────────────────────────────────────────────────┐
│                  统一数据接口层                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  IConfigAdapter                                       │  │
│  │  - getSettings(): Settings                           │  │
│  │  - getUserState(): UserState                         │  │
│  │  - getMcpConfig(): McpConfig                         │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  ISessionAdapter                                      │  │
│  │  - listSessions(projectPath): SessionInfo[]          │  │
│  │  - getSessionHistory(sessionId): Message[]           │  │
│  │  - saveSessionMessage(sessionId, msg): void          │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  IProjectAdapter                                      │  │
│  │  - encodeProjectPath(path): string                   │  │
│  │  - decodeProjectPath(encoded): string                │  │
│  │  - getProjectDir(path): string                       │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
         │                                │
         ▼                                ▼
┌──────────────────┐           ┌──────────────────┐
│ ClaudeAdapter    │           │ CodeBuddyAdapter │
│ (实现类)          │           │ (实现类)          │
└──────────────────┘           └──────────────────┘
```

### 3.2 设计原则

1. **接口统一**: 上层代码只依赖接口，不关心实现
2. **引擎隔离**: 每个引擎有独立的适配器实现
3. **动态切换**: 运行时根据 `AGENT_SDK` 选择适配器
4. **数据独立**: 不同引擎的数据互不干扰
5. **渐进迁移**: 先支持读取，再支持写入

### 3.3 不兼容字段处理

| 字段 | Claude Code | CodeBuddy | 处理方式 |
|------|-------------|-----------|----------|
| `model` | ❌ | ✅ | CodeBuddyAdapter 优先读取，Claude 使用 provider 配置 |
| `trustedDirectories` | ❌ | ✅ | 仅 CodeBuddy 使用 |
| 会话格式 | 目录 | JSONL | 适配器转换 |
| 路径编码 | `-User-...` | `User-...` | 适配器处理 |

---

## 实施方案

### 4.1 阶段划分

```
阶段 1: 基础架构 (2-3 天)
  ├─ 定义数据适配器接口
  ├─ 实现 ClaudeAdapter (基于现有代码重构)
  └─ 实现 CodeBuddyAdapter (新增)

阶段 2: 配置适配 (1-2 天)
  ├─ 配置文件读取适配
  ├─ MCP 配置适配
  └─ 路径编码转换

阶段 3: 会话适配 (2-3 天)
  ├─ 会话列表读取
  ├─ 会话历史解析
  └─ JSONL 格式支持

阶段 4: 集成测试 (2-3 天)
  ├─ 单元测试
  ├─ 集成测试
  └─ E2E 测试

阶段 5: 文档与部署 (1 天)
  ├─ 更新文档
  ├─ 迁移指南
  └─ 发布

总计: 8-12 天
```

### 4.2 文件结构

```
backend/src/adapters/
├── types.ts                              # 接口定义
├── ClaudeDataAdapter.ts                  # Claude Code 适配器
├── CodeBuddyDataAdapter.ts               # CodeBuddy 适配器
├── AdapterFactory.ts                     # 工厂模式
└── __tests__/
    ├── ClaudeAdapter.test.ts
    └── CodeBuddyAdapter.test.ts
```

### 4.3 核心接口定义

```typescript
// backend/src/adapters/types.ts

export interface Settings {
  env: Record<string, string>;
  model?: string;
  alwaysThinkingEnabled: boolean;
  statusLine?: {
    type: string;
    command: string;
  };
  enabledPlugins: Record<string, boolean>;
  trustedDirectories?: string[];
}

export interface UserState {
  numStartups: number;
  tipShowHistory: Record<string, number | { count: number; lastShown: number }>;
  lastTipShown?: string;
  lastPlanModeUse?: number;
}

export interface McpConfig {
  mcpServers: Record<string, {
    type: 'stdio' | 'sse' | 'http';
    command?: string;
    args?: string[];
    env?: Record<string, string>;
    url?: string;
    headers?: Record<string, string>;
    status?: 'active' | 'inactive';
    disabled?: boolean;
  }>;
}

export interface SessionInfo {
  sessionId: string;
  projectPath: string;
  lastModified: number;
  messageCount?: number;
}

export interface Message {
  id: string;
  parentId?: string;
  timestamp: number;
  type: string;
  role: 'user' | 'assistant';
  content: any[];
  sessionId: string;
  cwd?: string;
}

export interface IConfigAdapter {
  // 获取设置
  getSettings(): Promise<Settings>;

  // 获取用户状态
  getUserState(): Promise<UserState>;

  // 获取 MCP 配置
  getMcpConfig(): Promise<McpConfig>;

  // 保存设置
  saveSettings(settings: Settings): Promise<void>;
}

export interface ISessionAdapter {
  // 列出项目的所有会话
  listSessions(projectPath: string): Promise<SessionInfo[]>;

  // 获取会话历史
  getSessionHistory(projectPath: string, sessionId: string): Promise<Message[]>;

  // 保存会话消息
  saveSessionMessage(projectPath: string, sessionId: string, message: Message): Promise<void>;
}

export interface IProjectAdapter {
  // 编码项目路径
  encodeProjectPath(absolutePath: string): string;

  // 解码项目路径
  decodeProjectPath(encodedPath: string): string;

  // 获取项目目录
  getProjectDir(absolutePath: string): string;

  // 获取会话目录
  getSessionDir(projectPath: string, sessionId: string): string;
}

export interface IDataAdapter extends IConfigAdapter, ISessionAdapter, IProjectAdapter {
  // 适配器类型
  readonly type: 'claude-code' | 'code-buddy';

  // 根目录
  readonly rootDir: string;
}
```

---

## 数据适配层设计

### 5.1 ClaudeDataAdapter 实现

```typescript
// backend/src/adapters/ClaudeDataAdapter.ts

import * as fs from 'fs-extra';
import * as path from 'path';
import * as os from 'os';
import {
  IDataAdapter,
  Settings,
  UserState,
  McpConfig,
  SessionInfo,
  Message
} from './types';

export class ClaudeDataAdapter implements IDataAdapter {
  readonly type = 'claude-code' as const;
  readonly rootDir: string;

  constructor() {
    this.rootDir = path.join(os.homedir(), '.claude');
  }

  // ==================== Config Adapter ====================

  async getSettings(): Promise<Settings> {
    const settingsPath = path.join(this.rootDir, 'settings.json');
    if (await fs.pathExists(settingsPath)) {
      const data = await fs.readJson(settingsPath);
      return {
        env: data.env || {},
        alwaysThinkingEnabled: data.alwaysThinkingEnabled || false,
        statusLine: data.statusLine,
        enabledPlugins: data.enabledPlugins || {},
        model: undefined, // Claude Code 不在 settings 中存储 model
        trustedDirectories: undefined
      };
    }
    return this.getDefaultSettings();
  }

  async getUserState(): Promise<UserState> {
    const configPath = path.join(os.homedir(), '.claude.json');
    if (await fs.pathExists(configPath)) {
      const data = await fs.readJson(configPath);
      return {
        numStartups: data.numStartups || 0,
        tipShowHistory: data.tipsHistory || {},
        lastTipShown: undefined,
        lastPlanModeUse: undefined
      };
    }
    return { numStartups: 0, tipShowHistory: {} };
  }

  async getMcpConfig(): Promise<McpConfig> {
    // Claude Code 的 MCP 配置由 AgentStudio 管理
    // 位置: ~/.config/agentstudio/mcp-server-config.json
    const configDir = path.join(os.homedir(), '.config', 'agentstudio');
    const mcpConfigPath = path.join(configDir, 'mcp-server-config.json');

    if (await fs.pathExists(mcpConfigPath)) {
      return await fs.readJson(mcpConfigPath);
    }
    return { mcpServers: {} };
  }

  async saveSettings(settings: Settings): Promise<void> {
    const settingsPath = path.join(this.rootDir, 'settings.json');
    await fs.ensureDir(this.rootDir);
    await fs.writeJson(settingsPath, settings, { spaces: 2 });
  }

  // ==================== Session Adapter ====================

  async listSessions(projectPath: string): Promise<SessionInfo[]> {
    const projectDir = this.getProjectDir(projectPath);

    if (!(await fs.pathExists(projectDir))) {
      return [];
    }

    const entries = await fs.readdir(projectDir, { withFileTypes: true });
    const sessions: SessionInfo[] = [];

    for (const entry of entries) {
      if (entry.isDirectory()) {
        const sessionDir = path.join(projectDir, entry.name);
        const stat = await fs.stat(sessionDir);

        sessions.push({
          sessionId: entry.name,
          projectPath,
          lastModified: stat.mtimeMs,
          messageCount: undefined // Claude Code 不直接暴露消息数
        });
      }
    }

    return sessions.sort((a, b) => b.lastModified - a.lastModified);
  }

  async getSessionHistory(projectPath: string, sessionId: string): Promise<Message[]> {
    // Claude Code 的会话历史由 SDK 内部管理
    // 这里返回空数组，实际消息通过 SDK query() 获取
    return [];
  }

  async saveSessionMessage(projectPath: string, sessionId: string, message: Message): Promise<void> {
    // Claude Code 的会话消息由 SDK 自动保存
    // 这里不需要手动保存
  }

  // ==================== Project Adapter ====================

  encodeProjectPath(absolutePath: string): string {
    // Claude Code: /Users/foo/bar → -Users-foo-bar
    return '-' + absolutePath.replace(/\//g, '-');
  }

  decodeProjectPath(encodedPath: string): string {
    // -Users-foo-bar → /Users/foo/bar
    return encodedPath.substring(1).replace(/-/g, '/');
  }

  getProjectDir(absolutePath: string): string {
    const encoded = this.encodeProjectPath(absolutePath);
    return path.join(this.rootDir, 'projects', encoded);
  }

  getSessionDir(projectPath: string, sessionId: string): string {
    const projectDir = this.getProjectDir(projectPath);
    return path.join(projectDir, sessionId);
  }

  // ==================== Helper Methods ====================

  private getDefaultSettings(): Settings {
    return {
      env: {},
      alwaysThinkingEnabled: false,
      enabledPlugins: {},
      model: undefined,
      trustedDirectories: undefined
    };
  }
}
```

### 5.2 CodeBuddyDataAdapter 实现

```typescript
// backend/src/adapters/CodeBuddyDataAdapter.ts

import * as fs from 'fs-extra';
import * as path from 'path';
import * as os from 'os';
import * as readline from 'readline';
import {
  IDataAdapter,
  Settings,
  UserState,
  McpConfig,
  SessionInfo,
  Message
} from './types';

export class CodeBuddyDataAdapter implements IDataAdapter {
  readonly type = 'code-buddy' as const;
  readonly rootDir: string;

  constructor() {
    this.rootDir = path.join(os.homedir(), '.codebuddy');
  }

  // ==================== Config Adapter ====================

  async getSettings(): Promise<Settings> {
    const settingsPath = path.join(this.rootDir, 'settings.json');
    if (await fs.pathExists(settingsPath)) {
      const data = await fs.readJson(settingsPath);
      return {
        env: data.env || {},
        model: data.model,
        alwaysThinkingEnabled: data.alwaysThinkingEnabled || false,
        statusLine: data.statusLine,
        enabledPlugins: data.enabledPlugins || {},
        trustedDirectories: data.trustedDirectories
      };
    }
    return this.getDefaultSettings();
  }

  async getUserState(): Promise<UserState> {
    const statePath = path.join(this.rootDir, 'user-state.json');
    if (await fs.pathExists(statePath)) {
      const data = await fs.readJson(statePath);

      // 转换 tipShowHistory 格式
      const tipShowHistory: Record<string, number | { count: number; lastShown: number }> = {};
      for (const [key, value] of Object.entries(data.tipShowHistory || {})) {
        tipShowHistory[key] = value as any;
      }

      return {
        numStartups: data.numStartups || 0,
        tipShowHistory,
        lastTipShown: data.lastTipShown,
        lastPlanModeUse: data.lastPlanModeUse
      };
    }
    return { numStartups: 0, tipShowHistory: {} };
  }

  async getMcpConfig(): Promise<McpConfig> {
    const mcpConfigPath = path.join(this.rootDir, 'mcp.json');
    if (await fs.pathExists(mcpConfigPath)) {
      const data = await fs.readJson(mcpConfigPath);

      // 转换 disabled → status
      const mcpServers: McpConfig['mcpServers'] = {};
      for (const [serverName, config] of Object.entries(data.mcpServers || {})) {
        const serverConfig = config as any;
        mcpServers[serverName] = {
          ...serverConfig,
          status: serverConfig.disabled ? 'inactive' : 'active'
        };
      }

      return { mcpServers };
    }
    return { mcpServers: {} };
  }

  async saveSettings(settings: Settings): Promise<void> {
    const settingsPath = path.join(this.rootDir, 'settings.json');
    await fs.ensureDir(this.rootDir);

    // 移除 undefined 字段
    const cleanSettings = {
      env: settings.env,
      model: settings.model,
      alwaysThinkingEnabled: settings.alwaysThinkingEnabled,
      statusLine: settings.statusLine,
      enabledPlugins: settings.enabledPlugins,
      trustedDirectories: settings.trustedDirectories
    };

    await fs.writeJson(settingsPath, cleanSettings, { spaces: 2 });
  }

  // ==================== Session Adapter ====================

  async listSessions(projectPath: string): Promise<SessionInfo[]> {
    const projectDir = this.getProjectDir(projectPath);

    if (!(await fs.pathExists(projectDir))) {
      return [];
    }

    const entries = await fs.readdir(projectDir);
    const sessions: SessionInfo[] = [];

    for (const entry of entries) {
      if (entry.endsWith('.jsonl')) {
        const sessionId = entry.replace('.jsonl', '');
        const sessionFile = path.join(projectDir, entry);
        const stat = await fs.stat(sessionFile);

        // 计算消息数（快速方式：读取行数）
        const messageCount = await this.countJsonlLines(sessionFile);

        sessions.push({
          sessionId,
          projectPath,
          lastModified: stat.mtimeMs,
          messageCount
        });
      }
    }

    return sessions.sort((a, b) => b.lastModified - a.lastModified);
  }

  async getSessionHistory(projectPath: string, sessionId: string): Promise<Message[]> {
    const sessionFile = path.join(this.getProjectDir(projectPath), `${sessionId}.jsonl`);

    if (!(await fs.pathExists(sessionFile))) {
      return [];
    }

    const messages: Message[] = [];
    const fileStream = fs.createReadStream(sessionFile);
    const rl = readline.createInterface({
      input: fileStream,
      crlfDelay: Infinity
    });

    for await (const line of rl) {
      if (line.trim()) {
        try {
          const message = JSON.parse(line);
          messages.push(message);
        } catch (error) {
          console.error(`Failed to parse JSONL line: ${line}`, error);
        }
      }
    }

    return messages;
  }

  async saveSessionMessage(projectPath: string, sessionId: string, message: Message): Promise<void> {
    const projectDir = this.getProjectDir(projectPath);
    await fs.ensureDir(projectDir);

    const sessionFile = path.join(projectDir, `${sessionId}.jsonl`);
    const jsonLine = JSON.stringify(message) + '\n';

    await fs.appendFile(sessionFile, jsonLine, 'utf-8');
  }

  // ==================== Project Adapter ====================

  encodeProjectPath(absolutePath: string): string {
    // CodeBuddy: /Users/foo/bar → Users-foo-bar (无前导 -)
    return absolutePath.replace(/^\//, '').replace(/\//g, '-');
  }

  decodeProjectPath(encodedPath: string): string {
    // Users-foo-bar → /Users/foo/bar
    return '/' + encodedPath.replace(/-/g, '/');
  }

  getProjectDir(absolutePath: string): string {
    const encoded = this.encodeProjectPath(absolutePath);
    return path.join(this.rootDir, 'projects', encoded);
  }

  getSessionDir(projectPath: string, sessionId: string): string {
    // CodeBuddy 没有会话目录，会话是文件
    return path.join(this.getProjectDir(projectPath), `${sessionId}.jsonl`);
  }

  // ==================== Helper Methods ====================

  private async countJsonlLines(filePath: string): Promise<number> {
    let count = 0;
    const fileStream = fs.createReadStream(filePath);
    const rl = readline.createInterface({
      input: fileStream,
      crlfDelay: Infinity
    });

    for await (const line of rl) {
      if (line.trim()) {
        count++;
      }
    }

    return count;
  }

  private getDefaultSettings(): Settings {
    return {
      env: {},
      model: 'claude-sonnet-4.5',
      alwaysThinkingEnabled: false,
      enabledPlugins: {},
      trustedDirectories: []
    };
  }
}
```

### 5.3 AdapterFactory 工厂

```typescript
// backend/src/adapters/AdapterFactory.ts

import { SDK_ENGINE } from '../config/sdkConfig';
import { IDataAdapter } from './types';
import { ClaudeDataAdapter } from './ClaudeDataAdapter';
import { CodeBuddyDataAdapter } from './CodeBuddyDataAdapter';

let cachedAdapter: IDataAdapter | null = null;

export function getDataAdapter(): IDataAdapter {
  if (cachedAdapter) {
    return cachedAdapter;
  }

  switch (SDK_ENGINE) {
    case 'claude-code':
    case 'claude-internal':
      cachedAdapter = new ClaudeDataAdapter();
      break;

    case 'code-buddy':
      cachedAdapter = new CodeBuddyDataAdapter();
      break;

    default:
      console.warn(`Unknown SDK engine: ${SDK_ENGINE}, falling back to claude-code`);
      cachedAdapter = new ClaudeDataAdapter();
  }

  console.log(`🔌 Loaded data adapter: ${cachedAdapter.type}`);
  return cachedAdapter;
}

// 用于测试或特殊场景，强制重新创建适配器
export function resetDataAdapter(): void {
  cachedAdapter = null;
}
```

### 5.4 集成到现有代码

#### 步骤 1: 更新 SessionManager

```typescript
// backend/src/services/sessionManager.ts

import { getDataAdapter } from '../adapters/AdapterFactory';

export class SessionManager {
  private dataAdapter = getDataAdapter();

  async listProjectSessions(projectPath: string) {
    return await this.dataAdapter.listSessions(projectPath);
  }

  async getSessionHistory(projectPath: string, sessionId: string) {
    return await this.dataAdapter.getSessionHistory(projectPath, sessionId);
  }

  // ... 其他方法
}
```

#### 步骤 2: 更新配置读取

```typescript
// backend/src/utils/claudeUtils.ts

import { getDataAdapter } from '../adapters/AdapterFactory';

export async function buildQueryOptions(...) {
  const adapter = getDataAdapter();

  // 读取设置
  const settings = await adapter.getSettings();

  // 读取 MCP 配置
  const mcpConfig = await adapter.getMcpConfig();

  // 使用 adapter 编码项目路径
  const projectDir = adapter.getProjectDir(projectPath);

  // ...
}
```

---

## 测试计划

### 6.1 单元测试

```typescript
// backend/src/adapters/__tests__/ClaudeAdapter.test.ts

import { ClaudeDataAdapter } from '../ClaudeDataAdapter';

describe('ClaudeDataAdapter', () => {
  let adapter: ClaudeDataAdapter;

  beforeEach(() => {
    adapter = new ClaudeDataAdapter();
  });

  describe('路径编码', () => {
    it('应该正确编码项目路径', () => {
      const input = '/Users/kevinxjiang/Workspace/agentstudio';
      const expected = '-Users-kevinxjiang-Workspace-agentstudio';
      expect(adapter.encodeProjectPath(input)).toBe(expected);
    });

    it('应该正确解码项目路径', () => {
      const input = '-Users-kevinxjiang-Workspace-agentstudio';
      const expected = '/Users/kevinxjiang/Workspace/agentstudio';
      expect(adapter.decodeProjectPath(input)).toBe(expected);
    });
  });

  describe('配置读取', () => {
    it('应该读取 settings.json', async () => {
      const settings = await adapter.getSettings();
      expect(settings).toHaveProperty('env');
      expect(settings).toHaveProperty('enabledPlugins');
    });

    it('应该读取用户状态', async () => {
      const userState = await adapter.getUserState();
      expect(userState).toHaveProperty('numStartups');
      expect(userState).toHaveProperty('tipShowHistory');
    });
  });
});
```

```typescript
// backend/src/adapters/__tests__/CodeBuddyAdapter.test.ts

import { CodeBuddyDataAdapter } from '../CodeBuddyDataAdapter';

describe('CodeBuddyDataAdapter', () => {
  let adapter: CodeBuddyDataAdapter;

  beforeEach(() => {
    adapter = new CodeBuddyDataAdapter();
  });

  describe('路径编码', () => {
    it('应该正确编码项目路径（无前导-）', () => {
      const input = '/Users/kevinxjiang/Workspace/agentstudio';
      const expected = 'Users-kevinxjiang-Workspace-agentstudio';
      expect(adapter.encodeProjectPath(input)).toBe(expected);
    });

    it('应该正确解码项目路径', () => {
      const input = 'Users-kevinxjiang-Workspace-agentstudio';
      const expected = '/Users/kevinxjiang/Workspace/agentstudio';
      expect(adapter.decodeProjectPath(input)).toBe(expected);
    });
  });

  describe('JSONL 会话读取', () => {
    it('应该解析 JSONL 会话历史', async () => {
      const projectPath = '/Users/kevinxjiang/Workspace/agentstudio';
      const sessionId = '3bdfa152-2f2a-45a9-8727-317766854dc0';

      const messages = await adapter.getSessionHistory(projectPath, sessionId);
      expect(Array.isArray(messages)).toBe(true);

      if (messages.length > 0) {
        expect(messages[0]).toHaveProperty('id');
        expect(messages[0]).toHaveProperty('timestamp');
        expect(messages[0]).toHaveProperty('sessionId');
      }
    });
  });

  describe('MCP 配置适配', () => {
    it('应该转换 disabled 为 status', async () => {
      const mcpConfig = await adapter.getMcpConfig();

      for (const serverConfig of Object.values(mcpConfig.mcpServers)) {
        expect(serverConfig).toHaveProperty('status');
        expect(['active', 'inactive']).toContain(serverConfig.status);
      }
    });
  });
});
```

### 6.2 集成测试

```typescript
// backend/src/__tests__/integration/adapter.test.ts

import { getDataAdapter } from '../../adapters/AdapterFactory';

describe('数据适配器集成测试', () => {
  it('应该根据环境变量选择正确的适配器', () => {
    process.env.AGENT_SDK = 'code-buddy';
    const adapter = getDataAdapter();
    expect(adapter.type).toBe('code-buddy');
  });

  it('应该能够列出项目会话', async () => {
    const adapter = getDataAdapter();
    const projectPath = '/Users/kevinxjiang/Workspace/agentstudio';

    const sessions = await adapter.listSessions(projectPath);
    expect(Array.isArray(sessions)).toBe(true);
  });

  it('应该能够读取配置', async () => {
    const adapter = getDataAdapter();

    const settings = await adapter.getSettings();
    const userState = await adapter.getUserState();
    const mcpConfig = await adapter.getMcpConfig();

    expect(settings).toBeDefined();
    expect(userState).toBeDefined();
    expect(mcpConfig).toBeDefined();
  });
});
```

### 6.3 E2E 测试场景

1. **创建新会话 (CodeBuddy)**
   - 验证 JSONL 文件创建
   - 验证消息格式正确

2. **切换引擎**
   - 从 Claude Code 切换到 CodeBuddy
   - 验证配置正确加载
   - 验证会话列表正确

3. **MCP 配置同步**
   - 修改 MCP 配置
   - 验证两个引擎都能读取

4. **路径编码**
   - 复杂路径测试
   - 特殊字符处理

---

## 部署与迁移

### 7.1 部署步骤

#### 步骤 1: 安装依赖

```bash
cd backend
pnpm install
```

#### 步骤 2: 环境变量配置

```bash
# .env
AGENT_SDK=code-buddy  # 或 claude-code
```

#### 步骤 3: 启动服务

```bash
pnpm run dev:backend
```

#### 步骤 4: 验证

```bash
curl http://localhost:4936/api/config/sdk-engine
# 应返回: { "engine": "code-buddy" }
```

### 7.2 数据迁移（可选）

如果需要在两个引擎之间迁移数据：

```typescript
// scripts/migrate-data.ts

import { ClaudeDataAdapter } from '../backend/src/adapters/ClaudeDataAdapter';
import { CodeBuddyDataAdapter } from '../backend/src/adapters/CodeBuddyDataAdapter';

async function migrateClaudeToCodeBuddy() {
  const claudeAdapter = new ClaudeDataAdapter();
  const codeBuddyAdapter = new CodeBuddyDataAdapter();

  // 迁移配置
  const settings = await claudeAdapter.getSettings();
  await codeBuddyAdapter.saveSettings(settings);

  console.log('✅ 配置迁移完成');

  // 注意: 会话历史不迁移，因为格式差异太大
  console.log('⚠️  会话历史需要手动迁移或重新创建');
}

migrateClaudeToCodeBuddy();
```

### 7.3 回滚计划

如果 CodeBuddy 集成出现问题：

```bash
# 1. 切换回 Claude Code
export AGENT_SDK=claude-code

# 2. 重启服务
pnpm run dev:backend

# 3. 验证
curl http://localhost:4936/api/config/sdk-engine
```

---

## 总结

### 关键成果

1. ✅ **完整的数据结构对比** - 详细分析了 Claude Code 和 CodeBuddy 的差异
2. ✅ **统一适配器接口** - 定义了 `IDataAdapter` 等接口
3. ✅ **双引擎实现** - `ClaudeDataAdapter` 和 `CodeBuddyDataAdapter`
4. ✅ **工厂模式** - `AdapterFactory` 动态选择
5. ✅ **测试计划** - 单元测试、集成测试、E2E 测试
6. ✅ **部署方案** - 环境变量、迁移、回滚

### 风险与挑战

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| JSONL 解析性能 | 中 | 使用流式读取，缓存会话列表 |
| 路径编码差异 | 低 | 适配器封装，上层无感知 |
| MCP 配置不兼容 | 中 | 转换层处理 `disabled` ↔ `status` |
| 会话历史格式差异 | 高 | 不迁移历史，新会话使用新格式 |

### 下一步行动

1. **立即开始**: 实现 `backend/src/adapters/` 目录和接口
2. **并行开发**: `ClaudeDataAdapter` 和 `CodeBuddyDataAdapter`
3. **集成测试**: 在 AgentStudio 中测试适配器
4. **文档完善**: 更新 CLAUDE.md 和 README
5. **发布**: 合并到 main 分支

### 预期工期

- **最快**: 8 天（顺利情况）
- **正常**: 10 天（有小问题需调试）
- **最慢**: 12 天（遇到未知问题）

---

**文档结束**

> 下一步: 开始实施适配器代码
> 分支: feat/codebuddy-support
> 预计完成: 2026-02-10
