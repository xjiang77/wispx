# Gateway Modes | Gateway 模式详解

This document explains how Local Mode and Remote Mode work in Clawdbot's gateway architecture.

本文档详细解释 Clawdbot Gateway 的 Local Mode 和 Remote Mode 工作原理。

---

## Overview | 概述

**Core Concept**: `gateway.mode` determines whether this machine runs the Gateway server or connects to a remote Gateway.

**核心概念**：`gateway.mode` 决定这台机器是运行 Gateway 服务端还是连接远程 Gateway。

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      Local Mode vs Remote Mode                          │
│                      Local 模式 vs Remote 模式                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   【Local Mode】                    【Remote Mode】                      │
│   【Local 模式】                    【Remote 模式】                       │
│                                                                         │
│   ┌─────────────┐                  ┌─────────────┐                      │
│   │ This machine │                  │ This machine │                      │
│   │ runs Gateway │                  │ is a client  │                      │
│   │  (server)    │                  │    only      │                      │
│   └──────┬──────┘                  └──────┬──────┘                      │
│          │                                │                             │
│          ▼                                ▼                             │
│   ┌─────────────┐                  ┌─────────────┐                      │
│   │ Local state │                  │ Connect to  │                      │
│   │ ~/.clawdbot │                  │ remote GW   │                      │
│   └─────────────┘                  └─────────────┘                      │
│                                           │                             │
│                                           ▼                             │
│                                    ┌─────────────┐                      │
│                                    │Remote server│                      │
│                                    │ runs Gateway│                      │
│                                    └─────────────┘                      │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Local Mode | Local 模式详解

### Configuration | 配置

```json
{
  "gateway": {
    "mode": "local",
    "port": 18789,
    "bind": "loopback",
    "auth": {
      "mode": "token",
      "token": "your-secret-token"
    }
  }
}
```

### Startup Flow | 启动流程

```
clawdbot gateway run
    ↓
Load config + parse CLI args | 加载配置 + 解析 CLI 参数
    ↓
Verify gateway.mode === "local" | 验证 gateway.mode === "local"
    ↓
Acquire exclusive lock (only one Gateway instance) | 获取独占锁
    ↓
Resolve bind address (bind mode) | 解析绑定地址
    ↓
Start WebSocket + HTTP server | 启动 WebSocket + HTTP 服务
    ↓
Start Channel manager | 启动 Channel 管理器
    ↓
Optional: Configure Tailscale exposure | 可选: 配置 Tailscale 暴露
```

### Bind Modes | 绑定模式

| Mode | Bind Address | Fallback | Use Case |
|------|-------------|----------|----------|
| `loopback` | 127.0.0.1 | 0.0.0.0 | Local access only (most secure) |
| `lan` | 0.0.0.0 | None | LAN access (requires auth) |
| `tailnet` | 100.x.x.x | 127.0.0.1 | Tailscale network only |
| `auto` | 127.0.0.1 → 0.0.0.0 | Smart fallback | Default (flexible) |
| `custom` | User-specified IP | 0.0.0.0 | Specific network interface |

| 模式 | 绑定地址 | 回退 | 使用场景 |
|------|---------|------|----------|
| `loopback` | 127.0.0.1 | 0.0.0.0 | 仅本机访问（最安全） |
| `lan` | 0.0.0.0 | 无 | 局域网访问（需认证） |
| `tailnet` | 100.x.x.x | 127.0.0.1 | 仅 Tailscale 网络 |
| `auto` | 127.0.0.1 → 0.0.0.0 | 智能回退 | 默认（灵活） |
| `custom` | 用户指定 IP | 0.0.0.0 | 特定网卡 |

### Authentication | 认证机制

**Token Authentication | Token 认证**:
```json
{
  "gateway": {
    "auth": {
      "mode": "token",
      "token": "your-secret-token"
    }
  }
}
```

**Password Authentication | Password 认证**:
```json
{
  "gateway": {
    "auth": {
      "mode": "password",
      "password": "your-password"
    }
  }
}
```

