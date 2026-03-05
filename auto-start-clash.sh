#!/bin/bash

# Clash 智能自动启动脚本
# 用于在任何节点上自动启动Clash服务

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

# 检查Clash是否已经在运行
check_clash_running() {
    if pgrep -f "clash-linux" > /dev/null 2>&1; then
        if ss -lntp 2>/dev/null | grep -q ":7893"; then
            return 0  # 运行中且端口正常
        else
            return 1  # 进程存在但端口异常
        fi
    else
        return 2  # 未运行
    fi
}

# 主启动逻辑
main() {
    log_info "检查 Clash 服务状态..."
    
    check_clash_running
    case $? in
        0)
            log_success "Clash 服务已在运行，端口正常"
            return 0
            ;;
        1)
            log_warning "Clash 进程存在但端口异常，重启服务..."
            pkill -f "clash-linux" 2>/dev/null
            sleep 2
            ;;
        2)
            log_info "Clash 服务未运行，准备启动..."
            ;;
    esac
    
    # 检查必要文件
    if [ ! -f "$SCRIPT_DIR/start.sh" ]; then
        log_error "start.sh 文件不存在: $SCRIPT_DIR/start.sh"
        return 1
    fi
    
    if [ ! -f "$SCRIPT_DIR/.env" ]; then
        log_error ".env 配置文件不存在，请先配置订阅链接"
        return 1
    fi
    
    # 切换到Clash目录
    cd "$SCRIPT_DIR" || {
        log_error "无法切换到Clash目录: $SCRIPT_DIR"
        return 1
    }
    
    # 启动Clash服务
    log_info "启动 Clash 服务..."
    if bash start.sh > /tmp/clash_start.log 2>&1; then
        # 等待服务启动
        sleep 3
        
        # 验证启动结果
        check_clash_running
        if [ $? -eq 0 ]; then
            log_success "Clash 服务启动成功"
            log_info "端口信息:"
            ss -lntp | grep -E '789[0-9]|9091' | head -4
            return 0
        else
            log_error "Clash 服务启动失败，请检查日志"
            tail -10 /tmp/clash_start.log
            return 1
        fi
    else
        log_error "启动脚本执行失败"
        tail -10 /tmp/clash_start.log
        return 1
    fi
}

# 执行主函数
main "$@"

