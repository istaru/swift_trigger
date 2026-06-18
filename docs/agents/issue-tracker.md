# 议题追踪器：GitHub

此仓库的议题和 PRD 存放在 GitHub Issues 中，所有操作使用 `gh` CLI 完成。

## 常用命令

- **创建议题**：`gh issue create --title "..." --body "..."`，多行正文使用 heredoc。
- **查看议题**：`gh issue view <编号> --comments`，可结合 `jq` 过滤评论和标签。
- **列出议题**：`gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'`，可加 `--label` 和 `--state` 过滤。
- **评论议题**：`gh issue comment <编号> --body "..."`
- **添加/移除标签**：`gh issue edit <编号> --add-label "..."` / `--remove-label "..."`
- **关闭议题**：`gh issue close <编号> --comment "..."`

在克隆目录内运行 `gh` 时，仓库信息会自动从 `git remote -v` 推断，无需手动指定。

## 当技能说「发布到议题追踪器」时

创建一个 GitHub Issue。

## 当技能说「获取相关工单」时

执行 `gh issue view <编号> --comments`。
