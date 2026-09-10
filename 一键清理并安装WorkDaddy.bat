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
echo   [第 2 步] 当前为普通权限，符合安装要求
echo ==========================================================
echo.
echo 正在查询版本信息（本机已装版本 / GitHub 最新版本）...
call :GET_VERSIONS
echo.
echo ---------------------------------------------------------
echo   版本对照
echo ---------------------------------------------------------
call :SHOW_VER "WorkDaddy 国内版" "%LOCAL_CN%"
call :SHOW_VER "WorkDaddy 海外版" "%LOCAL_AI%"
echo ---------------------------------------------------------
if defined LATEST_TAG (
  echo   最新版本来源：github.com/babygoton/WorkDaddy
) else (
  echo   [!] 未能获取最新版本号（网络受限）。仍可安装，但需手动准备安装包。
)
echo.
echo ==========================================================
echo   选择要安装的版本
echo ==========================================================
echo   [1] 国内版 WorkDaddy
echo   [2] 海外版 WorkDaddy AI
echo   [3] 两个都装
echo   [0] 退出
echo.
choice /C 1230 /N /M "请输入选项 [1/2/3/0]："
if errorlevel 4 exit /b 0
if errorlevel 3 goto :BOTH
if errorlevel 2 goto :AI_ONLY
goto :CN_ONLY

:CN_ONLY
call :LAUNCH "WorkDaddy-Setup" "普通版安装包"
goto :DONE
:AI_ONLY
call :LAUNCH "WorkDaddy-AI-Setup" "AI版安装包"
goto :DONE
:BOTH
call :LAUNCH "WorkDaddy-Setup" "普通版安装包"
call :LAUNCH "WorkDaddy-AI-Setup" "AI版安装包"
goto :DONE

:LAUNCH
rem %~1 = 安装包文件名前缀（不含版本、不含扩展名），例如 WorkDaddy-Setup
rem %~2 = 显示名称
echo.
echo ---- 处理 %~2 ----
set "PKG="
call :FIND_PACKAGE "%~1-*.exe"
if not defined PKG (
  echo [提示] 本地未找到 %~2。
  echo.
  set "WD_ANS="
  if defined LATEST_TAG (
    set /P "WD_ANS=是否自动下载最新版 %LATEST_TAG%？[回车或 Y = 下载 / N = 手动指定路径]："
  ) else (
    set /P "WD_ANS=是否尝试自动下载最新版？[回车或 Y = 下载 / N = 手动指定路径]："
  )
  if /I "!WD_ANS!"=="N" (
    call :ASK_MANUAL "%~2"
  ) else (
    call :DOWNLOAD_LATEST "%~1" "%~2"
  )
)
if defined PKG (
  echo.
  echo 启动安装包：!PKG!
  start "" /WAIT "!PKG!"
) else (
  echo [跳过] 未提供 %~2。
)
exit /b 0

:DOWNLOAD_LATEST
rem %~1 = 安装包文件名前缀（如 WorkDaddy-Setup），%~2 = 显示名称
echo.
echo ---- 下载 %~2 ----
echo 源：github.com/babygoton/WorkDaddy Releases
echo 依次尝试网络出口：直连（依赖 Proxifier 等透明代理） -- 127.0.0.1:7897 -- 系统代理
echo.

set "WDU_PS=%TEMP%\wd_download.ps1"
set "WDU_DEST=%~dp0"
if "%WDU_DEST:~-1%"=="\" set "WDU_DEST=%WDU_DEST:~0,-1%"

