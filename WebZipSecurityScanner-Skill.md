---
name: web-zip-security-scanner
description: Use when a user provides a local target directory and asks Codex to inspect or fix static HTML package security and portability issues.
---

# Web Zip 安全扫描

## 概述

使用本技能扫描本地目标目录，检查：

- 路径命名问题
- 静态 Web 交付合规性
- HTML 中可直接命中的高风险浏览器执行内容
- 构建产物中的静态资源路径可移植性问题
- 常见前端构建配置中的固定基路径问题

本技能是静态检查，不负责：

- 解压压缩包
- 启动页面或服务
- 抓取远程资源
- 启动浏览器
- 替代完整渗透测试

## 适用场景

当用户提供一个本地目标目录，并希望对其中的静态 HTML/Web 内容执行安全检查、XSS 检查、HTML 包校验、可移植性审查或按要求修复时，使用本技能。

如果目标不是 HTML 文档，也不是会被浏览器执行的 HTML/JavaScript 交付内容，则不应将本技能当作通用源码审计器。

## 输入要求

期望输入是一个本地目标目录路径。

本技能不区分该目录来自：

- 解压后的交付包目录
- 游戏工程内的目标目录

只要目标目录中包含待检查的静态 Web 内容、构建产物或相关配置文件，均按统一规则执行检查。

如果用户提供的是 zip 文件，应要求用户先提供解压后的目录，或先明确是否需要先执行解压。

### 默认扫描范围

- 所有文件和目录路径：用于命名/路径规则检查
- `.html`
- `.htm`
- `vite.config.ts`
- `vite.config.js`
- `vite.config.mts`
- `vite.config.mjs`

### 默认排除范围

为避免把第三方依赖、版本控制元数据、构建缓存、引擎临时目录或明显非交付内容误纳入结果，扫描时默认排除以下目录：

- `node_modules`
- `.git`
- `.svn`
- `.hg`
- `dist`
- `build`
- `.cache`
- `.turbo`
- `.next`
- `coverage`
- `Library`
- `Temp`
- `Logs`

以上目录即使位于目标目录内部，也默认不进入递归扫描，不参与命名检查、HTML 扫描、配置扫描、问题统计或结论判定。

只有在以下情况之一满足时，才可突破默认排除：

- 用户明确要求检查某个默认排除目录
- 用户给出的目标目录本身就是某个默认排除目录

如果突破默认排除范围，应在最终报告中明确说明扫描边界已被放宽。

### 文件读取要求

- 优先按 UTF-8 读取
- 如果文件不可读，应报告“文件不可读”警告，而不是静默跳过

## 执行流程

1. 递归枚举目标目录下的所有文件和文件夹，但必须跳过默认排除目录；除非用户明确要求纳入，或目标目录本身就是该排除目录。
2. 检查每个相对路径组件是否包含中文字符。
3. 检查目标目录内容是否明显依赖包内后端或服务端模板。
4. 枚举所有 `.html` 和 `.htm` 文件。
5. 枚举支持的 `vite.config.*` 文件。
6. 对每个 HTML 文件读取原始文本内容，不执行其中代码。
7. 对 HTML 应用全部内容规则。
8. 对 `vite.config.*` 应用固定基路径规则。
9. 记录每一条命中项，包括相对路径、行号、规则名、风险级别、证据片段和修复建议。
10. 按 `文件 + 行号/路径 + 规则名/消息` 去重。
11. 按风险级别分组输出结果，顺序为：高风险、中风险、需人工复核。

优先使用本地快速搜索工具，例如：

```powershell
rg --files <directory> -g "*.html" -g "*.htm"
rg --files <directory> -g "vite.config.ts" -g "vite.config.js" -g "vite.config.mts" -g "vite.config.mjs"
```

不要为了校验外部脚本 URL 发起网络请求。

## 规则摘要

