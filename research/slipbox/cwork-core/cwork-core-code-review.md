# cwork-core 代码级深度评审报告

**评审视角**: Meta Distinguished Software Engineer
**评审日期**: 2026-01-28
**代码版本**: cwork-core (研究阶段)
**预期规模**: 中等规模 (1K-10K 用户)

---

## 评审文件清单

| 模块 | 文件路径 | 代码行数 |
|------|---------|---------|
| DB Schema | `packages/opencode/src/storage/pg-schema.ts` | 228 |
| DB Storage | `packages/opencode/src/storage/pg-storage.ts` | 1213 |
| Unified Storage | `packages/opencode/src/storage/unified-storage.ts` | 501 |
| COS Sync | `packages/opencode/src/sandbox/cos/index.ts` | 574 |
| COS Client | `packages/opencode/src/sandbox/cos/client.ts` | 292 |
| Docker Executor | `packages/opencode/src/sandbox/docker.ts` | 912 |
| Remote Executor | `packages/opencode/src/sandbox/remote.ts` | 544 |
| Sandbox Index | `packages/opencode/src/sandbox/index.ts` | 587 |

---

## 1. 数据库 Schema 设计评审

### 1.1 Critical Issues

#### Issue #1: 缺少多租户隔离
**位置**: `pg-schema.ts:13-176` (所有表定义)

**问题描述**: 9 个表都没有 `tenant_id` 列，无法实现租户级数据隔离。

```typescript
// 当前设计 (pg-schema.ts:16-37)
{
  name: "session",
  sql: `
    CREATE TABLE IF NOT EXISTS session (
      id VARCHAR(64) PRIMARY KEY,
      project_id VARCHAR(64) NOT NULL,  // ⚠️ 无租户隔离
      slug VARCHAR(64) NOT NULL,
      ...
    )
  `,
}
```

**建议修复**:
```sql
CREATE TABLE IF NOT EXISTS session (
  id VARCHAR(64) PRIMARY KEY,
  tenant_id VARCHAR(64) NOT NULL,      -- 添加租户隔离
  project_id VARCHAR(64) NOT NULL,
  ...
  CONSTRAINT fk_session_tenant FOREIGN KEY (tenant_id) REFERENCES tenant(id)
)
CREATE INDEX IF NOT EXISTS session_tenant_idx ON session(tenant_id);
```

**风险评估**:
- **影响**: 用户可能访问到其他租户的数据
- **严重性**: Critical - 数据泄露风险
- **修复优先级**: P0 - 立即修复

---

#### Issue #2: SQL 注入风险 (防御不完整)
**位置**: `pg-storage.ts:777-779`

```typescript
export async function read<T>(key: string[]): Promise<T> {
  const { table, id } = parseKey(key)
  // ...
  const result = await poolClient.query(
    `SELECT data FROM ${table} WHERE id = $1`,  // ⚠️ 动态表名拼接
    [id]
  )
}
```

**问题描述**: 虽然 `parseKey()` 函数 (lines 158-184) 使用 switch 语句验证 `table` 值，但防御层次不够深入：

```typescript
// pg-storage.ts:158-184
function parseKey(key: string[]): { table: string; id: string; prefix?: string } {
  const storageType = key[0]
  switch (storageType) {
    case "session": return { table: "session", id, prefix: key[1] }
    case "message": return { table: "message", id, prefix: key[1] }
    // ... 等等
    default:
      throw new Error(`Unsupported storage type: ${storageType}`)
  }
}
```

**建议修复**:
```typescript
const ALLOWED_TABLES = new Set([
  'session', 'message', 'part', 'share',
  'session_diff', 'permission', 'session_share', 'todo', 'project'
])

function validateTable(table: string): string {
  if (!ALLOWED_TABLES.has(table)) {
    throw new Error(`Invalid table: ${table}`)
  }
  return table
}
```

**风险评估**:
- **当前状态**: Switch 语句提供了基本保护
- **严重性**: Medium - 需要增加二次防御
- **修复优先级**: P1

---

### 1.2 High Priority Issues

#### Issue #3: 缺少关键索引
**位置**: `pg-schema.ts:72-82` (part 表), `pg-schema.ts:105-116` (permission 表)

