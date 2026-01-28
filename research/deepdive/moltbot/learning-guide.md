# Clawdbot 架构深度学习笔记

> 通过苏格拉底式问答学习法，系统性地理解 MoltBot/ Previous Clawdbot 的完整架构

---

## 目录

1. [项目概述](#一项目概述)
2. [系统架构全景](#二系统架构全景)
3. [Channel Layer 详解](#三channel-layer-详解)
4. [Gateway Server 详解](#四gateway-server-详解)
5. [Agent Layer 详解](#五agent-layer-详解)
6. [Infrastructure Layer 详解](#六infrastructure-layer-详解)
7. [部署模式详解](#七部署模式详解)
8. [后续学习计划](#八后续学习计划)
9. [SessionKey 深入解析](#九sessionkey-深入解析)
10. [路由绑定优先级](#十路由绑定优先级)
11. [安全检查链详解](#十一安全检查链详解)
12. [Session 压缩机制详解](#十二session-压缩机制详解)
13. [Memory 检索机制详解](#十三memory-检索机制详解)
14. [存储机制详解](#十四存储机制详解)
15. [System Prompt 构建机制详解](#十五system-prompt-构建机制详解)
16. [Subagent 系统详解](#十六subagent-系统详解)
17. [Sandbox 与文件系统隔离详解](#十七sandbox-与文件系统隔离详解)

---

## 一、项目概述

### 1.1 Clawdbot 是什么？

**Clawdbot** 是一个个人 AI 助手平台，运行在你自己的设备上。它是一个 local-first 的网关，能够将 Claude（通过 Anthropic）或其他 AI 模型连接到多个消息渠道，并提供语音交互、可视化画布控制和自主代理功能。

### 1.2 核心价值

用户想让 AI 助手处理各种消息平台的消息时，会遇到以下问题：

> **没有一个独立的、安全的地方让 AI 助手有足够的上下文和工具来执行必要的任务**

Clawdbot 解决了这个问题，提供：
- **隔离的运行环境**（类似 sandbox）
- **统一的上下文管理**（Session + Memory）
- **安全的工具执行**（Hooks + Approval）

---

## 二、系统架构全景

### 2.1 六层架构模型

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              Clawdbot 系统架构                                    │
└─────────────────────────────────────────────────────────────────────────────────┘

  ╔═══════════════════════════════════════════════════════════════════════════════╗
  ║                          1. ENTRY LAYER (入口层)                               ║
  ╠═══════════════════════════════════════════════════════════════════════════════╣
  ║   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  ║
  ║   │   CLI Tool   │  │  TUI (终端)   │  │  Control UI  │  │  Mobile Apps    │  ║
  ║   │  (Commander) │  │  (Pi-TUI)    │  │   (Web)      │  │  (iOS/Android)  │  ║
  ║   └──────────────┘  └──────────────┘  └──────────────┘  └──────────────────┘  ║
  ╚═══════════════════════════════════════════════════════════════════════════════╝
                                        │
                                        ▼
  ╔═══════════════════════════════════════════════════════════════════════════════╗
  ║                       2. GATEWAY LAYER (网关层) - "门卫"                        ║
  ╠═══════════════════════════════════════════════════════════════════════════════╣
  ║   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐       ║
  ║   │  WebSocket   │  │  HTTP API    │  │  Node Mgmt   │  │  Cron Jobs  │       ║
  ║   │  Handlers    │  │  (Hono)      │  │  Registry    │  │  Service    │       ║
  ║   └──────────────┘  └──────────────┘  └──────────────┘  └─────────────┘       ║
  ╚═══════════════════════════════════════════════════════════════════════════════╝
          │                            │                            │
          ▼                            ▼                            ▼
  ┌──────────────────┐      ┌──────────────────┐      ┌──────────────────┐
  │  3. CHANNELS     │      │   4. AGENTS      │      │   5. PLUGINS     │
  │     LAYER        │      │      LAYER       │      │      LAYER       │
  │                  │      │                  │      │                  │
  │  消息平台适配     │      │  AI 处理核心     │      │  扩展机制        │
  │  30+ 平台支持    │      │  Session/Memory  │      │  动态加载        │
  │  MsgContext      │      │  Tools 执行      │      │                  │
  └──────────────────┘      └──────────────────┘      └──────────────────┘
          │                            │                            │
          └────────────────────────────┼────────────────────────────┘
                                       ▼
  ╔═══════════════════════════════════════════════════════════════════════════════╗
  ║                    6. INFRASTRUCTURE LAYER (基础设施层)                         ║
  ╠═══════════════════════════════════════════════════════════════════════════════╣
  ║   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      ║
  ║   │   Config     │  │    Media     │  │   Memory     │  │  Sessions    │      ║
  ║   │   Manager    │  │  Processing  │  │    Store     │  │   Manager    │      ║
  ║   ├──────────────┤  ├──────────────┤  ├──────────────┤  ├──────────────┤      ║
  ║   │   Logging    │  │   Security   │  │    Hooks     │  │  Binaries    │      ║
  ║   │   (tslog)    │  │   Sandbox    │  │    System    │  │   Manager    │      ║
  ║   └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘      ║
  ║                                                                               ║
  ║   设计原则: Servant Pattern (单向依赖，从不调用上层)                            ║
  ╚═══════════════════════════════════════════════════════════════════════════════╝
                                       │
                                       ▼
  ╔═══════════════════════════════════════════════════════════════════════════════╗
  ║                       EXTERNAL SERVICES (外部服务)                             ║
  ╠═══════════════════════════════════════════════════════════════════════════════╣
  ║   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      ║
  ║   │  Anthropic   │  │   OpenAI     │  │   Google     │  │  Groq /      │      ║
  ║   │   Claude     │  │   GPT        │  │   Gemini     │  │  Deepgram    │      ║
  ║   └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘      ║
  ╚═══════════════════════════════════════════════════════════════════════════════╝
```

### 2.2 端到端消息流

```
用户在 Telegram 发送: "帮我查一下明天的天气"
                │
                ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│ 1. CHANNEL LAYER: Telegram 适配器                                                │
│    - 接收 Telegram 原始消息                                                      │
│    - 转换为统一的 MsgContext 格式                                                │
│    - 提取: From, To, Body, SenderName, ChatType...                              │
└─────────────────────────────────────────────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│ 2. GATEWAY LAYER: 路由和调度                                                     │
│    - 确定由哪个 Agent 处理这条消息                                               │
│    - 生成 SessionKey 用于会话持久化                                              │
│    - WebSocket 转发给 Agent                                                     │
└─────────────────────────────────────────────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│ 3. AGENT LAYER: AI 处理                                                         │
│    a. 加载 Session (短期记忆): 之前的对话上下文                                   │
│    b. 检索 Memory (长期记忆): 用户偏好、相关知识                                  │
│    c. 构建 System Prompt + 用户消息 + 历史                                       │
│    d. 调用 LLM (Claude/GPT/...)                                                 │
│    e. LLM 返回: 需要调用天气工具                                                 │
│    f. 执行 Tool: 调用天气 API                                                   │
│    g. 工具结果返回给 LLM                                                        │
│    h. LLM 生成最终回复                                                          │
└─────────────────────────────────────────────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│ 4. CHANNEL LAYER: 发送回复                                                       │
│    - 格式化回复内容                                                              │
│    - 通过 Telegram API 发送给用户                                                │
└─────────────────────────────────────────────────────────────────────────────────┘
                │
                ▼
用户收到回复: "北京明天天气晴朗，气温 15-22°C"
```

---

## 三、Channel Layer 详解

### 3.1 核心问题

每个消息平台的"语言"都不一样：
- Telegram 用 Bot API
- Discord 用 Gateway API
- WhatsApp 用 Baileys 协议
- Slack 用 Bolt 框架

**挑战**：
- 消息格式不同（Markdown、富文本、纯文本）
- 认证方式不同（Token、QR 码）
- 功能不同（"正在输入"提示、投票、反应）

### 3.2 解决方案：适配器模式 + 统一接口

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│    Telegram     │     │    Discord      │     │    WhatsApp     │
│   (原始格式)     │     │   (原始格式)     │     │   (原始格式)     │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Telegram 适配器 │     │  Discord 适配器  │     │  WhatsApp 适配器 │
│  (Grammy)       │     │  (Carbon)       │     │  (Baileys)      │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │   统一的 MsgContext     │
                    │   (系统内部只看这个)      │
                    └─────────────────────────┘
```

### 3.3 MsgContext 完整字段

#### 3.3.1 路由信息（消息从哪来，往哪去）

| 字段 | 类型 | 含义 | 示例 |
|------|------|------|------|
| `From` | string | 发送者 ID | `"123456789"` |
| `To` | string | 目标 ID | `"chat_987654"` |
| `Provider` | string | 来源平台 | `"telegram"`, `"discord"` |
| `Surface` | string | 平台表面标签（优先于 Provider） | `"telegram"` |
| `SessionKey` | string | 会话标识（用于存储） | `"telegram:123456789"` |
| `ParentSessionKey` | string | 父会话标识（用于线程） | |
| `ChatType` | string | 聊天类型（标准化） | `"dm"`, `"group"`, `"channel"` |
| `AccountId` | string | 账号 ID（多账号支持） | |

#### 3.3.2 消息内容

| 字段 | 类型 | 含义 | 用途 |
|------|------|------|------|
| `Body` | string | 原始消息文本（带结构上下文） | 日志、调试 |
| `BodyForAgent` | string | 清洗后的文本 | 发给 AI |
| `BodyForCommands` | string | 命令解析用的文本 | 检测 `/start` 等 |
| `CommandBody` | string | 原始文本（无结构上下文） | 命令检测 |
| `RawBody` | string | 最原始的文本 | 备用 |

#### 3.3.3 发送者信息

| 字段 | 类型 | 含义 | 示例 |
|------|------|------|------|
| `SenderName` | string | 显示名称 | `"张三"` |
| `SenderUsername` | string | 用户名 | `"@zhangsan"` |
| `SenderId` | string | 平台 ID | `"user_123"` |
| `SenderTag` | string | 提及格式 | `"@zhangsan"` |
| `SenderE164` | string | 电话号码（E.164 格式） | `"+8613812345678"` |

#### 3.3.4 群组/上下文信息

| 字段 | 类型 | 含义 | 示例 |
|------|------|------|------|
| `GroupSubject` | string | 群名称 | `"工作群"` |
| `GroupChannel` | string | 频道名 | `"#general"` |
| `GroupSpace` | string | 工作区/团队名 | `"Acme Corp"` |
| `GroupMembers` | string[] | 群成员列表 | |
| `GroupSystemPrompt` | string | 群专属系统提示 | |
| `MessageThreadId` | string | 话题/线程 ID | `"topic_456"` |
| `IsForum` | boolean | 是否为 Telegram 论坛群 | |
| `ConversationLabel` | string | 人类可读的对话标签 | |

#### 3.3.5 媒体附件

| 字段 | 类型 | 含义 |
|------|------|------|
| `MediaUrl` | string | 单个媒体 URL |
| `MediaUrls` | string[] | 多个媒体 URL |
| `MediaPath` | string | 本地媒体路径 |
| `MediaPaths` | string[] | 多个本地路径 |
| `MediaTypes` | string[] | 媒体类型 (image/jpeg, audio/mp3) |
| `MediaDir` | string | 媒体目录 |
| `Transcript` | string | 语音转文字结果 |
| `MediaUnderstanding` | object[] | 媒体分析结果 |
| `LinkUnderstanding` | object[] | 链接提取结果 |

#### 3.3.6 回复链（如果是回复某条消息）

| 字段 | 类型 | 含义 |
|------|------|------|
| `ReplyToId` | string | 被回复消息的 ID（短） |
| `ReplyToIdFull` | string | 被回复消息的完整 ID |
| `ReplyToBody` | string | 被回复消息的内容 |
| `ReplyToSender` | string | 被回复消息的发送者 |
| `ThreadStarterBody` | string | 线程起始消息内容 |
| `ThreadLabel` | string | 线程标签 |

#### 3.3.7 转发消息信息

| 字段 | 类型 | 含义 |
|------|------|------|
| `ForwardedFrom` | string | 原发送者名称 |
| `ForwardedFromType` | string | 原来源类型 |
| `ForwardedFromId` | string | 原发送者 ID |
| `ForwardedFromUsername` | string | 原发送者用户名 |
| `ForwardedFromTitle` | string | 原频道/群标题 |
| `ForwardedFromSignature` | string | 原签名 |
| `ForwardedDate` | number | 原消息时间戳 |

#### 3.3.8 授权和元数据

| 字段 | 类型 | 含义 |
|------|------|------|
| `WasMentioned` | boolean | 机器人是否被 @ |
| `CommandAuthorized` | boolean | 命令是否已授权 |
| `CommandSource` | string | 命令来源 ("text" 或 "native") |
| `Timestamp` | number | 消息时间戳 |
| `MaxChars` | number | 回复字符限制 |

### 3.4 具体转换示例：Telegram

**原始 Telegram 数据（平台特有格式）：**
```javascript
{
  message_id: 12345,
  chat: {
    id: -100123456,
    type: "supergroup",
    title: "工作群",
    is_forum: true
  },
  from: {
    id: 789,
    first_name: "张三",
    username: "zhangsan"
  },
  text: "帮我查一下明天的天气",
  message_thread_id: 42,
  reply_to_message: {
    message_id: 12340,
    text: "好的",
    from: { first_name: "李四" }
  }
}
```

**转换后的 MsgContext（统一格式）：**
```javascript
{
  // 路由
  From: "789",
  To: "-100123456:42",           // 包含话题 ID
  Provider: "telegram",
  SessionKey: "telegram:-100123456:42",
  ChatType: "group",

  // 内容
  Body: "帮我查一下明天的天气",
  BodyForAgent: "帮我查一下明天的天气",
  BodyForCommands: "帮我查一下明天的天气",

  // 发送者
  SenderName: "张三",
  SenderUsername: "zhangsan",
  SenderId: "789",

  // 群组
  GroupSubject: "工作群",
  MessageThreadId: "42",
  IsForum: true,

  // 回复
  ReplyToId: "12340",
  ReplyToBody: "好的",
  ReplyToSender: "李四",

  // 元数据
  Timestamp: 1706284800,
  CommandAuthorized: false       // 默认 false
}
```

### 3.5 Channel 插件接口

每个 Channel 插件实现以下接口：

```typescript
type ChannelPlugin<ResolvedAccount> = {
  // 必需
  id: ChannelId;                    // "telegram", "discord", "slack"
  meta: ChannelMeta;                // UI 元数据
  capabilities: ChannelCapabilities; // 功能声明 ["dm", "group", "poll", "reaction"]
  config: ChannelConfigAdapter;     // 账号管理

  // 可选 - 消息流
  outbound?: ChannelOutboundAdapter;   // 发送消息
  gateway?: ChannelGatewayAdapter;     // 连接管理
  status?: ChannelStatusAdapter;       // 状态探测
  auth?: ChannelAuthAdapter;           // 登录流程

  // 可选 - 安全和访问
  security?: ChannelSecurityAdapter;   // DM 策略
  elevated?: ChannelElevatedAdapter;   // 管理员列表

  // 可选 - 功能
  mentions?: ChannelMentionsAdapter;   // @ 提及处理
  threading?: ChannelThreadingAdapter; // 回复模式
  actions?: ChannelActionsAdapter;     // 反应、按钮、编辑
  commands?: ChannelCommandsAdapter;   // 原生命令支持
  streaming?: ChannelStreamingAdapter; // 流式配置

  // 可选 - 发现
  directory?: ChannelDirectoryAdapter; // 列出群组/成员
  resolver?: ChannelResolverAdapter;   // 解析 handle 到 ID

  // 可选 - UI 和引导
  onboarding?: ChannelOnboardingAdapter; // CLI 设置向导
  agentPrompt?: ChannelAgentPromptAdapter; // 专属提示
}
```

### 3.6 支持的消息平台

**核心平台（内置）：**
- WhatsApp (Baileys)
- Telegram (Grammy)
- Discord (Carbon)
- Slack (Bolt)
- Signal (signal-cli)
- iMessage (imsg)
- Google Chat
- LINE
- Web Chat

**扩展平台（通过插件）：**
- BlueBubbles
- Microsoft Teams
- Matrix
- Zalo / Zalo Personal
- Mattermost
- Nostr
- Voice Call
- 等 20+ 更多...

---

## 四、Gateway Server 详解

### 4.1 Gateway 的角色

Gateway 是系统的"门卫"和"协调者"，类似于公寓楼的门卫：
- 接收所有外部消息
- 验证身份和权限
- 路由到正确的 Agent
- 管理设备连接

### 4.2 四大核心组件

| 组件 | 职责 | 对应场景 |
|------|------|---------|
| **WebSocket Handlers** | 处理实时消息收发 | 用户发消息、收回复 |
| **HTTP API (Hono)** | 提供 REST 接口 | 健康检查、状态查询、Webhook |
| **Node Mgmt Registry** | 管理设备清单、连接状态 | 多设备连接、断线重连 |
| **Cron Jobs Service** | 处理定时任务 | "每天早上8点提醒我喝水" |

### 4.3 Gateway 组件职责详解

**WebSocket Handlers**:
```
场景: 用户在 Telegram 上发消息
      同时在 Discord 上也发了一条

WebSocket Handlers 确保:
  - 每条消息独立处理
  - 不会混淆消息来源
  - 支持并发处理
```

**HTTP API**:
```
提供的端点:
  GET  /health          -> 健康检查
  GET  /api/status      -> 系统状态
  POST /api/webhook/:id -> 接收外部 Webhook
  GET  /api/channels    -> 通道列表
```

**Node Mgmt Registry**:
```
场景: 你的 iPhone 和 MacBook 都想连接

Registry 维护:
  - 设备列表: [{id: "iphone", status: "online"}, {id: "macbook", status: "online"}]
  - 权限控制: 哪些设备可以连接
  - 状态追踪: 上次心跳时间、断线检测
```

**Cron Jobs Service**:
```
场景: 用户说"每天早上8点提醒我喝水"

Cron Service:
  - 存储定时任务: {cron: "0 8 * * *", action: "remind_water"}
  - 到时间自动触发
  - 即使没有用户消息也能执行
```

---

## 五、Agent Layer 详解

### 5.1 Agent 的核心挑战

AI 模型（如 Claude）是"无状态"的 -- 每次调用都是独立的，不记得之前的对话。

**解决方案**: Session（短期记忆）+ Memory（长期记忆）

### 5.2 Session vs Memory 详解

| 方面 | Session (短期记忆) | Memory (长期记忆) |
|------|-------------------|------------------|
| **存什么** | 当前对话的上下文 | 用户偏好、知识、事实 |
| **生命周期** | 对话期间 | 持久存储 |
| **存储位置** | `~/.clawdbot/agents/<id>/sessions/` | `~/.clawdbot/agents/<id>/memory/` |
| **存储格式** | JSONL 文件 | 向量数据库 (sqlite-vec) |
| **检索方式** | 按时间顺序 | 语义相似度搜索 |
| **典型例子** | "刚才说的会议室" | "用户喜欢简洁回复" |

### 5.3 Session 管理策略

当对话变长时，需要处理上下文窗口限制：

```
完整对话历史 (可能有 100+ 轮)
     │
     ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Session 管理策略                              │
│                                                                 │
│  策略 A: 滑动窗口                                                │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ 只保留最近 N 条消息                                          ││
│  │ [msg_98] [msg_99] [msg_100] <- 保留                          ││
│  │ [msg_1] ... [msg_97] <- 丢弃                                 ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  策略 B: 压缩/摘要 (Compaction)                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ 旧对话: "用户问了天气、订了会议室、讨论了项目进度..."           ││
│  │          ↓ 压缩成摘要                                        ││
│  │ 摘要: "之前讨论了天气查询和会议室预订"                         ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  策略 C: 相关性检索 (结合 Memory)                                │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ 当前问题: "订会议室"                                         ││
│  │ 从 Memory 检索: "用户偏好 3 楼大会议室"                       ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
     │
     ▼
最终发送给 AI:
  [摘要] 之前讨论了天气查询...
  [检索] 用户偏好: 3楼大会议室
  [最近] 用户: "帮我订会议室"
  [最近] AI: "好的，请问几点？"
  [当前] 用户: "下午3点"
```

### 5.4 工具系统详解

#### 5.4.1 AI 与工具的交互流程

```
用户: "帮我查明天北京的天气"
         │
         ▼
┌─────────────────┐
│  1. AI 分析意图   │   AI 看到消息 + 可用工具列表
│                 │   可用工具: [weather, calendar, email, bash...]
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  2. AI 输出工具   │   AI 不是直接执行，而是输出"我想调用这个工具"
│     调用请求     │
│                 │   输出: {
│                 │     tool: "weather",
│                 │     args: { city: "北京", date: "tomorrow" }
│                 │   }
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  3. 系统拦截     │   Agent Runtime 解析 AI 的输出
│     解析请求     │   识别出这是一个工具调用
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  4. 安全检查     │   Hooks System 检查:
│   (PreToolUse)   │   - 这个工具是否允许？
│                 │   - 参数是否安全？
│                 │   - 是否需要人工确认？
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  5. 执行工具     │   实际调用天气 API
│                 │   result = weatherAPI.query("北京", "tomorrow")
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  6. 后处理      │   Hooks System (PostToolUse):
│  (PostToolUse)   │   - 记录执行日志
│                 │   - 处理错误
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  7. 返回结果     │   结果发回给 AI:
│    给 AI        │   { result: "北京明天晴，15-22°C" }
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  8. AI 继续处理  │   AI 可能：
│                 │   a) 调用更多工具 -> 回到步骤 2
│                 │   b) 生成最终回复 -> 结束
└────────┬────────┘
         │
         ▼
AI 回复: "北京明天天气晴朗，气温 15-22°C，适合户外活动。"
```

#### 5.4.2 三种工具类型详解

**为什么不能只用 Bash？**

| 限制 | 说明 | 解决方案 |
|------|------|---------|
| **认证复杂** | OAuth token 管理、刷新、存储 | MCP Tools 封装认证逻辑 |
| **格式不统一** | 每个 API 返回格式不同 | MCP Tools 提供标准化接口 |
| **安全风险** | `rm -rf /` 等危险命令 | 需要审批和沙箱 |
| **复杂任务** | 多步骤流程难以用单命令表达 | Skills 打包工作流 |

**工具类型对比**:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           工具类型对比                                       │
├─────────────────┬─────────────────┬─────────────────┬─────────────────────┤
│                 │     Bash        │   MCP Tools     │      Skills         │
├─────────────────┼─────────────────┼─────────────────┼─────────────────────┤
│ 抽象级别        │ 低 (原始命令)    │ 中 (标准化接口)  │ 高 (复杂工作流)      │
├─────────────────┼─────────────────┼─────────────────┼─────────────────────┤
│ 典型用途        │ ls, git, curl   │ 日历、邮件、    │ /commit, /review    │
│                 │ 文件操作        │ Slack、数据库   │ /pdf, /pptx         │
├─────────────────┼─────────────────┼─────────────────┼─────────────────────┤
│ 认证处理        │ 手动            │ 自动管理        │ 自动管理            │
├─────────────────┼─────────────────┼─────────────────┼─────────────────────┤
│ 安全控制        │ 严格审批        │ 按工具配置      │ 按技能配置          │
├─────────────────┼─────────────────┼─────────────────┼─────────────────────┤
│ 错误处理        │ 手动解析        │ 结构化错误      │ 内置重试            │
├─────────────────┼─────────────────┼─────────────────┼─────────────────────┤
│ 比喻            │ 给员工终端      │ 给员工公司系统   │ 给员工操作手册      │
│                 │ (灵活但危险)    │ (标准化+权限)   │ (打包好的流程)      │
└─────────────────┴─────────────────┴─────────────────┴─────────────────────┘
```

---

## 六、Infrastructure Layer 详解

### 6.1 Servant Pattern（仆人模式）

Infrastructure Layer 的核心设计原则：

```
┌─────────────────────────────────────────────────────────────────┐
│                      依赖方向（单向）                         │
│                                                             │
│   Gateway ──────► 可以调用 Infrastructure                    │
│   Agent   ──────► 可以调用 Infrastructure                    │
│   Channel ──────► 可以调用 Infrastructure                    │
│                                                             │
│   Infrastructure ──✗──► 永远不调用上层                       │
│                                                             │
│   好处:                                                      │
│   - 避免循环依赖                                             │
│   - 代码更清晰                                               │
│   - 组件可独立测试                                           │
│   - 可轻松替换实现                                           │
└─────────────────────────────────────────────────────────────────┘
```

### 6.2 八大组件详解

| 组件 | 职责 | 典型场景 | 代码位置 |
|------|------|---------|---------|
| **Config Manager** | 读取/管理配置文件 | 启动时加载 `config.yaml` | `src/config/` |
| **Media Processing** | 图片/音频/视频处理 | 压缩图片、转码视频、语音转文字 | `src/media/` |
| **Memory Store** | AI 的长期记忆（向量存储） | 记住用户偏好、检索相关知识 | `src/memory/` |
| **Sessions Manager** | 管理对话会话状态 | 保持对话连续性、会话隔离 | `src/channels/session.ts` |
| **Logging** | 系统日志记录 | 调试、监控、问题排查 | `src/infra/logger/` |
| **Security Sandbox** | 安全隔离执行环境 | 限制 Bash 命令的执行范围 | `src/infra/security/` |
| **Hooks System** | 事件拦截和处理 | 工具执行前检查、自定义行为 | `src/infra/hooks/` |
| **Binaries Manager** | 管理外部二进制依赖 | 下载/更新 ffmpeg、signal-cli | `src/infra/binaries/` |

### 6.3 Hooks System 详解

#### 6.3.1 Hook 事件类型

| Hook 事件 | 触发时机 | 典型用途 |
|-----------|---------|---------|
| `PreToolUse` | 工具执行**前** | 安全检查、参数验证、审批 |
| `PostToolUse` | 工具执行**后** | 日志记录、结果处理、通知 |
| `UserPromptSubmit` | 用户消息提交时 | 预处理、翻译、过滤 |
| `Stop` | Agent 停止时 | 清理资源、发送通知 |
| `SubagentStop` | 子 Agent 停止时 | 子任务完成处理 |
| `SessionStart` | 会话开始时 | 初始化、加载上下文 |
| `SessionEnd` | 会话结束时 | 保存状态、清理 |
| `PreCompact` | 会话压缩前 | 自定义压缩逻辑 |
| `Notification` | 通知发送时 | 自定义通知处理 |

#### 6.3.2 Hook 使用示例

**场景: 检查 Bash 命令安全性**

```yaml
# 配置文件中定义 Hook
hooks:
  PreToolUse:
    - name: "安全检查"
      match:
        tool: "bash"
      action:
        type: "prompt"
        prompt: |
          检查以下命令是否安全:
          {{command}}

          如果包含 rm -rf、sudo 等危险操作，返回 BLOCK
```

**场景: 用户消息自动翻译**

```yaml
hooks:
  UserPromptSubmit:
    - name: "翻译为英文"
      action:
        type: "prompt"
        prompt: |
          将以下消息翻译为英文:
          {{message}}
```

### 6.4 安全机制总结

Clawdbot 采用多层防护策略：

| 策略 | 实现 | 说明 |
|------|------|------|
| **执行前审查** | Hooks System (PreToolUse) | 拦截、检查、可阻止执行 |
| **隔离区域** | Security Sandbox | 限制执行环境范围 |
| **权限控制** | 非 root 运行 | 降低破坏能力 |
| **人工确认** | Approval Manager | 危险操作需要人类批准 |
| **白名单** | 配置允许的命令 | 只允许预定义的操作 |

---

## 七、部署模式详解

### 7.1 Local vs Remote 模式

#### 7.1.1 核心概念

`gateway.mode` 决定了这台机器是**运行 Gateway**还是**连接到远程 Gateway**。

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      Local 模式 vs Remote 模式                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   【Local 模式】                    【Remote 模式】                       │
│                                                                         │
│   ┌─────────────┐                  ┌─────────────┐                      │
│   │  这台机器    │                  │  这台机器    │                      │
│   │  运行 Gateway │                  │  只是客户端  │                      │
│   │  (服务端)    │                  │             │                      │
│   └──────┬──────┘                  └──────┬──────┘                      │
│          │                                │                             │
│          ▼                                ▼                             │
│   ┌─────────────┐                  ┌─────────────┐                      │
│   │ 本地存储状态 │                  │ 连接远程     │                      │
│   │ ~/.clawdbot │                  │ Gateway     │                      │
│   └─────────────┘                  └─────────────┘                      │
│                                           │                             │
│                                           ▼                             │
│                                    ┌─────────────┐                      │
│                                    │ 远程服务器   │                      │
│                                    │ 运行 Gateway │                      │
│                                    └─────────────┘                      │
└─────────────────────────────────────────────────────────────────────────┘
```

#### 7.1.2 详细对比

| 方面 | Local 模式 | Remote 模式 |
|------|-----------|-------------|
| **Gateway 服务** | 在本机运行 | 在远程机器运行 |
| **数据存储** | 本地 `~/.clawdbot/` | 远程服务器上 |
| **启动命令** | `clawdbot gateway` 可启动 | 启动被禁用 |
| **认证** | `gateway.auth.token` | `gateway.remote.token` |
| **网络** | 监听本地端口 | 通过 URL 连接 |
| **典型场景** | 笔记本/台式机/服务器 | 手机 App/远程控制 |

### 7.2 网络绑定模式

| 绑定模式 | 监听地址 | 说明 | 安全性 |
|---------|---------|------|--------|
| **`loopback`** (默认) | `127.0.0.1` | 只有本机可访问 | 最安全 |
| **`lan`** | `0.0.0.0` | 局域网可访问 | 需要认证 |
| **`tailnet`** | Tailscale IP | Tailscale 网络可访问 | 需要认证 |
| **`auto`** | 自动选择 | 先尝试 loopback | 取决于结果 |
| **`custom`** | 自定义 IP | 用户指定 | 取决于配置 |

### 7.3 Tailscale 集成详解

#### 7.3.1 什么是 Tailscale？

Tailscale 是零配置的 VPN 工具，让设备组成私有网络（Tailnet）：

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Tailscale 网络 (Tailnet)                      │
│                                                                      │
│   ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐     │
│   │ 家里电脑  │    │ 公司电脑  │    │   手机    │    │ 云服务器  │     │
│   │ 100.x.x.1│    │ 100.x.x.2│    │ 100.x.x.3│    │ 100.x.x.4│     │
│   └──────────┘    └──────────┘    └──────────┘    └──────────┘     │
│        ↑               ↑               ↑               ↑            │
│        └───────────────┴───────────────┴───────────────┘            │
│                    彼此可以直接通信（端到端加密）                       │
└─────────────────────────────────────────────────────────────────────┘
```

#### 7.3.2 三种 Tailscale 模式

| 模式 | 作用 | 访问范围 | 安全要求 |
|------|------|---------|---------|
| **`off`** (默认) | 不使用 Tailscale | 仅本机 | 无 |
| **`serve`** | Tailscale 提供 HTTPS | **仅 Tailnet 内部** | 可选认证 |
| **`funnel`** | Tailscale 提供公网 HTTPS | **整个互联网** | **必须认证** |

#### 7.3.3 Serve 模式详解

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Tailscale Tailnet                            │
│                                                                      │
│   ┌─────────────────────┐         ┌─────────────────────┐           │
│   │   家庭服务器          │         │     你的手机         │           │
│   │ ┌─────────────────┐ │         │  ┌───────────────┐  │           │
│   │ │ Gateway         │ │  HTTPS  │  │   Clawdbot    │  │           │
│   │ │ (127.0.0.1)     │◄┼─────────┼──│     App       │  │           │
│   │ └────────┬────────┘ │         │  └───────────────┘  │           │
│   │          │          │         └─────────────────────┘           │
│   │          ▼          │                                            │
│   │ ┌─────────────────┐ │                                            │
│   │ │ Tailscale Serve │ │  ⚠️ 只有 Tailnet 内的设备可以访问           │
│   │ │ (代理 HTTPS)    │ │                                            │
│   │ └─────────────────┘ │                                            │
│   └─────────────────────┘                                            │
│                                                                      │
│   访问地址: https://server.tailnet-name.ts.net                       │
└─────────────────────────────────────────────────────────────────────┘
```

**配置示例:**
```json
{
  "gateway": {
    "mode": "local",
    "bind": "loopback",
    "tailscale": {
      "mode": "serve",
      "resetOnExit": false
    },
    "auth": {
      "mode": "token",
      "allowTailscale": true
    }
  }
}
```

#### 7.3.4 Funnel 模式详解

```
┌─────────────────────────────────────────────────────────────────────┐
│                              互联网                                  │
│                                                                      │
│          任何人都可以访问（需要密码认证）                              │
│                         │                                            │
│                         ▼                                            │
│              ┌─────────────────────┐                                │
│              │  Tailscale Funnel   │                                │
│              │  (公网 HTTPS 入口)   │                                │
│              └──────────┬──────────┘                                │
│                         │                                            │
│   ┌─────────────────────▼───────────────────────┐                   │
│   │              你的服务器                       │                   │
│   │   ┌─────────────────────────────────────┐   │                   │
│   │   │  Gateway (127.0.0.1) + Tailscale    │   │                   │
│   │   └─────────────────────────────────────┘   │                   │
│   └─────────────────────────────────────────────┘                   │
│                                                                      │
│   ⚠️ 必须配置密码认证！                                               │
└─────────────────────────────────────────────────────────────────────┘
```

**配置示例:**
```json
{
  "gateway": {
    "mode": "local",
    "bind": "loopback",
    "tailscale": { "mode": "funnel" },
    "auth": {
      "mode": "password",
      "password": "your-secure-password"
    }
  }
}
```

### 7.4 典型部署场景

#### 场景 1: 单机使用（笔记本电脑）

```json
{
  "gateway": {
    "mode": "local",
    "bind": "loopback"
  }
}
```

#### 场景 2: 家庭服务器 + 手机控制

**服务器配置:**
```json
{
  "gateway": {
    "mode": "local",
    "bind": "loopback",
    "tailscale": { "mode": "serve" }
  }
}
```

**手机配置:**
```json
{
  "gateway": {
    "mode": "remote",
    "remote": {
      "url": "https://server.tailnet-name.ts.net"
    }
  }
}
```

#### 场景 3: 云服务器 VPS

```json
{
  "gateway": {
    "mode": "local",
    "bind": "lan",
    "port": 18789,
    "auth": {
      "mode": "token",
      "token": "secure-token-here"
    }
  }
}
```

---

## 八、后续学习计划

### 阶段 1: 深入 Plugin System
- [ ] 理解插件的目录结构 (`extensions/`)
- [ ] 学习如何创建一个 Channel 插件
- [ ] 学习如何创建一个 MCP Tool
- [ ] 学习 Hooks 的实际配置

### 阶段 2: 动手实践
- [ ] 配置一个完整的 Clawdbot 实例
- [ ] 接入一个消息平台 (如 Telegram)
- [ ] 编写一个简单的自定义 Hook
- [ ] 测试 Local 和 Tailscale Serve 模式

### 阶段 3: 高级主题
- [x] Agent 的 System Prompt 构建机制 → 见 [第十五章](#十五system-prompt-构建机制详解)
- [ ] Model Selection 和 Failover 策略
- [x] Subagent 系统（多 Agent 协作）→ 见 [第十六章](#十六subagent-系统详解)
- [ ] 性能优化和监控

### 阶段 4: 源码深入
- [ ] 阅读 Telegram Channel 的完整实现
- [ ] 阅读 Gateway WebSocket 处理逻辑
- [x] 阅读 Session 压缩和 Memory 检索逻辑 → 见 [第十二章](#十二session-压缩机制详解) 和 [第十三章](#十三memory-检索机制详解)
- [ ] 理解 Tool 执行的完整流程

### 阶段 5: 路由与安全
- [ ] Approval 审批流程：socket 通信机制
- [ ] 实际配置练习：写一个多 Agent 路由配置
- [ ] Channel 层安全：深入 allowlist 和 groupPolicy

### 阶段 6: Sandbox 与隔离 (新增)
- [x] Sandbox 三层防护架构 → 见 [第十七章](#十七sandbox-与文件系统隔离详解)
- [ ] Docker Sandbox 实践：配置一个带 Sandbox 的 Agent
- [ ] 路径逃逸防护：深入 symlink 检测实现
- [ ] Sandbox Provider 抽象：探索 E2B 集成可行性

---

## 九、SessionKey 深入解析

### 9.1 SessionKey 格式

```
agent:<agentId>:<channel>:<peerKind>:<peerId>
```

### 9.2 三种 DM 隔离策略 (dmScope)

| dmScope | 效果 | SessionKey 示例 |
|---------|------|-----------------|
| `"main"` (默认) | 所有私聊共享一个会话 | `agent:main:main` |
| `"per-peer"` | 每个人独立会话 | `agent:main:dm:123456789` |
| `"per-channel-peer"` | 每个渠道每个人独立 | `agent:main:telegram:dm:123456789` |

### 9.3 跨渠道身份映射 (identityLinks)

配置同一个人在不同平台共享会话：
```json
{
  "session": {
    "dmScope": "per-peer",
    "identityLinks": {
      "alice": ["telegram:111111111", "discord:222222222"]
    }
  }
}
```

### 9.4 关键代码位置
- `src/routing/session-key.ts` - SessionKey 构建
- `src/routing/resolve-route.ts` - 路由决策

---

## 十、路由绑定优先级

### 10.1 优先级金字塔（从高到低）

| 优先级 | 类型 | matchedBy | 典型用途 |
|--------|------|-----------|---------|
| 1 | `peer` | `binding.peer` | VIP 群/用户专属 Agent |
| 2 | `guild` | `binding.guild` | Discord 服务器级别 |
| 3 | `team` | `binding.team` | Slack 工作区级别 |
| 4 | `account` | `binding.account` | 多 bot 账号区分 |
| 5 | `channel` | `binding.channel` | 平台默认 (accountId="*") |
| 6 | `default` | `default` | 全局兜底 |

### 10.2 设计原则：精确优先于模糊

代码使用两个机制实现优先级：
1. **执行顺序**: if 语句从 peer → guild → team → account → channel
2. **排除条件**: `!b.match?.peer` 等，防止降级匹配

### 10.3 排除条件的作用

```typescript
const accountMatch = bindings.find(
  (b) =>
    b.match?.accountId?.trim() !== "*" &&
    !b.match?.peer &&      // 排除带 peer 条件的绑定
    !b.match?.guildId &&   // 排除带 guild 条件的绑定
    !b.match?.teamId,      // 排除带 team 条件的绑定
);
```

**目的**: 确保带有高优先级条件的 binding 不会在低优先级阶段被错误匹配。

---

## 十一、安全检查链详解

### 11.1 多层安全检查（从前到后）

```
消息入站
    ↓
┌─────────────────────────────┐
│ 第 1 层: Channel 层          │
│ - allowlist 检查             │
│ - groupPolicy 检查           │
│ - requireMention 检查        │
└─────────────────────────────┘
    ↓
┌─────────────────────────────┐
│ 第 2 层: Gateway 层          │
│ - 无安全检查，只做路由        │
└─────────────────────────────┘
    ↓
┌─────────────────────────────┐
│ 第 3 层: Agent 层            │
│ - AI 决定调用工具             │
└─────────────────────────────┘
    ↓
┌─────────────────────────────┐
│ 第 4 层: Plugin Hooks        │
│ - before_tool_call          │
└─────────────────────────────┘
    ↓
┌─────────────────────────────┐
│ 第 5 层: Bash 执行安全        │
│ - 命令分析                   │
│ - AllowList 检查             │
│ - Safe Bins 检查             │
│ - 用户审批                   │
└─────────────────────────────┘
```

### 11.2 白名单策略（非黑名单）

Clawdbot 不维护危险命令黑名单，而是采用白名单策略：

**默认 Safe Bins**:
```typescript
["jq", "grep", "cut", "sort", "uniq", "head", "tail", "tr", "wc"]
```

**三种安全级别** (`security`):
| 级别 | 行为 |
|------|------|
| `"deny"` | 完全禁止 bash |
| `"allowlist"` (默认) | 只允许白名单命令 |
| `"full"` | 允许所有命令（危险！）|

### 11.3 管道 vs && 的安全区别

| 特性 | 管道 `\|` | 链接 `&&` `\|\|` `;` |
|------|----------|---------------------|
| 数据关系 | 有（stdout→stdin） | 无 |
| 第二个命令能力 | 只能处理第一个输出 | 可以做任何事 |
| Clawdbot 处理 | ✅ 允许，分段检查 | ❌ 直接拒绝 |

**代码位置**: `src/infra/exec-approvals.ts`

禁止的 token:
```typescript
const DISALLOWED_PIPELINE_TOKENS = new Set([">", "<", "`", "\n", "\r", "(", ")"]);
// 另外拒绝: &&, ||, ;, $()
```

**为什么管道安全**:
- 每个管道段独立检查白名单
- `echo "hello" | rm` → rm 只能从 stdin 读取，无法执行 `rm -rf /`

**为什么 && 危险**:
- `echo "hello" && rm -rf /` → rm 完全独立执行

---

## 十二、Session 压缩机制详解

### 12.1 为什么需要压缩

AI 模型是无状态的，每次调用需要传入完整上下文。当对话变长时：
- 100 轮对话 × 500 tokens/轮 = 50,000 tokens
- 需要在有限的上下文窗口内保持连贯性

### 12.2 压缩策略对比

| 策略 | 优点 | 缺点 |
|------|------|------|
| **滚动摘要** | 实现简单 | 信息丢失累积（复印件的复印件） |
| **分段摘要+合并** | 每条消息只被压缩 2 次 | 实现复杂 |
| **滑动窗口** | 无信息失真 | 早期信息完全丢失 |

### 12.3 Clawdbot 的分段摘要实现

```
原始消息 [1-25] [26-50] [51-75] [76-100]
              ↓        ↓        ↓        ↓
          摘要 A    摘要 B    摘要 C    摘要 D
              └────────┴────────┴────────┘
                           ↓
                      最终合并摘要
```

**关键代码**: `src/agents/compaction.ts`

```typescript
// 按 token 份额分割消息
function splitMessagesByTokenShare(messages, parts = 2) {
  // 将消息分成 N 组，每组 token 数大致相等
}

// 分阶段摘要
async function summarizeInStages(params) {
  // Stage 1: 分段
  const splits = splitMessagesByTokenShare(messages, parts);

  // Stage 2: 分别摘要
  for (const chunk of splits) {
    partialSummaries.push(await summarizeChunk(chunk));
  }

  // Stage 3: 合并
  return await mergeSummaries(partialSummaries);
}
```

### 12.4 超大消息的优雅降级

当某条消息超过上下文窗口限制时，不是强制截断，而是：

```typescript
if (isOversizedForSummary(msg, contextWindow)) {
  oversizedNotes.push(`[上下文包含一个大型内容: ${path}]`);
  // 跳过这条消息，但保留一个注释
}
```

**好处**: AI 至少知道"有这么个东西存在"

---

## 十三、Memory 检索机制详解

### 13.1 混合检索架构

```
用户查询: "怎么连接数据库"
           ↓
    ┌──────┴──────┐
    ↓             ↓
向量搜索        关键词搜索
(语义相似度)     (FTS5 BM25)
    ↓             ↓
 权重 0.7       权重 0.3
    └──────┬──────┘
           ↓
      合并排序结果
```

### 13.2 文本分块（Chunking）

**为什么要分块？**
- 语义稀释：太长的文本转成一个向量，细节被淹没
- 模型限制：embedding 模型有输入长度限制

**Clawdbot 默认参数**:
```typescript
chunking: {
  tokens: 400,    // 每个 chunk 大小
  overlap: 80,    // 相邻 chunk 重叠（解决边界切断问题）
}
```

### 13.3 Memory 的两个数据来源

| 来源 | 类型 | 存储位置 | 更新方式 |
|------|------|---------|---------|
| **memory** | 用户编辑的 markdown | `MEMORY.md` + `memory/*.md` | 文件保存时自动同步 |
| **sessions** | 对话记录 | `~/.clawdbot/agents/*/sessions/*.jsonl` | 增量同步 |

---

## 十四、存储机制详解

### 14.1 Session 存储：JSONL

**为什么选 JSONL 而不是 JSON？**

| 特性 | JSON 数组 | JSONL |
|------|----------|-------|
| 追加写入 | ❌ 需要读取整个文件 | ✅ 直接 append 一行 |
| 崩溃恢复 | ❌ 可能损坏整个文件 | ✅ 最多丢失最后一行 |
| 部分读取 | ❌ 必须解析整个数组 | ✅ 可以流式读取 |

**文件结构**:
```
~/.clawdbot/agents/{agentId}/sessions/
├── sessions.json          # 元数据索引
├── {sessionId}.jsonl      # 对话历史
└── {sessionId}-topic-{topicId}.jsonl  # 话题对话
```

**JSONL 格式示例**:
```jsonl
{"type":"session","version":"1.0.0","id":"uuid","timestamp":"..."}
{"role":"user","content":[{"type":"text","text":"你好"}]}
{"role":"assistant","content":[{"type":"text","text":"你好！"}]}
```

### 14.2 Memory 存储：SQLite + sqlite-vec

**为什么选 SQLite 而不是 Pinecone/Milvus？**
- **零依赖**: 嵌入式数据库，不需要额外服务
- **本地优先**: 数据完全在你的设备上
- **零成本**: 不需要付费订阅

**数据库位置**: `~/.clawdbot/state/memory/{agentId}.sqlite`

**Schema 设计**:
```sql
-- 元数据表
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT);

-- 源文件跟踪
CREATE TABLE files (
  path TEXT PRIMARY KEY,
  source TEXT,      -- 'memory' 或 'sessions'
  hash TEXT,        -- 检测文件变化
  mtime INTEGER,
  size INTEGER
);

-- 文本块
CREATE TABLE chunks (
  id TEXT PRIMARY KEY,
  path TEXT,
  source TEXT,
  start_line INTEGER,
  end_line INTEGER,
  text TEXT,
  embedding TEXT,   -- JSON fallback
  model TEXT
);

-- 向量表（sqlite-vec 扩展）
CREATE VIRTUAL TABLE chunks_vec USING vec0 (
  id TEXT PRIMARY KEY,
  embedding FLOAT[1536]
);

-- 全文搜索表（FTS5）
CREATE VIRTUAL TABLE chunks_fts USING fts5 (text, ...);

-- Embedding 缓存
CREATE TABLE embedding_cache (
  provider TEXT,
  model TEXT,
  hash TEXT,        -- 文本哈希
  embedding TEXT,
  PRIMARY KEY (provider, model, provider_key, hash)
);
```

### 14.3 Embedding 缓存的价值

1. **省钱**: 同一段文本不需要重复调用 API
2. **省时间**: 文件没变时直接从缓存读取

### 14.4 模型切换时的原子重建

不同模型的向量空间不兼容，切换时需要重建：

```
1. 创建临时数据库 (memory.sqlite.tmp-{uuid})
2. 复制 embedding_cache
3. 重新索引所有文件
4. 原子交换: temp → memory.sqlite
5. 删除旧数据库

中途失败 → 原数据库完好无损
```

### 14.5 后续学习建议

- [ ] Embedding 提供者深入：OpenAI/Gemini/Local 的实现差异
- [ ] 批量 Embedding API：Batch API 的成本优化
- [ ] 向量搜索优化：sqlite-vec 的性能调优
- [ ] Approval 审批流程：socket 通信机制

---

## 十五、System Prompt 构建机制详解

### 15.1 为什么 System Prompt 很重要

System Prompt 定义了 AI Agent 的"人格"和"能力边界"。一个好的 System Prompt 应该：
- 清晰定义 Agent 的角色和职责
- 注入必要的上下文（用户偏好、知识库）
- 设置安全约束和行为边界

### 15.2 核心构建函数：buildAgentSystemPrompt()

Clawdbot 使用分层组装的方式构建 System Prompt：

```
┌─────────────────────────────────────────────────────────────────┐
│                    System Prompt 构建流程                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Layer 1: 基础身份 (baseSystem)                                   │
│  - Agent 名称和角色                                               │
│  - 基本行为准则                                                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Layer 2: 上下文文件注入                                          │
│  - MEMORY.md (用户记忆和偏好)                                     │
│  - SOUL.md (Agent 个性和语气)                                     │
│  - 其他 bootstrap 文件                                            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Layer 3: 动态上下文                                              │
│  - 当前时间                                                       │
│  - 会话信息 (SessionKey, 渠道等)                                  │
│  - 消息上下文 (MsgContext 的关键字段)                              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Layer 4: 工具声明                                                │
│  - 可用工具列表                                                   │
│  - 工具使用说明                                                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                       最终 System Prompt
```

**关键代码**: `src/agents/system-prompt.ts`

```typescript
export async function buildAgentSystemPrompt(params: {
  agentId: string;
  config: AgentConfig;
  msgContext?: MsgContext;
  sessionKey?: string;
  promptMode?: PromptMode;
}): Promise<string> {
  // 1. 加载基础 system prompt
  const baseSystem = params.config.system || "";

  // 2. 加载上下文文件
  const bootstrapFiles = await loadBootstrapFiles(params.agentId);

  // 3. 组装最终 prompt
  return assemblePrompt({
    base: baseSystem,
    memory: bootstrapFiles.memory,
    soul: bootstrapFiles.soul,
    context: buildContextSection(params),
  });
}
```

### 15.3 三种 Prompt Mode

| Mode | 用途 | 包含内容 |
|------|------|---------|
| **`full`** (默认) | 正常对话 | 完整 System Prompt + 所有上下文 |
| **`minimal`** | 轻量任务 | 只有基础身份，无上下文文件 |
| **`none`** | 特殊场景 | 完全不设置 System Prompt |

**典型使用场景**:
- `full`: 正常用户对话
- `minimal`: Subagent 执行简单任务
- `none`: 调试或特殊测试

### 15.4 上下文文件 vs 向量 Memory 检索

Clawdbot 同时支持两种方式注入长期记忆，各有优劣：

| 方面 | 上下文文件 (MEMORY.md) | 向量 Memory 检索 |
|------|----------------------|-----------------|
| **注入时机** | 构建 System Prompt 时 | 构建用户消息时 |
| **内容类型** | 结构化、手动编辑 | 自动索引、语义检索 |
| **Token 消耗** | 每次都消耗 | 按需检索 |
| **适用场景** | 核心偏好、不变的规则 | 大量知识、动态查询 |
| **可控性** | 高（手动编辑） | 低（依赖检索算法） |

**设计权衡**:
- MEMORY.md: 用于"每次对话都需要知道"的信息
- 向量检索: 用于"相关时才需要"的信息

### 15.5 截断策略：70% Head + 20% Tail

当上下文文件过大时，Clawdbot 使用智能截断：

```
原始文件 (20,000+ 字符)
┌────────────────────────────────────────────────────────────────┐
│  前面 70% 的内容（重要的结构化信息通常在开头）                      │
├────────────────────────────────────────────────────────────────┤
│  ... [中间部分被截断] ...                                        │
├────────────────────────────────────────────────────────────────┤
│  后面 20% 的内容（最近更新的信息通常在末尾）                        │
└────────────────────────────────────────────────────────────────┘

默认限制: 20,000 字符
70% = 14,000 字符 (head)
20% = 4,000 字符 (tail)
10% = 预留给截断提示
```

**为什么是 70/20 而不是 50/50？**
- 结构化文档（如 MEMORY.md）的重要定义通常在开头
- 最近的更新和补充通常在末尾
- 中间部分往往是可以丢失的细节

### 15.6 嵌入式运行时的包装层

`pi-embedded-runner` 在 `buildAgentSystemPrompt` 之上添加了额外的包装：

```
┌─────────────────────────────────────────────────────────────────┐
│                Pi Embedded Runner System Prompt                  │
├─────────────────────────────────────────────────────────────────┤
│  [运行时信息]                                                     │
│  - 当前时间                                                       │
│  - 运行环境                                                       │
│  - 可用工具列表                                                   │
├─────────────────────────────────────────────────────────────────┤
│  [Agent System Prompt]                                           │
│  - buildAgentSystemPrompt() 的输出                               │
├─────────────────────────────────────────────────────────────────┤
│  [渠道特定提示]                                                   │
│  - 来自 ChannelAgentPromptAdapter                                │
│  - 平台特有的注意事项                                             │
└─────────────────────────────────────────────────────────────────┘
```

**关键代码**: `src/agents/pi-embedded-runner/system-prompt.ts`

---

## 十六、Subagent 系统详解

### 16.1 为什么需要 Subagent

复杂任务往往需要分解成多个子任务：

```
用户: "帮我分析这 10 个 CSV 文件，生成报告"
              │
              ▼
┌─────────────────────────────────────────────────────────────────┐
│  主 Agent 分解任务:                                               │
│  1. 解析 CSV 结构                                                 │
│  2. 数据清洗和标准化                                              │
│  3. 统计分析                                                      │
│  4. 生成可视化                                                    │
│  5. 撰写报告                                                      │
└─────────────────────────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────────┐
│  每个子任务由 Subagent 独立执行:                                   │
│  - 独立的 Session                                                │
│  - 独立的上下文窗口                                               │
│  - 可以并行执行                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### 16.2 四阶段生命周期

```
┌─────────────────────────────────────────────────────────────────┐
│                    Subagent 生命周期                              │
└─────────────────────────────────────────────────────────────────┘

  ┌────────────┐      ┌────────────┐      ┌────────────┐      ┌────────────┐
  │   Stage 1  │  →   │   Stage 2  │  →   │   Stage 3  │  →   │   Stage 4  │
  │  Register  │      │    Wait    │      │  Announce  │      │  Cleanup   │
  └────────────┘      └────────────┘      └────────────┘      └────────────┘
       │                    │                    │                    │
       ▼                    ▼                    ▼                    ▼
  在 Registry 中       等待任务执行       向父 Agent         从 Registry
  注册 Subagent       并收集结果         汇报结果           中移除
```

**阶段详解**:

| 阶段 | 触发条件 | 主要动作 |
|------|---------|---------|
| **Register** | 主 Agent 调用 spawn_session | 生成 UUID，创建 SessionKey，注册到 Registry |
| **Wait** | 注册完成后 | 执行任务，可能包含多轮工具调用 |
| **Announce** | 任务完成 | 收集统计信息，生成汇报，通知父 Agent |
| **Cleanup** | 汇报完成 | 从 Registry 移除，释放资源 |

### 16.3 SessionKey 格式

Subagent 使用特殊的 SessionKey 格式来标识其层级关系：

```
普通 Session:    agent:{agentId}:{channel}:{peerKind}:{peerId}
Subagent Session: agent:{agentId}:subagent:{uuid}
```

**示例**:
```
父 Agent SessionKey: agent:main:telegram:dm:123456789
Subagent SessionKey: agent:main:subagent:f47ac10b-58cc-4372-a567-0e02b2c3d479
```

**为什么使用 UUID 而不是继承父 SessionKey？**
- 明确区分：一眼就能看出是 Subagent
- 避免冲突：多个 Subagent 不会相互覆盖
- 简化清理：按 UUID 前缀批量清理

### 16.4 嵌套阻止机制

为了防止无限递归，Clawdbot 阻止 Subagent 再生成 Subagent：

```typescript
// src/routing/session-key.ts
export function isSubagentSessionKey(sessionKey: string): boolean {
  return sessionKey.includes(":subagent:");
}

// 在 spawn_session 工具中检查
if (isSubagentSessionKey(currentSessionKey)) {
  throw new Error("Subagent cannot spawn another subagent");
}
```

**为什么阻止嵌套？**
- 防止无限递归导致资源耗尽
- 简化状态管理
- 保持架构清晰

### 16.5 跨 Agent 生成权限：allowAgents

通过配置 `allowAgents`，可以控制哪些 Agent 可以生成 Subagent：

```json
{
  "agents": {
    "main": {
      "allowAgents": ["research", "coding"]
    },
    "research": {
      "allowAgents": []  // 不允许生成 Subagent
    }
  }
}
```

**权限矩阵**:

| 配置 | 效果 |
|------|------|
| `allowAgents: []` | 禁止生成任何 Subagent |
| `allowAgents: ["*"]` | 允许生成任何 Agent 的 Subagent |
| `allowAgents: ["a", "b"]` | 只允许生成指定 Agent 的 Subagent |

### 16.6 自动汇报和统计收集

Subagent 完成后会自动生成汇报：

```
┌─────────────────────────────────────────────────────────────────┐
│                    Subagent 汇报结构                              │
├─────────────────────────────────────────────────────────────────┤
│  {                                                               │
│    "subagentId": "f47ac10b-58cc-4372-a567-0e02b2c3d479",        │
│    "parentSessionKey": "agent:main:telegram:dm:123456789",      │
│    "status": "completed",                                        │
│    "duration": 12345,         // 执行时长 (ms)                   │
│    "turns": 5,                // 对话轮数                        │
│    "toolCalls": 3,            // 工具调用次数                    │
│    "tokensUsed": {                                               │
│      "input": 2500,                                              │
│      "output": 800                                               │
│    },                                                            │
│    "result": "分析完成，发现以下模式..."                           │
│  }                                                               │
└─────────────────────────────────────────────────────────────────┘
```

**关键代码**:
- `src/agents/tools/sessions-spawn-tool.ts` - 生成入口
- `src/agents/subagent-registry.ts` - 生命周期管理
- `src/agents/subagent-announce.ts` - 汇报机制

---

## 十七、Sandbox 与文件系统隔离详解

### 17.1 为什么需要 Sandbox

AI Agent 执行代码时可能带来安全风险：
- 恶意命令：`rm -rf /`
- 数据泄露：读取敏感文件
- 权限提升：利用系统漏洞
- 资源滥用：无限循环、大量写入

Sandbox 提供了一个受限的执行环境，让 Agent 可以安全地执行代码。

### 17.2 Agent Workspace 概念

每个 Agent 有独立的工作目录：

```
~/.clawdbot/agents/{agentId}/
├── sessions/           # 对话历史
├── memory/             # 本地 Memory 文件
├── workspace/          # Sandbox 工作目录 ⭐
│   ├── files/          # Agent 创建的文件
│   └── temp/           # 临时文件
└── logs/               # Agent 日志
```

**Workspace 是 Agent 唯一可写的目录**（在 Sandbox 模式下）。

### 17.3 三层防护架构

```
┌─────────────────────────────────────────────────────────────────┐
│                    三层防护架构                                   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  Layer 1: Docker 容器隔离                                        │
│  ─────────────────────────────────────────────────────────────   │
│  • --read-only: 文件系统只读                                     │
│  • --network none: 禁止网络访问                                  │
│  • --cap-drop ALL: 移除所有 Linux capabilities                  │
│  • --user: 以非 root 用户运行                                    │
│  • --memory: 内存限制                                            │
│  • --pids-limit: 进程数限制                                      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Layer 2: 文件系统隔离                                           │
│  ─────────────────────────────────────────────────────────────   │
│  • 路径验证: 所有路径必须在 workspace 内                          │
│  • Symlink 检测: 阻止符号链接逃逸                                 │
│  • 文件类型检查: 阻止设备文件、socket 等                          │
│  • 大小限制: 单文件和总大小限制                                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Layer 3: 命令执行控制                                           │
│  ─────────────────────────────────────────────────────────────   │
│  • Token 验证: 只执行带有效 token 的命令                          │
│  • Allowlist: 只允许白名单内的命令                                │
│  • Safe Bins: 预定义的安全二进制文件                              │
│  • 危险 pattern 检测: 阻止 &&, ||, 重定向等                       │
└─────────────────────────────────────────────────────────────────┘
```

### 17.4 三种 Workspace Access Mode

| Mode | 效果 | 适用场景 |
|------|------|---------|
| **`none`** | 不挂载 workspace | 纯对话，无文件操作 |
| **`ro`** (read-only) | 只读挂载 | 查看/分析文件 |
| **`rw`** (read-write) | 读写挂载 | 需要创建/修改文件 |

**配置示例**:
```json
{
  "agents": {
    "main": {
      "sandbox": {
        "enabled": true,
        "workspaceAccess": "rw"
      }
    }
  }
}
```

### 17.5 三种 Sandbox Scope

| Scope | Session 隔离 | 文件隔离 | 适用场景 |
|-------|-------------|---------|---------|
| **`shared`** | 同一 Agent 共享 | 同一 Agent 共享 | Agent 需要跨会话访问文件 |
| **`agent`** | 每 Agent 独立 | 每 Agent 独立 | 多 Agent 需要隔离 |
| **`session`** | 每会话独立 | 每会话独立 | 最高安全级别 |

### 17.6 分层执行模型

不同类型的操作在不同环境执行：

```
┌─────────────────────────────────────────────────────────────────┐
│                    分层执行模型                                   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  Docker 容器内执行:                                               │
│  • Bash 命令 (ls, cat, grep, etc.)                              │
│  • 用户代码执行 (python, node, etc.)                             │
│  • 文件操作 (在 workspace 内)                                    │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  主机执行 (带安全检查):                                           │
│  • MCP Tools (需要访问外部服务)                                   │
│  • Skills (需要访问配置和凭据)                                    │
│  • 系统管理操作                                                   │
└─────────────────────────────────────────────────────────────────┘
```

**为什么 MCP 不在容器内？**
- MCP 需要访问外部 API（网络）
- MCP 需要访问凭据文件
- MCP 本身是受信任的代码

### 17.7 路径验证和逃逸防护

**Symlink 攻击示例**:
```bash
# 攻击者尝试在 workspace 内创建指向 /etc/passwd 的链接
ln -s /etc/passwd workspace/passwd
cat workspace/passwd  # 读取系统文件！
```

**Clawdbot 的防护**:
```typescript
// src/agents/sandbox-paths.ts
export function validatePath(path: string, workspace: string): boolean {
  // 1. 规范化路径
  const resolved = path.resolve(path);

  // 2. 检查是否在 workspace 内
  if (!resolved.startsWith(workspace)) {
    return false;
  }

  // 3. 检查 symlink
  const real = fs.realpathSync(resolved);
  if (!real.startsWith(workspace)) {
    return false;  // Symlink 指向外部！
  }

  return true;
}
```

### 17.8 默认状态和启用方式

**重要**: Sandbox 默认是**关闭**的，需要显式启用。

```json
{
  "agents": {
    "main": {
      "sandbox": {
        "enabled": true,       // 必须显式设置为 true
        "mode": "docker",      // 使用 Docker 隔离
        "workspaceAccess": "rw"
      }
    }
  }
}
```

**为什么默认关闭？**
- Docker 不是所有环境都有
- 对于受信任的单用户场景，Sandbox 增加复杂性
- 允许用户根据安全需求选择

### 17.9 当前架构限制

当前实现紧耦合 Docker，存在一些限制：

| 限制 | 影响 | 潜在解决方案 |
|------|------|-------------|
| **Docker 依赖** | 无 Docker 环境无法使用 | Provider 抽象层 |
| **无 Provider 抽象** | 难以支持其他 Sandbox 技术 | 定义 SandboxProvider 接口 |
| **macOS 支持有限** | Docker on Mac 性能较差 | 支持 lima/colima |
| **Windows 支持有限** | WSL2 依赖 | 支持 Hyper-V |

### 17.10 可扩展性讨论：集成其他 Sandbox

未来可以通过 Provider 抽象支持更多 Sandbox 技术：

```typescript
// 潜在的 Provider 接口
interface SandboxProvider {
  id: string;
  name: string;

  // 检查是否可用
  isAvailable(): Promise<boolean>;

  // 创建 Sandbox 实例
  create(config: SandboxConfig): Promise<SandboxInstance>;

  // 执行命令
  exec(instance: SandboxInstance, cmd: string): Promise<ExecResult>;

  // 清理
  destroy(instance: SandboxInstance): Promise<void>;
}

// 可能支持的 Provider
const providers: SandboxProvider[] = [
  new DockerProvider(),    // 当前实现
  new E2BProvider(),       // E2B (cloud sandbox)
  new FirecrackerProvider(), // AWS Firecracker
  new GVisorProvider(),    // Google gVisor
];
```

**E2B 集成的潜在价值**:
- 无需本地 Docker
- 云端执行，本地设备无负载
- 更强的隔离性

**关键代码**:
- `src/agents/sandbox/config.ts` - 配置解析
- `src/agents/sandbox/docker.ts` - Docker 容器管理
- `src/agents/sandbox-paths.ts` - 路径验证和逃逸防护
- `src/infra/exec-approvals.ts` - 非沙箱模式的命令安全

---

## 附录：关键代码文件索引

| 组件 | 文件路径 | 说明 |
|------|---------|------|
| CLI 入口 | `src/entry.ts` | 命令行入口点 |
| 命令注册 | `src/cli/program.ts` | Commander.js 命令注册 |
| Gateway 服务 | `src/gateway/server.impl.ts` | WebSocket/HTTP 核心服务 |
| Agent 运行时 | `src/agents/pi-embedded-runner/run.ts` | Agent 执行引擎 |
| MsgContext 定义 | `src/auto-reply/templating.ts` | 统一消息格式 |
| Channel 插件接口 | `src/channels/plugins/types.plugin.ts` | 插件接口定义 |
| Channel 适配器 | `src/channels/plugins/types.adapters.ts` | 适配器接口 |
| Telegram 实现 | `src/telegram/bot-message-context.ts` | Telegram 消息转换 |
| Discord 实现 | `src/discord/monitor/message-handler.preflight.ts` | Discord 消息转换 |
| 配置类型 | `src/config/types.gateway.ts` | Gateway 配置定义 |
| Hooks 系统 | `src/infra/hooks/` | 事件拦截系统 |
| Memory 存储 | `src/memory/` | 向量记忆存储 |
| Session 管理 | `src/channels/session.ts` | 会话管理 |
| SessionKey 构建 | `src/routing/session-key.ts` | SessionKey 生成逻辑 |
| 路由决策 | `src/routing/resolve-route.ts` | Agent 路由匹配 |
| Bash 安全检查 | `src/infra/exec-approvals.ts` | 命令白名单验证 |
| Channel 访问控制 | `src/web/inbound/access-control.ts` | Web 入站访问控制 |
| 提及检查 | `src/channels/mention-gating.ts` | @提及 门控逻辑 |
| Session 存储 | `src/config/sessions/store.ts` | Session 持久化实现 |
| Session 类型定义 | `src/config/sessions/types.ts` | Session 数据结构 |
| Session Key 生成 | `src/config/sessions/session-key.ts` | SessionKey 生成 |
| 压缩算法 | `src/agents/compaction.ts` | 对话历史压缩 |
| 嵌入式压缩 | `src/agents/pi-embedded-runner/compact.ts` | Pi 运行时压缩 |
| Memory 管理器 | `src/memory/manager.ts` | Memory 核心管理 |
| Memory Schema | `src/memory/memory-schema.ts` | SQLite Schema 定义 |
| Embedding 提供者 | `src/memory/embeddings.ts` | 向量嵌入接口 |
| 混合搜索 | `src/memory/hybrid.ts` | 向量+FTS5 混合检索 |
| Memory 搜索 | `src/memory/manager-search.ts` | Memory 搜索实现 |
| System Prompt 构建 | `src/agents/system-prompt.ts` | 核心 System Prompt 构建函数 |
| 嵌入式 System Prompt | `src/agents/pi-embedded-runner/system-prompt.ts` | Pi 运行时的包装层 |
| Bootstrap 文件加载 | `src/agents/bootstrap-files.ts` | 上下文文件（MEMORY.md 等）加载 |
| Subagent 生成工具 | `src/agents/tools/sessions-spawn-tool.ts` | Subagent 生成入口 |
| Subagent Registry | `src/agents/subagent-registry.ts` | Subagent 生命周期管理 |
| Subagent 汇报 | `src/agents/subagent-announce.ts` | 完成后的汇报机制 |
| Sandbox 配置 | `src/agents/sandbox/config.ts` | Sandbox 配置解析 |
| Docker Sandbox | `src/agents/sandbox/docker.ts` | Docker 容器管理 |
| Sandbox 路径验证 | `src/agents/sandbox-paths.ts` | 路径验证和逃逸防护 |

---

## 附录：架构文档索引

| 文档 | 路径 | 内容 |
|------|------|------|
| 系统总览 | `docs/architecture/01-system-overview.md` | 架构图和组件关系 |
| 端到端详解 | `docs/architecture/09-end-to-end-detailed.md` | 完整数据流 |
| Gateway 安全 | `docs/gateway/security.md` | 安全配置指南 |
| 配置文档 | `docs/configuration.md` | 配置选项说明 |
| Channel 文档 | `docs/channels/` | 各平台接入指南 |

---

*本文档记录了通过苏格拉底式问答学习 Clawdbot 架构的完整过程。*
*生成时间: 2026-01-26*
*更新时间: 2026-01-27（新增 SessionKey、路由绑定优先级、安全检查链、Session 压缩、Memory 检索、存储机制章节）*
*更新时间: 2026-01-27（新增 System Prompt 构建机制、Subagent 系统、Sandbox 与文件系统隔离章节）*
