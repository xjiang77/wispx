# OpenCode 学习路线图

> 基于今天的探索，制定后续深入学习的路线图

---

## 学习目标

**最终目标**：构建自己的 AI 编程助手

**关键能力**：
- 理解 AI Agent 核心循环
- 掌握上下文管理策略
- 能够设计 Tool/Agent 系统
- 能够实现 TUI 界面

---

## Phase 1: 上下文管理深入

### 学习目标

深入理解 AI Agent 最核心的难题：上下文管理

### 关键问题

1. **消息结构设计**
   - MessageV2 为什么这样设计？
   - 用户消息、AI 响应、工具调用如何统一表示？
   - 附件（文件、图片）如何处理？

2. **上下文压缩策略**
   - Compaction 何时触发？
   - 压缩提示词如何设计？
   - 如何保留关键信息？

3. **工具输出截断**
   - Truncate 的阈值如何确定？
   - 截断后如何让 AI 知道完整内容？

4. **消息处理流水线**
   - processor.ts 的处理步骤？
   - 如何构建发送给 LLM 的最终消息？

### 学习路径

```
1. 阅读 session/message-v2.ts
   → 理解消息数据结构

2. 阅读 session/processor.ts
   → 理解消息处理流程

3. 阅读 agent/prompt/compaction.txt
   → 理解压缩提示词设计

4. 阅读 tool/truncation.ts
   → 理解截断策略

5. 实验：跟踪一次完整对话的上下文变化
```

### 输出

- 上下文管理策略文档
- 自己的设计方案草稿

---

## Phase 2: TUI/UI 实现

### 学习目标

理解如何用 Solid.js + @opentui 构建终端 UI

### 关键问题

1. **为什么选择 Solid.js 而不是 React/Ink？**
   - 性能考虑？
   - @opentui 的特性？

2. **组件结构**
   - 主要有哪些组件？
   - 状态如何管理？
   - 事件如何流动？

3. **实时更新**
   - Stream 输出如何渲染？
   - 工具执行状态如何展示？

### 学习路径

```
1. 阅读 packages/app/src/index.tsx
   → 理解入口结构

2. 阅读 packages/app/src/components/
   → 理解组件设计

3. 研究 @opentui 文档
   → 理解 TUI 框架

4. 实验：修改一个组件，观察效果
```

### 输出

- TUI 架构分析文档
- 简单 Demo 实现

---

## Phase 3: MCP 和插件系统

### 学习目标

理解如何扩展 Agent 能力

### 关键问题

1. **MCP 协议**
   - MCP 是什么？
   - 如何注册 MCP 工具？
   - 与内置工具有何区别？

2. **插件系统**
   - 插件如何加载？
   - 插件能做什么？
   - Hook 机制如何实现？

3. **事件总线**
   - Bus/BusEvent 如何工作？
   - 有哪些内置事件？
   - 如何自定义事件？

### 学习路径

```
1. 阅读 plugin/index.ts
   → 理解插件加载机制

2. 阅读 plugin/mcp.ts
   → 理解 MCP 集成

3. 阅读 bus/bus.ts
   → 理解事件系统

4. 实验：写一个简单插件
```

### 输出

- 扩展系统分析文档
- 示例插件代码

---

## Phase 4: Provider 抽象和 AI SDK 使用

### 学习目标

理解如何支持多 LLM 提供商

### 关键问题

1. **Vercel AI SDK**
   - 核心 API 有哪些？
   - streamText 如何使用？
   - Tool 如何定义？

2. **Provider 适配**
   - 不同 Provider 有何差异？
   - Transform 层如何设计？
   - 认证如何管理？

3. **模型选择**
   - 如何根据任务选择模型？
   - 小模型 vs 大模型的使用场景？

### 学习路径

```
1. 阅读 Vercel AI SDK 文档
   → 理解核心 API

2. 阅读 provider/provider.ts
   → 理解抽象接口

3. 阅读 provider/providers/anthropic.ts
   → 理解具体适配

4. 实验：添加一个新 Provider
```

### 输出

- Provider 抽象设计文档
- 新 Provider 适配代码

---

## Phase 5: 动手实践计划

### 5.1 Mini Agent 项目

**目标**：从零构建一个最小可用的 AI Agent

**范围**：
- 单一 LLM（Anthropic）
- 基础工具（read、edit、bash）
- 简单 TUI
- 基础权限

**步骤**：
1. 搭建项目结构
2. 实现 Tool 系统
3. 实现 Session 管理
4. 实现 LLM 调用
5. 实现简单 TUI
6. 添加权限系统

### 5.2 功能增强

在 Mini Agent 基础上逐步添加：
- [ ] 上下文压缩
- [ ] 多 Provider 支持
- [ ] MCP 集成
- [ ] 插件系统
- [ ] 子 Agent

### 5.3 差异化探索

考虑自己的工具可以有哪些不同：
- 更好的上下文管理？
- 更好的 TUI 体验？
- 特定领域优化？
- 本地 LLM 支持？

---

## 时间安排建议

| Phase | 预估周期 | 重点 |
|-------|----------|------|
| Phase 1 | 1-2 天 | 上下文管理（最核心） |
| Phase 2 | 2-3 天 | TUI 实现 |
| Phase 3 | 1-2 天 | 扩展系统 |
| Phase 4 | 1 天 | Provider 抽象 |
| Phase 5 | 持续 | 动手实践 |

---

## 学习资源

### 官方文档

- [OpenCode GitHub](https://github.com/anomalyco/opencode)
- [Vercel AI SDK](https://sdk.vercel.ai/docs)
- [MCP Protocol](https://modelcontextprotocol.io/)

### 相关项目

- [Claude Code](https://github.com/anthropics/claude-code) - Anthropic 官方
- [Aider](https://github.com/paul-gauthier/aider) - Python 实现
- [Cursor](https://cursor.com/) - IDE 集成

### 技术栈文档

- [Solid.js](https://www.solidjs.com/)
- [Zod](https://zod.dev/)
- [Bun](https://bun.sh/)

---

## 检查点

完成每个 Phase 后，问自己：

1. **Phase 1 完成后**
   - 能否画出完整的上下文流转图？
   - 能否解释 Compaction 的工作原理？

2. **Phase 2 完成后**
   - 能否修改 TUI 组件？
   - 能否添加新的 UI 功能？

3. **Phase 3 完成后**
   - 能否写一个简单插件？
   - 能否集成 MCP 工具？

4. **Phase 4 完成后**
   - 能否添加新的 LLM Provider？
   - 能否理解消息格式转换？

5. **Phase 5 完成后**
   - 能否独立构建一个可用的 Agent？
   - 有没有自己的创新点？
