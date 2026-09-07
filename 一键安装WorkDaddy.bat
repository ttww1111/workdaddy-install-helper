@echo off
chcp 936 >nul
setlocal EnableExtensions EnableDelayedExpansion

title WorkDaddy 安装启动器（普通权限）
echo ==========================================================
echo   WorkDaddy 安装启动器（普通未提权权限）
echo   可选择：国内版、AI版，或两个都装
echo   本脚本不会结束任何进程，只负责启动安装包
echo ==========================================================
echo.

net session >nul 2>&1
if %errorlevel%==0 goto :ELEVATED

echo 当前脚本未处于管理员提权状态。
echo 请先运行“管理员结束WorkBuddy进程.bat”，并确认 WorkBuddy 已退出。
echo.
echo 选择要启动的安装包：
echo   [1] 国内版 WorkBuddy
echo   [2] 海外版 WorkBuddyAI
echo   [3] 两个都装
echo   [0] 退出
echo.
choice /C 1230 /N /M "请输入选项 [1/2/3/0]："
if errorlevel 4 exit /b 0
if errorlevel 3 goto :BOTH
if errorlevel 2 goto :AI_ONLY
if errorlevel 1 goto :CN_ONLY
exit /b 0

:CN_ONLY
call :LAUNCH_CN
goto :DONE

:AI_ONLY
call :LAUNCH_AI
goto :DONE

:BOTH
call :LAUNCH_CN
call :LAUNCH_AI
goto :DONE

:LAUNCH_CN
echo.
echo ---- 查找普通版（国内 WorkBuddy）安装包 ----
call :FIND_PACKAGE "WorkDaddy-Setup-*.exe" CN_PACKAGE
if not defined CN_PACKAGE (
  echo [提示] 自动搜索未找到普通版安装包。
  echo         请把安装包拖到本窗口，或直接输入完整路径。
  call :ASK_MANUAL "普通版安装包" CN_PACKAGE
)
if defined CN_PACKAGE (
  echo 启动：!CN_PACKAGE!
  start "" /WAIT "!CN_PACKAGE!"
) else (
  echo [跳过] 未提供普通版安装包。
)
exit /b 0

:LAUNCH_AI
echo.
echo ---- 查找 AI 版（海外 WorkBuddyAI）安装包 ----
call :FIND_PACKAGE "WorkDaddy-AI-Setup-*.exe" AI_PACKAGE
if not defined AI_PACKAGE (
  echo [提示] 自动搜索未找到 AI 版安装包。
  echo         请把安装包拖到本窗口，或直接输入完整路径。
  call :ASK_MANUAL "AI版安装包" AI_PACKAGE
)
if defined AI_PACKAGE (
  echo 启动：!AI_PACKAGE!
  start "" /WAIT "!AI_PACKAGE!"
) else (
  echo [跳过] 未提供 AI 版安装包。
)
exit /b 0

:FIND_PACKAGE
set "PATTERN=%~1"
set "__OUTVAR=%~2"
set "!__OUTVAR!="
for %%D in ("%USERPROFILE%\Desktop" "%USERPROFILE%\Downloads" "%USERPROFILE%" "%~dp0") do (
  for /f "delims=" %%F in ('dir /b /a-d "%%~D\!PATTERN!" 2^>nul') do if not defined !__OUTVAR! set "!__OUTVAR!=%%~D\%%F"
)
exit /b 0

:ASK_MANUAL
set "LABEL=%~1"
set "__OUTVAR=%~2"
set "INPUT_PATH="
echo.
set /P "INPUT_PATH=请输入 !LABEL! 的完整路径（直接回车跳过）："
if not defined INPUT_PATH exit /b 0
set "INPUT_PATH=!INPUT_PATH:"=!"
if exist "!INPUT_PATH!" set "!__OUTVAR!=!INPUT_PATH!"
if not defined !__OUTVAR! echo [提示] 路径不存在，已跳过：!INPUT_PATH!
exit /b 0

:DONE
echo.
echo 选择的安装包已处理完毕。
pause
exit /b 0

:ELEVATED
echo.
echo [!] 当前安装启动器处于管理员 / 高权限状态，已停止。
echo     项目源码明确禁止管理员模式安装；这里不能继续启动安装器。
echo     请关闭这个窗口，从文件资源管理器直接双击本 BAT。
echo     不要从管理员 Terminal/cmd 启动，也不要右键“以管理员身份运行”。
pause
exit /b 1
