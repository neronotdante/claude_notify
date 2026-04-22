# claude-notify

> Claude Code `/notify` 插件：输入 `/notify [消息]` 即可向 Windows 桌面发送 Toast 通知，通知常驻屏幕直到手动关闭。

无需安装任何 Python 第三方库，完全依赖系统自带的 PowerShell + Windows Runtime。

---

## 效果预览

```
┌─────────────────────────────────┐
│ Claude Code [claude_notify]     │
│ 任务已执行完成                   │
│                            [×]  │
└─────────────────────────────────┘
```

通知使用 `scenario="reminder"` 模式，常驻右下角直到用户手动关闭。

---

## 使用方式

在 Claude Code 对话中输入：

```
/notify                          # 发送默认通知：任务已执行完成
/notify 部署完成，请检查日志      # 发送自定义消息
```

---

## 安装

### 方式一：通过 Plugin Marketplace（推荐）

在 `~/.claude/settings.json` 中添加：

```json
{
  "extraKnownMarketplaces": {
    "claude-notify": {
      "source": {
        "source": "directory",
        "path": "<claude_notify 本地路径>"
      }
    }
  },
  "enabledPlugins": {
    "claude-notify@claude-notify": true
  }
}
```

重启 Claude Code 后自动识别，`/notify` 指令即可使用。

### 方式二：手动注册全局 Hook（备选）

若不使用插件系统，可在 `~/.claude/settings.json` 中直接添加 Stop hook（但此方式为被动触发，已由本项目废弃）。

---

## 文件结构

```
claude_notify/
├── .claude-plugin/
│   ├── marketplace.json        # Marketplace 声明
│   ├── plugin.json             # 插件元数据 + command 注册
│   └── notify/
│       └── src/
│           ├── notify.py       # 核心脚本（支持直接调用 + Hook 兼容）
│           └── install.bat     # 旧版手动安装（已废弃）
├── commands/
│   └── notify.md               # /notify slash command 定义
└── README.md
```

---

## 实现原理

```
用户输入 /notify [消息]
        │
        ▼
Claude Code 加载 commands/notify.md
        │
        ▼
Claude 调用 Bash 执行：
  python notify.py "<消息>"
        │
        ▼
notify.py 直接调用模式
  title   = "Claude Code [当前工作目录名]"
  message = 用户消息 or "任务已执行完成"
        │
        ▼
PowerShell → ToastNotificationManager
  scenario="reminder"           ──► 成功 ──► 通知常驻屏幕
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
