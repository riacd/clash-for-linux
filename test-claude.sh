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
