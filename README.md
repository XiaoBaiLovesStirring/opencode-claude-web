# OpenCode Claude Web

给 **OpenCode V2** 做的 Claude 风格网页界面。

**独立项目，不是插件。** 一条命令拉起 OpenCode 的无头服务 + 网页界面：

```bash
./start.sh
```

浏览器自动打开，直接开始用。

---

## 快速开始

```bash
# 1. 解压进入目录
cd opencode-claude-web

# 2. 注册全局命令（可选，推荐）
./install.sh
#   加上 --with-alias 还能用 `opencode web` 这个写法

# 3. 启动
opencode-web                # 注册后用这个，任意目录都行
# 或
./start.sh                  # 直接跑

# 指定工作目录
opencode-web ~/myproj

# 换端口
OCW_WEB_PORT=8899 opencode-web
```

**当前打开的工作目录会显示在侧边栏底部**（`已连接 OpenCode · /path/to/dir`），不用猜有没有生效。

依赖：`opencode`（V2）+ `python3`（只用来托管静态页面）。

**不依赖 `curl` / `script` / `node`** —— 端口探活用 bash 内建 `/dev/tcp` 实现，所以 Termux 上也能直接跑。

| 平台 | 说明 |
|---|---|
| macOS / Linux | 装好 `opencode` + `python3` 即可 |
| **Termux (Android)** | 先 `pkg install python`；开浏览器走 `termux-open-url` |
| WSL | 用 `wslview` 打开浏览器 |

Ctrl+C 会把无头服务和网页服务一起关掉。

---

## 工作原理

```
┌─────────────┐   fetch (CORS)   ┌──────────────────────────┐
│  浏览器      │ ───────────────▶ │  opencode serve          │
│  127.0.0.1  │                  │  127.0.0.1:4096 (无头)    │
│  :7788      │ ◀─────────────── │  ─ HTTP API (Basic Auth) │
└─────────────┘                  └──────────────────────────┘
       ▲
       │ 静态托管
┌─────────────┐
│ python http │
│  .server    │
└─────────────┘
```

`start.sh` 依次做四件事：

1. `opencode serve --port 4096 --hostname 127.0.0.1 --cors http://127.0.0.1:7788`
   —— `--cors` 放行网页来源，这是官方给自定义前端留的口子
2. 从启动日志里读出 OpenCode 生成的服务密码
3. 生成 `web/config.js`（地址 + Basic 凭据），**不落进任何仓库文件**
4. 用 python 托管 `web/`，并打开浏览器

浏览器不经过任何中间代理，直接调 OpenCode 的 HTTP API。

---

## 用到了哪些 API

均在 `http://127.0.0.1:4096`，认证方式为 **HTTP Basic**（用户名固定 `opencode`，密码由服务启动时生成）。

| 用途 | 端点 |
|---|---|
| 模型列表 | `GET /api/model` |
| 默认模型 | `GET /api/model/default` |
| 会话列表 | `GET /api/session` |
| 创建会话 | `POST /api/session` |
| 会话详情 | `GET /api/session/{id}` |
| **发消息** | `POST /api/session/{id}/prompt`  body: `{"text":"..."}` |
| **读消息** | `GET /api/session/{id}/message` |
| 切换模型 | `POST /api/session/{id}/model`  body: `{"model":{"providerID":"...","id":"..."}}` |
| 中断执行 | `POST /api/session/{id}/interrupt` |
| Agent 列表 | `GET /api/agent?location[directory]=<dir>` |
| 插件列表 | `GET /api/plugin?location[directory]=<dir>` |
| 当前目录 | `GET /api/location` |
| 实时事件 | `GET /api/event`（SSE） |

完整规范：`curl -u opencode:<密码> http://127.0.0.1:4096/openapi.json`（142 个端点）。

> ⚠️ `agent` / `plugin` 必须带 `location[directory]` 参数，否则返回空数组。

---

## 界面

**Markdown 完整渲染** —— AI 输出的内容按真实排版显示，不是纯文本：

| 语法 | 渲染效果 |
|---|---|
| `**粗体**` / `*斜体*` / `~~删除~~` | 对应样式 |
| `` `行内代码` `` | 灰底圆角 |
| ` ```代码块``` ` | 独立卡片（语言标签 + 复制 + 折叠 + 语法高亮） |
| `\| 表格 \|` | 真正的表格（表头灰底、圆角边框、宽表横向滚动） |
| `# 标题` ~ `######` | h1–h6 分级字号 |
| `- 列表` / `1. 列表` | 无序 / 有序列表 |
| `> 引用` | 左侧竖线 + 弱化文字 |
| `[链接](url)` | 品牌色 + 下划线 |
| `---` | 分割线 |

**过程可视化** —— 不铺日志，Agent 的每一步都收敛成可点击的一行：

| 元素 | 收起态 | 展开后 |
|---|---|---|
| 思考 | `✳ 思考了 1.6 秒 ›` | 斜体浅色思考正文 |
| 工具调用 | `📄 读取文件 · 完成 ›` | 入参 + 输出 |
| 失败调用 | `📄 写入文件 · 失败 ›`（红） | 错误详情 |

**模块化承载** —— 产物全部进卡片：

| 卡片 | 头部 | 操作 |
|---|---|---|
| 代码块 | 语言标签 | 复制 / 折叠 |
| 差异 | 文件名 + `+6 −1` | 横向滚动 |

每轮回答底部带真实元信息：`Big Pickle · ↑3026 ↓33 · 8.7s`。

其它：左侧真实会话列表、模型选择器（12 个模型）、插件/Agent 计数与列表、浅色/深色主题、中英切换、移动端底部抽屉式侧栏。

---

## 数据结构

渲染层不做任何映射 —— OpenCode 的助手消息本身就是一个有序块数组：

```ts
Assistant.content = Array<AssistantText | AssistantReasoning | AssistantTool>
//   { type:"text",      text }
//   { type:"reasoning", text, time:{ created, completed } }
//   { type:"tool",      name, state: streaming|running|completed|error }
```

界面直接遍历渲染：`reasoning` → 思考行、`text` → 正文（markdown + 代码卡片）、`tool` → 工具行。
所以「思考 → 文本 → 思考 → 工具」这种交替是数据原生形态。

- 耗时取自 `time.created / time.completed`，不是估算
- 工具状态取自 `state.status`，运行中转圈、失败转红

---

## 文件结构

```
opencode-claude-web/
├── start.sh            启动脚本（无头服务 + 网页 + 浏览器）
├── web/
│   ├── index.html      界面（单文件，零依赖）
│   └── config.js       启动时生成：服务地址 + 凭据
└── README.md
```

---

## 已知限制

- **`agent` / `plugin` 列表需要 location** —— OpenCode 的 location 服务在纯 `serve` 模式下是惰性的，所以这两个列表可能为空。它们在首次会话活动后才会填充。
- 界面仅监听 `127.0.0.1`
- Windows 建议用 WSL
- `config.js` 含服务凭据，已在 `.gitignore` 中排除，不要提交