| 规则 | 检测目标 | 命中信号 | 默认风险 |
| --- | --- | --- | --- |
| 路径名、文件夹名或文件名包含中文 | 所有路径组件 | 相对路径片段中出现 `[\u4E00-\u9FFF]` | Medium |
| 非静态 Web 交付 | 整个交付包 | 包内包含本地启动后端、服务端模板或必须依赖包内服务端运行 | High |
| 绝对路径或固定路径引用 | `.html` / `.htm` | `/...`、Windows 盘符、固定本机目录、`file:///...` | High |
| 危险嵌入内容标签 | `.html` / `.htm` | `<iframe`、`<frame`、`<object`、`<embed` | High |
| JavaScript 协议引用 | `.html` / `.htm` | `href` / `src` / `action` / `data` 以 `javascript:` 开头 | High |
| 活跃源属性中的 Data URI | `.html` / `.htm` | `src` / `action` 以 `data:` 开头 | Medium / High |
| Meta Refresh 跳转 | `.html` / `.htm` | `<meta ... http-equiv="refresh"` | High |
| 高风险 JavaScript API | `.html` / `.htm` | `eval(`、`document.write(`、`document.writeln(`、`document.cookie` | Medium / High |
| 外部脚本来源校验 | `.html` / `.htm` | `<script src="http://...">`、非 HTTPS、localhost、本地/私网 IP | High |
| 不安全的 `innerHTML` / `outerHTML` 赋值 | `.html` / `.htm` | 动态赋值或静态赋值中包含危险 HTML / 协议 / 外部脚本 | High / Review |
| 静态资源路径可移植性 | `.html` / `.htm` | 固定站点根路径、固定子路径、盘符路径、`file:///` | Medium / High |
| 构建配置固定基路径（Vite base） | `vite.config.*` | `base: "/.../"` 或等价固定根路径/子路径配置 | Medium / High |

除非规则另有说明，内容匹配默认按大小写不敏感处理。

## 详细规则

### 1. 路径名、文件夹名或文件名包含中文

只要扫描目录下的任一路径组件包含中文字符，就应报告问题。

主要检测信号：

```text
[\u4E00-\u9FFF]
```

风险级别：`Medium`

原因：
中文路径可能在 URL 编码、部署流水线、某些文件系统、某些静态托管规则或下游校验器中导致兼容性问题。

修复建议：

- 改为仅包含 ASCII 的名称
- 优先使用不带声调的小写拼音
- 需要分词时使用 `-` 或 `_`
- 保留原扩展名
- 重命名后同步更新内部引用

### 2. 非静态 Web 交付

当交付包不是纯静态 Web 交付物时，应报告问题。

命中示例包括但不限于：

- `server.js`
- `app.py`
- `main.go`
- `*.php`
- `*.jsp`
- `*.aspx`
- 包内服务端模板
- README、脚本或配置明确要求先本地启动后端服务

不应因为前端调用外部 API 就将其误判为非静态 Web。

风险级别：`High`

### 3. 绝对路径或固定路径引用

当 HTML 内容或其内联脚本/样式中存在不依赖当前包相对位置的固定路径时，应报告问题。

高风险命中包括：

- 以 `/` 开头的站点根路径
- 以 `\` 开头的路径
- Windows 盘符路径，如 `C:\`、`D:\`
- 固定本机目录，如 `/usr/share/...`、`/opt/app/...`
- `file:///...`

常见位置包括：

- `src`
- `href`
- `action`
- `poster`
- `data`
- CSS `url(...)`
- 内联 JavaScript 中明显用于加载资源的字符串字面量

风险级别：`High`

修复建议：

- 改为 `./assets/...`
- 改为 `../assets/...`
- 改为 `assets/...`

### 4. 危险嵌入内容标签

只要 HTML 中出现以下标签起始形式，就应报告：

```text
<iframe
<frame
<object
<embed
```

风险级别：`High`

### 5. JavaScript 协议引用

当 `href`、`src`、`action` 或 `data` 属性的带引号值以 `javascript:` 开头时，应报告问题。

示例：