```typescript
// pg-schema.ts:72-82 - part 表缺少 message_id 索引
{
  name: "part",
  sql: `
    CREATE TABLE IF NOT EXISTS part (
      id VARCHAR(64) PRIMARY KEY,
      message_id VARCHAR(64) NOT NULL,  // ⚠️ 无索引，JOIN 会全表扫描
      data JSONB NOT NULL,
      ...
    )
  `,
  // indexes: []  ← 缺失！
}

// pg-schema.ts:105-116 - permission 表缺少 project_id 索引
{
  name: "permission",
  sql: `
    CREATE TABLE IF NOT EXISTS permission (
      ...
      project_id VARCHAR(64) NOT NULL,  // ⚠️ 无索引
      ...
    )
  `,
  // indexes: []  ← 缺失！
}
```

**影响分析**:
- `listMessages()` 查询 (pg-storage.ts:1027-1028) 按 `message_id` 过滤 parts 会导致全表扫描
- `list(["permission", projectID])` (pg-storage.ts:1031-1036) 同样会全表扫描

**建议修复**:
```typescript
{
  name: "part",
  sql: `...`,
  indexes: [
    "CREATE INDEX IF NOT EXISTS part_message_id_idx ON part(message_id, created_at ASC)",
  ],
}

{
  name: "permission",
  sql: `...`,
  indexes: [
    "CREATE INDEX IF NOT EXISTS permission_project_id_idx ON permission(project_id, created_at DESC)",
  ],
}
```

---

#### Issue #4: update 操作非原子性
**位置**: `pg-storage.ts:890-952`

```typescript
export async function update<T>(key: string[], fn: (draft: T) => void): Promise<T> {
  const { table, id } = parseKey(key)

  // 对于 session/message/project 使用专用方法
  if (table === "session") {
    const content = await readSession(id)  // ⚠️ 读取 (非事务)
    fn(content as unknown as T)             // ⚠️ 在内存中修改
    await writeSession(content)             // ⚠️ 写回 (可能覆盖并发修改)
    return content as unknown as T
  }
  // ... 类似模式用于 message, project
}
```

**问题描述**: Read-Modify-Write 模式没有使用数据库级锁或乐观锁，两个并发请求可能导致数据丢失：

```
时间线:
T1: 请求A 读取 session {version: 1}
T2: 请求B 读取 session {version: 1}
T3: 请求A 修改为 {version: 1, title: "A"}
T4: 请求B 修改为 {version: 1, title: "B"}
T5: 请求A 写入 {title: "A"}
T6: 请求B 写入 {title: "B"}  ← A 的修改丢失!
```

**建议修复** (乐观锁方案):
```typescript
// 1. 在 schema 中添加 version 列
version INTEGER NOT NULL DEFAULT 1

// 2. 修改 update 逻辑
export async function update<T>(key: string[], fn: (draft: T) => void): Promise<T> {
  const client = await pool.connect()
  try {
    await client.query('BEGIN')

    // SELECT ... FOR UPDATE 获取行锁
    const result = await client.query(
      `SELECT data, version FROM ${table} WHERE id = $1 FOR UPDATE`,
      [id]
    )

    const content = result.rows[0].data
    const currentVersion = result.rows[0].version

    fn(content)

    // 使用 version 检查并发修改
    const updateResult = await client.query(
      `UPDATE ${table} SET data = $1, version = version + 1, updated_at = $2
       WHERE id = $3 AND version = $4`,
      [JSON.stringify(content), new Date().toISOString(), id, currentVersion]
    )

    if (updateResult.rowCount === 0) {
      throw new Error('Concurrent modification detected, please retry')
    }

    await client.query('COMMIT')
    return content
  } catch (err) {
    await client.query('ROLLBACK')
    throw err
  } finally {
    client.release()
  }
}
```

---

### 1.3 Medium Priority Issues

