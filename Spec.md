# Agent Wisp — 产品规格文档

## Context

个人 AI coding 工作台，整合多个 AI agent（Claude Code、Codex 等），配备智能记忆系统，支持跨设备使用。解决的核心问题：当前各 AI coding 工具各自为战，没有统一的记忆、没有协作能力、无法跨设备延续工作。

---

## 1. 产品定位

- **一句话描述**: 个人 AI coding 工作台，带记忆的 meta-agent
- **形态**: Hybrid — 轻量 TUI 壳 + 协议层核心，各工具以 adapter/plugin 接入
- **用户**: 个人开发者（非团队工具）
- **名称含义**: Wisp — 幽灵般的存在，可以在设备间传送（teleport）

## 2. 核心架构

### 2.1 技术栈

- **语言**: TypeScript
- **基础框架**: pi-mono 生态（独立项目，依赖 npm packages）
  - `@mariozechner/pi-ai` — 统一多 provider LLM API
  - `@mariozechner/pi-agent-core` — Agent runtime + tool calling + state management
  - `@mariozechner/pi-tui` — Terminal UI 库
- **界面**: TUI（Terminal UI）
- **交互**: 命令 + 自然语言对话混合（slash commands + free-form input）

### 2.2 Agent 系统

```
┌─────────────────────────────────────────────┐
│                  User (TUI)                 │
├─────────────────────────────────────────────┤
│              Wisp Meta-Agent                │
│         (Frontier LLM Orchestrator)         │
│    Claude 4.6 Opus / GPT-5.3 (可配置)       │
│                                             │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐     │
│  │ 任务理解 │  │ 计划制定 │  │ 结果综合 │     │
│  └─────────┘  └─────────┘  └─────────┘     │
├─────────────────────────────────────────────┤
│             Adapter / Plugin Layer          │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐ │
│  │Claude Code│ │   Codex   │ │  Future   │ │
│  │ Adapter   │ │  Adapter  │ │ Adapters  │ │
│  └───────────┘ └───────────┘ └───────────┘ │
├─────────────────────────────────────────────┤
│              Git Worktree Layer             │
│  worktree-1/  worktree-2/  worktree-3/     │
└─────────────────────────────────────────────┘
```

**Meta-Agent 职责**:
- 理解用户任务意图
- 制定执行计划，分解子任务
- 智能路由：决定哪个 agent 执行哪个子任务
- 并行协作：多个 agent 可同时工作
- 综合结果并呈现给用户

**Adapter 统一接口**:
```typescript
interface AgentAdapter {
  name: string
  capabilities: string[]              // 擅长的任务类型
  sendTask(task: Task): Promise<void> // 发送任务
  streamOutput(): AsyncIterable<Output> // 流式输出
  getStatus(): AgentStatus            // 当前状态
  cancel(): Promise<void>             // 取消任务
}
```

**并发控制**: Git worktree 隔离 — 每个 agent 在独立 worktree 中工作，避免文件冲突

**API Key 管理**: 各工具自管（Claude Code 用自己的 subscription，Codex 用自己的）

### 2.3 记忆系统

**设计原则**:
- 比 ClawdBot 的 PARA + JSON 更轻量
- 更智能的检索（超越 BM25）
- 代码感知（理解代码库结构和架构决策）
- 更好的自动化（减少人工维护）

**记忆层级**:

| 层级 | 范围 | 内容 | 存储 |
|------|------|------|------|
| 项目级 | 单个代码库 | 架构决策、代码库地图、模块依赖、Bug 模式、编码约定、测试策略、部署流程 | Markdown 文件（项目根目录） |
| 个人级 | 跨所有项目 | 编码风格偏好、常用 pattern、学习记录、工具配置 | SQLite + Markdown |

**并行存储策略**:
- **Markdown 文件**: 长期记忆、叙述性知识、人可读
- **SQLite**: 短期记忆、结构化数据、快速检索、关系索引

**代码感知记忆** — Wisp 记住的代码知识：
- 架构决策（为什么选了这个方案、之前否决了什么）
- 代码库地图（文件结构、模块依赖、关键函数位置、数据流向）
- Bug 模式（历史 bug 的原因和 fix，常见陷阱，易出错区域）
- 编码约定、测试策略、部署流程

**自动化提取**（混合时机）:
- **实时提取**: 对话过程中识别并存储关键信息（架构决策、新 pattern）
- **Session 后整理**: 每次 session 结束时批量分析，提取遗漏的记忆
- **定时衰减**: 定期整理记忆优先级，cold 记忆降权但不删除

**检索增强**:
- 超越简单的 BM25 全文搜索
- LLM-assisted retrieval: 用 LLM 理解查询意图，生成多角度搜索查询
- 结合 embedding similarity + keyword match
- Context-aware: 根据当前任务和项目自动调整检索范围

## 3. 用户交互

### 3.1 TUI 界面

- 主区域: 对话流（类似 Claude Code 的交互体验）
- 状态栏: 当前项目、活跃 agent、记忆状态
- 后台 agent 完成时推送通知

### 3.2 命令系统

```
/plan <description>     — 制定任务计划
/memory search <query>  — 搜索记忆
/memory show            — 查看当前项目记忆摘要
/agent list             — 查看可用 agent
/agent status           — 查看活跃 agent 状态
/switch <agent>         — 手动切换 agent
/config                 — 配置管理
```

自然语言输入自动路由到 meta-agent 处理。

## 4. 跨设备 (Teleport)

> **状态**: 概念阶段，MVP 不包含，后续迭代

- 选择性传送：用户选择传送哪些部分（对话上下文、任务状态、记忆快照等）
- Mobile 支持：通过 Telegram / WhatsApp 与 agent 交互（类似 ClawdBot）
- 具体技术方案待定

## 5. MVP 定义

### 范围: 单 Agent + 记忆系统

**包含**:
- [ ] Wisp agent loop（基于 pi-agent-core）
- [ ] Claude Code adapter（首选集成）
- [ ] Codex adapter（次选集成）
- [ ] 记忆系统 v1（项目级 + 个人级）
- [ ] Markdown 记忆存储
- [ ] SQLite 索引 / 结构化存储
- [ ] 基础 TUI（基于 pi-tui）
- [ ] 命令 + 对话混合交互
- [ ] 基础记忆自动提取

**不包含（后续迭代）**:
- 多 agent 并行协作
- 智能路由
- Git worktree 并发隔离
- Teleport 跨设备
- Telegram/WhatsApp 集成
- Memory decay / heartbeat
- 高级代码感知（代码库地图、Bug 模式分析）

## 6. 已知风险与对策

| 风险 | 严重度 | 对策 |
|------|--------|------|
| 复杂度失控 | 高 | 严格控制 MVP 范围；单 agent 先跑通再扩展 |
| 记忆质量（垃圾进垃圾出） | 高 | LLM-assisted extraction with quality scoring；人工 review 机制；先手动提取建立直觉 |
| LLM 调用成本 | 中 | MVP 不做 meta-agent routing；orchestrator 层尽量用 prompt caching |
| 工具 API 变更 | 中 | Adapter 层抽象隔离；先集成最稳定的工具 |
