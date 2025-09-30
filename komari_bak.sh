#!/usr/bin/env bash

#===============================================================
#                   Komari Dashboard Backup Script
#
# 此备份脚本适用于 komari 面板，将其存放于 VPS 的 /root 目录
#
# 功能:
#   - 自动检查并安装依赖 (git, sqlite3, tar, curl, wget, jq)。
#   - 备份: 打包并备份 Komari 面板的数据目录至私有 GitHub 仓库。
#           同时生成一个 README.md 文件，记录最新的备份文件名。
#   - 还原: 从 GitHub 仓库拉取最新的备份文件并恢复至面板。
#
# 使用方法:
#   - 备份: bash komari_bak.sh bak
#   - 还原: bash komari_bak.sh res
#
#===============================================================

#---------------------------------------------------------------
# GITHUB 仓库配置 (请务必修改为自己的信息)
#---------------------------------------------------------------
GH_BACKUP_USER="${GH_BACKUP_USER:-your_github_username}"
GH_REPO="${GH_REPO:-your_private_repo_name}"
GH_PAT="${GH_PAT:-your_github_personal_access_token}"
GH_EMAIL="${GH_EMAIL:-your_github_email@example.com}"
DATA_DIR="${KOMARI_DATA_DIR:-/opt/komari/data}"

#---------------------------------------------------------------
# 面板工作目录配置 (如果不是默认路径，请修改)
#---------------------------------------------------------------
WORK_DIR="/opt/komari"
DATA_DIR="${WORK_DIR}/data"

#---------------------------------------------------------------
# 脚本核心逻辑 (非专业人士请勿修改以下内容)
#---------------------------------------------------------------

# 颜色定义
info() { echo -e "\033[32m\033[01m$*\033[0m"; }    # 绿色
error() { echo -e "\033[31m\033[01m$*\033[0m" && exit 1; } # 红色
hint() { echo -e "\033[33m\033[01m$*\033[0m"; }    # 黄色

check_and_install_dependencies() {
    info "============== 正在检查脚本依赖 =============="
    declare -A CMD_PKG_MAP
    CMD_PKG_MAP=(
        [git]="git"
        [sqlite3]="sqlite3"
        [tar]="tar"
        [curl]="curl"
        [wget]="wget"
        [jq]="jq"
    )

    if command -v apt-get &>/dev/null; then
        PM="apt"
    elif command -v yum &>/dev/null; then
        PM="yum"
        CMD_PKG_MAP[sqlite3]="sqlite"
    elif command -v dnf &>/dev/null; then
        PM="dnf"
        CMD_PKG_MAP[sqlite3]="sqlite"
    elif command -v apk &>/dev/null; then
        PM="apk"
        CMD_PKG_MAP[sqlite3]="sqlite"
    else
        error "未能识别的包管理器。请手动安装以下依赖: ${!CMD_PKG_MAP[@]}"
    fi

    MISSING_PKGS=()
    for cmd in "${!CMD_PKG_MAP[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            MISSING_PKGS+=("${CMD_PKG_MAP[$cmd]}")
        fi
    done

    if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
        info "检测到缺失的依赖: ${MISSING_PKGS[*]}，正在自动安装..."
        install_failed=0
        case "$PM" in
            apt)
                if ! (apt-get update && apt-get install -y "${MISSING_PKGS[@]}"); then
                    install_failed=1
                fi
                ;;
            yum|dnf)
                if ! "$PM" install -y "${MISSING_PKGS[@]}"; then
                    install_failed=1
                fi
                ;;
            apk)
                if ! (apk update && apk add --no-cache "${MISSING_PKGS[@]}"); then
                    install_failed=1
                fi
                ;;
        esac

        if [ "$install_failed" -eq 1 ]; then
            error "部分或全部依赖自动安装失败，请手动安装后重试。"
        fi

        info "所有缺失的依赖已成功安装。"
    else
        info "所有依赖均已安装。"
    fi
}

# 检查运行环境 (Docker 或 systemd)
IS_DOCKER=0
if [ -f "/.dockerenv" ] || grep -q "docker" /proc/1/cgroup; then
    IS_DOCKER=1
fi

