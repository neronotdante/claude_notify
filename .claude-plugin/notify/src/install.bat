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

:: 检查脚本存在
if not exist "%NOTIFY_SCRIPT%" (
    echo [错误] notify.py 不存在: %NOTIFY_SCRIPT%
    pause & exit /b 1
)

:: 1. 将 manifest.json 里的占位符替换为真实路径
set SAFE_PATH=%NOTIFY_SCRIPT:\=/%
powershell -NonInteractive -NoProfile -Command ^
  "$m = '%MANIFEST:\=/%'; ^
   $s = '%SAFE_PATH%'; ^
   $txt = Get-Content $m -Raw; ^
   if ($txt -match 'NOTIFY_SCRIPT_PATH') { ^
       $txt = $txt -replace 'NOTIFY_SCRIPT_PATH', \"python \`\"$s\`\"\"; ^
       Set-Content $m $txt -Encoding utf8; ^
       Write-Host '[OK] manifest.json 路径已写入' ^
   } else { Write-Host '[OK] manifest.json 路径已是最新' }"

:: 2. 注册插件到 settings.json，并清理旧的全局 Stop hook
powershell -NonInteractive -NoProfile -Command ^
 "$f = '%SETTINGS:\=/%'; ^
  $j = Get-Content $f -Raw | ConvertFrom-Json; ^
  $pd = '%PLUGIN_ROOT:\=/%'; ^
  if (-not $j.PSObject.Properties['extraKnownMarketplaces']) { ^
      $j | Add-Member -NotePropertyName extraKnownMarketplaces -NotePropertyValue ([PSCustomObject]@{}) ^
  }; ^
  $j.extraKnownMarketplaces | Add-Member -Force -NotePropertyName 'claude-notify' ^
      -NotePropertyValue ([PSCustomObject]@{ source=[PSCustomObject]@{source='directory';path=$pd} }); ^
  if (-not $j.PSObject.Properties['enabledPlugins']) { ^
      $j | Add-Member -NotePropertyName enabledPlugins -NotePropertyValue ([PSCustomObject]@{}) ^
  }; ^
  $j.enabledPlugins | Add-Member -Force -NotePropertyName 'claude-notify@claude-notify' -NotePropertyValue $true; ^
  if ($j.PSObject.Properties['hooks'] -and $j.hooks.PSObject.Properties['Stop']) { ^
      $kept = @($j.hooks.Stop | Where-Object { ^
          -not ($_.hooks | Where-Object { $_.command -like '*notify.py*' }) }); ^
      if ($kept.Count -eq 0) { $j.hooks.PSObject.Properties.Remove('Stop') } ^
      else { $j.hooks.Stop = $kept }; ^
      if ($j.hooks.PSObject.Properties.Count -eq 0) { $j.PSObject.Properties.Remove('hooks') } ^
  }; ^
  $j | ConvertTo-Json -Depth 10 | Set-Content $f -Encoding utf8; ^
  Write-Host '[OK] settings.json 已更新'"

if errorlevel 1 ( echo [错误] settings.json 更新失败 & pause & exit /b 1 )

:: 3. 发送测试通知
echo.
echo 正在发送测试通知...
echo {"session_id":"install-test","transcript_path":"","stop_hook_active":false} | python "%NOTIFY_SCRIPT%"
echo (通知需要 transcript_path 有效才会弹出，此测试正常静默)

echo.
echo ============================================
echo  安装完成！重启 Claude Code 后生效。
echo  触发关键字：[notify]  -notify  !done  [完成通知]
echo  自定义消息：[notify: 你的提示文字]
echo ============================================
pause