**Device Authentication (automatic) | 设备认证（自动）**:
- Device ID: Unique per machine | 设备 ID: 每台机器唯一
- Device Token: Issued by server, stored in `~/.clawdbot/device-auth/` | 设备 Token: 服务端签发
- Public key signature: Cryptographic device verification | 公钥签名: 加密验证设备身份

### Security Constraints | 安全约束

```typescript
// Constraint 1: Non-loopback binding requires authentication
// 约束 1: 非 loopback 绑定必须有认证
if (!isLoopbackHost(bindHost) && !hasSharedSecret) {
  throw new Error(`refusing to bind gateway to ${bindHost} without auth`);
}

// Constraint 2: Tailscale exposure requires loopback binding
// 约束 2: Tailscale 暴露必须绑定 loopback
if (tailscaleMode !== "off" && !isLoopbackHost(bindHost)) {
  throw new Error("tailscale serve/funnel requires bind=loopback");
}

// Constraint 3: Tailscale Funnel requires password authentication
// 约束 3: Tailscale Funnel 必须使用 password 认证
if (tailscaleMode === "funnel" && authMode !== "password") {
  throw new Error("tailscale funnel requires auth mode=password");
}
```

---

## Remote Mode | Remote 模式详解

### Configuration | 配置

```json
{
  "gateway": {
    "mode": "remote",
    "remote": {
      "url": "ws://192.168.1.100:18789",
      "token": "shared-token"
    }
  }
}
```

### Connection Flow | 连接流程

```
clawdbot agent "Hello"
    ↓
Detect gateway.mode === "remote" | 检测 gateway.mode === "remote"
    ↓
Read gateway.remote.url | 读取 gateway.remote.url
    ↓
Create WebSocket client | 创建 WebSocket 客户端
    ↓
TLS fingerprint verification (if configured) | TLS 指纹验证（如果配置）
    ↓
Send connect message + auth info | 发送 connect 消息 + 认证信息
    ↓
Server validates → returns device token | 服务端验证 → 返回设备 Token
    ↓
Execute request | 执行请求
```

### URL Resolution Priority | URL 解析优先级

