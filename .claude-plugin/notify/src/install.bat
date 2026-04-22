@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

:: 本文件位于 .claude-plugin/notify/src/，向上三级是插件根目录
set SRC_DIR=%~dp0
set NOTIFY_SCRIPT=%SRC_DIR%notify.py
for %%i in ("%SRC_DIR%..\..\..") do set PLUGIN_ROOT=%%~fi
set MANIFEST=%SRC_DIR%..\..\manifest.json
set SETTINGS=%USERPROFILE%\.claude\settings.json

echo ============================================
echo  Claude Notify 插件安装
echo ============================================
echo  插件根目录: %PLUGIN_ROOT%
echo  核心脚本:   %NOTIFY_SCRIPT%
echo.

:: 检查 Python
python --version >nul 2>&1
if errorlevel 1 ( echo [错误] 未找到 Python & pause & exit /b 1 )
echo [OK] Python 已找到

if not exist "%NOTIFY_SCRIPT%" (
    echo [错误] notify.py 不存在: %NOTIFY_SCRIPT%
    pause & exit /b 1
)

:: 1. 将 manifest.json 占位符替换为真实路径（仅供展示，实际 hook 写 settings.json）
set SAFE_PATH=%NOTIFY_SCRIPT:\=/%
powershell -NonInteractive -NoProfile -Command ^
  "$m = '%MANIFEST:\=/%'; ^
   $s = '%SAFE_PATH%'; ^
   $txt = Get-Content $m -Raw; ^
   if ($txt -match 'NOTIFY_SCRIPT_PATH') { ^
       $txt = $txt -replace 'NOTIFY_SCRIPT_PATH', \"python \`\"$s\`\"\"; ^
       Set-Content $m $txt -Encoding utf8; ^
       Write-Host '[OK] manifest.json 路径已写入' ^
   } else { Write-Host '[OK] manifest.json 已是最新' }"

:: 2. 将 Stop hook 直接写入 settings.json（插件 manifest 不会自动注入 hook）
powershell -NonInteractive -NoProfile -Command ^
 "$f = '%SETTINGS:\=/%'; ^
  $s = '%SAFE_PATH%'; ^
  $j = Get-Content $f -Raw | ConvertFrom-Json; ^
  $pd = '%PLUGIN_ROOT:\=/%'; ^
  if (-not $j.PSObject.Properties['hooks']) { ^
      $j | Add-Member -NotePropertyName hooks -NotePropertyValue ([PSCustomObject]@{}) ^
  }; ^
  if (-not $j.hooks.PSObject.Properties['Stop']) { ^
      $j.hooks | Add-Member -NotePropertyName Stop -NotePropertyValue @() ^
  }; ^
  $exists = $j.hooks.Stop | Where-Object { ^
      $_.hooks | Where-Object { $_.command -like '*notify.py*' } }; ^
  if (-not $exists) { ^
      $hook = [PSCustomObject]@{ type='command'; command=\"python \`\"$s\`\"\"; timeout=20 }; ^
      $entry = [PSCustomObject]@{ matcher=''; hooks=@($hook) }; ^
      $j.hooks.Stop = @($j.hooks.Stop) + $entry; ^
      Write-Host '[OK] hooks.Stop 已写入 settings.json' ^
  } else { Write-Host '[OK] hooks.Stop 已存在，跳过' }; ^
  if (-not $j.PSObject.Properties['extraKnownMarketplaces']) { ^
      $j | Add-Member -NotePropertyName extraKnownMarketplaces -NotePropertyValue ([PSCustomObject]@{}) ^
  }; ^
  $j.extraKnownMarketplaces | Add-Member -Force -NotePropertyName 'claude-notify' ^
      -NotePropertyValue ([PSCustomObject]@{ source=[PSCustomObject]@{source='directory';path=$pd} }); ^
  if (-not $j.PSObject.Properties['enabledPlugins']) { ^
      $j | Add-Member -NotePropertyName enabledPlugins -NotePropertyValue ([PSCustomObject]@{}) ^
  }; ^
  $j.enabledPlugins | Add-Member -Force -NotePropertyName 'claude-notify@claude-notify' -NotePropertyValue $true; ^
  $j | ConvertTo-Json -Depth 10 | Set-Content $f -Encoding utf8; ^
  Write-Host '[OK] settings.json 更新完成'"

if errorlevel 1 ( echo [错误] settings.json 更新失败 & pause & exit /b 1 )

:: 3. 验证 hook 已写入
echo.
echo 验证配置...
python -c "import json,pathlib; j=json.loads(pathlib.Path('%SETTINGS:\=/%').read_text('utf-8')); stops=j.get('hooks',{}).get('Stop',[]); cmds=[h['command'] for e in stops for h in e['hooks'] if 'notify' in h.get('command','')]; print('[OK] 已注册 hook:',cmds[0] if cmds else '未找到！')"

:: 4. 发送测试通知（需要有效 transcript，此处静默退出属正常）
echo.
echo 正在发送测试通知...
echo {"session_id":"install","transcript_path":"","stop_hook_active":false} | python "%NOTIFY_SCRIPT%"

echo.
echo ============================================
echo  安装完成！重启 Claude Code 后生效。
echo.
echo  测试方法：在 Claude Code 任意项目对话中发送
echo    test --notify
echo  应在 5 秒内收到 Windows 系统通知。
echo ============================================
pause
