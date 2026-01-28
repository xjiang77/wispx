# Clawdbot v6.1 Architecture Topology

This document records the canonical topology structure of the Clawdbot Agent-Centric System Architecture v6.1 diagram for reference in future communications and documentation.

## Overview Layout

The architecture uses a **left-to-right flow** with 5 distinct layers:

```
┌──────────────┐  ┌──────────────┐  ┌────────────────────────────────┐  ┌────────────┐
│ ENTRY LAYER  │→ │GATEWAY LAYER │→ │         AGENT LAYER            │→ │  EXTERNAL  │
│    (Blue)    │  │   (Yellow)   │  │           (Green)              │  │   (Red)    │
│  x:-160      │  │  x:200       │  │         x:640                  │  │  x:1270    │
│  w:280       │  │  w:370       │  │         w:560                  │  │  w:200     │
└──────────────┘  └──────────────┘  └────────────────────────────────┘  └────────────┘
       │                 │                        │                            │
       └─────────────────┴────────────────────────┴────────────────────────────┘
                              INFRASTRUCTURE (Gray) x:-120 w:1600
```

## Layer Details

### 1. Entry Layer (Blue - #C6DAFC)

User-facing inputs and messaging channels.

```
┌─────────────────────────────────────┐
│  ENTRY LAYER (入口层)               │
├─────────────────────────────────────┤
│  Messaging Channels:                │
│  ┌──────────┐ ┌──────────┐         │
│  │ Telegram │ │ Discord  │         │
│  ├──────────┤ ├──────────┤         │
│  │  Slack   │ │  Signal  │         │
│  ├──────────┤ ├──────────┤         │
│  │ WhatsApp │ │ iMessage │         │
│  ├──────────┤ ├──────────┤         │
│  │ MS Teams │ │  Matrix  │         │
│  └──────────┘ └──────────┘         │
├─────────────────────────────────────┤
│  Native Interfaces:                 │
│  ┌──────────┐ ┌──────────┐         │
│  │  Web UI  │ │   CLI    │         │
│  ├──────────┤ ├──────────┤         │
│  │ Mac App  │ │Mobile App│         │
│  └──────────┘ └──────────┘         │
├─────────────────────────────────────┤
│  Other Inputs:                      │
│  ┌──────────┐ ┌──────────┐         │
│  │Voice/Siri│ │ HTTP API │         │
│  ├──────────┤ ├──────────┤         │
│  │  Hooks   │ │Scheduled │         │
│  │          │ │  Tasks   │         │
│  └──────────┘ └──────────┘         │
└─────────────────────────────────────┘
```

### 2. Gateway Layer (Yellow - #FEEFC3)

Network interfaces and deployment modes.

```
┌─────────────────────────────────────┐
│  GATEWAY LAYER (网关层)             │
├─────────────────────────────────────┤
│  Deployment Modes:                  │
│  ┌──────────────────────────────┐  │
│  │ ┌────────┐ ┌───────────────┐ │  │
│  │ │ LOCAL  │ │   Tailscale   │ │  │
│  │ │localhost│ │ serve|funnel │ │  │
│  │ │ :18789 │ │               │ │  │
│  │ ├────────┤ │               │ │  │
│  │ │ REMOTE │ │               │ │  │
│  │ │0.0.0.0 │ │               │ │  │
│  │ │ :18789 │ │               │ │  │
│  │ └────────┘ └───────────────┘ │  │
│  └──────────────────────────────┘  │
├─────────────────────────────────────┤
│  Core Services:                     │
│  ┌───────────┐                     │
│  │ WebSocket │                     │
│  ├───────────┤                     │
│  │ HTTP API  │                     │
│  ├───────────┤                     │
│  │   Node    │                     │
│  ├───────────┤                     │
│  │ Cron Jobs │                     │
│  └───────────┘                     │
└─────────────────────────────────────┘
```

### 3. Agent Layer (Green - #CEEAD6) - Architecture Core

The central intelligence layer with LLM orchestration, state management, and the agentic loop.

