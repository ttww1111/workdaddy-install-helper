# WorkDaddy install helper

适用于 Windows 的 WorkDaddy 安装辅助脚本，针对安装器要求“普通权限运行”、而 WorkBuddy 后台进程可能以更高权限残留的场景设计。

## 文件

- `管理员结束WorkBuddy进程.bat`：请求一次管理员权限，检查 UAC/LUA 与内置 Administrator 分离令牌，清理 WorkBuddy / WorkBuddyAI / WorkDaddy 相关进程；不会启动安装器。
- `一键安装WorkDaddy.bat`：保持普通未提权权限，支持选择国内版、AI 版或两者，自动搜索安装包，也支持手动输入完整路径；不会结束进程或修改注册表。

## 使用顺序

1. 双击 `管理员结束WorkBuddy进程.bat`，按提示允许管理员权限。
2. 如果脚本提示启用 UAC 或内置 Administrator 分离令牌，确认后重启 Windows，再重新运行清理脚本。
3. 清理完成后关闭管理员窗口。
4. 直接双击 `一键安装WorkDaddy.bat`，选择要安装的版本。
5. 安装器不要选择“以管理员身份运行”。

## 说明

安装启动器搜索当前用户的桌面、下载、用户目录以及脚本所在目录，并匹配：

- `WorkDaddy-Setup-*.exe`
- `WorkDaddy-AI-Setup-*.exe`

如果没有自动找到，可以在脚本中输入安装包完整路径。

脚本按项目安装器源码的用户级安装设计工作：管理员权限只用于结束残留进程，安装器本身保持普通权限运行。
