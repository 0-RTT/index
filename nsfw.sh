#!/bin/sh

# 默认的安装目录
NSFW_DIR="/root/nsfw"

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
    # 创建 nsfw 目录
    mkdir -p "$NSFW_DIR"
    cd "$NSFW_DIR" || exit

    # 检查必要的命令
    check_command curl
    check_command wget

    # 下载 index.js 和 package.json
    INDEX_URL="https://raw.githubusercontent.com/0-RTT/nsfw/main/index.js"
    PACKAGE_URL="https://raw.githubusercontent.com/0-RTT/nsfw/main/package.json"

    curl -o index.js "$INDEX_URL"
    curl -o package.json "$PACKAGE_URL"

    # 进入 nsfw 目录并执行 npm install
    if [ -f package.json ]; then
        echo "正在执行 npm install..."
        check_command npm
        npm install
        if [ $? -eq 0 ]; then
            echo "npm install 执行成功！"
        else
            echo "npm install 执行失败！"
        fi
    else
        echo "未找到 package.json，无法执行 npm install。"
    fi

    # 创建 systemd 服务文件
    SERVICE_FILE="/etc/systemd/system/nsfw.service"

    cat <<EOL | sudo tee "$SERVICE_FILE"
[Unit]
Description=NSFW Service
After=network.target

[Service]
ExecStart=/usr/bin/node $NSFW_DIR/index.js
WorkingDirectory=$NSFW_DIR
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOL

    # 重新加载 systemd 配置
    sudo systemctl daemon-reload

    # 启动服务
    sudo systemctl start nsfw.service

    # 设置开机自启
    sudo systemctl enable nsfw.service

    # 输出安装完成信息
    echo "nsfw 已安装，请阅读 README.md 配置 Nginx 反向代理。"
}

# 卸载函数
remove() {
    # 停止服务
    sudo systemctl stop nsfw.service

    # 禁用开机自启
    sudo systemctl disable nsfw.service

    # 删除 systemd 服务文件
    SERVICE_FILE="/etc/systemd/system/nsfw.service"
    if [ -f "$SERVICE_FILE" ]; then
        sudo rm "$SERVICE_FILE"
        echo "已删除服务文件: $SERVICE_FILE"
    else
        echo "服务文件不存在: $SERVICE_FILE"
    fi

    # 重新加载 systemd 配置
    sudo systemctl daemon-reload

    # 删除 nsfw 目录
    if [ -d "$NSFW_DIR" ]; then
        rm -rf "$NSFW_DIR"
        echo "已删除 nsfw 目录: $NSFW_DIR"
    else
        echo "nsfw 目录不存在: $NSFW_DIR"
    fi

    # 输出卸载完成信息
    echo "nsfw 已卸载，有缘再会！"
}

# 主程序
case "$1" in
    install)
        install
        ;;
    remove)
        remove
        ;;
    *)
        echo "用法: $0 {install|remove}"
        exit 1
        ;;
esac
