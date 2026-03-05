 ：# Clash for Claude 自动配置指南

这是一个专门为 Claude AI 访问优化的 Clash 代理自动配置工具。

## 🚀 快速开始

### 一键配置
```bash
# 使用美国节点（推荐）
bash auto-setup-claude.sh "你的订阅链接" US

# 使用日本节点
bash auto-setup-claude.sh "你的订阅链接" JP

# 使用新加坡节点
bash auto-setup-claude.sh "你的订阅链接" SG
```

### 测试连接
```bash
# 快速测试
bash test-claude.sh

# 手动测试
curl -x http://127.0.0.1:7893 https://claude.ai/
```

## 📋 功能特性

- ✅ **自动配置**: 一键设置所有必要的配置
- ✅ **智能节点选择**: 根据地区偏好自动选择最佳节点
- ✅ **Mixed-Port 支持**: 使用现代化的混合端口配置
- ✅ **Claude 专用规则**: 针对 Anthropic/Claude 域名的专用路由
- ✅ **端口冲突处理**: 自动检测并解决端口占用问题
- ✅ **连接测试**: 自动验证代理和 Claude 连接
- ✅ **详细日志**: 提供详细的配置和连接日志

## 🔧 配置详情

### 端口配置
| 端口 | 协议 | 用途 | 推荐 |
|------|------|------|------|
| 7890 | HTTP | HTTP 代理 | |
| 7891 | SOCKS5 | SOCKS5 代理 | |
| 7892 | Redir | 透明代理 | |
| **7893** | **Mixed** | **HTTP + SOCKS5** | **✅ 推荐** |
| 9091 | HTTP | 控制面板 | |

### Claude 专用规则
脚本会自动添加以下规则，确保 Claude 相关流量走指定节点：

```yaml
# Claude / Anthropic 专用规则
- DOMAIN-SUFFIX,anthropic.com,选定节点
- DOMAIN-SUFFIX,claude.ai,选定节点
- DOMAIN,servd-anthropic-website.b-cdn.net,选定节点
- DOMAIN-KEYWORD,claude,选定节点
- DOMAIN-KEYWORD,anthropic,选定节点
```

## 📖 使用方法

### 1. 系统代理方式
```bash
# 开启系统代理
proxy_on

# 现在所有应用都会通过代理访问网络
# 直接访问 https://claude.ai

# 关闭系统代理
proxy_off
```

### 2. 应用程序代理设置
在需要使用代理的应用中设置：
- **HTTP 代理**: `127.0.0.1:7893`
- **HTTPS 代理**: `127.0.0.1:7893`

### 3. 浏览器代理设置
#### Chrome/Edge
1. 设置 → 高级 → 系统 → 打开代理设置
2. 手动代理设置
3. HTTP 代理: `127.0.0.1:7893`

#### Firefox
1. 设置 → 网络设置 → 设置
2. 手动代理配置
3. HTTP 代理: `127.0.0.1` 端口: `7893`
4. ✅ 勾选"为所有协议使用此代理服务器"

### 4. 命令行使用
```bash
# 使用 curl
curl -x http://127.0.0.1:7893 https://claude.ai/

# 使用 wget
wget --proxy=on --http-proxy=127.0.0.1:7893 https://claude.ai/

# 使用环境变量
export http_proxy=http://127.0.0.1:7893
export https_proxy=http://127.0.0.1:7893
curl https://claude.ai/
```

## 🎛️ 管理界面

### Clash Dashboard
访问地址: `http://你的IP:9091/ui`

**登录信息**:
- API Base URL: `http://你的IP:9091`
- Secret: 查看启动日志或 `conf/config.yaml` 中的 `secret` 字段

### 功能
- 📊 实时流量监控
- 🔄 节点切换
- 📋 规则查看
- 🔍 连接日志
- ⚙️ 配置管理

## 🛠️ 常用命令

### 服务管理
```bash
# 启动服务
bash start.sh

# 重启服务
bash restart.sh

# 停止服务
bash shutdown.sh

# 查看状态
ss -lntp | grep -E '789[0-3]|9091'
```

### 日志查看
```bash
# 查看实时日志
tail -f logs/clash.log

# 查看 Claude 相关日志
tail -f logs/clash.log | grep -i claude

# 查看连接日志
tail -f logs/clash.log | grep "TCP"
```

