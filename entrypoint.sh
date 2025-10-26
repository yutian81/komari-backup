#!/usr/bin/env bash

# 定义文件路径
CRON_ENV_FILE="app/cron_env.sh"
CRONTAB_FILE="/etc/crontabs/root"
BACKUP_SCRIPT="/app/data/komari_bak.sh"

echo "#!/usr/bin/env bash" > "$CRON_ENV_FILE"
echo "export GH_BACKUP_USER=\"$GH_BACKUP_USER\"" >> "$CRON_ENV_FILE"
echo "export GH_REPO=\"$GH_REPO\"" >> "$CRON_ENV_FILE"
echo "export GH_PAT=\"$GH_PAT\"" >> "$CRON_ENV_FILE"
echo "export GH_EMAIL=\"$GH_EMAIL\"" >> "$CRON_ENV_FILE"
chmod +x "$CRON_ENV_FILE"

# UTC 20:00 (北京时间 04:00) 启动备份任务
echo "0 20 * * * . $CRON_ENV_FILE && $BACKUP_SCRIPT bak" > "$CRONTAB_FILE"

# 启动 Cron 服务 (在后台运行)
echo "正在启动 Cron 服务..."
/usr/sbin/crond -f & 
CRON_PID=$!

# 启动komari面板 (作为主进程)
echo "正在启动 Komari 面板..."
exec "$@"

wait $CRON_PID