>  "%WDU_PS%" echo param([string]$Prefix, [string]$Dir)
>> "%WDU_PS%" echo $ErrorActionPreference = 'Stop'
>> "%WDU_PS%" echo $repo = 'https://github.com/babygoton/WorkDaddy'
>> "%WDU_PS%" echo $latest = $repo + '/releases/latest'
>> "%WDU_PS%" echo function Set-NetProxy($url) {
>> "%WDU_PS%" echo   if ($url) {
>> "%WDU_PS%" echo     $wp = New-Object System.Net.WebProxy($url)
>> "%WDU_PS%" echo     $wp.Credentials = [System.Net.CredentialCache]::DefaultCredentials
>> "%WDU_PS%" echo     [System.Net.WebRequest]::DefaultWebProxy = $wp
>> "%WDU_PS%" echo   } else {
>> "%WDU_PS%" echo     [System.Net.WebRequest]::DefaultWebProxy = $null
>> "%WDU_PS%" echo   }
>> "%WDU_PS%" echo }
>> "%WDU_PS%" echo function Resolve-Tag {
>> "%WDU_PS%" echo   $req = [System.Net.HttpWebRequest]::Create($latest)
>> "%WDU_PS%" echo   $req.AllowAutoRedirect = $false
>> "%WDU_PS%" echo   $req.Method = 'HEAD'
>> "%WDU_PS%" echo   $req.UserAgent = 'WorkDaddy-Installer'
>> "%WDU_PS%" echo   $res = $null
>> "%WDU_PS%" echo   try {
>> "%WDU_PS%" echo     $res = $req.GetResponse()
>> "%WDU_PS%" echo     $loc = $res.Headers['Location']
>> "%WDU_PS%" echo     if (-not $loc) { $loc = $res.GetResponseHeader('Location') }
>> "%WDU_PS%" echo     if ($loc) { $pp = $loc.Split('/'); return $pp[$pp.Length-1] }
>> "%WDU_PS%" echo     return ''
>> "%WDU_PS%" echo   } catch {
>> "%WDU_PS%" echo     $er = $_.Exception.Response
>> "%WDU_PS%" echo     if ($er -and $er.Headers['Location']) { $qq = $er.Headers['Location'].Split('/'); return $qq[$qq.Length-1] }
>> "%WDU_PS%" echo     return ''
>> "%WDU_PS%" echo   } finally {
>> "%WDU_PS%" echo     if ($res) { $res.Close() }
>> "%WDU_PS%" echo   }
>> "%WDU_PS%" echo }
>> "%WDU_PS%" echo function RouteLabel($px) { if ($px) { return $px } else { return 'direct' } }
>> "%WDU_PS%" echo $pool = New-Object System.Collections.ArrayList
>> "%WDU_PS%" echo [void]$pool.Add('')
>> "%WDU_PS%" echo [void]$pool.Add('http://127.0.0.1:7897')
>> "%WDU_PS%" echo try {
>> "%WDU_PS%" echo   $ie = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction Stop
>> "%WDU_PS%" echo   if ($ie.ProxyEnable -eq 1 -and $ie.ProxyServer) { [void]$pool.Add('http://' + $ie.ProxyServer) }
>> "%WDU_PS%" echo } catch {}
>> "%WDU_PS%" echo $tag = ''
>> "%WDU_PS%" echo foreach ($px in $pool) {
>> "%WDU_PS%" echo   Set-NetProxy $px
>> "%WDU_PS%" echo   Write-Host ('  [tag] route=' + (RouteLabel $px))
>> "%WDU_PS%" echo   $tag = Resolve-Tag
>> "%WDU_PS%" echo   if ($tag) { Write-Host ('  [tag] latest version = ' + $tag); break }
>> "%WDU_PS%" echo   Write-Host '  [tag] no answer on this route'
>> "%WDU_PS%" echo }
>> "%WDU_PS%" echo if (-not $tag) { Write-Output 'FAIL=cannot resolve latest version'; exit 1 }
>> "%WDU_PS%" echo $name = $Prefix + '-' + $tag + '.exe'
>> "%WDU_PS%" echo $dl = $repo + '/releases/download/' + $tag + '/' + $name
>> "%WDU_PS%" echo Write-Host ('  [target] ' + $name)
>> "%WDU_PS%" echo $expect = 0
>> "%WDU_PS%" echo foreach ($px in $pool) {
>> "%WDU_PS%" echo   try {
>> "%WDU_PS%" echo     Set-NetProxy $px
>> "%WDU_PS%" echo     $rq = [System.Net.HttpWebRequest]::Create($dl)
>> "%WDU_PS%" echo     $rq.Method = 'HEAD'
>> "%WDU_PS%" echo     $rq.UserAgent = 'WorkDaddy-Installer'
>> "%WDU_PS%" echo     $rs = $rq.GetResponse()
>> "%WDU_PS%" echo     $expect = $rs.ContentLength
>> "%WDU_PS%" echo     $rs.Close()
>> "%WDU_PS%" echo     if ($expect -gt 0) { Write-Host ('  [size] ' + [math]::Round($expect/1MB,1) + ' MB expected'); break }
>> "%WDU_PS%" echo   } catch { Write-Host ('  [size] probe failed: ' + $_.Exception.Message) }
>> "%WDU_PS%" echo }
>> "%WDU_PS%" echo $out = Join-Path $Dir $name
>> "%WDU_PS%" echo $done = $false
>> "%WDU_PS%" echo foreach ($px in $pool) {
>> "%WDU_PS%" echo   if ($done) { break }
>> "%WDU_PS%" echo   try {
>> "%WDU_PS%" echo     Set-NetProxy $px
>> "%WDU_PS%" echo     Write-Host ('  [get] route=' + (RouteLabel $px))
>> "%WDU_PS%" echo     if (Test-Path $out) { Remove-Item $out -Force -ErrorAction SilentlyContinue }
>> "%WDU_PS%" echo     $wc = New-Object System.Net.WebClient
>> "%WDU_PS%" echo     $wc.Headers.Add('User-Agent','WorkDaddy-Installer')
>> "%WDU_PS%" echo     $wc.Proxy = [System.Net.WebRequest]::DefaultWebProxy
>> "%WDU_PS%" echo     $wc.DownloadFile($dl, $out)
>> "%WDU_PS%" echo     if (Test-Path $out) {
>> "%WDU_PS%" echo       $len = (Get-Item $out).Length
>> "%WDU_PS%" echo       if ($expect -gt 0 -and $len -ne $expect) {
>> "%WDU_PS%" echo         Write-Host ('  [get] incomplete: got ' + $len + ' expected ' + $expect + ', retry next route')
>> "%WDU_PS%" echo         Remove-Item $out -Force -ErrorAction SilentlyContinue
>> "%WDU_PS%" echo       } else {
>> "%WDU_PS%" echo         $done = $true
>> "%WDU_PS%" echo         Write-Host ('  [OK] saved ' + [math]::Round($len/1MB,1) + ' MB')
>> "%WDU_PS%" echo         break
>> "%WDU_PS%" echo       }
>> "%WDU_PS%" echo     }
>> "%WDU_PS%" echo   } catch {
>> "%WDU_PS%" echo     Write-Host ('  [get] failed: ' + $_.Exception.Message)
>> "%WDU_PS%" echo     Remove-Item $out -Force -ErrorAction SilentlyContinue
>> "%WDU_PS%" echo   }
>> "%WDU_PS%" echo }
>> "%WDU_PS%" echo if (-not $done) { Write-Output 'FAIL=all network routes failed'; exit 1 }
>> "%WDU_PS%" echo Write-Output ('OK=' + $out)

