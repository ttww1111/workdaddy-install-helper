@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 936 >nul
title WorkDaddy 一键清理并安装

if /I "%~1"=="KILL" goto :DO_KILL

echo ==========================================================
echo   WorkDaddy 一键脚本：结束旧进程 + 启动安装包（一次搞定）
echo ==========================================================
echo.

echo 正在检查 UAC / 内置 Administrator 配置...
powershell -NoProfile -Command "$p=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -ErrorAction SilentlyContinue; $id=[Security.Principal.WindowsIdentity]::GetCurrent(); if($null -eq $p -or $p.EnableLUA -ne 1){exit 10}; if($id.User.Value -match '-500$' -and $p.FilterAdministratorToken -ne 1){exit 11}; exit 0"
if %errorlevel%==11 goto :FILTER_OFF
if %errorlevel%==10 goto :UAC_OFF
if not %errorlevel%==0 goto :POLICY_READ_FAIL
echo [OK] UAC 配置正常。
echo.

net session >nul 2>&1
if %errorlevel%==0 goto :IS_ELEVATED

echo [第 1 步] 正在请求管理员权限结束旧进程（UAC 弹窗请点“是”）...
powershell -NoProfile -Command "$p = Start-Process -FilePath '%~f0' -ArgumentList 'KILL' -Verb RunAs -Wait -PassThru; exit $p.ExitCode"
if not "%errorlevel%"=="0" echo [提示] 清理步骤返回码 %errorlevel%，若提示“找不到进程”属正常，可继续安装。
echo.

:MENU
echo ==========================================================
echo   [第 2 步] 选择要安装的版本（当前为普通权限，符合安装要求）
echo ==========================================================
echo   [1] 国内版 WorkBuddy
echo   [2] 海外版 WorkBuddyAI
echo   [3] 两个都装
echo   [0] 退出
echo.
choice /C 1230 /N /M "请输入选项 [1/2/3/0]："
if errorlevel 4 exit /b 0
if errorlevel 3 goto :BOTH
if errorlevel 2 goto :AI_ONLY
goto :CN_ONLY

:CN_ONLY
call :LAUNCH "WorkDaddy-Setup-*.exe" "普通版安装包"
goto :DONE
:AI_ONLY
call :LAUNCH "WorkDaddy-AI-Setup-*.exe" "AI版安装包"
goto :DONE
:BOTH
call :LAUNCH "WorkDaddy-Setup-*.exe" "普通版安装包"
call :LAUNCH "WorkDaddy-AI-Setup-*.exe" "AI版安装包"
goto :DONE

:LAUNCH
echo.
echo ---- 查找 %~2（匹配 %~1）----
set "PKG="
call :FIND_PACKAGE "%~1"
if not defined PKG (
  echo [提示] 本地未找到。
  choice /C YN /N /M "自动下载最新版？[Y=自动下载 / N=手动输入路径]："
  if not errorlevel 2 (
    call :DOWNLOAD_LATEST "%~1"
  ) else (
    call :ASK_MANUAL "%~2"
  )
)
if defined PKG (
  echo 启动：!PKG!
  start "" /WAIT "!PKG!"
) else (
  echo [跳过] 未提供 %~2。
)
exit /b 0

:DOWNLOAD_LATEST
echo.
echo 正在获取最新版本号并下载（源：github.com/babygoton/WorkDaddy Releases）...
echo 若下载失败多为网络被墙，可改用浏览器下载后手动输入路径。
for /f "usebackq delims=" %%P in (`powershell -NoProfile -Command "$ErrorActionPreference='Stop'; $r=Invoke-RestMethod 'https://api.github.com/repos/babygoton/WorkDaddy/releases/latest'; $n='%~1-' + $r.tag_name + '.exe'; $a=$r.assets | Where-Object { $_.name -eq $n }; if(-not $a){throw 'asset not found'}; $out=Join-Path '%~dp0' $n; Write-Host ('下载 ' + $n + ' （约 28MB）...'); curl.exe -sL $a.browser_download_url -o $out; if((Get-Item $out).Length -lt 10MB){Remove-Item $out -Force; throw 'download incomplete'}; Write-Host ('[OK] 已保存到 ' + $out); $out"`) do set "PKG=%%P"
if not defined PKG echo [!] 自动下载失败，请手动输入路径或用浏览器下载。
if defined PKG if not exist "!PKG!" set "PKG="
exit /b 0

:FIND_PACKAGE
for %%D in ("%USERPROFILE%\Desktop" "%USERPROFILE%\Downloads" "%USERPROFILE%" "%~dp0") do (
  for /f "delims=" %%F in ('dir /b /a-d "%%~D\%~1" 2^>nul') do if not defined PKG set "PKG=%%~D\%%F"
)
exit /b 0

