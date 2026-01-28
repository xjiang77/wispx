# cwork-core vs openwork-main 深度对比分析

## 概述

**cwork-core** 是基于 **openwork-main** 进行的重大架构升级，从单用户桌面应用转变为多租户云 SaaS 平台。

---

## 1. 核心架构变化总览

### 1.1 架构演进图

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           openwork-main (桌面应用)                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                    │
│   │   Electron  │───▶│   React     │───▶│   SQLite    │                    │
│   │  (桌面框架)  │    │  (前端 UI)   │    │  (本地数据库) │                    │
│   └─────────────┘    └─────────────┘    └─────────────┘                    │
│          │                                     │                            │
│          ▼                                     ▼                            │
│   ┌─────────────┐                       ┌─────────────┐                    │
│   │  node-pty   │                       │  本地文件系统  │                    │
│   │ (OpenCode)  │                       │   (存储)     │                    │
│   └─────────────┘                       └─────────────┘                    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ 架构升级
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           cwork-core (云 SaaS 平台)                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────────────────────┐   │
│   │   Tauri     │───▶│   SolidJS   │───▶│     混合存储层              │   │
│   │  (桌面框架)  │    │  (前端 UI)   │    │  ┌───────┐ ┌───────┐ ┌───┐ │   │
│   └─────────────┘    └─────────────┘    │  │  PG   │ │  COS  │ │本地│ │   │
│          │                              │  └───────┘ └───────┘ └───┘ │   │
│          │                              └─────────────────────────────┘   │
│          ▼                                            │                   │
│   ┌─────────────────────────────────────┐            │                   │
│   │           沙箱执行层                 │            │                   │
│   │  ┌───────┐  ┌───────┐  ┌───────┐  │            │                   │
│   │  │ Local │  │Docker │  │Remote │  │◀───────────┘                   │
│   │  └───────┘  └───────┘  └───────┘  │     (COS 同步/挂载)             │
│   └─────────────────────────────────────┘                               │
│          │                                                               │
│          ▼                                                               │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                    SST/Cloudflare 基础设施                       │   │
│   │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐  │   │
│   │  │ Workers │ │   KV    │ │   R2    │ │PlanetSc │ │ Stripe  │  │   │
│   │  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘  │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 技术栈对比表

| 方面 | openwork-main | cwork-core |
|------|---------------|------------|
| **桌面框架** | Electron | Tauri (Rust) |
| **前端框架** | React 19 | SolidJS 1.9 |
| **包管理器** | pnpm 9.15 | Bun 1.3.5 |
| **构建工具** | Vite 6 | Turborepo + Vite 7 |
| **部署方式** | 桌面安装包 | Serverless (SST/Cloudflare) |
| **数据库** | SQLite (本地) | PostgreSQL + PlanetScale MySQL |
| **存储** | 本地文件系统 | PostgreSQL/COS/本地 混合 |

---

## 2. PostgreSQL 存储层实现 (重大新增)

### 2.1 存储层架构图

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         UnifiedStorage (统一存储抽象)                      │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   write(key, data)  ──▶  getBackendFor(key)  ──▶  路由到对应后端          │
│                                │                                         │
│                    ┌───────────┼───────────┐                            │
│                    ▼           ▼           ▼                            │
│              ┌──────────┐ ┌──────────┐ ┌──────────┐                     │
│              │  Local   │ │   PG     │ │   COS    │                     │
│              │ Storage  │ │ Storage  │ │ Storage  │                     │
│              └────┬─────┘ └────┬─────┘ └────┬─────┘                     │
│                   │            │            │                            │
│                   ▼            ▼            ▼                            │
│              ┌──────────┐ ┌──────────┐ ┌──────────┐                     │
│              │ 文件系统  │ │PostgreSQL│ │腾讯云 COS │                     │
│              │   JSON   │ │  JSONB   │ │  对象存储  │                     │
│              └──────────┘ └──────────┘ └──────────┘                     │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

### 2.2 路由决策流程

```
                    ┌─────────────────┐
                    │   存储请求       │
                    │ key = [type, …] │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │  isLocal()?     │
                    └────────┬────────┘
                             │
              ┌──────────────┴──────────────┐
              │ Yes                         │ No
              ▼                             ▼
       ┌─────────────┐            ┌─────────────────┐
       │ return      │            │ isSessionData?  │
       │ "local"     │            │ (session/msg/   │
       └─────────────┘            │  part/share…)   │
                                  └────────┬────────┘
                                           │
                            ┌──────────────┴──────────────┐
                            │ Yes                         │ No
                            ▼                             ▼
                   ┌─────────────────┐          ┌─────────────┐
                   │ usePGForSess?   │          │ return      │
                   └────────┬────────┘          │ "cos"       │
                            │                   └─────────────┘
             ┌──────────────┴──────────────┐
             │ Yes                         │ No
             ▼                             ▼
      ┌─────────────┐              ┌─────────────┐
      │ return "pg" │              │ return "cos"│
      └─────────────┘              └─────────────┘
```

**代码位置**: `unified-storage.ts:98-111`

```typescript
function getBackendFor(key: string[]): "local" | "cos" | "pg" {
  if (isLocal()) {
    return "local"
  }

  const storageType = key[0]
  const isSessionData = ["session", "message", "part", "share",
    "session_diff", "permission", "session_share", "todo", "project"]
    .includes(storageType)

  if (config.usePGForSessions && isSessionData) {
    return "pg"
  }

  return "cos"
}
```

