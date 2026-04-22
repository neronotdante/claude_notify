---
description: 发送 Windows 桌面 Toast 通知
argument-hint: 可选消息内容，例如：部署完成，请检查日志
allowed-tools: Bash
---

向用户发送一条 Windows 桌面 Toast 通知。

1. 提取用户在 `/notify` 后填写的消息。若无消息，使用默认值 `任务已执行完成`。
2. 运行以下命令（将 `<MESSAGE>` 替换为实际消息）：

```bash
python "e:/HF.Work/98claudeCodeLearning/claude_notify/.claude-plugin/notify/src/notify.py" "<MESSAGE>"
```

3. 回复用户"通知已发送"，不需要其他说明。
