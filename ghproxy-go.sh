#!/bin/sh

# 检查命令是否存在的函数
check_command() {
    command -v "$1" >/dev/null 2>&1 || { 
        echo >&2 "错误: 需要安装 $1。正在尝试自动安装..."
        install_command "$1"
    }
}

# 安装命令的函数
install_command() {
    if [ -x "$(command -v apt)" ]; then
        sudo apt update && sudo apt install -y "$1"
    elif [ -x "$(command -v yum)" ]; then
        sudo yum install -y "$1"
    elif [ -x "$(command -v dnf)" ]; then
        sudo dnf install -y "$1"
    else
        echo "错误: 无法找到合适的包管理器来安装 $1。请手动安装。"
        exit 1
    fi
}

# 安装函数
install() {
    # 创建 ghproxy 目录
    GH_PROXY_DIR="/root/ghproxy"
    mkdir -p "$GH_PROXY_DIR"
    cd "$GH_PROXY_DIR" || exit

    # 检查必要的命令
    check_command curl
    check_command wget
    check_command unzip

    # 获取最新 release 的下载链接
    LATEST_URL=$(curl -s https://api.github.com/repos/0-RTT/ghproxy-go/releases/latest | grep "browser_download_url" | grep "zip" | cut -d '"' -f 4)

    # 下载 ZIP 文件
    wget "$LATEST_URL" -O ghproxy-go-latest.zip

    # 解压 ZIP 文件
    unzip ghproxy-go-latest.zip

    # 设置解压后文件的权限为 755
    chmod 755 ghproxy-go

    # 清理 ZIP 文件
    rm ghproxy-go-latest.zip

    # 创建 systemd 服务文件
    SERVICE_FILE="/etc/systemd/system/ghproxy-go.service"

    cat <<EOL | sudo tee "$SERVICE_FILE"
[Unit]
Description=ghproxy-go Service
After=network.target

[Service]
Type=simple
ExecStart=$GH_PROXY_DIR/ghproxy-go
WorkingDirectory=$GH_PROXY_DIR
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

    # 重新加载 systemd 配置
    sudo systemctl daemon-reload

    # 启动服务
    sudo systemctl start ghproxy-go.service

    # 设置开机自启
    sudo systemctl enable ghproxy-go.service

    # 输出安装完成信息
    echo "ghproxy-go 已安装，请阅读README.md配置nginx反向代理。"
}

# 卸载函数
remove() {
    # 停止服务
    sudo systemctl stop ghproxy-go.service

    # 禁用开机自启
    sudo systemctl disable ghproxy-go.service

    # 删除 systemd 服务文件
    SERVICE_FILE="/etc/systemd/system/ghproxy-go.service"
    if [ -f "$SERVICE_FILE" ]; then
        sudo rm "$SERVICE_FILE"
        echo "已删除服务文件: $SERVICE_FILE"
    else
        echo "服务文件不存在: $SERVICE_FILE"
    fi

    # 重新加载 systemd 配置
    sudo systemctl daemon-reload

    # 删除安装目录及其内容
    GH_PROXY_DIR="/root/ghproxy"
    if [ -d "$GH_PROXY_DIR" ]; then
        rm -r "$GH_PROXY_DIR"
        echo "已删除安装目录: $GH_PROXY_DIR"
    else
        echo "安装目录不存在: $GH_PROXY_DIR"
    fi

    # 输出卸载完成信息
    echo "ghproxy-go 已卸载，有缘再会！"
}

# 主程序
if [ "$1" = "install" ]; then
    install
elif [ "$1" = "remove" ]; then
    remove
else
    echo "用法: $0 {install|remove}"
    exit 1
fi