:ASK_MANUAL
set "INPUT_PATH="
echo.
set /P "INPUT_PATH=请输入 %~1 的完整路径（直接回车跳过）："
if not defined INPUT_PATH exit /b 0
set "INPUT_PATH=%INPUT_PATH:"=%"
if exist "%INPUT_PATH%" set "PKG=%INPUT_PATH%"
if not defined PKG echo [提示] 路径不存在，已跳过。
exit /b 0

:DONE
echo.
echo 全部处理完毕。
pause
exit /b 0

:IS_ELEVATED
echo.
echo [!] 本脚本正运行在管理员 / 高权限状态，不能在这个权限下启动安装器。
echo     两种可能：
echo       1. 你从“管理员 Terminal/cmd”或“以管理员身份运行”启动了本脚本
echo          —— 请关闭本窗口，改为在文件资源管理器里直接双击运行；
echo       2. 你设置了 UAC 分离令牌 / 开启了 UAC，但还没有重启电脑
echo          —— 请重启 Windows 后再双击运行本脚本。
pause
exit /b 2

:DO_KILL
title 管理员步骤：清理旧进程
echo ==========================================================
echo   [管理员] 结束 WorkBuddy / WorkDaddy 旧进程
echo ==========================================================
taskkill /IM WorkBuddy.exe /F /T 2>nul
taskkill /IM WorkBuddyAI.exe /F /T 2>nul
taskkill /IM WorkDaddy.exe /F /T 2>nul
taskkill /IM WorkDaddyLauncher.exe /F /T 2>nul
echo.
powershell -NoProfile -Command "$ps = Get-CimInstance Win32_Process -Filter \"Name='node.exe'\" | Where-Object { $_.CommandLine -match '(?i)workdaddy|workbuddy' }; if ($ps) { $ps | ForEach-Object { Write-Host ('结束 PID ' + $_.ProcessId); Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } } else { Write-Host '未发现匹配的 Node 后台进程。' }"
echo.
echo 等待 2 秒并复核...
timeout /t 2 >nul
set "LEFT=0"
tasklist /FI "IMAGENAME eq WorkBuddy.exe" 2>nul | findstr /I /C:"WorkBuddy.exe" >nul && set "LEFT=1"
tasklist /FI "IMAGENAME eq WorkBuddyAI.exe" 2>nul | findstr /I /C:"WorkBuddyAI.exe" >nul && set "LEFT=1"
tasklist /FI "IMAGENAME eq WorkDaddy.exe" 2>nul | findstr /I /C:"WorkDaddy.exe" >nul && set "LEFT=1"
tasklist /FI "IMAGENAME eq WorkDaddyLauncher.exe" 2>nul | findstr /I /C:"WorkDaddyLauncher.exe" >nul && set "LEFT=1"
if "%LEFT%"=="1" (
  echo.
  echo [!] 仍有目标进程存在，可能被自动重启或受安全软件保护。
  echo     请先关闭 WorkBuddy 自启动，再重新运行本脚本。
  pause
  exit /b 1
)
echo [OK] 进程清理完成。请按任意键返回安装菜单。
pause >nul
exit /b 0

:UAC_OFF
echo.
echo [!] 检测到 UAC/LUA 已关闭。WorkDaddy 安装器要求 UAC 开启。
choice /C YN /N /M "现在自动开启 UAC？[Y/N]："
if errorlevel 2 exit /b 2
powershell -NoProfile -Command "Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile -Command \"New-ItemProperty -Path ''HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'' -Name EnableLUA -PropertyType DWord -Value 1 -Force | Out-Null\"'"
echo [OK] UAC 已开启。请重启 Windows 后重新运行本脚本。
pause
exit /b 2

:FILTER_OFF
echo.
echo [!] 当前是内置 Administrator，且 UAC 分离令牌未开启（FilterAdministratorToken 不为 1）。
echo     不开启的话，双击运行也永远是管理员权限，安装器会拒绝工作。
choice /C YN /N /M "现在自动设置 FilterAdministratorToken=1？[Y/N]："
if errorlevel 2 exit /b 2
powershell -NoProfile -Command "Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile -Command \"New-ItemProperty -Path ''HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'' -Name FilterAdministratorToken -PropertyType DWord -Value 1 -Force | Out-Null\"'"
echo [OK] 分离令牌已设置。请重启 Windows 后重新运行本脚本。
pause
exit /b 2

:POLICY_READ_FAIL
echo.
echo [!] 无法读取 UAC 配置（注册表或 PowerShell 异常），已停止。
pause
exit /b 3
