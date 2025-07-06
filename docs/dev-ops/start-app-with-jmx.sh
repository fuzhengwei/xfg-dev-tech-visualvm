#!/bin/bash

# VisualVM JMX 远程连接启动脚本
# 作者: xiaofuge
# 用途: 启动Spring Boot应用并开启JMX远程连接功能

# 给脚本添加执行权限
# chmod +x start-app-with-jmx.sh

# 启动应用
# ./start-app-with-jmx.sh start

# 查看状态
# ./start-app-with-jmx.sh status

# 显示JMX连接信息
# ./start-app-with-jmx.sh jmx

# 查看日志
# ./start-app-with-jmx.sh logs

# 停止应用
# ./start-app-with-jmx.sh stop

# 配置参数
APP_NAME="xfg-dev-tech-visuallvm-app"
APP_VERSION="1.0-SNAPSHOT"
JAR_FILE="../../xfg-dev-tech-app/target/${APP_NAME}.jar"
PID_FILE="./app.pid"
LOG_FILE="./app.log"

# JMX 配置
JMX_PORT=1099
JMX_HOST="192.168.1.103"
RMI_PORT=1099

# JVM 内存配置
XMS="512m"
XMX="2048m"

# 颜色输出
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

# 检查Java环境
check_java() {
    if ! command -v java &> /dev/null; then
        log_error "Java 未安装或未配置到PATH中"
        exit 1
    fi
    
    java_version=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2)
    log_info "Java版本: $java_version"
}

# 检查jar文件是否存在
check_jar() {
    if [ ! -f "$JAR_FILE" ]; then
        log_error "JAR文件不存在: $JAR_FILE"
        log_info "请先执行 'mvn clean package' 构建项目"
        exit 1
    fi
    log_info "JAR文件: $JAR_FILE"
}

# 检查端口是否被占用
check_port() {
    local port=$1
    local service_name=$2
    
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        log_warning "端口 $port ($service_name) 已被占用"
        local pid=$(lsof -Pi :$port -sTCP:LISTEN -t)
        log_info "占用进程PID: $pid"
        return 1
    fi
    return 0
}

# 获取应用PID
get_app_pid() {
    if [ -f "$PID_FILE" ]; then
        cat "$PID_FILE"
    else
        echo ""
    fi
}

# 检查应用是否运行
is_app_running() {
    local pid=$(get_app_pid)
    if [ -n "$pid" ] && ps -p $pid > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 启动应用
start_app() {
    log_info "开始启动应用..."
    
    # 检查环境
    check_java
    check_jar
    
    # 检查应用是否已经运行
    if is_app_running; then
        log_warning "应用已经在运行中"
        show_status
        return 0
    fi
    
    # 检查端口
    if ! check_port 8091 "应用服务"; then
        log_error "应用端口8091被占用，请先停止占用进程"
        return 1
    fi
    
    if ! check_port $JMX_PORT "JMX服务"; then
        log_error "JMX端口$JMX_PORT被占用，请先停止占用进程"
        return 1
    fi
    
    if ! check_port $RMI_PORT "RMI服务"; then
        log_error "RMI端口$RMI_PORT被占用，请先停止占用进程"
        return 1
    fi
    
    # 构建JVM参数
    JVM_OPTS="-Xms$XMS -Xmx$XMX"
    
    # JMX配置参数
    JMX_OPTS="-Dcom.sun.management.jmxremote"
    JMX_OPTS="$JMX_OPTS -Dcom.sun.management.jmxremote.port=$JMX_PORT"
    JMX_OPTS="$JMX_OPTS -Dcom.sun.management.jmxremote.rmi.port=$RMI_PORT"
    JMX_OPTS="$JMX_OPTS -Dcom.sun.management.jmxremote.authenticate=false"
    JMX_OPTS="$JMX_OPTS -Dcom.sun.management.jmxremote.ssl=false"
    JMX_OPTS="$JMX_OPTS -Djava.rmi.server.hostname=$JMX_HOST"
    
    # GC日志配置 - 兼容不同Java版本
    JAVA_MAJOR_VERSION=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2 | cut -d'.' -f1)
    if [ "$JAVA_MAJOR_VERSION" = "1" ]; then
        # Java 8 (版本号格式为 1.8.x)
        JAVA_MAJOR_VERSION=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2 | cut -d'.' -f2)
    fi
    
    if [ "$JAVA_MAJOR_VERSION" -ge "9" ]; then
        # Java 9+ 使用新的GC日志参数
        GC_OPTS="-Xlog:gc*:gc.log:time,tags"
    else
        # Java 8 使用旧的GC日志参数
        GC_OPTS="-XX:+PrintGC -XX:+PrintGCDetails -XX:+PrintGCTimeStamps"
        GC_OPTS="$GC_OPTS -XX:+PrintGCApplicationStoppedTime"
        GC_OPTS="$GC_OPTS -Xloggc:gc.log"
    fi
    
    # 堆转储配置
    DUMP_OPTS="-XX:+HeapDumpOnOutOfMemoryError"
    DUMP_OPTS="$DUMP_OPTS -XX:HeapDumpPath=../dump/"
    
    # 启动应用
    log_info "启动命令: java $JVM_OPTS $JMX_OPTS $GC_OPTS $DUMP_OPTS -jar $JAR_FILE"
    
    nohup java $JVM_OPTS $JMX_OPTS $GC_OPTS $DUMP_OPTS -jar "$JAR_FILE" > "$LOG_FILE" 2>&1 &
    
    local pid=$!
    echo $pid > "$PID_FILE"
    
    log_info "应用启动中，PID: $pid"
    
    # 等待应用启动并显示日志
    log_info "等待应用启动..."
    sleep 5
    
    # 检查进程是否还在运行
    if ps -p $pid > /dev/null 2>&1; then
        log_success "应用启动成功！"
        show_status
        show_jmx_info
        
        # 显示最新的应用日志
        log_info "=== 应用启动日志 ==="
        if [ -f "$LOG_FILE" ]; then
            tail -20 "$LOG_FILE"
        fi
        echo ""
        return 0
    else
        log_error "应用启动失败，进程已退出"
        log_info "=== 错误日志 ==="
        if [ -f "$LOG_FILE" ]; then
            tail -20 "$LOG_FILE"
        fi
        return 1
    fi
}

