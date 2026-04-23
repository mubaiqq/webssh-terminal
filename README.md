# ⚡ WebSSH Terminal

基于 Web 的 SSH 终端工具，支持多服务器管理、多标签终端、快捷命令、笔记等功能。

## ✨ 功能

- 🔐 **密码认证** — 登录密码保护，Cookie 记忆 6 小时
- 🖥️ **多标签终端** — xterm.js + WebSocket + node-pty，支持多标签同时连接
- 📋 **服务器管理** — 添加/编辑/删除 SSH 服务器，支持密码和密钥认证
- ⚡ **快捷命令** — 保存常用命令，一键发送到终端
- 📝 **笔记** — 内置记事本，自动保存
- ⌨️ **虚拟键盘** — 悬浮可拖拽虚拟键盘（快捷键/数字/字母/符号/F键 5页翻页）
- 🎨 **主题** — 暗色/亮色主题切换，背景自定义（纯色/外链/本地上传）
- 📱 **移动端适配** — 响应式设计，手机平板可用
- 🔒 **进程守护** — pm2 管理，崩溃自动重启，内存超限自动重启
- ⚡ **开机自启** — systemd 服务，重启服务器后自动恢复

## 🛠️ 技术栈

- **后端**: Express + WebSocket + node-pty
- **前端**: 原生 JS + xterm.js 5.5 + Font Awesome 6
- **UI**: 毛玻璃 (Glassmorphism) 风格
- **运维**: pm2 进程守护 + systemd 开机自启

## 🚀 一键部署

**国内服务器（推荐，自动加速）：**

```bash
bash <(curl -sL https://ghfast.top/https://raw.githubusercontent.com/mubaiqq/webssh-terminal/main/deploy.sh)
```

**海外服务器：**

```bash
bash <(curl -sL https://raw.githubusercontent.com/mubaiqq/webssh-terminal/main/deploy.sh)
```

**手动克隆部署：**

```bash
git clone https://github.com/mubaiqq/webssh-terminal.git
cd webssh-terminal
bash deploy.sh
```

部署完成后自动配置：
- ✅ **pm2 进程守护** — 崩溃自动重启，内存超限自动重启
- ✅ **开机自启** — 通过 systemd 实现，重启服务器后自动恢复
- ✅ **国内加速** — npm/clone 自动使用镜像源

部署完成后会显示本地、公网、隧道访问地址。

## 🔧 管理命令

```bash
pm2 status          # 查看运行状态
pm2 logs            # 查看实时日志
pm2 restart         # 重启服务
pm2 stop            # 停止服务
pm2 monit           # 资源监控面板
bash stop.sh        # 停止所有（含隧道）
```

## 🗑️ 一键卸载

```bash
bash <(curl -sL https://ghfast.top/https://raw.githubusercontent.com/mubaiqq/webssh-terminal/main/uninstall.sh)
```

或手动：

```bash
bash uninstall.sh
rm -rf ~/webssh-terminal
```

卸载脚本会自动：停止 pm2 进程、移除开机自启、清理端口、删除文件。

## 📁 项目结构

```
webssh-terminal/
├── server.js          # 后端主入口
├── public/index.html  # 前端单页应用
├── deploy.sh          # 一键部署（含加速 + pm2 + 自启）
├── uninstall.sh       # 一键卸载（清理 pm2 + systemd）
├── stop.sh            # 停止服务
├── package.json       # 依赖配置
└── data/              # 运行时数据（自动创建）
```

## ⚠️ 注意事项

- 默认密码 `123456`，登录后在设置中修改
- 需要 Node.js >= 16
- node-pty 需要编译原生模块（需要 build-essential/gcc）
- 建议生产环境使用 nginx 反代 + SSL
- 国内服务器部署自动使用 npm/git 镜像加速
