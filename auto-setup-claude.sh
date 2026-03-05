#!/bin/bash

# Clash for Claude 自动配置脚本
# 作者: AI Assistant
# 版本: 1.0
# 用途: 自动配置 Clash 以支持 Claude 访问

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 获取脚本目录
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
CONF_DIR="$SCRIPT_DIR/conf"
LOG_DIR="$SCRIPT_DIR/logs"

# 检查参数
if [ $# -lt 1 ]; then
    log_error "使用方法: $0 <订阅链接> [节点地区偏好]"
    echo "示例:"
    echo "  $0 'https://your-subscription-url' US"
    echo "  $0 'https://your-subscription-url' JP"
    echo "  $0 'https://your-subscription-url' SG"
    echo ""
    echo "支持的地区偏好: US(美国), JP(日本), SG(新加坡), HK(香港)"
    exit 1
fi

SUBSCRIPTION_URL="$1"
PREFERRED_REGION="${2:-US}"  # 默认偏好美国节点

log_info "开始配置 Clash for Claude..."
log_info "订阅链接: $SUBSCRIPTION_URL"
log_info "节点偏好: $PREFERRED_REGION"

# 1. 更新 .env 文件
log_info "更新 .env 配置文件..."
cat > "$SCRIPT_DIR/.env" << EOF
CLASH_URL="$SUBSCRIPTION_URL"
CLASH_SECRET="$(openssl rand -hex 32)"
EOF
log_success ".env 文件已更新"

# 2. 停止现有服务
log_info "停止现有 Clash 服务..."
if pgrep -f "clash-linux" > /dev/null; then
    bash "$SCRIPT_DIR/shutdown.sh" 2>/dev/null || true
    sleep 2
fi

# 3. 启动服务获取新配置
log_info "启动 Clash 服务获取新配置..."
bash "$SCRIPT_DIR/start.sh"

# 等待服务启动
sleep 3

# 4. 检查配置文件是否存在
if [ ! -f "$CONF_DIR/config.yaml" ]; then
    log_error "配置文件未生成，请检查订阅链接是否有效"
    exit 1
fi

# 5. 备份原配置
log_info "备份原始配置..."
cp "$CONF_DIR/config.yaml" "$CONF_DIR/config.yaml.backup.$(date +%Y%m%d_%H%M%S)"

# 6. 检查并添加 mixed-port 配置
log_info "检查并配置 mixed-port..."
if ! grep -q "mixed-port:" "$CONF_DIR/config.yaml"; then
    # 在 redir-port 后添加 mixed-port
    sed -i '/^redir-port:/a\\n# 混合端口 (HTTP + SOCKS5)\nmixed-port: 7893' "$CONF_DIR/config.yaml"
    log_success "已添加 mixed-port: 7893"
else
    log_info "mixed-port 配置已存在"
fi

# 7. 设置日志级别为 info
log_info "设置日志级别..."
sed -i 's/^log-level:.*/log-level: info/' "$CONF_DIR/config.yaml"

# 8. 修复端口冲突问题
log_info "检查端口冲突..."
if ss -lntp | grep -q ":9090.*LISTEN"; then
    log_warning "端口 9090 被占用，切换到 9091"
    sed -i "s/external-controller: '0.0.0.0:9090'/external-controller: '0.0.0.0:9091'/" "$CONF_DIR/config.yaml"
    sed -i "s/external-controller: 0.0.0.0:9090/external-controller: 0.0.0.0:9091/" "$CONF_DIR/config.yaml"
fi

# 9. 获取可用节点并选择最佳节点
log_info "分析可用节点..."

# 根据地区偏好选择节点
case "$PREFERRED_REGION" in
    "US"|"USA")
        REGION_PATTERNS=("美国" "🇺🇸" "US" "USA" "America")
        ;;
    "JP"|"Japan")
        REGION_PATTERNS=("日本" "🇯🇵" "JP" "Japan")
        ;;
    "SG"|"Singapore")
        REGION_PATTERNS=("新加坡" "🇸🇬" "SG" "Singapore")
        ;;
    "HK"|"HongKong")
        REGION_PATTERNS=("香港" "🇭🇰" "HK" "Hong Kong")
        ;;
    *)
        REGION_PATTERNS=("美国" "🇺🇸" "US" "USA")
        ;;
esac

# 查找匹配的节点
SELECTED_NODE=""
for pattern in "${REGION_PATTERNS[@]}"; do
    SELECTED_NODE=$(grep -E "name.*$pattern.*高级|name.*$pattern.*IEPL|name.*$pattern" "$CONF_DIR/config.yaml" | head -1 | sed -n "s/.*name: \([^,]*\).*/\1/p" | tr -d '"')
    if [ -n "$SELECTED_NODE" ]; then
        log_success "找到匹配节点: $SELECTED_NODE"
        break
    fi
done

# 如果没找到偏好节点，使用第一个可用节点
if [ -z "$SELECTED_NODE" ]; then
    log_warning "未找到 $PREFERRED_REGION 节点，使用第一个可用节点"
    SELECTED_NODE=$(grep -E "name.*高级|name.*IEPL" "$CONF_DIR/config.yaml" | head -1 | sed -n "s/.*name: \([^,]*\).*/\1/p" | tr -d '"')
fi