| 问题 | 位置 | 说明 | 建议 |
|------|------|------|------|
| 连接池静态配置 | `pg-storage.ts:127-132` | `max: 20` 硬编码 | 改为 `Math.max(20, os.cpus().length * 4)` |
| 无事务隔离级别 | 全局 | 写操作未指定隔离级别 | 添加 `SET TRANSACTION ISOLATION LEVEL READ COMMITTED` |
| 时间戳类型不一致 | schema | session/message 用 BIGINT，其他用 TIMESTAMP | 统一为 TIMESTAMP WITH TIME ZONE |
| 无查询超时 | `pg-storage.ts:127-132` | 缺少 `statement_timeout` | 添加 `statement_timeout: 30000` |
| 无连接健康检查 | pool 配置 | 缺少连接验证 | 添加 `healthCheck: { enabled: true }` |

---

## 2. COS 同步实现评审

### 2.1 Critical Issues

#### Issue #5: 竞态条件 - syncInProgress 检查
**位置**: `cos/index.ts:247-257`

```typescript
export async function fullSync(sessionID: string): Promise<{...}> {
  const state = syncStates.get(sessionID)
  // ...

  if (state.syncInProgress) {                    // ⚠️ 检查
    log.debug("sync already in progress, skipping", { sessionID })
    return { uploaded: 0, downloaded: 0, deleted: 0 }
  }
  state.syncInProgress = true                     // ⚠️ 设置 - 不是原子操作!
```

**问题描述**: JavaScript 虽然是单线程的，但由于 async/await 的存在，两个并发调用可能同时通过检查：

```
时间线:
T1: 请求A 检查 syncInProgress = false ✓
T2: 请求B 检查 syncInProgress = false ✓  (A 还没来得及设置)
T3: 请求A 设置 syncInProgress = true
T4: 请求B 设置 syncInProgress = true
T5: 两个 sync 同时执行 → 文件冲突
```

**建议修复**:
```typescript
// 使用 Promise 作为锁
const syncLocks = new Map<string, Promise<SyncResult>>()

export async function fullSync(sessionID: string): Promise<SyncResult> {
  // 检查是否有正在进行的同步
  const existingLock = syncLocks.get(sessionID)
  if (existingLock) {
    log.debug("sync already in progress, waiting", { sessionID })
    return existingLock
  }

  // 创建新的同步 Promise
  const syncPromise = doFullSync(sessionID)
  syncLocks.set(sessionID, syncPromise)

  try {
    return await syncPromise
  } finally {
    syncLocks.delete(sessionID)
  }
}
```

---

#### Issue #6: 冲突解决策略不健壮
**位置**: `cos/index.ts:304-319`

```typescript
// Download: remote files that don't exist or are newer locally
for (const [relativePath, remoteFile] of state.remoteFiles) {
  const localFile = state.localFiles.get(relativePath)
  const needDownload =
    !localFile ||
    (remoteFile.lastModified.getTime() > localFile.mtime &&  // ⚠️ 时钟偏移问题
     remoteFile.etag !== localFile.hash)

  if (needDownload) {
    // ... download
  }
}
```

**问题描述**:
1. **时钟偏移**: 不同机器的系统时钟可能不同步，导致错误的冲突判断
2. **双向修改**: 没有处理"本地和远程都修改了同一文件"的情况

**场景示例**:
```
机器A (时钟快 5 秒):
  T1: 本地修改 file.txt, mtime = 1000005

机器B (时钟准确):
  T2: COS 上传 file.txt, lastModified = 1000000

机器A 同步:
  remoteFile.lastModified (1000000) < localFile.mtime (1000005)
  → 不下载远程版本 (可能是更新的)
```

**建议修复** (向量时钟或版本号):
```typescript
interface FileVersion {
  contentHash: string
  vectorClock: Record<string, number>  // { nodeID: logicalTime }
  lastWriter: string
}

function resolveConflict(local: FileVersion, remote: FileVersion): 'keep-local' | 'keep-remote' | 'conflict' {
  // 比较向量时钟确定因果关系
  const localDominates = Object.entries(local.vectorClock).every(
    ([node, time]) => (remote.vectorClock[node] ?? 0) <= time
  )
  const remoteDominates = Object.entries(remote.vectorClock).every(
    ([node, time]) => (local.vectorClock[node] ?? 0) <= time
  )

  if (localDominates && !remoteDominates) return 'keep-local'
  if (remoteDominates && !localDominates) return 'keep-remote'
  if (local.contentHash === remote.contentHash) return 'keep-local'
  return 'conflict'  // 需要人工解决或自动合并
}
```