**设计原因**:
- 会话元数据需要快速查询（按项目、时间范围等）→ 使用 PostgreSQL
- 大文件和工作区文件 → 使用对象存储 (COS)
- 本地开发模式 → 使用本地文件系统

### 2.3 数据库 Schema 关系图

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           PostgreSQL Schema                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────┐       ┌─────────────┐       ┌─────────────┐           │
│  │   project   │       │   session   │       │   message   │           │
│  ├─────────────┤       ├─────────────┤       ├─────────────┤           │
│  │ id (PK)     │──┐    │ id (PK)     │──┐    │ id (PK)     │           │
│  │ worktree    │  │    │ project_id  │◀─┘    │ session_id  │◀──┐       │
│  │ name        │  │    │ slug        │       │ role        │   │       │
│  │ vcs         │  │    │ title       │       │ agent       │   │       │
│  │ created_at  │  │    │ version     │       │ model_id    │   │       │
│  │ data (JSONB)│  │    │ created_at  │       │ cost        │   │       │
│  └─────────────┘  │    │ data (JSONB)│       │ data (JSONB)│   │       │
│                   │    └─────────────┘       └──────┬──────┘   │       │
│                   │           │                     │          │       │
│                   │           │    ┌────────────────┘          │       │
│                   │           │    │                           │       │
│                   │           ▼    ▼                           │       │
│                   │    ┌─────────────┐       ┌─────────────┐   │       │
│                   │    │    part     │       │    todo     │   │       │
│                   │    ├─────────────┤       ├─────────────┤   │       │
│                   │    │ id (PK)     │       │ id (PK)     │   │       │
│                   │    │ message_id  │       │ session_id  │───┘       │
│                   │    │ data (JSONB)│       │ data (JSONB)│           │
│                   │    └─────────────┘       └─────────────┘           │
│                   │                                                     │
│  ┌─────────────┐  │    ┌─────────────┐       ┌─────────────┐           │
│  │ permission  │  │    │session_share│       │session_diff │           │
│  ├─────────────┤  │    ├─────────────┤       ├─────────────┤           │
│  │ id (PK)     │  │    │ id (PK)     │       │ id (PK)     │           │
│  │ project_id  │◀─┘    │ secret      │       │ session_id  │           │
│  │ data (JSONB)│       │ url         │       │ data (JSONB)│           │
│  └─────────────┘       │ data (JSONB)│       └─────────────┘           │
│                        └─────────────┘                                 │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.4 文件位置
```
packages/opencode/src/storage/
├── pg-storage.ts      # 核心 PG 实现 (1213 行)
├── pg-schema.ts       # 数据库 Schema (228 行)
├── unified-storage.ts # 统一存储抽象 (501 行)
├── init-pg.ts         # 初始化管理 (156 行)
└── storage.ts         # 本地存储回退 (228 行)
```

### 2.5 连接池配置

**代码位置**: `pg-storage.ts:127-132`

```typescript
pool = new Pool({
  connectionString: databaseUrl,
  max: 20,                      // 最大并发连接
  idleTimeoutMillis: 30000,     // 30秒空闲超时
  connectionTimeoutMillis: 5000 // 5秒连接超时
})
```

**设计原因**:
- `max: 20`: 控制连接数，避免数据库过载
- `idleTimeoutMillis: 30000`: 回收空闲连接，节约资源
- `connectionTimeoutMillis: 5000`: 快速失败，避免阻塞

### 2.6 双列存储设计详解

**代码位置**: `pg-schema.ts:15-37` (session 表示例)

```typescript
{
  name: "session",
  sql: `
    CREATE TABLE IF NOT EXISTS session (
      id VARCHAR(64) PRIMARY KEY,
      project_id VARCHAR(64) NOT NULL,
      slug VARCHAR(64) NOT NULL,
      title TEXT,
      version VARCHAR(32) DEFAULT 'local',
      directory TEXT,
      summary_files INTEGER DEFAULT 0,
      summary_additions INTEGER DEFAULT 0,
      summary_deletions INTEGER DEFAULT 0,
      created_at BIGINT NOT NULL,           -- 展开字段：毫秒时间戳
      updated_at BIGINT NOT NULL,           -- 展开字段：毫秒时间戳
      data JSONB NOT NULL,                   -- 完整 JSON 数据
      created_at_ts TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    )
  `,
  indexes: [
    "CREATE INDEX IF NOT EXISTS session_project_id_idx ON session(project_id, created_at DESC)",
    "CREATE INDEX IF NOT EXISTS session_slug_idx ON session(slug)",
  ],
}
```

**设计原因**:
1. **双列模式**（展开字段 + JSONB）:
   - 展开字段 (`project_id`, `created_at` 等) 用于高效索引和查询
   - `data` JSONB 列保存完整对象，支持灵活的数据结构变更

2. **BIGINT 时间戳**: 毫秒精度，比 TIMESTAMP 更高效的范围查询

3. **复合索引** `(project_id, created_at DESC)`: 优化 "按项目列出最近会话" 查询

### 2.7 字段提取与 Upsert 实现

**代码位置**: `pg-storage.ts:193-219` (extractSessionFields)

```typescript
function extractSessionFields(data: SessionData): Record<string, unknown> {
  const createdAt = data.time?.created
    ? typeof data.time.created === "string"
      ? new Date(data.time.created).getTime()  // 处理字符串时间
      : data.time.created
    : Date.now()
  const updatedAt = data.time?.updated
    ? typeof data.time.updated === "string"
      ? new Date(data.time.updated).getTime()
      : data.time.updated
    : createdAt

  return {
    id: data.id,
    project_id: data.projectID,
    slug: data.slug,
    title: data.title || null,
    version: data.version || "local",
    directory: data.directory || null,
    summary_files: data.summary?.files || 0,
    summary_additions: data.summary?.additions || 0,
    summary_deletions: data.summary?.deletions || 0,
    created_at: createdAt,
    updated_at: updatedAt,
    data: JSON.stringify(data),  // 保存完整 JSON
  }
}
```

