#!/usr/bin/env bash

#===============================================================
#               Komari Dashboard Backup Script
#
# 此脚本专为在 Docker 版 Komari 面板数据的备份还原设计
# ---------------------------------------------------------------
# 功能:
#   - 备份: 打包并备份 Komari 面板的数据目录至私有 GitHub 仓库。
#   - 还原: 从 GitHub 仓库拉取最新的备份文件并恢复至面板。
#
# 使用方法:
#   - 备份 (由 Cron 自动调用): bash komari_bak.sh bak
#   - 还原 (手动调用): bash komari_bak.sh res
#===============================================================

#---------------------------------------------------------------
# GITHUB 仓库配置 (请务必修改为自己的信息，建议通过环境变量传递)
#---------------------------------------------------------------
GH_BACKUP_USER="${GH_BACKUP_USER:-your_github_username}"
GH_REPO="${GH_REPO:-your_private_repo_name}"
GH_PAT="${GH_PAT:-your_github_personal_access_token}"
GH_EMAIL="${GH_EMAIL:-your_github_email@example.com}"

#---------------------------------------------------------------
# 面板工作目录配置 (与 Dockerfile 中 Komari 的工作路径保持一致)
#---------------------------------------------------------------
WORK_DIR="/app"
DATA_DIR="${WORK_DIR}/data"

#---------------------------------------------------------------
# 脚本核心逻辑
#---------------------------------------------------------------

# 颜色定义
info() { echo -e "\033[32m\033[01m$*\033[0m"; }     # 绿色
error() { echo -e "\033[31m\033[01m$*\033[0m" && exit 1; } # 红色
hint() { echo -e "\033[33m\033[01m$*\033[0m"; }     # 黄色

# 检查 GH_PAT，防止 Cron 任务因缺少环境变量而失败
if [ "$GH_PAT" = "your_github_personal_access_token" ] || [ -z "$GH_PAT" ]; then
    error "GitHub PAT 未正确设置。Cron 任务不会自动继承 Docker 环境变量。请确保在运行容器时使用 -e GH_PAT=... 正确设置。"
fi

# 备份函数
do_backup() {
    info "============== 开始执行 Komari 备份任务 =============="
    
    cd "$WORK_DIR" || error "无法进入工作目录: $WORK_DIR"

    hint "正在克隆备份仓库..."
    BACKUP_TEMP_DIR="/tmp/$GH_REPO"
    [ -d "$BACKUP_TEMP_DIR" ] && rm -rf "$BACKUP_TEMP_DIR"
    
    # 使用 PAT 克隆私有仓库
    if ! git clone "https://$GH_PAT@github.com/$GH_BACKUP_USER/$GH_REPO.git" --depth 1 "$BACKUP_TEMP_DIR"; then
        error "克隆 GitHub 仓库失败。请检查 GH_PAT 或网络连接。"
    fi

    TIME=$(TZ="Asia/Shanghai" date "+%Y-%m-%d-%H%M%S")
    BACKUP_FILE="komari-$TIME.tar.gz"
    
    hint "正在压缩数据目录: $DATA_DIR"
    tar czvf "$BACKUP_TEMP_DIR/$BACKUP_FILE" -C "$WORK_DIR" data/

    if [ ! -s "$BACKUP_TEMP_DIR/$BACKUP_FILE" ]; then
        error "压缩文件失败或文件为空。"
    fi
    info "文件已压缩为: $BACKUP_FILE"

    cd "$BACKUP_TEMP_DIR" || error "进入临时仓库目录失败。"
    
    hint "正在清理旧备份，保留最新的 5 个..."
    find ./ -name 'komari-*.tar.gz' | sort | head -n -5 | xargs -r rm -f
    
    # 记录最新的备份文件名
    echo "$BACKUP_FILE" > README.md

    # 配置 Git 用户信息并提交
    git config user.name "$GH_BACKUP_USER"
    git config user.email "$GH_EMAIL"
    git add .
    # 检查是否有文件变动再提交
    if git status --porcelain | grep -q .; then
        git commit -m "Backup at $TIME"
    else
        info "无新文件或变更需要提交。"
        rm -rf "$BACKUP_TEMP_DIR"
        info "============== 备份任务执行完毕 (无变更) =============="
        return
    fi
    
    if git push -f -u origin main; then
        info "备份文件和 README.md 已成功上传至 GitHub！"
    else
        error "上传失败。请检查网络或 GitHub PAT 权限。"
    fi

    rm -rf "$BACKUP_TEMP_DIR"
    info "============== 备份任务执行完毕 =============="
}

# 还原函数
do_restore() {
    info "============== 开始执行还原任务 =============="
    hint "警告: 此操作将覆盖现有的 $DATA_DIR 数据！"
    
    # 由于在容器内无法使用交互式输入，这里改为强制执行
    # 如果希望更安全，请在容器外手动执行此脚本
    # read -p "确定要继续吗? (y/N): " choice
    # [[ "$choice" != "y" && "$choice" != "Y" ]] && error "操作已取消。"
    
    hint "正在获取最新备份文件的下载链接..."
    # 使用 GH_PAT 获取最新的 .tar.gz 文件的下载 URL
    LATEST_BACKUP_URL=$(curl -s -H "Authorization: token $GH_PAT" \
      "https://api.github.com/repos/$GH_BACKUP_USER/$GH_REPO/contents/" | \
      jq -r '.[] | select(.name | endswith(".tar.gz")) | .download_url' | sort -r | head -n 1)
      
    if [ -z "$LATEST_BACKUP_URL" ]; then
        error "无法从 GitHub 仓库获取最新备份文件。请检查仓库路径或 GH_PAT 权限。"
    fi
    
    DOWNLOAD_PATH="/tmp/komari_latest.tar.gz"
    hint "正在下载最新备份文件: $LATEST_BACKUP_URL"
    if ! wget -q -O "$DOWNLOAD_PATH" "$LATEST_BACKUP_URL"; then
        error "下载最新备份文件失败。"
    fi
    info "已成功下载最新备份文件。"

    cd "$WORK_DIR" || error "无法进入工作目录: $WORK_DIR"

    hint "正在清理旧数据并应用备份..."
    # 移除现有数据目录
    if [ -d "$DATA_DIR" ]; then
        rm -rf "$DATA_DIR"
    fi
    
    # 解压备份文件。由于 tar 包内路径是 data/，所以解压到 $WORK_DIR (即 /app) 即可
    if ! tar xzvf "$DOWNLOAD_PATH" -C "$WORK_DIR/"; then
        rm -f "$DOWNLOAD_PATH"
        error "解压备份文件失败。数据可能已损坏！"
    fi
    
    rm -f "$DOWNLOAD_PATH"
    info "请手动重启容器以确保 Komari 服务加载新数据。"
    info "============== 还原任务执行完毕 =============="
}

# --- 主逻辑 ---
case "$1" in
    bak)
        do_backup
        ;;
    res)
        do_restore
        ;;
    *)
        echo "使用方法:"
        echo "  $0 bak   - 执行备份 (Cron 自动调用)"
        echo "  $0 res   - 执行还原 (手动调用)"
        exit 1
        ;;
esac