---

### 2.2 High Priority Issues

#### Issue #7: 无重试机制
**位置**: `cos/index.ts:297-301`, `cos/index.ts:312-316`

```typescript
// 上传没有重试 (cos/index.ts:297-301)
if (needUpload) {
  const key = COSConfig.buildObjectKey(...)
  const content = await fs.readFile(localFile.absolutePath)
  await COSClient.uploadFile(config.cos, key, content)  // ⚠️ 网络失败直接抛异常
  uploaded++
}

// 下载也没有重试 (cos/index.ts:312-316)
if (needDownload) {
  const localPath = path.join(state.workdir, relativePath)
  await fs.mkdir(path.dirname(localPath), { recursive: true })
  const content = await COSClient.downloadFile(config.cos, remoteFile.key)  // ⚠️ 无重试
  await fs.writeFile(localPath, content)
}
```

**建议修复**:
```typescript
async function withRetry<T>(
  operation: () => Promise<T>,
  options: { maxRetries?: number; baseDelay?: number; maxDelay?: number } = {}
): Promise<T> {
  const { maxRetries = 3, baseDelay = 1000, maxDelay = 30000 } = options

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await operation()
    } catch (err) {
      if (attempt === maxRetries) throw err

      const delay = Math.min(baseDelay * Math.pow(2, attempt), maxDelay)
      const jitter = delay * 0.2 * Math.random()

      log.warn("operation failed, retrying", { attempt, delay, error: err })
      await new Promise(resolve => setTimeout(resolve, delay + jitter))
    }
  }
  throw new Error('Unreachable')
}

// 使用
await withRetry(() => COSClient.uploadFile(config.cos, key, content))
```

---

#### Issue #8: 内存问题 - 大目录扫描
**位置**: `cos/index.ts:142-187`

```typescript
async function scanLocalDirectory(
  baseDir: string,
  excludePatterns: string[],
): Promise<Map<string, LocalFileInfo>> {
  const files = new Map<string, LocalFileInfo>()

  async function scan(dir: string): Promise<void> {
    // ...
    for (const entry of entries) {
      if (entry.isFile()) {
        const hash = await hashFile(fullPath)  // ⚠️ 每个文件都计算 MD5
        files.set(relativePath, {              // ⚠️ 全部加载到内存
          relativePath,
          absolutePath: fullPath,
          size: stat.size,
          mtime: stat.mtimeMs,
          hash,
        })
      }
    }
  }
}
```

**问题描述**:
- 对于大型项目 (>10K 文件)，所有文件信息都加载到内存
- 每个文件都计算完整 MD5 哈希，CPU 密集

**建议修复** (流式处理 + 延迟哈希):
```typescript
async function* scanLocalDirectoryStream(
  baseDir: string,
  excludePatterns: string[],
): AsyncGenerator<LocalFileInfo> {
  const queue: string[] = [baseDir]

  while (queue.length > 0) {
    const dir = queue.shift()!
    const entries = await fs.readdir(dir, { withFileTypes: true })

    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name)
      const relativePath = path.relative(baseDir, fullPath)

      if (isExcluded(relativePath, excludePatterns)) continue

      if (entry.isDirectory()) {
        queue.push(fullPath)
      } else if (entry.isFile()) {
        const stat = await fs.stat(fullPath)
        yield {
          relativePath,
          absolutePath: fullPath,
          size: stat.size,
          mtime: stat.mtimeMs,
          // hash 延迟计算，只在真正需要时才计算
          get hash() {
            return this._hash ??= hashFileSync(fullPath)
          },
        }
      }
    }
  }
}
```

---

### 2.3 Medium Priority Issues

| 问题 | 位置 | 说明 |
|------|------|------|
| 无进度回调 | `fullSync()` | 大文件同步无法显示进度 |
| 排除模式硬编码 | 配置 | 应支持用户自定义 `.syncignore` |
| 无断点续传 | 上传/下载 | 大文件传输失败需要完全重传 |
| 防抖时间可能不够 | 未在此文件 | IDE 频繁保存场景建议 2000-3000ms |

---

## 3. Docker 沙箱执行器评审

