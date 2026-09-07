# WorkDaddy install helper

适用于 Windows 的 WorkDaddy 安装辅助脚本，针对安装器要求“普通权限运行”、而 WorkBuddy 后台进程可能以更高权限残留的场景设计。

## 文件

- `一键清理并安装WorkDaddy.bat`：**双击一次完成全部流程**
  1. 检查 UAC / 内置 Administrator 分离令牌配置，异常时引导修复（改注册表需重启生效）；
  2. 自动请求一次管理员权限，结束 WorkBuddy / WorkBuddyAI / WorkDaddy / 残留 node 进程；
  3. 回到普通权限，选择安装国内版 / AI 版 / 两者；
  4. 本地找不到安装包时，可自动从 GitHub Releases 下载最新版。

## 使用

1. 从文件资源管理器**直接双击**本脚本（不要用管理员身份运行，也不要从管理员终端启动）。
2. UAC 弹窗点“是”，脚本自动清理旧进程。
3. 按菜单选择要安装的版本；本地没有安装包时按提示自动下载。
4. 如果脚本提示“分离令牌 / UAC 改动需重启”，重启 Windows 后再运行一次即可。

## 说明

- 安装包搜索范围：当前用户的桌面、下载、用户目录、脚本所在目录。
- 自动下载源：`github.com/babygoton/WorkDaddy` 的 Latest Release（`WorkDaddy-Setup-<版本>.exe` / `WorkDaddy-AI-Setup-<版本>.exe`），下载后保存在脚本所在目录。
- 下载走 GitHub 直连，如网络不通可浏览器下载后手动输入完整路径。
- 管理员权限仅用于结束残留进程，安装器本身始终以普通权限运行。
- 历史版本的两个分步脚本（`管理员结束WorkBuddy进程.bat` / `一键安装WorkDaddy.bat`）已被本脚本取代，见 git 历史。