1. CLI argument `--url` | CLI 参数 `--url`
2. Config `gateway.remote.url` | 配置 `gateway.remote.url`
3. Local URL (ws://127.0.0.1:18789) | 本地 URL

### TLS Certificate Fingerprint | TLS 证书指纹

```json
{
  "gateway": {
    "mode": "remote",
    "remote": {
      "url": "wss://my-server:18789",
      "tlsFingerprint": "sha256:ABC123..."
    }
  }
}
```

### SSH Tunnel Mode | SSH 隧道模式

```json
{
  "gateway": {
    "mode": "remote",
    "remote": {
      "transport": "ssh",
      "sshTarget": "user@gateway-host",
      "sshIdentity": "~/.ssh/id_rsa"
    }
  }
}
```

---

## Tailscale Integration | Tailscale 集成

### Three Modes | 三种模式

| Mode | Access Scope | Security Requirement |
|------|-------------|---------------------|
| `off` | Local only | None |
| `serve` | Within Tailnet | Optional auth |
| `funnel` | Entire internet | Must use password auth |

| 模式 | 访问范围 | 安全要求 |
|------|---------|---------|
| `off` | 仅本机 | 无 |
| `serve` | Tailnet 内部 | 可选认证 |
| `funnel` | 整个互联网 | 必须 password 认证 |

### Serve Mode | Serve 模式

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Tailscale Tailnet                            │
│                                                                      │
│   ┌─────────────────────┐         ┌─────────────────────┐           │
│   │   Server             │         │     Phone            │           │
│   │ ┌─────────────────┐ │  HTTPS  │  ┌───────────────┐  │           │
│   │ │ Gateway         │ │◄────────│  │   App         │  │           │
│   │ │ (127.0.0.1)     │ │         │  └───────────────┘  │           │
│   │ └────────┬────────┘ │         └─────────────────────┘           │
│   │          │          │                                            │
│   │          ▼          │                                            │
│   │ ┌─────────────────┐ │                                            │
│   │ │ Tailscale Serve │ │   Only devices in Tailnet can access      │
│   │ └─────────────────┘ │   只有 Tailnet 内的设备可以访问             │
│   └─────────────────────┘                                            │
│                                                                      │
│   Access URL: https://{hostname}.ts.net                              │
│   访问地址: https://{hostname}.ts.net                                │
└─────────────────────────────────────────────────────────────────────┘
```

### Funnel Mode | Funnel 模式

```
┌─────────────────────────────────────────────────────────────────────┐
│                              Internet | 互联网                       │
│                                                                      │
│          Anyone can access (requires password auth)                  │
│          任何人都可以访问（需要密码认证）                              │
│                         │                                            │
│                         ▼                                            │
│              ┌─────────────────────┐                                │
│              │  Tailscale Funnel   │                                │
│              │  (Public HTTPS)     │                                │
│              │  (公网 HTTPS 入口)   │                                │
│              └──────────┬──────────┘                                │
│                         │                                            │
│   ┌─────────────────────▼───────────────────────┐                   │
│   │              Your Server | 你的服务器         │                   │
│   │   ┌─────────────────────────────────────┐   │                   │
│   │   │  Gateway (127.0.0.1) + Tailscale    │   │                   │
│   │   └─────────────────────────────────────┘   │                   │
│   └─────────────────────────────────────────────┘                   │
│                                                                      │
│   WARNING: Must configure password authentication!                   │
│   警告：必须配置密码认证！                                             │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Typical Deployment Scenarios | 典型部署场景

### Scenario 1: Single Machine (Laptop) | 场景 1: 单机使用（笔记本）

```json
{
  "gateway": {
    "mode": "local",
    "bind": "loopback"
  }
}
```

### Scenario 2: Home Server + Phone Control | 场景 2: 家庭服务器 + 手机控制

**Server | 服务器**:
```json
{
  "gateway": {
    "mode": "local",
    "bind": "loopback",
    "tailscale": { "mode": "serve" }
  }
}
```

**Phone | 手机**:
```json
{
  "gateway": {
    "mode": "remote",
    "remote": {
      "url": "https://server.ts.net"
    }
  }
}
```

### Scenario 3: Cloud VPS | 场景 3: 云服务器 VPS

```json
{
  "gateway": {
    "mode": "local",
    "bind": "lan",
    "port": 18789,
    "auth": {
      "mode": "token",
      "token": "secure-token"
    }
  }
}
```

---

## Key Code File Index | 关键代码文件索引

| Concept | File Path |
|---------|-----------|
| Gateway config types | `src/config/types.gateway.ts` |
| Gateway server impl | `src/gateway/server.impl.ts` |
| Bind address resolution | `src/gateway/net.ts` |
| Authentication logic | `src/gateway/auth.ts` |
| Runtime config | `src/gateway/server-runtime-config.ts` |
| CLI run command | `src/cli/gateway-cli/run.ts` |
| Run loop | `src/cli/gateway-cli/run-loop.ts` |
| WebSocket client | `src/gateway/client.ts` |
| Gateway calls | `src/gateway/call.ts` |
| Tailscale integration | `src/infra/tailscale.ts` |
| Remote config wizard | `src/commands/onboard-remote.ts` |
| Device auth storage | `src/infra/device-auth-store.ts` |

| 概念 | 文件路径 |
|------|---------|
| Gateway 配置类型 | `src/config/types.gateway.ts` |
| Gateway 服务实现 | `src/gateway/server.impl.ts` |
| 绑定地址解析 | `src/gateway/net.ts` |
| 认证逻辑 | `src/gateway/auth.ts` |
| 运行时配置 | `src/gateway/server-runtime-config.ts` |
| CLI 启动命令 | `src/cli/gateway-cli/run.ts` |
| 启动循环 | `src/cli/gateway-cli/run-loop.ts` |
| WebSocket 客户端 | `src/gateway/client.ts` |
| Gateway 调用 | `src/gateway/call.ts` |
| Tailscale 集成 | `src/infra/tailscale.ts` |
| 远程配置向导 | `src/commands/onboard-remote.ts` |
| 设备认证存储 | `src/infra/device-auth-store.ts` |

---

*Document created: 2026-01-27*