```html
<a href="javascript:alert(1)">
<form action="javascript:submitForm()">
```

风险级别：`High`

### 6. 活跃源属性中的 Data URI

当 `src` 或 `action` 属性的带引号值以 `data:` 开头时，应报告问题。

示例：

```html
<img src="data:image/svg+xml,...">
<form action="data:text/html,...">
```

风险级别：

- 默认 `Medium`
- 如果承载 HTML、SVG、可执行脚本，或用于表单/跳转上下文，提升为 `High`

### 7. Meta Refresh 跳转

当 `<meta>` 的 `http-equiv` 值为 `refresh` 时，应报告问题。

示例：

```html
<meta http-equiv="refresh" content="0;url=https://example.com">
```

风险级别：`High`

### 8. 高风险 JavaScript API

当内容中出现以下任一形式时，应报告：

```text
eval(
document.write(
document.writeln(
document.cookie
```

风险级别：

- 默认 `Medium`
- 如果与用户输入、动态 HTML 构造或外部数据结合使用，提升为 `High`

### 9. 外部脚本来源

检查：

```html
<script src="..."></script>
```

只有当 `src` 以以下前缀开头时，才视为“外部脚本”：

```text
http://
https://
//
```

以下情况应报告：

- URL 非法或无 host
- 包含 userinfo
- 协议不是 HTTPS
- host 为 `localhost`、`*.localhost`、`*.local`
- host 为本地/私网 IP、loopback、link-local、multicast、IPv6 unique-local

风险级别：`High`

不要对普通公网域名做联网 DNS 推断。

### 10. `innerHTML` / `outerHTML` 赋值

检查：

```text
innerHTML =
outerHTML =
```

赋值表达式提取规则：

- 从赋值号后开始提取
- 读到下一个分号或换行
- 但如果仍处于引号、括号、方括号、大括号或模板字符串内部，则不能提前截断

如果表达式以下列 sanitizer 开头，则不报告：

```text
DOMPurify.sanitize(...)
sanitizeHtml(...)
filterXSS(...)
```

分类：

- 空表达式或无法可靠解析：`需人工复核`
- 动态表达式、变量、函数调用、模板字符串插值、非纯字面量拼接：`High`
- 静态字符串中包含 `<script`：`High`
- 静态字符串中包含危险嵌入标签：`High`
- 静态字符串中包含内联事件：`High`
- 静态字符串中包含 `javascript:`：`High`
- 静态字符串中包含 `data:`：`Medium` 或 `High`
- 静态字符串中包含 meta refresh：`High`
- 静态字符串中包含不安全外部脚本：`High`

### 11. 静态资源路径可移植性

当交付包预期会被上传到任意网站目录、子目录，或作为解压后的静态包直接部署时，应应用本规则。

应命中示例：

- `/assets/app.js`
- `/Game_Desktap_Pet/assets/index.js`
- `C:\site\assets\main.css`
- `D:\wwwroot\game\index.html`
- `file:///C:/temp/game/index.html`

不应命中示例：

- `./assets/app.js`
- `../img/logo.png`
- `assets/main.css`
- `https://cdn.example.com/app.js`

默认风险级别：`Medium`

如果明显用于任意目录上传、任意子目录部署或 zip 解压直用，则提升为 `High`。

### 12. 构建配置固定基路径（Vite base）

检测目标：

- `vite.config.ts`
- `vite.config.js`
- `vite.config.mts`
- `vite.config.mjs`

当 `base` 为固定根路径或固定部署子路径时，应报告问题。

应命中示例：

- `base: "/"`
- `base: "/app/"`
- `base: "/Game_Desktap_Pet/"`

不应命中示例：

- `base: "./"`
- `base: ""`

风险级别：

- 默认 `Medium`
- 如果交付场景明确要求支持任意目录上传、任意子目录部署、zip 解压即用或任意静态托管路径，则提升为 `High`
- 如果构建产物 HTML 已经出现由该配置导致的固定路径，例如：
  - `src="/Game_Desktap_Pet/assets/index.js"`
  - `href="/Game_Desktap_Pet/assets/index.css"`
  则应优先按构建产物路径问题报告为 `High`，并在原因中引用该 `base` 配置作为根因

