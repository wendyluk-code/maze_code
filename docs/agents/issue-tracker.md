# 问题跟踪：GitHub Issues

本项目的问题、规格和开发票据记录在
`wendyluk-code/maze_code` 的 GitHub Issues 中，使用 `gh` 命令行操作。

## 操作约定

所有命令显式指定仓库，避免操作到其他项目：

- 创建：`gh issue create --repo wendyluk-code/maze_code --title "标题" --body-file "正文文件"`
- 读取：`gh issue view <编号> --repo wendyluk-code/maze_code --comments`
- 列表：`gh issue list --repo wendyluk-code/maze_code --state open --json number,title,body,labels`
- 评论：`gh issue comment <编号> --repo wendyluk-code/maze_code --body-file "评论文件"`
- 添加标签：`gh issue edit <编号> --repo wendyluk-code/maze_code --add-label "<标签>"`
- 移除标签：`gh issue edit <编号> --repo wendyluk-code/maze_code --remove-label "<标签>"`
- 关闭：`gh issue close <编号> --repo wendyluk-code/maze_code --comment "关闭依据"`

正文与评论以中文为主。操作前检查登录身份、仓库和授权范围；
失败时保留错误，不把未成功的操作记录为已发布。

## 技能指令的对应动作

- “发布到问题跟踪系统”：创建 GitHub Issue。
- “读取相关票据”：读取对应 Issue 正文、标签及评论。
- 问题分流标签采用 `docs/agents/triage-labels.md` 的映射。

本配置只指定记录位置，不改变 AGENTS.md 中的确认、派单、
执行和验收要求。标签或问题关闭状态不能替代实际验收证据。

## 拉取请求处理开关

PRs as a request surface: no.