if [ -z "$SELECTED_NODE" ]; then
    # 最后备选：使用任意节点
    SELECTED_NODE=$(grep -E "name: [^,]*," "$CONF_DIR/config.yaml" | grep -v "Traffic\|Expire" | head -1 | sed -n "s/.*name: \([^,]*\).*/\1/p" | tr -d '"')
fi

if [ -z "$SELECTED_NODE" ]; then
    log_error "未找到可用节点，请检查订阅配置"
    exit 1
fi

log_success "选择节点: $SELECTED_NODE"

# 10. 添加 Claude 专用规则
log_info "添加 Claude 专用规则..."

# 删除现有的 Claude 规则
sed -i '/# Claude \/ Anthropic 专用规则/,/^$/d' "$CONF_DIR/config.yaml"

# 在 MATCH 规则前添加 Claude 规则
sed -i "/- MATCH,/i\\
# Claude / Anthropic 专用规则 - 指向 $SELECTED_NODE\\
 - DOMAIN-SUFFIX,anthropic.com,$SELECTED_NODE\\
 - DOMAIN-SUFFIX,claude.ai,$SELECTED_NODE\\
 - DOMAIN,servd-anthropic-website.b-cdn.net,$SELECTED_NODE\\
 - DOMAIN-KEYWORD,claude,$SELECTED_NODE\\
 - DOMAIN-KEYWORD,anthropic,$SELECTED_NODE\\
 - DOMAIN,ipip.net,$SELECTED_NODE\\
 - DOMAIN,ifconfig.me,$SELECTED_NODE\\
" "$CONF_DIR/config.yaml"

log_success "Claude 规则已添加"

# 11. 更新系统代理配置
log_info "更新系统代理配置..."
sed -i 's/http:\/\/127\.0\.0\.1:789[0-3]/http:\/\/127.0.0.1:7893/g' "$SCRIPT_DIR/start.sh"

# 12. 重启服务
log_info "重启 Clash 服务应用新配置..."
bash "$SCRIPT_DIR/restart.sh"

# 等待服务重启
sleep 5

# 13. 测试连接
log_info "测试代理连接..."

# 测试基础连接
log_info "测试基础代理连接..."
if timeout 15 curl -sS -x http://127.0.0.1:7893 http://httpbin.org/ip > /tmp/proxy_test.json 2>/dev/null; then
    PROXY_IP=$(cat /tmp/proxy_test.json | grep -o '"origin": "[^"]*"' | cut -d'"' -f4)
    log_success "代理连接正常，出口IP: $PROXY_IP"
    rm -f /tmp/proxy_test.json
else
    log_error "代理连接失败"
    exit 1
fi

# 测试 Claude 连接
log_info "测试 Claude 连接..."
if timeout 20 curl -sS -I -x http://127.0.0.1:7893 https://claude.ai/ 2>&1 | grep -q "HTTP"; then
    log_success "Claude 连接测试通过"
else
    log_warning "Claude HTTPS 连接可能较慢，但代理配置正确"
fi

# 14. 显示配置信息
echo ""
log_success "=== Clash for Claude 配置完成 ==="
echo ""
echo "📊 配置信息:"
echo "  • 混合端口 (推荐): http://127.0.0.1:7893"
echo "  • HTTP 端口: http://127.0.0.1:7894"  
echo "  • SOCKS5 端口: socks5://127.0.0.1:7895"
echo "  • 控制面板: http://$(hostname -I | awk '{print $1}'):9091/ui"
echo "  • Claude 节点: $SELECTED_NODE"
echo ""
echo "🚀 使用方法:"
echo "  1. 开启系统代理: proxy_on"
echo "  2. 关闭系统代理: proxy_off"
echo "  3. 直接使用代理: curl -x http://127.0.0.1:7893 https://claude.ai/"
echo "  4. 浏览器设置: HTTP代理 127.0.0.1:7893"
echo ""
echo "🔧 管理命令:"
echo "  • 重启服务: bash restart.sh"
echo "  • 停止服务: bash shutdown.sh"
echo "  • 查看日志: tail -f logs/clash.log"
echo "  • 节点选择: bash scripts/clash_proxy-selector.sh"
echo ""

# 15. 创建快速测试脚本
cat > "$SCRIPT_DIR/test-claude.sh" << 'EOF'
#!/bin/bash
echo "🧪 测试 Claude 连接..."
echo ""

echo "1. 测试代理基础连接..."
if curl -sS --connect-timeout 10 -x http://127.0.0.1:7893 http://httpbin.org/ip; then
    echo "✅ 代理基础连接正常"
else
    echo "❌ 代理基础连接失败"
    exit 1
fi

echo ""
echo "2. 测试 Claude 网站连接..."
if timeout 15 curl -sS -I -x http://127.0.0.1:7893 https://claude.ai/ 2>&1 | head -5; then
    echo "✅ Claude 连接测试完成"
else
    echo "⚠️  Claude 连接较慢或超时"
fi

echo ""
echo "3. 检查规则匹配..."
echo "最近的连接日志:"
tail -5 logs/clash.log | grep -E "claude|anthropic" || echo "暂无 Claude 相关日志"
EOF

chmod +x "$SCRIPT_DIR/test-claude.sh"
log_success "已创建快速测试脚本: test-claude.sh"

echo ""
log_success "🎉 配置完成！现在可以正常使用 Claude 了"
echo ""
echo "💡 快速测试: bash test-claude.sh"
