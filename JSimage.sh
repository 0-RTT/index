#!/bin/sh

# 默认的安装目录
JSIMAGE_DIR="/usr/local/bin/JSimage"

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
        # 对于 apt，先更新包索引
        echo "正在更新包索引..."
        sudo apt update
        sudo apt install -y "$1"
    elif [ -x "$(command -v yum)" ]; then
        # 对于 yum，直接安装
        sudo yum install -y "$1"
    elif [ -x "$(command -v dnf)" ]; then
        # 对于 dnf，直接安装
        sudo dnf install -y "$1"
    else
        echo "错误: 无法找到合适的包管理器来安装 $1。请手动安装。"
        exit 1
    fi
}

# 检查并安装必要的命令
check_and_install_dependencies() {
    check_command curl
    check_command git
    check_command nodejs
    check_command npm
}

# 安装函数
install() {
    # 检查并安装必要的命令
    check_and_install_dependencies

    # 创建 JSimage 目录
    sudo mkdir -p "$JSIMAGE_DIR"
    sudo chown $USER:$USER "$JSIMAGE_DIR"  # 更改目录所有者为当前用户
    cd "$JSIMAGE_DIR" || exit

    # 使用 git 克隆项目
    REPO_URL="https://github.com/0-RTT/JSimage.git"
    git clone "$REPO_URL" .

    # 进入 JSimage 目录并执行 npm install
    if [ -f package.json ]; then
        echo "正在执行 npm install..."
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
    SERVICE_FILE="/etc/systemd/system/JSimage.service"

    cat <<EOL | sudo tee "$SERVICE_FILE"
[Unit]
Description=JSimage Service
After=network.target

[Service]
ExecStart=/usr/bin/node $JSIMAGE_DIR/main.mjs
WorkingDirectory=$JSIMAGE_DIR
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOL

    # 重新加载 systemd 配置
    sudo systemctl daemon-reload

    # 启动服务
    sudo systemctl start JSimage.service

    # 设置开机自启
    sudo systemctl enable JSimage.service

    # 输出安装完成信息
    echo "JSimage 已安装，请阅读 README.md 配置 Nginx 反向代理。"
}

# 卸载函数
remove() {
    # 检查服务文件和目录是否存在
    SERVICE_FILE="/etc/systemd/system/JSimage.service"
    if [ ! -f "$SERVICE_FILE" ] && [ ! -d "$JSIMAGE_DIR" ]; then
        echo "请先安装 JSimage。"
        exit 1
    fi

    # 停止服务
    sudo systemctl stop JSimage.service
    echo "JSimage.service 服务已停止。"

    # 禁用开机自启
    sudo systemctl disable JSimage.service

    # 删除 systemd 服务文件
    if [ -f "$SERVICE_FILE" ]; then
        sudo rm "$SERVICE_FILE"
        echo "已删除服务文件: $SERVICE_FILE"
    else
        echo "服务文件不存在: $SERVICE_FILE"
    fi

    # 重新加载 systemd 配置
    sudo systemctl daemon-reload

    # 提示用户是否保留数据
    read -p "是否保留数据（$JSIMAGE_DIR/images）？(y/n): " choice
    case "$choice" in
        y|Y )
            echo "已保留 JSimage 目录: $JSIMAGE_DIR"
            ;;
        n|N )
            # 删除 JSimage 目录
            if [ -d "$JSIMAGE_DIR" ]; then
                sudo rm -rf "$JSIMAGE_DIR"
                echo "已删除 JSimage 目录: $JSIMAGE_DIR"
            else
                echo "JSimage 目录不存在: $JSIMAGE_DIR"
            fi
            ;;
        * )
            echo "无效的选择，未做任何更改。"
            ;;
    esac

    # 输出卸载完成信息
    if [ "$choice" != "y" ] && [ "$choice" != "Y" ]; then
        echo "已卸载，有缘再会！"
    fi
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