set "PKG="
set "WD_ERR="
for /f "usebackq tokens=1,* delims==" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%WDU_PS%" -Prefix "%~1" -Dir "%WDU_DEST%"`) do (
  if /I "%%A"=="OK" set "PKG=%%B"
  if /I "%%A"=="FAIL" set "WD_ERR=%%B"
)
if defined WD_ERR echo [!] 下载失败：%WD_ERR%
if not defined PKG (
  echo [!] 自动下载未完成。可改用浏览器下载后手动指定路径：
  echo     https://github.com/babygoton/WorkDaddy/releases/latest
)
if defined PKG if not exist "!PKG!" set "PKG="
exit /b 0

:GET_VERSIONS
rem 输出变量：LATEST_TAG / LOCAL_CN / LOCAL_AI
set "LATEST_TAG="
set "LOCAL_CN="
set "LOCAL_AI="
set "WDV_PS=%TEMP%\wd_versions.ps1"
>  "%WDV_PS%" echo $ErrorActionPreference = 'Stop'
>> "%WDV_PS%" echo function Get-InstalledVer([string]$dir) {
>> "%WDV_PS%" echo   $p = Join-Path $env:LOCALAPPDATA ('Programs\' + $dir)
>> "%WDV_PS%" echo   if (-not (Test-Path $p)) { return '' }
>> "%WDV_PS%" echo   $v = Get-ChildItem -Path $p -Filter *.exe -ErrorAction SilentlyContinue ^| ForEach-Object { $_.VersionInfo.ProductVersion } ^| Where-Object { $_ -and $_.Trim() -ne '' } ^| Select-Object -First 1
>> "%WDV_PS%" echo   if ($v) { return ([string]$v).Trim() } else { return '' }
>> "%WDV_PS%" echo }
>> "%WDV_PS%" echo function Get-LatestTag {
>> "%WDV_PS%" echo   $req = [System.Net.HttpWebRequest]::Create('https://github.com/babygoton/WorkDaddy/releases/latest')
>> "%WDV_PS%" echo   $req.AllowAutoRedirect = $false
>> "%WDV_PS%" echo   $req.Method = 'HEAD'
>> "%WDV_PS%" echo   $req.UserAgent = 'WorkDaddy-Installer'
>> "%WDV_PS%" echo   $res = $null
>> "%WDV_PS%" echo   try {
>> "%WDV_PS%" echo     $res = $req.GetResponse()
>> "%WDV_PS%" echo     $loc = $res.Headers['Location']
>> "%WDV_PS%" echo     if (-not $loc) { $loc = $res.GetResponseHeader('Location') }
>> "%WDV_PS%" echo     if ($loc) { $pp = $loc.Split('/'); return $pp[$pp.Length-1] }
>> "%WDV_PS%" echo     return ''
>> "%WDV_PS%" echo   } catch {
>> "%WDV_PS%" echo     $er = $_.Exception.Response
>> "%WDV_PS%" echo     if ($er -and $er.Headers['Location']) { $qq = $er.Headers['Location'].Split('/'); return $qq[$qq.Length-1] }
>> "%WDV_PS%" echo     return ''
>> "%WDV_PS%" echo   } finally {
>> "%WDV_PS%" echo     if ($res) { $res.Close() }
>> "%WDV_PS%" echo   }
>> "%WDV_PS%" echo }
>> "%WDV_PS%" echo Write-Output ('TAG=' + (Get-LatestTag))
>> "%WDV_PS%" echo Write-Output ('CN=' + (Get-InstalledVer 'WorkDaddy'))
>> "%WDV_PS%" echo Write-Output ('AI=' + (Get-InstalledVer 'WorkDaddy AI'))
for /f "usebackq tokens=1,* delims==" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%WDV_PS%"`) do (
  if /I "%%A"=="TAG" set "LATEST_TAG=%%B"
  if /I "%%A"=="CN" set "LOCAL_CN=%%B"
  if /I "%%A"=="AI" set "LOCAL_AI=%%B"
)
exit /b 0

:SHOW_VER
rem %~1 = 显示名称，%~2 = 本地版本号
if "%~2"=="" (
  echo   %~1 ：未安装 ^| 最新版：%LATEST_TAG%
) else (
  echo   %~1 ：已装 %~2 ^| 最新版：%LATEST_TAG%
  if "%~2"=="%LATEST_TAG%" (
    echo       ^(已是最新^)
  ) else (
    echo       ^(有新版本可升级^)
  )
)
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