### 3.1 Critical Issues

#### Issue #9: 命令注入漏洞
**位置**: `docker.ts:700-716`

```typescript
async writeFile(filepath: string, content: string): Promise<void> {
  if (this.config.isolateWorkdir) {
    await this.ensureContainer()
    const containerPath = this.toSandboxPath(filepath)

    // ⚠️ 命令注入风险!
    const escapedContent = content.replace(/'/g, "'\\''")
    const result = await this.execute({
      command: `mkdir -p "$(dirname '${containerPath}')" && cat > '${containerPath}' << 'OPENCODE_EOF'\n${content}\nOPENCODE_EOF`,
      timeout: 30000,
    })
  }
}
```

**攻击向量**:

1. **路径注入**: `containerPath` 可能包含 `;`, `|`, `$()` 等特殊字符
```typescript
// 恶意输入
filepath = "/workspace/'; rm -rf / #"
// 生成的命令
command = `mkdir -p "$(dirname '/workspace/'; rm -rf / #')" && ...`
```

2. **Heredoc 边界攻击**: `content` 如果包含 `OPENCODE_EOF` 会导致命令提前终止
```typescript
// 恶意内容
content = "some data\nOPENCODE_EOF\nrm -rf /\necho '"
// 生成的命令执行了 rm -rf /
```

**建议修复** (使用 docker cp 或 base64 编码):
```typescript
async writeFile(filepath: string, content: string): Promise<void> {
  if (this.config.isolateWorkdir) {
    await this.ensureContainer()
    const containerPath = this.toSandboxPath(filepath)

    // 方案1: 使用 docker cp (推荐)
    const tempFile = await createTempFile(content)
    try {
      await execAsync(`docker cp "${tempFile}" "${this.containerID}:${containerPath}"`)
    } finally {
      await fs.unlink(tempFile)
    }

    // 方案2: base64 编码
    const base64Content = Buffer.from(content).toString('base64')
    await this.execute({
      command: `mkdir -p "$(dirname ${shellEscape(containerPath)})" && echo "${base64Content}" | base64 -d > ${shellEscape(containerPath)}`,
      timeout: 30000,
    })
  }
}

function shellEscape(str: string): string {
  return `'${str.replace(/'/g, "'\\''")}'`
}
```

---

#### Issue #10: 缺少默认资源限制
**位置**: `docker.ts:372-378`

```typescript
// Resource limits (docker.ts:372-378)
if (this.config.memory) {
  args.push("--memory", this.config.memory)
}
if (this.config.cpu) {
  args.push("--cpus", String(this.config.cpu))
}
// ⚠️ 如果未配置，容器可以无限制使用资源!
```

**风险**: 恶意代码或失控进程可能耗尽主机资源，影响其他用户。

**建议修复**:
```typescript
// 强制默认限制
const DEFAULT_MEMORY = "512m"
const DEFAULT_CPU = 1.0
const DEFAULT_PIDS_LIMIT = 256

const memory = this.config.memory || DEFAULT_MEMORY
const cpu = this.config.cpu || DEFAULT_CPU

args.push("--memory", memory)
args.push("--cpus", String(cpu))
args.push("--pids-limit", String(DEFAULT_PIDS_LIMIT))
args.push("--memory-swap", memory)  // 禁用 swap 以防止内存溢出攻击
```

---

#### Issue #11: 缺少容器安全加固
**位置**: `docker.ts:346-398`

```typescript
private async createContainer(): Promise<string> {
  const args = ["run", "-d", "--rm"]

  // 添加了标签...
  args.push("--label", "opencode.sandbox=true")

  // 网络...
  args.push("--network", this.config.network)

  // ⚠️ 缺少安全加固选项!
}
```

**缺少的安全措施**:

| 选项 | 说明 | 重要性 |
|------|------|--------|
| `--security-opt no-new-privileges` | 防止提权 | Critical |
| `--cap-drop ALL` | 移除所有 capabilities | Critical |
| `--read-only` | 根文件系统只读 | High |
| `--security-opt seccomp=...` | 限制系统调用 | High |
| `--tmpfs /tmp` | 临时文件系统 | Medium |

**建议修复**:
```typescript
// 安全加固选项
args.push("--security-opt", "no-new-privileges")
args.push("--cap-drop", "ALL")
// 按需添加必要的 capabilities
args.push("--cap-add", "CHOWN")
args.push("--cap-add", "SETUID")
args.push("--cap-add", "SETGID")

