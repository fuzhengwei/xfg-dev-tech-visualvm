#!/bin/bash

# VisualVM 内存测试自动化脚本
# 作者: xiaofuge
# 用途: 自动化测试内存接口并生成dump文件

# 配置参数
BASE_URL="http://localhost:8091"
DUMP_DIR="../dump"
LOG_FILE="$DUMP_DIR/test_log_$(date +%Y%m%d_%H%M%S).txt"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# 检查应用是否启动
check_app_status() {
    log_info "检查应用状态..."
    response=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/memory/status")
    if [ "$response" = "200" ]; then
        log_success "应用已启动，状态正常"
        return 0
    else
        log_error "应用未启动或状态异常 (HTTP: $response)"
        return 1
    fi
}

# 等待应用启动
wait_for_app() {
    log_info "等待应用启动..."
    for i in {1..30}; do
        if check_app_status > /dev/null 2>&1; then
            log_success "应用启动成功"
            return 0
        fi
        log_info "等待中... ($i/30)"
        sleep 2
    done
    log_error "应用启动超时"
    return 1
}

# 调用API接口
call_api() {
    local endpoint=$1
    local description=$2
    local count=${3:-1}
    
    log_info "调用接口: $description"
    for ((i=1; i<=count; i++)); do
        response=$(curl -s "$BASE_URL$endpoint")
        status=$(echo "$response" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
        if [ "$status" = "success" ]; then
            log_success "[$i/$count] $description - 成功"
        else
            log_error "[$i/$count] $description - 失败: $response"
        fi
        sleep 1
    done
}

# 显示内存状态
show_memory_status() {
    log_info "获取内存状态..."
    response=$(curl -s "$BASE_URL/api/memory/status")
    echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
    echo ""
}

# 生成dump文件
generate_dump() {
    log_info "生成堆转储文件..."
    response=$(curl -s "$BASE_URL/api/jmap/dump")
    status=$(echo "$response" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    if [ "$status" = "success" ]; then
        filename=$(echo "$response" | grep -o '"fileName":"[^"]*"' | cut -d'"' -f4)
        log_success "堆转储文件生成成功: $filename"
    else
        log_error "堆转储文件生成失败: $response"
    fi
}

# 生成内存信息文件
generate_memory_info() {
    log_info "生成内存信息文件..."
    response=$(curl -s "$BASE_URL/api/jmap/memory-info")
    status=$(echo "$response" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    if [ "$status" = "success" ]; then
        filename=$(echo "$response" | grep -o '"fileName":"[^"]*"' | cut -d'"' -f4)
        log_success "内存信息文件生成成功: $filename"
    else
        log_error "内存信息文件生成失败: $response"
    fi
}

# 清理缓存
clear_cache() {
    log_info "清理缓存..."
    response=$(curl -s "$BASE_URL/api/memory/clear-cache")
    status=$(echo "$response" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    if [ "$status" = "success" ]; then
        log_success "缓存清理成功"
    else
        log_error "缓存清理失败: $response"
    fi
}

# 主测试流程
run_test() {
    log_info "开始VisualVM内存测试"
    
    # 检查dump目录
    if [ ! -d "$DUMP_DIR" ]; then
        log_info "创建dump目录: $DUMP_DIR"
        mkdir -p "$DUMP_DIR"
    fi
    
    # 等待应用启动
    if ! wait_for_app; then
        log_error "应用启动失败，退出测试"
        exit 1
    fi
    
    # 显示初始内存状态
    log_info "=== 初始内存状态 ==="
    show_memory_status
    
    # 测试普通接口
    call_api "/api/memory/normal" "普通接口测试" 5
    
    # 显示内存状态
    log_info "=== 普通接口调用后内存状态 ==="
    show_memory_status
    
    # 测试大对象接口
    call_api "/api/memory/big-object" "大对象接口测试" 10
    
    # 显示内存状态
    log_info "=== 大对象创建后内存状态 ==="
    show_memory_status
    
    # 生成第一次dump
    generate_dump
    generate_memory_info
    
    # 测试内存泄漏接口
    call_api "/api/memory/memory-leak" "内存泄漏接口测试" 20
    
    # 显示内存状态
    log_info "=== 内存泄漏测试后内存状态 ==="
    show_memory_status
    
    # 测试超大对象接口
    call_api "/api/memory/huge-object" "超大对象接口测试" 5
    
    # 显示内存状态
    log_info "=== 超大对象创建后内存状态 ==="
    show_memory_status
    
    # 生成第二次dump
    generate_dump
    generate_memory_info
    
    # 清理缓存
    clear_cache
    
    # 显示清理后内存状态
    log_info "=== 缓存清理后内存状态 ==="
    show_memory_status
    
    # 生成第三次dump
    generate_dump
    generate_memory_info
    
    log_success "VisualVM内存测试完成"
    log_info "日志文件: $LOG_FILE"
    log_info "dump文件目录: $DUMP_DIR"
}

# 显示帮助信息
show_help() {
    echo "VisualVM 内存测试脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  test          运行完整测试流程"
    echo "  check         检查应用状态"
    echo "  status        显示内存状态"
    echo "  dump          生成堆转储文件"
    echo "  memory-info   生成内存信息文件"
    echo "  clear         清理缓存"
    echo "  help          显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 test       # 运行完整测试"
    echo "  $0 check      # 检查应用状态"
    echo "  $0 dump       # 生成dump文件"
}

# 主程序
case "${1:-test}" in
    "test")
        run_test
        ;;
    "check")
        check_app_status
        ;;
    "status")
        show_memory_status
        ;;
    "dump")
        generate_dump
        ;;
    "memory-info")
        generate_memory_info
        ;;
    "clear")
        clear_cache
        ;;
    "help")
        show_help
        ;;
    *)
        log_error "未知选项: $1"
        show_help
        exit 1
        ;;
esac