### 节点管理
```bash
# 使用终端选择器
bash scripts/clash_proxy-selector.sh

# 查看当前节点延迟
curl -H "Authorization: Bearer $(grep secret conf/config.yaml | cut -d' ' -f2)" \
     http://127.0.0.1:9091/proxies
```

## 🔍 故障排除

### 常见问题

#### 1. 连接被重置 (Connection reset by peer)
**原因**: 节点被封禁或网络问题
**解决**: 
```bash
# 重新运行配置脚本，尝试其他地区节点
bash auto-setup-claude.sh "订阅链接" JP  # 尝试日本节点
bash auto-setup-claude.sh "订阅链接" SG  # 尝试新加坡节点
```

#### 2. 端口被占用
**现象**: `bind: address already in use`
**解决**: 脚本会自动处理，或手动修改端口
```bash
# 查看端口占用
ss -lntp | grep 9090

# 杀死占用进程
sudo kill $(lsof -t -i:9090)
```

#### 3. 代理无响应
**检查步骤**:
```bash
# 1. 检查服务状态
ps aux | grep clash

# 2. 检查端口监听
ss -lntp | grep 7893

# 3. 查看日志
tail -20 logs/clash.log

# 4. 重新配置
bash auto-setup-claude.sh "订阅链接" US
```

#### 4. Claude 访问慢
**优化建议**:
1. 尝试不同地区节点
2. 在 Dashboard 中手动选择延迟低的节点
3. 检查本地网络环境

### 调试模式
```bash
# 启用详细日志
sed -i 's/log-level: info/log-level: debug/' conf/config.yaml
bash restart.sh

# 查看详细连接信息
tail -f logs/clash.log
```

## 📊 性能优化

### 节点选择建议
1. **Claude 访问**: 优先选择美国、日本、新加坡节点
2. **延迟要求**: 选择延迟 < 300ms 的节点
3. **稳定性**: 优先选择 IEPL 专线节点

### 系统优化
```bash
# 增加文件描述符限制
echo "* soft nofile 65535" >> /etc/security/limits.conf
echo "* hard nofile 65535" >> /etc/security/limits.conf

# 优化网络参数
echo "net.core.rmem_max = 16777216" >> /etc/sysctl.conf
echo "net.core.wmem_max = 16777216" >> /etc/sysctl.conf
sysctl -p
```

## 🔄 更新订阅

### 自动更新
```bash
# 使用新的订阅链接重新配置
bash auto-setup-claude.sh "新的订阅链接" US
```

### 手动更新
```bash
# 1. 更新 .env 文件
echo 'CLASH_URL="新的订阅链接"' > .env
echo 'CLASH_SECRET="现有密钥"' >> .env

# 2. 重新启动
bash start.sh

# 3. 重新配置 Claude 规则
bash auto-setup-claude.sh "新的订阅链接" US
```

## 📝 配置文件说明

### 关键配置文件
- `.env`: 订阅链接和密钥配置
- `conf/config.yaml`: Clash 主配置文件
- `start.sh`: 启动脚本
- `auto-setup-claude.sh`: 自动配置脚本
- `test-claude.sh`: 连接测试脚本

### 备份与恢复
```bash
# 备份配置
cp conf/config.yaml conf/config.yaml.backup

# 恢复配置
cp conf/config.yaml.backup conf/config.yaml
bash restart.sh
```

## 🤝 支持与反馈

### 获取帮助
1. 查看日志: `tail -f logs/clash.log`
2. 运行测试: `bash test-claude.sh`
3. 检查配置: 访问 Dashboard `http://IP:9091/ui`

### 常用检查命令
```bash
# 一键检查脚本
cat > check-status.sh << 'EOF'
#!/bin/bash
echo "=== Clash 状态检查 ==="
echo "1. 进程状态:"
ps aux | grep clash | grep -v grep || echo "❌ Clash 未运行"

echo -e "\n2. 端口监听:"
ss -lntp | grep -E '789[0-3]|9091' || echo "❌ 端口未监听"

echo -e "\n3. 代理测试:"
curl -s --connect-timeout 5 -x http://127.0.0.1:7893 http://httpbin.org/ip || echo "❌ 代理连接失败"

echo -e "\n4. 最近日志:"
tail -5 logs/clash.log
EOF
chmod +x check-status.sh
```

---

## 📄 许可证

本项目基于开源 Clash 项目，仅供学习和个人使用。

**免责声明**: 请遵守当地法律法规，合理使用代理服务。