# 停止应用
stop_app() {
    log_info "停止应用..."
    
    local pid=$(get_app_pid)
    if [ -z "$pid" ]; then
        log_warning "应用未运行"
        return 0
    fi
    
    if ! ps -p $pid > /dev/null 2>&1; then
        log_warning "应用进程不存在，清理PID文件"
        rm -f "$PID_FILE"
        return 0
    fi
    
    log_info "停止进程 PID: $pid"
    kill $pid
    
    # 等待进程停止
    for i in {1..10}; do
        if ! ps -p $pid > /dev/null 2>&1; then
            log_success "应用已停止"
            rm -f "$PID_FILE"
            return 0
        fi
        sleep 1
    done
    
    # 强制停止
    log_warning "强制停止应用"
    kill -9 $pid
    rm -f "$PID_FILE"
    log_success "应用已强制停止"
}

# 重启应用
restart_app() {
    log_info "重启应用..."
    stop_app
    sleep 2
    start_app
}

# 显示应用状态
show_status() {
    local pid=$(get_app_pid)
    
    if [ -z "$pid" ]; then
        log_info "应用状态: 未运行"
        return 1
    fi
    
    if ps -p $pid > /dev/null 2>&1; then
        log_success "应用状态: 运行中 (PID: $pid)"
        
        # 显示内存使用情况
        local memory_info=$(ps -p $pid -o pid,ppid,rss,vsz,pcpu,pmem,comm --no-headers)
        log_info "内存信息: $memory_info"
        
        # 检查端口
        if lsof -Pi :8091 -sTCP:LISTEN -t >/dev/null 2>&1; then
            log_success "应用端口: 8091 (正常)"
        else
            log_warning "应用端口: 8091 (未监听)"
        fi
        
        if lsof -Pi :$JMX_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
            log_success "JMX端口: $JMX_PORT (正常)"
        else
            log_warning "JMX端口: $JMX_PORT (未监听)"
        fi
        
        return 0
    else
        log_error "应用状态: 进程不存在，清理PID文件"
        rm -f "$PID_FILE"
        return 1
    fi
}

# 显示JMX连接信息
show_jmx_info() {
    echo ""
    log_info "=== VisualVM JMX 连接信息 ==="
    log_info "JMX服务地址: service:jmx:rmi:///jndi/rmi://$JMX_HOST:$JMX_PORT/jmxrmi"
    log_info "简化连接地址: $JMX_HOST:$JMX_PORT"
    log_info "RMI端口: $RMI_PORT"
    echo ""
    log_info "=== VisualVM 连接步骤 ==="
    log_info "1. 启动 VisualVM"
    log_info "2. 右键点击 'Remote' 节点"
    log_info "3. 选择 'Add Remote Host'"
    log_info "4. 输入主机名: $JMX_HOST"
    log_info "5. 右键点击新添加的主机"
    log_info "6. 选择 'Add JMX Connection'"
    log_info "7. 输入连接地址: $JMX_HOST:$JMX_PORT"
    log_info "8. 点击 'OK' 完成连接"
    echo ""
    log_info "=== 应用接口地址 ==="
    log_info "应用首页: http://localhost:8091"
    log_info "内存状态: http://localhost:8091/api/memory/status"
    log_info "生成dump: http://localhost:8091/api/jmap/dump"
    echo ""
}

# 查看日志
show_logs() {
    if [ -f "$LOG_FILE" ]; then
        log_info "应用日志 (最后50行):"
        tail -50 "$LOG_FILE"
    else
        log_warning "日志文件不存在: $LOG_FILE"
    fi
}

# 实时查看日志
follow_logs() {
    if [ -f "$LOG_FILE" ]; then
        log_info "实时查看应用日志 (Ctrl+C 退出):"
        tail -f "$LOG_FILE"
    else
        log_warning "日志文件不存在: $LOG_FILE"
    fi
}

# 显示帮助信息
show_help() {
    echo "VisualVM JMX 远程连接启动脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  start         启动应用"
    echo "  stop          停止应用"
    echo "  restart       重启应用"
    echo "  status        显示应用状态"
    echo "  jmx           显示JMX连接信息"
    echo "  logs          查看应用日志"
    echo "  follow        实时查看应用日志"
    echo "  help          显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 start      # 启动应用"
    echo "  $0 status     # 查看状态"
    echo "  $0 jmx        # 显示JMX连接信息"
    echo "  $0 logs       # 查看日志"
    echo ""
    echo "JMX配置:"
    echo "  JMX端口: $JMX_PORT"
    echo "  RMI端口: $RMI_PORT"
    echo "  连接地址: $JMX_HOST:$JMX_PORT"
    echo ""
}

# 主程序
case "${1:-help}" in
    "start")
        start_app
        ;;
    "stop")
        stop_app
        ;;
    "restart")
        restart_app
        ;;
    "status")
        show_status
        ;;
    "jmx")
        show_jmx_info
        ;;
    "logs")
        show_logs
        ;;
    "follow")
        follow_logs
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