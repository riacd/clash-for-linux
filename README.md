# clash-for-linux 使用说明


## 1. 安装

```bash
cd ~
git clone https://github.com/riacd/clash-for-linux.git
cd clash-for-linux
```

## 2. 配置订阅

编辑 `.env`：

```bash
cat > .env << 'ENVEOF'
CLASH_URL="你的订阅链接"
CLASH_SECRET=""
ENVEOF
```




## 3. 一次性设置（推荐）

把 `init.sh` 加到 `~/.bashrc`，以后每次打开终端都会自动加载命令并自动启用代理。

```bash
echo '[ -f "$HOME/clash-for-linux/init.sh" ] && source "$HOME/clash-for-linux/init.sh"' >> ~/.bashrc
source ~/.bashrc
```

## 4. 启动与更新

首次启动：

```bash
clash_start
```

需要更新订阅并启动：

```bash
clash_start "新的订阅链接"
```

## 5. 日常常用命令

```bash
clash_start        # 启动
clash_restart      # 重启
clash_stop         # 停止
clash_status       # 查看状态
clash_test         # 测试代理
proxy_on           # 开启代理环境变量
proxy_off          # 关闭代理环境变量
```

## 6. 浏览器管理面板

打开：

```text
http://你的服务器IP:9091/ui
```

登录时：

- API Base URL: `http://你的服务器IP:9091`
- Secret: 使用 `.env` 中的 `CLASH_SECRET`（或 `conf/config.yaml` 里的 `secret`）

## 7. Claude 快速测试（可选）

```bash
claude_test
```

## 8. 关闭自动启动（可选）

如果你不想每次开终端自动启动 Clash，在 `~/.bashrc` 里 `source init.sh` 前加：

```bash
export CLASH_AUTO_START=0
```