# 服务控制函数
control_service() {
    local action="$1" # "stop" 或 "start"
    hint "正在 $action Komari 面板服务..."

    if [ -f "${WORK_DIR}/docker-compose.yaml" ] || docker ps -a --format '{{.Names}}' | grep -q "^komari-dashboard$"; then
        IS_DOCKER=1
    fi

    if [ "$IS_DOCKER" = 1 ]; then
        docker "$action" komari-dashboard >/dev/null 2>&1
        if [ $? -ne 0 ]; then
             hint "无法执行 'docker $action komari-dashboard' (可能容器已处于目标状态或不存在)。"
        fi
    else
        if command -v systemctl &>/dev/null; then
            if systemctl is-active --quiet komari-dashboard && [ "$action" = "stop" ]; then
                systemctl stop komari-dashboard
            elif ! systemctl is-active --quiet komari-dashboard && [ "$action" = "start" ]; then
                systemctl start komari-dashboard
            fi
        else
            error "未找到 systemctl 命令。请根据您的系统调整服务控制逻辑。"
        fi
    fi
    sleep 3
}

# 备份函数
do_backup() {
    info "============== 开始执行备份任务 =============="
    control_service "stop"
    
    cd "$WORK_DIR" || error "无法进入工作目录: $WORK_DIR"

    hint "正在准备备份..."
    [ ! -d "$DATA_DIR" ] && error "数据目录不存在: $DATA_DIR"

    hint "正在克隆备份仓库..."
    [ -d /tmp/$GH_REPO ] && rm -rf /tmp/$GH_REPO
    if ! git clone "https://$GH_PAT@github.com/$GH_BACKUP_USER/$GH_REPO.git" --depth 1 /tmp/$GH_REPO; then
        control_service "start"
        error "克隆仓库失败。请检查 GitHub 配置。"
    fi

    TIME=$(TZ="Asia/Shanghai" date "+%Y-%m-%d-%H%M%S")
    BACKUP_FILE="komari-$TIME.tar.gz"
    hint "正在压缩备份文件..."
    tar czvf "/tmp/$GH_REPO/$BACKUP_FILE" -C "$WORK_DIR" data/

    if [ ! -s "/tmp/$GH_REPO/$BACKUP_FILE" ]; then
        control_service "start"
        error "压缩文件失败或文件为空。"
    fi
    info "文件已压缩为: $BACKUP_FILE"

    cd /tmp/$GH_REPO || error "进入临时仓库目录失败。"
    find ./ -name '*.gz' | sort | head -n -5 | xargs -r rm -f
    echo "$BACKUP_FILE" > README.md

    git config --global user.name "$GH_BACKUP_USER"
    git config --global user.email "$GH_EMAIL"
    git add .
    git commit -m "Backup at $TIME"
    
    if git push -f -u origin main; then
        info "备份文件和 README.md 已成功上传至 GitHub！"
    else
        control_service "start"
        error "上传失败。请检查网络或 GitHub PAT 权限。"
    fi

    cd "$WORK_DIR"
    rm -rf /tmp/$GH_REPO
    control_service "start"
    info "============== 备份任务执行完毕 =============="
}

# 还原函数
do_restore() {
    info "============== 开始执行还原任务 =============="
    hint "警告: 此操作将覆盖现有的数据！"
    read -p "确定要继续吗? (y/N): " choice
    [[ "$choice" != "y" && "$choice" != "Y" ]] && error "操作已取消。"

    hint "正在获取最新备份文件..."
    LATEST_BACKUP_URL=$(curl -s -H "Authorization: token $GH_PAT" \
      "https://api.github.com/repos/$GH_BACKUP_USER/$GH_REPO/contents/" | \
      jq -r '.[] | select(.name | endswith(".tar.gz")) | .download_url' | sort -r | head -n 1)
      
    if [ -z "$LATEST_BACKUP_URL" ]; then
        error "无法从 GitHub 仓库获取最新备份文件。"
    fi
    
    if ! wget -q -O "/tmp/komari_latest.tar.gz" "$LATEST_BACKUP_URL"; then
        error "下载最新备份文件失败。"
    fi
    info "已成功下载最新备份文件。"

    control_service "stop"
    cd "$WORK_DIR" || error "无法进入工作目录: $WORK_DIR"

    hint "正在清理旧数据并应用备份..."
    rm -rf "$DATA_DIR"
    
    if ! tar xzvf "/tmp/komari_latest.tar.gz" -C "$WORK_DIR/"; then
        control_service "start"
        rm -f "/tmp/komari_latest.tar.gz"
        error "解压备份文件失败。数据可能已损坏！"
    fi
    
    rm -f "/tmp/komari_latest.tar.gz"
    control_service "start"
    info "============== 还原任务执行完毕 =============="
}

# --- 主逻辑 ---
check_and_install_dependencies

case "$1" in
    bak)
        do_backup
        ;;
    res)
        do_restore
        ;;
    *)
        echo "使用方法:"
        echo "  $0 bak   - 执行备份"
        echo "  $0 res   - 执行还原"
        exit 1
        ;;
esac