// 文件系统保护
if (!this.config.isolateWorkdir) {
  // 只有在非隔离模式才考虑只读
  args.push("--read-only")
  args.push("--tmpfs", "/tmp:rw,noexec,nosuid,size=100m")
}

// seccomp 配置 (使用默认配置文件)
args.push("--security-opt", "seccomp=unconfined")  // 或指定自定义 seccomp profile
```

---

### 3.2 High Priority Issues

#### Issue #12: 容器复用数据泄露风险
**位置**: `docker.ts:256-269`

```typescript
// Check if a container with the expected name already exists and is running
const containerName = `opencode-${this.sessionID}`.replace(/[^a-zA-Z0-9_.-]/g, "-")
const existingContainerID = await this.getRunningContainerByName(containerName)
if (existingContainerID) {
  log.debug("reusing existing container", { containerName, containerID: existingContainerID })
  this.containerID = existingContainerID  // ⚠️ 复用可能残留上次数据
  // ...
}
```

**问题描述**: 当 `isolateWorkdir = false` 时，复用容器可能导致：
- 上一个会话的环境变量残留
- 临时文件未清理
- 进程状态遗留

**建议修复**:
```typescript
if (existingContainerID) {
  // 在复用前清理容器状态
  await this.execute({
    command: 'rm -rf /tmp/* 2>/dev/null; unset $(env | grep -v "^PATH=" | cut -d= -f1) 2>/dev/null || true',
    timeout: 10000,
  })
  // 或者：不复用，强制创建新容器
  if (!this.config.isolateWorkdir) {
    log.warn("not reusing container in non-isolated mode for security")
    await this.stopContainer(existingContainerID)
    existingContainerID = null
  }
}
```

---

#### Issue #13: 空闲超时竞态条件
**位置**: `docker.ts:180-199`

```typescript
private startIdleChecker(): void {
  const checkInterval = Math.min(this.config.idleTimeout / 2, 60000)
  this.idleTimer = setInterval(() => {
    if (this.disposed) {
      this.stopIdleChecker()
      return
    }

    const idleTime = Date.now() - this.lastActivityTime
    if (idleTime >= this.config.idleTimeout!) {
      log.info("container idle timeout, disposing", {...})
      this.dispose().catch(...)  // ⚠️ 检查和 dispose 之间可能有新活动
    }
  }, checkInterval)
}
```

**问题描述**: 在检查 `idleTime` 和调用 `dispose()` 之间，可能有新的 `execute()` 调用更新了 `lastActivityTime`，导致活跃容器被错误销毁。

**建议修复**:
```typescript
private startIdleChecker(): void {
  const checkInterval = Math.min(this.config.idleTimeout / 2, 60000)
  this.idleTimer = setInterval(async () => {
    if (this.disposed) {
      this.stopIdleChecker()
      return
    }

    // 使用锁防止竞态
    if (this.disposeLock) return
    this.disposeLock = true

    try {
      const idleTime = Date.now() - this.lastActivityTime
      if (idleTime >= this.config.idleTimeout!) {
        // 再次检查 (double-check)
        await new Promise(r => setTimeout(r, 100))
        const idleTime2 = Date.now() - this.lastActivityTime
        if (idleTime2 >= this.config.idleTimeout!) {
          log.info("container idle timeout, disposing", {...})
          await this.dispose()
        }
      }
    } finally {
      this.disposeLock = false
    }
  }, checkInterval)
}
```

---

## 4. Remote 沙箱执行器评审

### 4.1 Critical Issues

#### Issue #14: API Key 环境变量污染
**位置**: `remote.ts:124-146`

```typescript
private setupE2BEnv(): void {
  // E2B SDK reads these environment variables:
  // - E2B_API_KEY: API key for authentication
  // - E2B_DOMAIN: Custom domain (e.g., for Tencent AGS)

  if (this.config.apiKey) {
    process.env["E2B_API_KEY"] = this.config.apiKey  // ⚠️ 全局污染!
  } else if (Flag.OPENCODE_SANDBOX_REMOTE_API_KEY) {
    process.env["E2B_API_KEY"] = Flag.OPENCODE_SANDBOX_REMOTE_API_KEY
  }

  if (this.config.url) {
    process.env["E2B_DOMAIN"] = url.hostname  // ⚠️ 全局污染!
  }
}
```

**问题描述**:
1. 设置到 `process.env` 是全局的，可能被其他代码读取
2. 多租户环境下，不同用户可能需要不同的 API Key
3. 如果 E2B SDK 在其他地方被初始化，可能使用错误的凭证

**建议修复**:
```typescript
// 方案1: 使用 E2B SDK 的构造函数参数 (如果支持)
const sandbox = await E2BSandboxClass.create(template, {
  apiKey: this.config.apiKey,  // 直接传递，不污染 process.env
  domain: this.config.url ? new URL(this.config.url).hostname : undefined,
  timeoutMs,
})