```
┌─────────────────────────────────────────────────────────────────┐
│  AGENT LAYER (代理层 - 架构核心)                                │
├─────────────────────────────────────────────────────────────────┤
│  LLM Orchestration:                                             │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Provider Router │ Streaming │ Model Selection │ Fallback│   │
│  └─────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────┤
│  State Management:                                              │
│  ┌──────────┐ ┌──────────┐ ┌───────────┐ ┌───────────┐        │
│  │ Session  │ │  Memory  │ │  Context  │ │Guardrails │        │
│  │ (短期)   │ │  (长期)  │ │   Mgmt    │ │ (Safety)  │        │
│  └──────────┘ └──────────┘ └───────────┘ └───────────┘        │
├─────────────────────────────────────────────────────────────────┤
│  Agent Runtime (Agentic Loop):                                  │
│  场景: "帮我生成一个项目进度 PPT"                               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌────────┐│   │
│  │  │1.理解意图│ → │2.调用工具│ → │3.执行工具│ → │4.返回/ ││   │
│  │  │ Analyze  │   │ Request  │   │ Execute  │   │  继续  ││   │
│  │  │ 需要/pptx│   │skill:pptx│   │验证+执行 │   │Loop    ││   │
│  │  └──────────┘   └──────────┘   └──────────┘   └────────┘│   │
│  │       ↑                                            │      │   │
│  │       └──────────────── 循环 ←─────────────────────┘      │   │
│  └─────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────┤
│  ┌────────────────────────┐  ┌─────────────────────────────┐   │
│  │ TOOLS (工具层)         │  │ SKILLS (技能系统)           │   │
│  │                        │  │                             │   │
│  │ • File Ops             │  │ 文档: /pptx /pdf /docx      │   │
│  │ • Browser              │  │ 代码: /commit /review-pr    │   │
│  │ • Shell                │  │ 测试: /test /deploy         │   │
│  │ • MCP Tools            │  │                             │   │
│  │                        │  │ Skill Loader:               │   │
│  │ Tool Executor:         │  │ 动态加载 → MCP Client       │   │
│  │ 验证→执行→格式化→重试  │  │ 连接外部服务                │   │
│  └────────────────────────┘  └─────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────┤
│  Extensions:                                                    │
│  ┌────────────────┐ ┌────────────────┐ ┌────────────────┐      │
│  │ Hooks&Plugins  │ │Agent Commands  │ │ Persona&Config │      │
│  │(Extension Pts) │ │(Built-in Acts) │ │ (System Prompt)│      │
│  └────────────────┘ └────────────────┘ └────────────────┘      │
└─────────────────────────────────────────────────────────────────┘
```

### 4. External Layer (Red - #FAD2CF)

External LLM providers and third-party services.

```
┌─────────────────────────┐
│ EXTERNAL (外部服务)     │
├─────────────────────────┤
│ LLM Providers:          │
│ ┌─────────────────────┐ │
│ │ Anthropic (Claude)  │ │
│ ├─────────────────────┤ │
│ │   OpenAI (GPT)      │ │
│ ├─────────────────────┤ │
│ │  Google (Gemini)    │ │
│ ├─────────────────────┤ │
│ │     DeepSeek        │ │
│ ├─────────────────────┤ │
│ │   Ollama (Local)    │ │
│ └─────────────────────┘ │
├─────────────────────────┤
│ External Services:      │
│ ┌─────────────────────┐ │
│ │    MCP Servers      │ │
│ ├─────────────────────┤ │
│ │     Webhooks        │ │
│ ├─────────────────────┤ │
│ │ Third-party APIs    │ │
│ └─────────────────────┘ │
└─────────────────────────┘
```

### 5. Infrastructure Layer (Gray - #F1F3F4) - Bottom

Shared infrastructure services spanning all layers.

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│  INFRASTRUCTURE (基础设施)                                                      │
│  ┌────────┐ ┌─────────┐ ┌────────┐ ┌─────────┐ ┌────────┐ ┌────────┐ ┌───────┐│
│  │ Crypto │ │ Process │ │ Cache  │ │ Logging │ │ Config │ │  File  │ │SQLite ││
│  │ (Keys) │ │(Spawn/  │ │(Memory)│ │(Unified)│ │(Setting│ │ System │ │(Data) ││
│  │        │ │  IPC)   │ │        │ │         │ │   s)   │ │        │ │       ││
│  └────────┘ └─────────┘ └────────┘ └─────────┘ └────────┘ └────────┘ └───────┘│
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Data Flow

```
User Input → Entry Layer → Gateway Layer → Agent Layer ⟷ External Layer
                               │                │
                               └────────────────┴──────→ Infrastructure Layer
```

1. **User messages** arrive via Entry Layer channels (Telegram, Discord, CLI, etc.)
2. **Gateway** handles routing, authentication, and protocol translation
3. **Agent Layer** processes requests through the agentic loop:
   - Understands intent
   - Selects and calls tools/skills
   - Executes with error handling
   - Returns results or continues loop
4. **External services** (LLM providers, MCP servers) are called as needed
5. **Infrastructure** provides persistence, logging, and security across all layers

## Color Palette

| Layer          | Fill Color | Stroke Color | Text Color |
|----------------|------------|--------------|------------|
| Entry          | #C6DAFC    | #1A73E8      | #0D47A1    |
| Gateway        | #FEEFC3    | #E37400      | #5D4200    |
| Agent          | #CEEAD6    | #188038      | #0B5323    |
| External       | #FAD2CF    | #C5221F      | #7F0000    |
| Infrastructure | #F1F3F4    | #5F6368      | #202124    |

## Coordinates Reference

| Element        | X Position | Y Position | Width | Height |
|----------------|------------|------------|-------|--------|
| Title          | 500        | 20         | 800   | 40     |
| Entry Layer    | -160       | 75         | 280   | 660    |
| Gateway Layer  | 200        | 80         | 370   | 650    |
| Agent Layer    | 640        | 80         | 560   | 650    |
| External Layer | 1270       | 75         | 200   | 640    |
| Infra Layer    | -120       | 780        | 1600  | 140    |

---

*Generated from clawdbot-v6.1-agent-centric-system.drawio*
