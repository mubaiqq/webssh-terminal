# ⚡ WebSSH Terminal

基于 Web 的 SSH 终端工具，支持多服务器管理、多标签终端、快捷命令、笔记等功能。

## ✨ 功能

- 🔐 **密码认证** — 登录密码保护，Cookie 记忆 6 小时
- 🖥️ **多标签终端** — xterm.js + WebSocket + node-pty，支持多标签同时连接
- 📋 **服务器管理** — 添加/编辑/删除 SSH 服务器，支持密码和密钥认证
- ⚡ **快捷命令** — 保存常用命令，一键发送到终端
- 📝 **笔记** — 内置记事本，自动保存
- ⌨️ **虚拟键盘** — 悬浮可拖拽虚拟键盘，支持方向键、F 键、符号、字母、数字
- 🎨 **主题** — 暗色/亮色主题切换，背景自定义（纯色/外链/本地上传）
- 📱 **移动端适配** — 响应式设计，手机平板可用

## 🛠️ 技术栈

- **后端**: Express + WebSocket + node-pty
- **前端**: 原生 JS + xterm.js 5.5 + Font Awesome 6
- **UI**: 毛玻璃 (Glassmorphism) 风格

## 🚀 快速部署

```bash
# 上传并解压
tar xzf webssh.tar.gz && cd webssh

# 一键部署
bash deploy.sh
```

部署完成后：
- 本地访问: `http://localhost:9111`
- 公网隧道: 自动通过 serveo.net 生成公网地址

## 📦 手动安装

```bash
cd webssh
npm install --production
node server.js
```

默认端口 `9111`，默认密码 `123456`（登录后可在设置中修改）。

## 📁 项目结构

```
webssh/
├── server.js          # 后端主入口
├── public/index.html  # 前端单页应用
├── deploy.sh          # 一键部署脚本
├── stop.sh            # 停止脚本
├── package.json       # 依赖配置
└── data/              # 运行时数据（自动创建）
```

## ⚠️ 注意事项

- 默认密码 `123456`，请在生产环境中修改
- 需要 Node.js >= 16
- node-pty 需要编译原生模块（需要 build-essential/gcc）
- 建议在生产环境使用 nginx 反代 + SSL