// 方案2: 使用作用域环境变量
private async withE2BEnv<T>(fn: () => Promise<T>): Promise<T> {
  const originalApiKey = process.env["E2B_API_KEY"]
  const originalDomain = process.env["E2B_DOMAIN"]

  try {
    if (this.config.apiKey) {
      process.env["E2B_API_KEY"] = this.config.apiKey
    }
    if (this.config.url) {
      process.env["E2B_DOMAIN"] = new URL(this.config.url).hostname
    }
    return await fn()
  } finally {
    // 恢复原始值
    if (originalApiKey !== undefined) {
      process.env["E2B_API_KEY"] = originalApiKey
    } else {
      delete process.env["E2B_API_KEY"]
    }
    // ... 同样处理 E2B_DOMAIN
  }
}
```

---

### 4.2 High Priority Issues

#### Issue #15: 超时无上限验证
**位置**: `remote.ts:184`

```typescript
const template = this.config.template || "base"
const timeoutMs = this.config.timeout || 60000  // ⚠️ 用户可以设置任意大的 timeout
```

**风险**: 用户可能设置非常大的 timeout (如 24 小时)，导致：
- E2B 计费成本失控
- 资源长期占用

**建议修复**:
```typescript
const MAX_TIMEOUT = 600000  // 10 分钟上限
const MIN_TIMEOUT = 60000   // 1 分钟下限

const rawTimeout = this.config.timeout || 300000
const timeoutMs = Math.max(MIN_TIMEOUT, Math.min(rawTimeout, MAX_TIMEOUT))

if (rawTimeout > MAX_TIMEOUT) {
  log.warn("timeout exceeds maximum, capping", {
    requested: rawTimeout,
    actual: timeoutMs
  })
}
```

---

#### Issue #16: COS 挂载失败静默继续
**位置**: `remote.ts:96-102`

```typescript
try {
  await COSClient.uploadFile(config.cos, placeholderKey, "")
  log.debug("created COS directory placeholder", { key: placeholderKey })
} catch (err) {
  log.warn("failed to create COS directory placeholder", { error: err })
  // ⚠️ 继续执行，但挂载可能不工作
}

