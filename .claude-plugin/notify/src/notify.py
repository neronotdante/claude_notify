#!/usr/bin/env python3
"""
Claude Code Windows 通知 Hook
当对话包含特定关键字或特殊命令时，通过 Windows API 弹出系统通知。

触发方式（在对话中包含以下任一关键字）：
  [notify]                   -> 弹出默认完成通知，标题含当前项目名
  [notify: 自定义消息内容]    -> 弹出自定义消息，标题含当前项目名
  --notify / -notify         -> 同 [notify]
  !done                      -> 同 [notify]
  [完成通知]                  -> 同 [notify]
"""

import sys
import json
import re
import subprocess
import os
from pathlib import Path

NOTIFY_PATTERNS = [
    (r'\[notify:\s*(.+?)\]', True),   # 带自定义消息
    (r'\[notify\]', False),
    (r'--?notify', False),
    (r'!done', False),
    (r'\[完成通知\]', False),
    (r'!通知', False),
]


def get_project_name(transcript_path: str) -> str:
    """
    从对话记录中读取当前工作目录，提取项目名称。
    优先读取 transcript 中 user 消息的顶层 cwd 字段；
    降级策略：从 transcript 路径解析项目文件夹名。
    """
    try:
        with open(transcript_path, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue
                cwd = obj.get("cwd") or obj.get("message", {}).get("cwd", "")
                if cwd:
                    return Path(cwd).name or cwd
    except Exception:
        pass

    # 路径结构: .claude/projects/<sanitized-cwd>/<session-id>/transcript.jsonl
    try:
        p = Path(transcript_path)
        sanitized = p.parts[-3]
        rest = sanitized.split('--', 1)[1] if '--' in sanitized else sanitized
        parts = [s for s in rest.split('-') if s]
        return '-'.join(parts[-2:]) if len(parts) >= 2 else rest
    except Exception:
        pass

    return ""


def send_toast(title: str, message: str) -> bool:
    """通过 PowerShell 调用 Windows Runtime API 发送 Toast 通知。"""
    title = title.replace('"', "'").replace('\n', ' ')[:64]
    message = message.replace('"', "'").replace('\n', ' ')[:128]

    ps = f"""
$ErrorActionPreference = 'Stop'
try {{
    $null = [Windows.UI.Notifications.ToastNotificationManager,
             Windows.UI.Notifications, ContentType = WindowsRuntime]
    $null = [Windows.Data.Xml.Dom.XmlDocument,
             Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]

    $xml = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent(
        [Windows.UI.Notifications.ToastTemplateType]::ToastText02)
    $nodes = $xml.GetElementsByTagName('text')
    $nodes.Item(0).InnerText = "{title}"
    $nodes.Item(1).InnerText = "{message}"

    $doc = [Windows.Data.Xml.Dom.XmlDocument]::new()
    $xmlStr = $xml.GetXml() -replace '<toast>', '<toast duration="long">'
    $doc.LoadXml($xmlStr)
    $toast = [Windows.UI.Notifications.ToastNotification]::new($doc)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier(
        "Claude Code").Show($toast)
    exit 0
}} catch {{
    exit 1
}}
"""
    result = subprocess.run(
        ["powershell", "-NonInteractive", "-NoProfile", "-Command", ps],
        capture_output=True, timeout=15
    )
    return result.returncode == 0


def send_balloon(title: str, message: str) -> None:
    """降级方案：使用 PowerShell 系统托盘气泡通知。"""
    title = title.replace("'", "''")[:63]
    message = message.replace("'", "''")[:255]
    ps = f"""
Add-Type -AssemblyName System.Windows.Forms
$n = [System.Windows.Forms.NotifyIcon]::new()
$n.Icon = [System.Drawing.SystemIcons]::Information
$n.Visible = $true
$n.ShowBalloonTip(30000, '{title}', '{message}',
    [System.Windows.Forms.ToolTipIcon]::Info)
Start-Sleep -Seconds 31
$n.Dispose()
"""
    subprocess.Popen(
        ["powershell", "-NonInteractive", "-NoProfile", "-WindowStyle", "Hidden",
         "-Command", ps],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )


def extract_user_texts(transcript_path: str, look_back: int = 10) -> list[str]:
    """从 JSONL 格式的对话记录中提取最近的用户消息文本。"""
    texts = []
    try:
        with open(transcript_path, "r", encoding="utf-8", errors="replace") as f:
            lines = [l.strip() for l in f if l.strip()]

        for raw in reversed(lines):
            try:
                obj = json.loads(raw)
            except json.JSONDecodeError:
                continue

            if obj.get("type") != "user":
                continue

            msg = obj.get("message", obj)
            content = msg.get("content", "")

            if isinstance(content, str):
                texts.append(content)
            elif isinstance(content, list):
                for block in content:
                    if isinstance(block, dict) and block.get("type") == "text":
                        texts.append(block.get("text", ""))

            if len(texts) >= look_back:
                break
    except Exception:
        pass
    return texts


def find_trigger(texts: list[str]) -> tuple[bool, str]:
    """扫描文本列表，返回 (是否触发, 通知消息)。"""
    for text in texts:
        for pattern, has_group in NOTIFY_PATTERNS:
            m = re.search(pattern, text, re.IGNORECASE)
            if m:
                custom = m.group(1).strip() if has_group and m.lastindex else ""
                return True, custom or "任务已执行完成"
    return False, ""


def main() -> None:
    raw = sys.stdin.read().strip()
    try:
        data = json.loads(raw) if raw else {}
    except json.JSONDecodeError:
        sys.exit(0)

    if data.get("stop_hook_active"):
        sys.exit(0)

    transcript_path = data.get("transcript_path", "")
    if not transcript_path or not os.path.isfile(transcript_path):
        sys.exit(0)

    texts = extract_user_texts(transcript_path)
    triggered, message = find_trigger(texts)

    if not triggered:
        sys.exit(0)

    project = get_project_name(transcript_path)
    title = f"Claude Code [{project}]" if project else "Claude Code"

    ok = send_toast(title, message)
    if not ok:
        send_balloon(title, message)


if __name__ == "__main__":
    main()