原因：
固定 `base` 会让构建产物依赖站点根路径或特定子路径，破坏静态包的可移植性。

修复建议：

```ts
base: "./"
```

修复后应重新构建，并验证构建产物中资源路径为：

- `./assets/index.js`
- `./assets/index.css`

而不是：

- `/assets/index.js`
- `/Game_Desktap_Pet/assets/index.js`

## 风险分级

统一使用以下级别：

| 级别 | 含义 |
| --- | --- |
| High | 很可能导致脚本执行、强制跳转、不安全远程加载、本地/私网引用、HTML 注入或直接破坏交付可用性 |
| Medium | 存在潜在安全或可移植性问题，是否可利用或是否会部署失败取决于上下文 |
| 需人工复核 | 静态分析无法安全下结论，需要结合上下文进一步确认 |

同一问题可能落入多个级别时，选择更高等级，并说明原因。

## 证据要求

每一条问题都应尽量包含：

- 相对扫描根目录的文件路径
- 1-based 行号；纯路径命名问题可填 `N/A`
- 规则名
- 风险级别
- 简短证据片段
- 风险原因
- 具体修复建议

证据片段尽量控制在 240 字符以内。

不要编造无证据支撑的问题。

## 输出格式

使用以下结构：

```markdown
# Web Zip 安全扫描报告

扫描路径: <directory>
扫描的 HTML 文件数: <count>
问题统计: 共 <total> 项，其中高风险 <high> 项，中风险 <medium> 项，需人工复核 <review> 项

## 总体结论

<通过 / 需修复 / 需人工复核>

## 高风险

### H-1 <规则名>
- 文件: <relative/path>
- 行号: <line>
- 证据: `<snippet>`
- 原因: <why this is dangerous>
- 修复: <specific remediation>

## 中风险

### M-1 <规则名>
- 文件: <relative/path>
- 行号: <line>
- 证据: `<snippet>`
- 原因: <why this may be dangerous>
- 修复: <specific remediation>

## 需人工复核

### R-1 <规则名>
- 文件: <relative/path>
- 行号: <line>
- 证据: `<snippet>`
- 原因: <what could not be determined statically>
- 复核建议: <what a human should verify>

## 建议修复顺序

1. 先修复所有高风险问题。
2. 再修复或说明所有中风险问题。
3. 最后人工复核动态或无法可靠解析的内容问题。
```

如果没有发现任何问题，应输出：

```markdown
# Web Zip 安全扫描报告

扫描路径: <directory>
扫描的 HTML 文件数: <count>
问题统计: 0

## 总体结论

通过。本次扫描未命中本技能定义的安全规则。

## 备注

本次仅对路径、`.html`、`.htm` 和支持的 `vite.config.*` 文件进行了静态扫描，不能证明交付包不存在所有安全漏洞。
```

## 常见误区

- 不要把相对脚本路径误判为不安全外部脚本
- 不要对普通公网域名做联网 DNS 推断
- 如果 `innerHTML` / `outerHTML` 以 `DOMPurify.sanitize(`、`sanitizeHtml(` 或 `filterXSS(` 开头，不要误报
- 不要发现第一条问题后就停止扫描
- 不要把“前端调用外部 API”误判为“非静态 Web”
- 不要把外部 `http://` / `https://` URL 误报成“绝对路径或固定路径”问题
- 不要把“中文命名检查”限制在 HTML 文件中
- 不要默认扫描 `node_modules`、引擎缓存目录或其他默认排除目录中的内容
- 不要把 `vite.config.*` 中的固定 `base` 当成唯一证据后就停止继续检查构建产物 HTML
- 如果同时存在 `vite.config.*` 命中和构建产物 HTML 命中，应优先报告构建产物路径证据，并在原因中指出 `base` 配置是根因
