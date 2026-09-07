@echo off
chcp 65001 >nul
setlocal

:: 本脚本只负责清理 WorkBuddy / WorkDaddy，不会启动安装器。
:: 需要管理员权限；普通双击时会请求一次 UAC 提权。
if /I "%~1"=="elevated" goto :RUN
net session >nul 2>&1
if %errorlevel%==0 goto :RUN

echo 正在请求管理员权限，仅用于结束 WorkBuddy / WorkDaddy 进程...
powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList 'elevated' -Verb RunAs"
exit /b

:RUN
title 管理员清理 WorkBuddy / WorkDaddy 进程
echo ==========================================================
echo   管理员清理脚本（自动检查 UAC，只结束进程）
echo ==========================================================
echo.
echo 正在检查 UAC 和内置 Administrator 配置...
powershell -NoProfile -Command "$p=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -ErrorAction SilentlyContinue; $id=[Security.Principal.WindowsIdentity]::GetCurrent(); if($null -eq $p -or $p.EnableLUA -ne 1){exit 10}; if($id.User.Value -match '-500$' -and $p.FilterAdministratorToken -ne 1){exit 11}; exit 0"
if %errorlevel%==11 goto :FILTER_OFF
if %errorlevel%==10 goto :UAC_OFF
if not %errorlevel%==0 goto :POLICY_READ_FAIL
echo [OK] UAC/LUA 已开启，当前账户权限配置可用。
echo.
goto :CLEAN

:UAC_OFF
echo.
echo [!] 检测到 UAC/LUA 已关闭。
echo     WorkDaddy 安装器要求 UAC 开启；是否现在自动开启？
choice /C YN /N /M "启用 UAC？[Y/N]："
if errorlevel 2 exit /b 2
powershell -NoProfile -Command "New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name EnableLUA -PropertyType DWord -Value 1 -Force | Out-Null"
echo [OK] UAC 已开启。请重启 Windows 后重新运行这两个脚本。
pause
exit /b 2

:FILTER_OFF
echo.
echo [!] 检测到当前是内置 Administrator，且 UAC 分离令牌未开启。
echo     即使 UAC 滑块正常，普通双击也可能仍是高权限。
echo     是否现在自动设置 FilterAdministratorToken=1？
choice /C YN /N /M "启用分离令牌？[Y/N]："
if errorlevel 2 exit /b 2
powershell -NoProfile -Command "New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name FilterAdministratorToken -PropertyType DWord -Value 1 -Force | Out-Null"
echo [OK] 分离令牌已设置。请重启 Windows 后重新运行这两个脚本。
pause
exit /b 2

:POLICY_READ_FAIL
echo.
echo [!] 无法读取 UAC 配置，已停止清理。
echo     请确认系统 PowerShell 可用，然后重试。
pause
exit /b 3

:CLEAN
echo 正在结束 WorkBuddy 及其子进程...
taskkill /IM WorkBuddy.exe /F /T
taskkill /IM WorkBuddyAI.exe /F /T
echo.
echo 正在结束 WorkDaddy 生命周期进程...
taskkill /IM WorkDaddy.exe /F /T
taskkill /IM WorkDaddyLauncher.exe /F /T
echo.
echo 正在查找命令行中明确属于 WorkDaddy / WorkBuddy 的 Node 后台进程...
powershell -NoProfile -Command "$ps = Get-CimInstance Win32_Process -Filter \"Name='node.exe'\" | Where-Object { $_.CommandLine -match '(?i)workdaddy|workbuddy' }; if ($ps) { $ps | ForEach-Object { Write-Host ('结束 PID ' + $_.ProcessId + ': ' + $_.CommandLine); Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } } else { Write-Host '未发现匹配的 Node 后台进程。' }"
echo.
echo 等待 2 秒并精确复核...
timeout /t 2 >nul
set "LEFT=0"
tasklist /FI "IMAGENAME eq WorkBuddy.exe" 2>nul | findstr /I /C:"WorkBuddy.exe" >nul && set "LEFT=1"
tasklist /FI "IMAGENAME eq WorkBuddyAI.exe" 2>nul | findstr /I /C:"WorkBuddyAI.exe" >nul && set "LEFT=1"
tasklist /FI "IMAGENAME eq WorkDaddy.exe" 2>nul | findstr /I /C:"WorkDaddy.exe" >nul && set "LEFT=1"
tasklist /FI "IMAGENAME eq WorkDaddyLauncher.exe" 2>nul | findstr /I /C:"WorkDaddyLauncher.exe" >nul && set "LEFT=1"
if "%LEFT%"=="1" (
  echo.
  echo [!] 仍有目标进程存在：
  tasklist /FI "IMAGENAME eq WorkBuddy.exe"
  tasklist /FI "IMAGENAME eq WorkBuddyAI.exe"
  tasklist /FI "IMAGENAME eq WorkDaddy.exe"
  tasklist /FI "IMAGENAME eq WorkDaddyLauncher.exe"
  echo.
  echo 可能是进程正在自动重启，或被安全软件保护。请先关闭 WorkBuddy 自动启动，
  echo 再运行本脚本；不要在这个窗口里启动安装器。
  pause
  exit /b 1
)
echo [OK] 目标进程已清理完成。
echo 现在请关闭本窗口，再直接双击“一键安装WorkDaddy.bat”。
echo 后一个脚本必须以普通未提权权限运行。
echo 如果只安装一个版本，安装启动器会让你选择国内版或 AI 版。
pause
exit /b 0
