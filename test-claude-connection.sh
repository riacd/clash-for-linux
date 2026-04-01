#!/bin/bash

# Claude 连接测试脚本
# 用于验证 Clash 代理和 Claude 访问是否正常

echo "🧪 Clash for Claude 连接测试"
echo "================================"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 测试函数
test_step() {
    local step_name="$1"
    local command="$2"
    echo -n "测试 $step_name... "
    
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ 通过${NC}"
        return 0
    else
        echo -e "${RED}❌ 失败${NC}"
        return 1
    fi
}

# 1. 检查 Clash 服务状态
echo -e "\n${BLUE}1. 检查 Clash 服务状态${NC}"
if pgrep -f "clash-linux" > /dev/null; then
    echo -e "${GREEN}✅ Clash 服务正在运行${NC}"
    echo "   进程ID: $(pgrep -f clash-linux)"
else
    echo -e "${RED}❌ Clash 服务未运行${NC}"
    echo "   请运行: bash start.sh"
    exit 1
fi

# 2. 检查端口监听
echo -e "\n${BLUE}2. 检查端口监听状态${NC}"
ports=(7893 7894 7895 9091)
for port in "${ports[@]}"; do
    if ss -lntp | grep -q ":$port.*LISTEN"; then
        echo -e "${GREEN}✅ 端口 $port 正在监听${NC}"
    else
        echo -e "${YELLOW}⚠️  端口 $port 未监听${NC}"
    fi
done

# 3. 测试代理连接
echo -e "\n${BLUE}3. 测试代理连接${NC}"

# 测试 Mixed Port 7893
echo -n "测试 Mixed Port (7893)... "
if timeout 10 curl -s -x http://127.0.0.1:7893 http://httpbin.org/ip | grep -q "origin"; then
    echo -e "${GREEN}✅ 连接正常${NC}"
    PROXY_IP=$(timeout 10 curl -s -x http://127.0.0.1:7893 http://httpbin.org/ip | grep -o '"origin": "[^"]*"' | cut -d'"' -f4)
    echo "   出口IP: $PROXY_IP"
else
    echo -e "${RED}❌ 连接失败${NC}"
fi

# 测试 HTTP Port 7894
echo -n "测试 HTTP Port (7894)... "
if timeout 10 curl -s -x http://127.0.0.1:7894 http://httpbin.org/ip | grep -q "origin"; then
    echo -e "${GREEN}✅ 连接正常${NC}"
else
    echo -e "${YELLOW}⚠️  连接异常${NC}"
fi

# 4. 测试 Claude 访问
echo -e "\n${BLUE}4. 测试 Claude 网站访问${NC}"

echo -n "测试 Claude.ai 连接... "
CLAUDE_RESPONSE=$(timeout 15 curl -s -I -x http://127.0.0.1:7893 https://claude.ai/ 2>/dev/null)
if echo "$CLAUDE_RESPONSE" | grep -q "HTTP"; then
    STATUS_CODE=$(echo "$CLAUDE_RESPONSE" | head -1 | awk '{print $2}')
    if [[ "$STATUS_CODE" == "200" || "$STATUS_CODE" == "302" ]]; then
        echo -e "${GREEN}✅ 连接成功 (HTTP $STATUS_CODE)${NC}"
    else
        echo -e "${YELLOW}⚠️  连接异常 (HTTP $STATUS_CODE)${NC}"
    fi
else
    echo -e "${RED}❌ 连接失败${NC}"
fi

# 5. 检查 Claude 路由规则
echo -e "\n${BLUE}5. 检查 Claude 路由规则${NC}"
if grep -q "DOMAIN-SUFFIX,claude.ai" conf/config.yaml; then
    CLAUDE_NODE=$(grep "DOMAIN-SUFFIX,claude.ai" conf/config.yaml | awk -F',' '{print $3}')
    echo -e "${GREEN}✅ Claude 规则已配置${NC}"
    echo "   目标节点: $CLAUDE_NODE"
    
    # 检查节点是否存在
    if grep -q "name: $CLAUDE_NODE" conf/config.yaml; then
        echo -e "${GREEN}✅ 目标节点存在${NC}"
    else
        echo -e "${RED}❌ 目标节点不存在${NC}"
        echo "   可用美国节点:"
        grep "name: USA-" conf/config.yaml | head -3 | sed 's/.*name: /   - /'
    fi
else
    echo -e "${RED}❌ Claude 规则未配置${NC}"
fi

# 6. 环境变量检查
echo -e "\n${BLUE}6. 检查代理环境变量${NC}"
if [[ "$http_proxy" == "http://127.0.0.1:7893" ]]; then
    echo -e "${GREEN}✅ HTTP 代理变量已设置${NC}"
else
    echo -e "${YELLOW}⚠️  HTTP 代理变量未设置${NC}"
    echo "   请运行: proxy_on"
fi

if [[ "$https_proxy" == "http://127.0.0.1:7893" ]]; then
    echo -e "${GREEN}✅ HTTPS 代理变量已设置${NC}"
else
    echo -e "${YELLOW}⚠️  HTTPS 代理变量未设置${NC}"
fi

# 7. 性能测试
echo -e "\n${BLUE}7. 性能测试${NC}"
echo -n "测试延迟... "
LATENCY=$(timeout 5 curl -s -o /dev/null -w "%{time_total}" -x http://127.0.0.1:7893 http://httpbin.org/ip 2>/dev/null)
if [[ -n "$LATENCY" ]]; then
    LATENCY_MS=$(echo "$LATENCY * 1000" | bc 2>/dev/null || echo "N/A")
    echo -e "${GREEN}✅ ${LATENCY_MS}ms${NC}"
else
    echo -e "${RED}❌ 测试失败${NC}"
fi

# 总结
echo -e "\n${BLUE}📊 测试总结${NC}"
echo "================================"

# 检查关键组件状态
ISSUES=0

if ! pgrep -f "clash-linux" > /dev/null; then
    echo -e "${RED}❌ Clash 服务未运行${NC}"
    ((ISSUES++))
fi

if ! ss -lntp | grep -q ":7893.*LISTEN"; then
    echo -e "${RED}❌ Mixed Port 7893 未监听${NC}"
    ((ISSUES++))
fi

if ! timeout 5 curl -s -x http://127.0.0.1:7893 http://httpbin.org/ip | grep -q "origin"; then
    echo -e "${RED}❌ 代理连接失败${NC}"
    ((ISSUES++))
fi

if [[ "$ISSUES" -eq 0 ]]; then
    echo -e "${GREEN}🎉 所有测试通过！Clash for Claude 配置正常${NC}"
    echo ""
    echo "💡 使用方法:"
    echo "   proxy_on     - 开启系统代理"
    echo "   proxy_off    - 关闭系统代理"
    echo "   clash-status - 检查服务状态"
    echo ""
    echo "🌐 访问 Claude: https://claude.ai/"
else
    echo -e "${RED}⚠️  发现 $ISSUES 个问题，请检查配置${NC}"
    echo ""
    echo "🔧 故障排除:"
    echo "   bash start.sh           - 重启服务"
    echo "   tail -f logs/clash.log  - 查看日志"
    echo "   clash-status           - 检查状态"
fi

echo ""

