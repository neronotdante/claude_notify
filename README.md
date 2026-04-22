# claude-notify

Claude Code **Stop Hook** 插件：当对话包含特定关键字时，通过 Windows Toast API 弹出系统通知，标题自动显示当前项目名。

无需安装任何 Python 第三方库，完全依赖 PowerShell + Windows Runtime。

---

## 效果

```
标题：Claude Code [my_project]
正文：任务已执行完成
```

---

## 触发关键字

在 Claude Code 对话中写入以下任一关键字即可触发：

| 关键字 | 效果 |
|--------|------|
| `[notify]` | 默认通知 |
| `[notify: 你的消息]` | 自定义通知内容 |
| `-notify` / `--notify` | 同 `[notify]` |
| `!done` | 同 `[notify]` |
| `[完成通知]` / `!通知` | 同 `[notify]` |

示例：

```
帮我完成数据库迁移脚本 [notify: 迁移脚本已生成]
```

---

## 安装

### 方式一：克隆安装（推荐）

```bat
git clone https://github.com/<your-username>/claude-notify.git
cd claude-notify
.claude-plugin\notify\src\install.bat
```

`install.bat` 会自动完成：
1. 将脚本绝对路径写入 `.claude-plugin/manifest.json`
2. 在 `~/.claude/settings.json` 注册插件（`extraKnownMarketplaces` + `enabledPlugins`）
3. 清理旧的全局 Stop hook（避免重复触发）

重启 Claude Code 后生效。

### 方式二：手动配置

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
            "command": "python \"<绝对路径>/notify.py\"",
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
claude-notify/
├── .claude-plugin/
│   ├── manifest.json               # 插件声明 + Stop hook 配置
│   └── notify/
│       └── src/
│           ├── notify.py           # 核心脚本
│           └── install.bat         # 一键安装脚本（Windows）
└── README.md
```

---

## 通知实现原理

```
用户消息含关键字
       ↓
Claude Code 响应结束 → Stop 事件
       ↓
notify.py 从 stdin 读取 JSON payload
       ↓
读取 transcript.jsonl → 提取用户消息 → 匹配关键字
       ↓
读取 cwd 字段 → Path.name → 项目名
       ↓
PowerShell → ToastNotificationManager (主路径)
       ↓ 失败
PowerShell → NotifyIcon 托盘气泡 (降级)
```

---

## 系统要求

- Windows 10 / 11
- Python 3.8+
- Claude Code（任意版本）
- PowerShell 5.1+（系统自带）