**代码位置**: `pg-storage.ts:254-286` (writeSession with ON CONFLICT)

```typescript
await poolClient.query(
  `INSERT INTO session (
    id, project_id, slug, title, version, directory,
    summary_files, summary_additions, summary_deletions,
    created_at, updated_at, data
  ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
  ON CONFLICT (id) DO UPDATE SET
    project_id = EXCLUDED.project_id,
    slug = EXCLUDED.slug,
    title = EXCLUDED.title,
    version = EXCLUDED.version,
    directory = EXCLUDED.directory,
    summary_files = EXCLUDED.summary_files,
    summary_additions = EXCLUDED.summary_additions,
    summary_deletions = EXCLUDED.summary_deletions,
    updated_at = EXCLUDED.updated_at,
    data = EXCLUDED.data`,
  [/* ... 参数 ... */]
)
```

**设计原因**:
- `ON CONFLICT ... DO UPDATE`: 实现幂等的 upsert 操作，无需事务开销
- 比 "先查询再插入/更新" 模式更高效，避免竞态条件

### 2.8 已知问题与建议修复

#### 问题 1: 连接泄漏风险 (中等严重性)

**位置**: `pg-storage.ts:812-884` (write 函数中的 generic 分支)

```typescript
export async function write<T>(key: string[], content: T): Promise<void> {
  // ...
  const client = await poolClient.connect()  // 获取连接

  try {
    await client.query("BEGIN")
    // ... 操作 ...
    await client.query("COMMIT")
  } catch (err) {
    await client.query("ROLLBACK")
    throw err
  } finally {
    client.release()  // ✅ 正确释放
  }
}
```

**问题**: 虽然当前实现有 `finally` 块，但如果 `poolClient.connect()` 成功后，`BEGIN` 之前发生错误，`finally` 不会执行。

**建议修复**:
```typescript
const client = await poolClient.connect()
try {
  await client.query("BEGIN")
  // ...
} catch (err) {
  await client.query("ROLLBACK").catch(() => {})  // 忽略 rollback 错误
  throw err
} finally {
  client.release()  // 始终释放
}
```

#### 问题 2: 缺少数据库连接健康检查 (低严重性)

**位置**: `pg-storage.ts:117-145`

**问题**: `init()` 只在启动时测试连接，长时间运行后连接可能失效。

**建议修复**:
```typescript
// 添加周期性健康检查
let healthCheckInterval: NodeJS.Timeout | null = null

export async function init() {
  // ... 现有初始化代码 ...

  // 启动健康检查
  healthCheckInterval = setInterval(async () => {
    try {
      await pool?.query('SELECT 1')
    } catch (err) {
      log.error("Database health check failed", { error: err })
      // 可选: 触发重连或告警
    }
  }, 60000)  // 每分钟检查一次
}
```

#### 问题 3: SQL 注入风险 - 动态表名 (高严重性)

**位置**: `pg-storage.ts:777-779`

```typescript
const result = await poolClient.query(
  `SELECT data FROM ${table} WHERE id = $1`,  // ⚠️ 动态表名
  [id]
)
```

**问题**: 虽然 `table` 来自 `parseKey()` 的白名单，但如果 `parseKey` 逻辑被修改或绕过，可能导致 SQL 注入。

**建议修复**:
```typescript
const ALLOWED_TABLES = new Set([
  "session", "message", "part", "share", "session_diff",
  "permission", "session_share", "todo", "project"
])

function validateTable(table: string): string {
  if (!ALLOWED_TABLES.has(table)) {
    throw new Error(`Invalid table name: ${table}`)
  }
  return table
}

// 使用时
const safeTable = validateTable(table)
const result = await poolClient.query(
  `SELECT data FROM ${safeTable} WHERE id = $1`,
  [id]
)
```

---

## 3. COS 文件同步实现

### 3.1 同步模式架构

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          COS 同步系统                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌───────────────┐   ┌───────────────┐   ┌───────────────┐             │
│  │   REALTIME    │   │    BATCH      │   │    MANUAL     │             │
│  │    模式       │   │     模式      │   │     模式      │             │
│  └───────┬───────┘   └───────┬───────┘   └───────┬───────┘             │
│          │                   │                   │                      │
│          ▼                   ▼                   ▼                      │
│  ┌───────────────┐   ┌───────────────┐   ┌───────────────┐             │
│  │  立即上传     │   │ 队列 + 定时   │   │  手动触发     │             │
│  │  延迟: ~0ms   │   │ 延迟: 30s     │   │  延迟: N/A    │             │
│  └───────┬───────┘   └───────┬───────┘   └───────┬───────┘             │
│          │                   │                   │                      │
│          └───────────────────┴───────────────────┘                      │
│                              │                                          │
│                              ▼                                          │
│                    ┌─────────────────┐                                  │
│                    │   COS Client    │                                  │
│                    │   (SDK v5)      │                                  │
│                    └────────┬────────┘                                  │
│                             │                                           │
│                             ▼                                           │
│                    ┌─────────────────┐                                  │
│                    │   腾讯云 COS    │                                  │
│                    │   对象存储      │                                  │
│                    └─────────────────┘                                  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.2 双向同步工作流

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        双向同步流程                                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────────┐                    ┌──────────────────┐          │
│  │    本地文件系统   │                    │    腾讯云 COS    │          │
│  └────────┬─────────┘                    └────────┬─────────┘          │
│           │                                       │                     │
│           ▼                                       ▼                     │
│  ┌──────────────────┐                    ┌──────────────────┐          │
│  │  扫描本地目录     │                    │  列出远程对象    │          │
│  │  计算 MD5 哈希    │                    │  获取 ETag      │          │
│  └────────┬─────────┘                    └────────┬─────────┘          │
│           │                                       │                     │
│           └───────────────┬───────────────────────┘                     │
│                           ▼                                             │
│                  ┌─────────────────┐                                    │
│                  │   比较差异       │                                    │
│                  │ (hash vs etag)  │                                    │
│                  └────────┬────────┘                                    │
│                           │                                             │
│           ┌───────────────┴───────────────┐                            │
│           ▼                               ▼                            │
│  ┌─────────────────┐             ┌─────────────────┐                   │
│  │ 本地有/远程无    │             │ 远程有/本地无    │                   │
│  │ 或 hash 不同    │             │ 且 mtime 更新   │                   │
│  └────────┬────────┘             └────────┬────────┘                   │
│           │                               │                            │
│           ▼                               ▼                            │
│  ┌─────────────────┐             ┌─────────────────┐                   │
│  │  上传到 COS     │             │  下载到本地      │                   │
│  │  (PUT Object)  │             │  (GET Object)   │                   │
│  └─────────────────┘             └─────────────────┘                   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.3 核心同步逻辑实现

**代码位置**: `cos/index.ts:237-335` (fullSync)

```typescript
export async function fullSync(sessionID: string): Promise<{
  uploaded: number
  downloaded: number
  deleted: number
}> {
  const state = syncStates.get(sessionID)
  if (!state) {
    throw new Error(`No sync state for session ${sessionID}`)
  }

  // ⚠️ 问题1: 简单的布尔锁，多并发请求可能导致竞态
  if (state.syncInProgress) {
    log.debug("sync already in progress, skipping", { sessionID })
    return { uploaded: 0, downloaded: 0, deleted: 0 }
  }

  state.syncInProgress = true
  // ...

  try {
    // 扫描本地文件
    state.localFiles = await scanLocalDirectory(state.workdir, config.exclude)

    // 列出远程文件
    const prefix = `${config.pathPrefix}/${state.projectID}/${sessionID}/`
    const remoteObjects = await COSClient.listObjects(config.cos, prefix)

    // 上传: 本地有但远程没有，或 hash 不同
    for (const [relativePath, localFile] of state.localFiles) {
      const remoteFile = state.remoteFiles.get(relativePath)
      const needUpload = !remoteFile || remoteFile.etag !== localFile.hash

      if (needUpload) {
        const key = COSConfig.buildObjectKey(/* ... */)
        const content = await fs.readFile(localFile.absolutePath)
        await COSClient.uploadFile(config.cos, key, content)
        uploaded++
      }
    }

    // 下载: 远程有但本地没有，且远程更新
    for (const [relativePath, remoteFile] of state.remoteFiles) {
      const localFile = state.localFiles.get(relativePath)
      // ⚠️ 问题2: 仅比较 mtime，不够精确
      const needDownload =
        !localFile ||
        (remoteFile.lastModified.getTime() > localFile.mtime &&
         remoteFile.etag !== localFile.hash)

      if (needDownload) {
        // ... 下载逻辑 ...
      }
    }
  } finally {
    state.syncInProgress = false
  }
}
```

### 3.4 文件哈希计算

**代码位置**: `cos/index.ts:111-116`

```typescript
async function hashFile(filePath: string): Promise<string> {
  const content = await Bun.file(filePath).arrayBuffer()
  const hash = crypto.createHash("md5")
  hash.update(Buffer.from(content))
  return hash.digest("hex")
}
```

**设计原因**:
- 使用 MD5 哈希与 COS ETag 对比，检测文件变更
- COS 对于非分片上传的对象，ETag 就是 MD5

### 3.5 COS 路径结构
```
{pathPrefix}/{projectID}/{sessionID}/
├── metadata/
│   ├── session.json
│   ├── messages/{messageID}.json
│   └── parts/{messageID}/{partID}.json
├── files/{relativePath}
└── snapshots/{snapshotID}.json
```

### 3.6 已知问题与建议修复

#### 问题 1: 同步竞态条件 (高严重性)

**位置**: `cos/index.ts:247-250`

```typescript
if (state.syncInProgress) {
  log.debug("sync already in progress, skipping", { sessionID })
  return { uploaded: 0, downloaded: 0, deleted: 0 }
}
state.syncInProgress = true  // ⚠️ 非原子操作
```

**问题**: 两个并发的 `fullSync` 调用可能同时通过 `if` 检查，导致重复同步或数据损坏。

**建议修复**:
```typescript
// 使用互斥锁
import { Mutex } from 'async-mutex'

const syncMutex = new Map<string, Mutex>()

export async function fullSync(sessionID: string) {
  let mutex = syncMutex.get(sessionID)
  if (!mutex) {
    mutex = new Mutex()
    syncMutex.set(sessionID, mutex)
  }

  return mutex.runExclusive(async () => {
    // ... 同步逻辑 ...
  })
}
```

#### 问题 2: 冲突检测不完善 (中等严重性)

**位置**: `cos/index.ts:305-310`

```typescript
const needDownload =
  !localFile ||
  (remoteFile.lastModified.getTime() > localFile.mtime &&
   remoteFile.etag !== localFile.hash)
```

**问题**: 如果本地和远程同时修改同一文件，当前逻辑会用远程版本覆盖本地，可能丢失本地修改。

**建议修复**:
```typescript
// 检测真正的冲突
const hasLocalChange = localFile && localFile.hash !== originalHash
const hasRemoteChange = remoteFile && remoteFile.etag !== originalEtag

if (hasLocalChange && hasRemoteChange) {
  // 记录冲突，让用户决定
  conflicts.push({
    path: relativePath,
    local: localFile,
    remote: remoteFile,
  })
  continue
}

if (hasRemoteChange) {
  // 只有远程变更，安全下载
}
```

#### 问题 3: 大文件同步性能 (低严重性)

**位置**: `cos/index.ts:111-116`

```typescript
async function hashFile(filePath: string): Promise<string> {
  const content = await Bun.file(filePath).arrayBuffer()  // ⚠️ 全量读入内存
  // ...
}
```

**问题**: 大文件会被完整读入内存进行哈希，可能导致 OOM。

**建议修复**:
```typescript
async function hashFile(filePath: string): Promise<string> {
  const hash = crypto.createHash("md5")
  const stream = fs.createReadStream(filePath)

  for await (const chunk of stream) {
    hash.update(chunk)
  }

  return hash.digest("hex")
}
```

---

## 4. 远程沙箱实现

### 4.1 沙箱执行器架构

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          沙箱执行器系统                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│                    ┌─────────────────────┐                              │
│                    │   Sandbox.execute() │                              │
│                    │   (统一入口)         │                              │
│                    └──────────┬──────────┘                              │
│                               │                                         │
│              ┌────────────────┼────────────────┐                        │
│              ▼                ▼                ▼                        │
│     ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                  │
│     │   LOCAL     │  │   DOCKER    │  │   REMOTE    │                  │
│     │  Executor   │  │  Executor   │  │  Executor   │                  │
│     └──────┬──────┘  └──────┬──────┘  └──────┬──────┘                  │
│            │                │                │                          │
│            ▼                ▼                ▼                          │
│     ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                  │
│     │  直接执行    │  │ 容器 + COS  │  │ E2B/AGS +   │                  │
│     │  (无隔离)   │  │  双向同步   │  │  COS 挂载   │                  │
│     └─────────────┘  └─────────────┘  └─────────────┘                  │
│            │                │                │                          │
│            ▼                ▼                ▼                          │
│     ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                  │
│     │   主机      │  │   Docker    │  │  云端沙箱   │                  │
│     │  进程       │  │   容器      │  │  (E2B/AGS)  │                  │
│     └─────────────┘  └─────────────┘  └─────────────┘                  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 4.2 执行器对比

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         执行器对比                                       │
├───────────┬───────────────┬───────────────────┬─────────────────────────┤
│  执行器    │    隔离级别    │     文件同步       │       使用场景          │
├───────────┼───────────────┼───────────────────┼─────────────────────────┤
│           │               │                   │                         │
│  Local    │    无隔离     │       无          │   本地开发/调试          │
│           │   ┌─────┐    │                   │                         │
│           │   │ Host│    │                   │                         │
│           │   └─────┘    │                   │                         │
│           │               │                   │                         │
├───────────┼───────────────┼───────────────────┼─────────────────────────┤
│           │               │                   │                         │
│  Docker   │   容器级隔离   │   双向 COS 同步   │   本地隔离执行          │
│           │   ┌─────┐    │  ┌────┐  ┌────┐  │                         │
│           │   │Container│ │  │本地│◀▶│COS │  │                         │
│           │   └─────┘    │  └────┘  └────┘  │                         │
│           │               │                   │                         │
├───────────┼───────────────┼───────────────────┼─────────────────────────┤
│           │               │                   │                         │
│  Remote   │   完全隔离     │    COS 挂载      │   云端安全沙箱          │
│           │   ┌─────┐    │       ┌────┐     │                         │
│           │   │E2B/ │    │  Mount│COS │     │                         │
│           │   │ AGS │◀───│───────┴────┘     │                         │
│           │   └─────┘    │                   │                         │
│           │               │                   │                         │
└───────────┴───────────────┴───────────────────┴─────────────────────────┘
```

### 4.3 Remote 执行器 COS 挂载实现

**代码位置**: `remote.ts:152-217` (ensureSandbox)

```typescript
private async ensureSandbox(): Promise<E2BSandbox> {
  if (this.sandbox) {
    try {
      const running = await this.sandbox.isRunning()
      if (running) return this.sandbox
    } catch {
      // Sandbox 可能已失效，重建
    }
    this.sandbox = null
  }

  // 构建 COS 挂载配置
  const cosMounts = [
    {
      name: 'cwork',
      mountPath: this.getWorkdir(),  // 默认 /home/workspace
      readOnly: false,
      subPath: this.getCOSMountPath(),  // opencode/{proj}/{sess}/files
    }
  ]

  // 通过 metadata 传递挂载配置给 E2B/AGS
  const metadata: Record<string, string> = {}
  if (cosMounts && cosMounts.length > 0) {
    metadata["x-mounts"] = JSON.stringify(cosMounts)
    log.info("adding COS mounts", { sessionID: this.sessionID, mounts: cosMounts })
  }

  // 创建沙箱实例
  const { Sandbox: E2BSandboxClass } = await import("@e2b/code-interpreter")
  this.sandbox = await E2BSandboxClass.create(template, {
    timeoutMs,
    metadata: Object.keys(metadata).length > 0 ? metadata : undefined,
  })

  // 确保工作目录存在
  await this.sandbox.commands.run(`mkdir -p "${workdir}"`)

  return this.sandbox
}
```

**设计原因**:
- 使用 `x-mounts` metadata 将 COS 挂载配置传递给云端沙箱
- 云端沙箱直接挂载 COS，无需手动文件同步
- 文件变更自动持久化到 COS

### 4.4 Remote 执行器环境配置

**代码位置**: `remote.ts:124-147` (setupE2BEnv)

```typescript
private setupE2BEnv(): void {
  // E2B SDK 读取这些环境变量:
  // - E2B_API_KEY: API 认证密钥
  // - E2B_DOMAIN: 自定义域名 (如腾讯 AGS)

  // 优先级: config.apiKey > Flag 环境变量 > 现有环境变量
  if (this.config.apiKey) {
    process.env["E2B_API_KEY"] = this.config.apiKey
  } else if (Flag.OPENCODE_SANDBOX_REMOTE_API_KEY) {
    process.env["E2B_API_KEY"] = Flag.OPENCODE_SANDBOX_REMOTE_API_KEY
  }

  // 从 URL 提取域名
  if (this.config.url) {
    try {
      const url = new URL(this.config.url)
      process.env["E2B_DOMAIN"] = url.hostname
    } catch {
      process.env["E2B_DOMAIN"] = this.config.url
    }
  }
}
```

**问题**: 直接修改 `process.env` 是全局的，多个并发 Remote 执行器可能互相覆盖配置。

### 4.5 Docker 隔离模式详解

**代码位置**: `docker.ts:345-429` (createContainer)

```typescript
private async createContainer(): Promise<string> {
  const args = ["run", "-d", "--rm"]
  const isMacOS = process.platform === "darwin"

  // 容器命名
  const containerName = `opencode-${this.sessionID}`.replace(/[^a-zA-Z0-9_.-]/g, "-")
  args.push("--name", containerName)

  // 添加标签用于识别和清理
  args.push("--label", "opencode.sandbox=true")
  args.push("--label", `opencode.session=${this.sessionID}`)

  // 网络模式 (macOS 不完全支持 host 模式)
  if (this.config.network === "host" && isMacOS) {
    log.warn("host network mode is not fully supported on macOS, using bridge instead")
    args.push("--network", "bridge")
  } else {
    args.push("--network", this.config.network)
  }

  // 资源限制
  if (this.config.memory) args.push("--memory", this.config.memory)
  if (this.config.cpu) args.push("--cpus", String(this.config.cpu))

  // 工作目录挂载
  const projectDir = Instance.directory
  const mountSuffix = isMacOS ? ":delegated" : ""

  if (this.config.isolateWorkdir && this.isolatedWorkdir) {
    // 隔离模式: 会话目录挂载为 /workspace，项目目录只读挂载为 /project
    args.push("-v", `${this.isolatedWorkdir}:${this.config.workdir}${mountSuffix}`)
    args.push("-v", `${projectDir}:/project:ro${isMacOS ? ",delegated" : ""}`)
  } else {
    // 共享模式: 项目目录直接挂载为 /workspace
    args.push("-v", `${projectDir}:${this.config.workdir}${mountSuffix}`)
  }
  args.push("-w", this.config.workdir)

  // ... 更多配置 ...
}
```

### 4.6 Docker 空闲超时机制

**代码位置**: `docker.ts:415-428`

```typescript
if (this.config.idleTimeout && this.config.idleTimeout > 0) {
  const timeoutSeconds = Math.floor(this.config.idleTimeout / 1000)
  // 使用 shell 脚本监控 activity 文件的修改时间
  args.push(
    this.config.image,
    "/bin/sh",
    "-c",
    `touch /tmp/.opencode_activity; while true; do sleep 30; ` +
    `if [ $(($(date +%s) - $(stat -c %Y /tmp/.opencode_activity 2>/dev/null || ` +
    `stat -f %m /tmp/.opencode_activity 2>/dev/null || echo 0))) -gt ${timeoutSeconds} ]; ` +
    `then exit 0; fi; done`,
  )
} else {
  // 无超时，容器持续运行
  args.push(this.config.image, "tail", "-f", "/dev/null")
}
```

**代码位置**: `docker.ts:514-515` (execute 时更新 activity)

```typescript
// 如果配置了空闲超时，在命令前添加 touch 命令更新活动时间戳
const touchCmd = this.config.idleTimeout ? "touch /tmp/.opencode_activity; " : ""
args.push(containerID, "/bin/sh", "-c", touchCmd + options.command)
```

**设计原因**:
- 使用 `/tmp/.opencode_activity` 文件的 mtime 追踪最后活动时间
- 每次执行命令前 touch 该文件
- 容器内脚本定期检查，超时则自动退出

### 4.7 Docker 文件操作实现

**代码位置**: `docker.ts:692-716` (writeFile)

```typescript
async writeFile(filepath: string, content: string): Promise<void> {
  if (this.config.isolateWorkdir) {
    await this.ensureContainer()
    const containerPath = this.toSandboxPath(filepath)

    // ⚠️ 安全问题: 使用 heredoc 写入文件
    const result = await this.execute({
      command: `mkdir -p "$(dirname '${containerPath}')" && ` +
               `cat > '${containerPath}' << 'OPENCODE_EOF'\n${content}\nOPENCODE_EOF`,
      timeout: 30000,
    })

    if (result.exitCode !== 0) {
      throw new Error(`Failed to write file in container: ${result.stderr}`)
    }
  } else {
    // 非隔离模式: 直接写入主机
    const dir = path.dirname(filepath)
    await fs.mkdir(dir, { recursive: true })
    await fs.writeFile(filepath, content, "utf-8")
  }
}
```

### 4.8 已知问题与建议修复

#### 问题 1: Docker 命令注入 (高严重性)

**位置**: `docker.ts:701-705`

```typescript
const result = await this.execute({
  command: `mkdir -p "$(dirname '${containerPath}')" && ` +
           `cat > '${containerPath}' << 'OPENCODE_EOF'\n${content}\nOPENCODE_EOF`,
  // ...
})
```

**问题**: 如果 `containerPath` 或 `content` 包含特殊字符（如 `'`、`\n`、`OPENCODE_EOF`），可能导致命令注入或文件写入失败。

**攻击向量**:
```typescript
// content 包含: "OPENCODE_EOF\n'; rm -rf /; echo '"
// 会导致: cat > '/path' << 'OPENCODE_EOF'
//         OPENCODE_EOF
//         '; rm -rf /; echo '
//         OPENCODE_EOF
```

**建议修复**:
```typescript
async writeFile(filepath: string, content: string): Promise<void> {
  if (this.config.isolateWorkdir) {
    await this.ensureContainer()
    const containerPath = this.toSandboxPath(filepath)

    // 使用 base64 编码避免转义问题
    const encoded = Buffer.from(content).toString('base64')
    const result = await this.execute({
      command: `mkdir -p "$(dirname '${containerPath}')" && ` +
               `echo "${encoded}" | base64 -d > '${containerPath}'`,
      timeout: 30000,
    })
    // ...
  }
}
```

#### 问题 2: Remote 执行器全局环境变量污染 (中等严重性)

**位置**: `remote.ts:124-147`

```typescript
private setupE2BEnv(): void {
  if (this.config.apiKey) {
    process.env["E2B_API_KEY"] = this.config.apiKey  // ⚠️ 全局修改
  }
}
```

**问题**: 多个并发 Remote 执行器使用不同配置时，全局 `process.env` 修改会导致竞态条件。

**建议修复**:
```typescript
// 使用 E2B SDK 的实例级配置（如果支持）
this.sandbox = await E2BSandboxClass.create(template, {
  timeoutMs,
  metadata,
  apiKey: this.config.apiKey,  // 实例级配置
  domain: this.config.url ? new URL(this.config.url).hostname : undefined,
})

// 或者在创建前后使用临时环境变量
const originalApiKey = process.env["E2B_API_KEY"]
try {
  process.env["E2B_API_KEY"] = this.config.apiKey
  this.sandbox = await E2BSandboxClass.create(...)
} finally {
  if (originalApiKey) {
    process.env["E2B_API_KEY"] = originalApiKey
  } else {
    delete process.env["E2B_API_KEY"]
  }
}
```

#### 问题 3: COS 挂载初始化顺序问题 (中等严重性)

**位置**: `remote.ts:72-106`

```typescript
async initCOSSync(): Promise<void> {
  // ...
  // 创建占位文件以确保 COS 目录存在
  const placeholderKey = `${mountPath}/.placeholder`
  try {
    await COSClient.uploadFile(config.cos, placeholderKey, "")
  } catch (err) {
    log.warn("failed to create COS directory placeholder", { error: err })
    // 继续执行 - 挂载可能仍然有效 ⚠️
  }
  this.cosInitialized = true
}
```

**问题**: 如果 COS 占位文件创建失败但继续执行，后续挂载可能失败，但 `cosInitialized` 已被设为 `true`。

**建议修复**:
```typescript
async initCOSSync(): Promise<void> {
  // ...
  try {
    await COSClient.uploadFile(config.cos, placeholderKey, "")
    this.cosInitialized = true  // 仅在成功后设置
  } catch (err) {
    log.error("failed to initialize COS mount", { error: err })
    throw new Error(`COS mount initialization failed: ${err}`)
  }
}
```

#### 问题 4: Docker 容器资源泄漏 (低严重性)

**位置**: `docker.ts:830-884` (dispose)

```typescript
async dispose(): Promise<void> {
  // ...
  if (this.containerID) {
    await new Promise<void>((resolve) => {
      const proc = spawn("docker", ["stop", "-t", "5", this.containerID!], {
        stdio: ["ignore", "ignore", "ignore"],
      })

      proc.once("exit", () => {
        // ...
        resolve()
      })

      proc.once("error", () => {
        resolve()  // ⚠️ 错误时也 resolve，不重试
      })
    })
  }
}
```

**问题**: 如果 `docker stop` 失败（如 Docker 守护进程无响应），容器不会被清理。

**建议修复**:
```typescript
async dispose(): Promise<void> {
  // ...
  if (this.containerID) {
    try {
      // 尝试优雅停止
      await this.runDockerCommand(["stop", "-t", "5", this.containerID])
    } catch (stopErr) {
      log.warn("graceful stop failed, trying force kill", { err: stopErr })
      try {
        // 强制杀死
        await this.runDockerCommand(["kill", this.containerID])
      } catch (killErr) {
        log.error("failed to kill container", { err: killErr })
      }
    } finally {
      // 确保从注册表移除
      containers.delete(this.sessionID)
    }
  }
}
```

---

## 5. 企业版和控制台架构

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          企业版架构                                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                     packages/console/                             │ │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐│ │
│  │  │  app/   │  │  core/  │  │function/│  │  mail/  │  │resource/││ │
│  │  │SolidSt- │  │ Drizzle │  │Cloudfl- │  │  JSX    │  │ 资源管理 ││ │
│  │  │  art UI │  │  ORM    │  │  are    │  │ Email   │  │         ││ │
│  │  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘│ │
│  └───────┴────────────┴────────────┴────────────┴────────────┴──────┘ │
│                              │                                         │
│                              ▼                                         │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                     外部服务集成                                   │ │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐│ │
│  │  │PlanetSc-│  │ Stripe  │  │  OAuth  │  │Honeycomb│  │ Email-  ││ │
│  │  │ale MySQL│  │ 支付    │  │GitHub/  │  │可观测性 │  │ Octopus ││ │
│  │  │         │  │         │  │ Google  │  │         │  │         ││ │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────┘  └─────────┘│ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 6. SST 基础设施

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     SST/Cloudflare 基础设施                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  infra/app.ts                          infra/console.ts                │
│  ┌─────────────────────────┐          ┌─────────────────────────┐     │
│  │  ┌─────────────────┐   │          │  ┌─────────────────┐   │     │
│  │  │Cloudflare Worker│   │          │  │  PlanetScale    │   │     │
│  │  │    (API)        │   │          │  │    MySQL        │   │     │
│  │  └─────────────────┘   │          │  └─────────────────┘   │     │
│  │  ┌─────────────────┐   │          │  ┌─────────────────┐   │     │
│  │  │ Durable Objects │   │          │  │  Cloudflare KV  │   │     │
│  │  │  (Sync Server)  │   │          │  │   (Auth Store)  │   │     │
│  │  └─────────────────┘   │          │  └─────────────────┘   │     │
│  │  ┌─────────────────┐   │          │  ┌─────────────────┐   │     │
│  │  │  GitHub App     │   │          │  │    Stripe       │   │     │
│  │  │  Integration    │   │          │  │   Webhooks      │   │     │
│  │  └─────────────────┘   │          │  └─────────────────┘   │     │
│  └─────────────────────────┘          │  ┌─────────────────┐   │     │
│                                        │  │   AWS SES       │   │     │
│  infra/enterprise.ts                   │  │    Email        │   │     │
│  ┌─────────────────────────┐          │  └─────────────────┘   │     │
│  │  ┌─────────────────┐   │          └─────────────────────────┘     │
│  │  │  Cloudflare R2  │   │                                          │
│  │  │ (Object Storage)│   │                                          │
│  │  └─────────────────┘   │                                          │
│  │  ┌─────────────────┐   │                                          │
│  │  │  Team Features  │   │                                          │
│  │  └─────────────────┘   │                                          │
│  └─────────────────────────┘                                          │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 7. 关键设计决策

| 决策 | 原因 | 实现位置 |
|------|------|----------|
| **双列存储** | 查询需要展开字段和完整 JSON | `pg-schema.ts:15-37` |
| **BIGINT 时间戳** | 毫秒精度，高效范围查询 | `pg-schema.ts:27-28` |
| **ON CONFLICT** | 幂等 upsert 无需事务开销 | `pg-storage.ts:255-271` |
| **COS 挂载 vs 同步** | 远程执行器无需同步开销 | `remote.ts:166-176` |
| **防抖文件监听** | 避免编辑时频繁同步 | `watcher.ts` (1000ms) |
| **批量模式默认** | 平衡延迟和网络效率 | `scheduler.ts` (30s) |

---

## 8. 问题汇总与优先级

| 优先级 | 模块 | 问题 | 严重性 | 位置 |
|--------|------|------|--------|------|
| P0 | Docker | 命令注入漏洞 | 高 | `docker.ts:701-705` |
| P0 | PG | SQL 注入风险 (动态表名) | 高 | `pg-storage.ts:777-779` |
| P1 | COS | 同步竞态条件 | 高 | `cos/index.ts:247-250` |
| P1 | COS | 冲突检测不完善 | 中 | `cos/index.ts:305-310` |
| P1 | Remote | 全局环境变量污染 | 中 | `remote.ts:124-147` |
| P2 | Remote | COS 初始化顺序问题 | 中 | `remote.ts:72-106` |
| P2 | PG | 连接泄漏风险 | 中 | `pg-storage.ts:812-884` |
| P3 | Docker | 容器资源泄漏 | 低 | `docker.ts:830-884` |
| P3 | COS | 大文件同步性能 | 低 | `cos/index.ts:111-116` |
| P3 | PG | 缺少健康检查 | 低 | `pg-storage.ts:117-145` |

---

## 9. 总结

**cwork-core 实现了从桌面应用到云 SaaS 的完整转型:**

1. **存储层**: SQLite → PostgreSQL + COS 混合存储，支持会话元数据高效查询和大文件对象存储
2. **执行环境**: 本地 Electron → Local/Docker/Remote 三种执行器，支持 E2B 和腾讯 AGS
3. **文件同步**: 无 → 实时/批量/手动三种 COS 同步模式，MD5 哈希变更检测
4. **部署架构**: 桌面安装包 → SST/Cloudflare 全栈 Serverless
5. **企业功能**: 单用户 → 团队版 + 管理控制台 + Stripe 计费

**代码质量评估**:
- ✅ 良好的模块化和抽象
- ✅ 完善的日志记录
- ⚠️ 部分安全问题需要修复 (命令注入、SQL 注入风险)
- ⚠️ 并发控制需要加强 (COS 同步竞态)
- ⚠️ 资源清理需要更健壮 (容器泄漏)
