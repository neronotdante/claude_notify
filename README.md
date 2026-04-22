# claude-notify

> Claude Code **Stop Hook** 插件：对话含触发关键字时，通过 Windows Toast API 弹出系统通知，标题自动显示当前项目名。

无需安装任何 Python 第三方库，完全依赖系统自带的 PowerShell + Windows Runtime。

---

## 效果预览

```
┌─────────────────────────────────┐
│ Claude Code [claude_notify]     │
│ 任务已执行完成                   │
└─────────────────────────────────┘
```

---

## 触发关键字

在 Claude Code 对话消息中写入以下任一关键字即可触发：

| 关键字 | 说明 |
|--------|------|
| `[notify]` | 默认通知 |
| `[notify: 自定义内容]` | 自定义通知正文 |
| `-notify` / `--notify` | 同 `[notify]` |
| `!done` | 同 `[notify]` |
| `[完成通知]` / `!通知` | 同 `[notify]` |

**示例：**

```
帮我完成数据库迁移脚本 [notify: 迁移脚本已生成]
```

---

## 快速安装

```bat
git clone https://github.com/neronotdante/claude_notify.git
cd claude_notify
.claude-plugin\notify\src\install.bat
```

`install.bat` 自动完成：

1. 将脚本绝对路径写入 `.claude-plugin/manifest.json`
2. 在 `~/.claude/settings.json` 注册插件（`extraKnownMarketplaces` + `enabledPlugins`）
3. 清理旧的全局 Stop hook（避免重复触发）

> 重启 Claude Code 后生效。

### 手动配置（可选）

在 `~/.claude/settings.json` 的 `hooks.Stop` 中添加：

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "python \"<绝对路径>/.claude-plugin/notify/src/notify.py\"",
            "timeout": 20
          }
        ]
      }
    ]
  }
}
```

---

## 文件结构

```
claude_notify/
├── .claude-plugin/
│   ├── manifest.json               # 插件声明 + Stop hook 配置
│   ├── run.py                      # 路径 wrapper（备用）
│   └── notify/
│       └── src/
│           ├── notify.py           # 核心脚本
│           └── install.bat         # 一键安装（Windows）
└── README.md
```

---

## 实现原理

```
用户消息含触发关键字
        │
        ▼
Claude 响应结束 ──► Stop 事件触发
        │
        ▼
notify.py 从 stdin 读取 JSON payload
  {session_id, transcript_path, stop_hook_active}
        │
        ├─ stop_hook_active = true ──► 退出（防递归）
        │
        ▼
读取 transcript.jsonl
  倒序扫描最近 10 条用户消息
        │
        ├─ 无关键字 ──► 静默退出
        │
        ▼
读取消息顶层 cwd 字段 ──► Path.name ──► 项目名
        │
        ▼
构建通知
  title   = "Claude Code [项目名]"
  message = 自定义内容 or "任务已执行完成"
        │
        ▼
PowerShell → ToastNotificationManager  ──► 成功 ──► 通知弹出
        │ 失败
        ▼
PowerShell → NotifyIcon 托盘气泡（降级）
```

---

## 系统要求

| 项目 | 要求 |
|------|------|
| 操作系统 | Windows 10 / 11 |
| Python | 3.8+ |
| Claude Code | 任意版本 |
| PowerShell | 5.1+（系统自带） |

---

## License

MIT