this.cosInitialized = true  // ⚠️ 即使失败也标记为已初始化
```

**问题描述**: COS 初始化失败后仍标记为 `cosInitialized = true`，后续操作会假设 COS 已就绪。

**建议修复**:
```typescript
try {
  await COSClient.uploadFile(config.cos, placeholderKey, "")
  log.debug("created COS directory placeholder", { key: placeholderKey })
  this.cosInitialized = true
} catch (err) {
  log.error("failed to initialize COS, file persistence may not work", { error: err })
  this.cosInitialized = false

  // 可选: 抛出错误或设置降级模式
  if (this.config.requireCOS) {
    throw new Error(`COS initialization failed: ${err.message}`)
  }
}
```

---

## 5. 统一存储层评审

### 5.1 High Priority Issues

#### Issue #17: 后端回退可能导致数据不一致
**位置**: `unified-storage.ts:67-85`

```typescript
if (config.backend === "cos") {
  const cosEnabled = await COSConfig.isEnabled()
  if (cosEnabled) {
    await COSStorage.init()
  } else if (config.fallbackToLocal) {
    log.warn("COS not configured, falling back to local storage")
    config.backend = "local"           // ⚠️ 静默回退
    config.usePGForSessions = false
  } else {
    throw new Error("COS backend requested but not configured")
  }
}
```

**问题描述**: 当 COS 不可用时静默回退到本地存储，可能导致：
- 用户以为数据在云端，实际在本地
- 切换机器后数据"丢失"
- 数据分布在多个后端，难以管理

**建议修复**:
```typescript
if (cosEnabled) {
  await COSStorage.init()
} else if (config.fallbackToLocal) {
  log.warn("COS not configured, falling back to local storage")
  config.backend = "local"
  config.usePGForSessions = false

  // 添加明确的用户通知机制
  Bus.publish(UnifiedStorage.Event.BackendFallback, {
    requested: "cos",
    actual: "local",
    reason: "COS not configured",
  })

  // 可选：在首次写入时再次警告
  let fallbackWarned = false
  const originalWrite = write
  write = async (key, content) => {
    if (!fallbackWarned) {
      log.warn("Writing to local storage instead of COS", { key })
      fallbackWarned = true
    }
    return originalWrite(key, content)
  }
}
```

---

## 6. 总体评审结论

### 6.1 问题统计

| 严重性 | 数量 | 主要类别 |
|--------|------|----------|
| Critical | 6 | 安全漏洞 (SQL注入、命令注入)、数据隔离 |
| High | 8 | 可靠性 (竞态条件)、数据一致性 (乐观锁) |
| Medium | 10+ | 性能 (缺失索引)、代码质量 |

### 6.2 按模块风险评估

| 模块 | 风险等级 | 主要问题 |
|------|----------|----------|
| pg-schema | **Critical** | 无多租户隔离、缺少关键索引 |
| pg-storage | **High** | update 非原子性、SQL 动态拼接 |
| cos/index | **Critical** | 竞态条件、冲突解决不健壮 |
| docker | **Critical** | 命令注入、缺少资源限制 |
| remote | **High** | API Key 污染、超时无上限 |
| unified-storage | **Medium** | 后端回退可能导致数据不一致 |

### 6.3 修复优先级建议

#### P0 - 立即修复 (阻塞发布)
1. **添加多租户 `tenant_id` 隔离** - 数据泄露风险
2. **修复 Docker `writeFile` 命令注入** - 远程代码执行风险
3. **添加容器默认资源限制** - 拒绝服务攻击风险
4. **添加容器安全加固选项** - 沙箱逃逸风险

#### P1 - 本周内
1. 添加缺失的数据库索引 (`part.message_id`, `permission.project_id`)
2. 实现 COS 同步重试机制
3. 修复 API Key 环境变量污染问题
4. 修复 `syncInProgress` 竞态条件

#### P2 - 本迭代
1. 实现 `update` 操作乐观锁
2. 改进 COS 冲突解决策略
3. 添加超时上限验证
4. 优化大目录扫描内存使用

---

## 7. 架构建议

### 7.1 安全加固清单

```
[ ] 添加 tenant_id 到所有表
[ ] 实现行级安全策略 (Row Level Security)
[ ] 添加 SQL 参数化查询审计
[ ] Docker 容器安全加固
    [ ] --security-opt no-new-privileges
    [ ] --cap-drop ALL
    [ ] --read-only (where applicable)
[ ] 实现敏感操作审计日志
[ ] 添加速率限制
```

### 7.2 可靠性改进清单

```
[ ] 实现乐观锁或悲观锁
[ ] 添加网络操作重试机制
[ ] 实现断点续传
[ ] 添加健康检查端点
[ ] 实现优雅降级策略
[ ] 添加数据一致性校验
```

### 7.3 可观测性建议

```
[ ] 结构化日志标准化
[ ] 添加 OpenTelemetry 集成
    [ ] Traces: 请求链路追踪
    [ ] Metrics: 性能指标
    [ ] Logs: 关联日志
[ ] 添加关键路径监控告警
[ ] 实现慢查询日志
```

---

**评审人签名**: Claude (Meta Distinguished Software Engineer 视角)
**评审日期**: 2026-01-28
