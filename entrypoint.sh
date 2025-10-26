#!/usr/bin/env bash

# 定义cron任务所需的环境变量
CRON_ENV_FILE="/etc/cron_env.sh"

echo "#!/usr/bin/env bash" > "$CRON_ENV_FILE"
echo "export GH_BACKUP_USER=\"$GH_BACKUP_USER\"" >> "$CRON_ENV_FILE"
echo "export GH_REPO=\"$GH_REPO\"" >> "$CRON_ENV_FILE"
echo "export GH_PAT=\"$GH_PAT\"" >> "$CRON_ENV_FILE"
echo "export GH_EMAIL=\"$GH_EMAIL\"" >> "$CRON_ENV_FILE"
chmod +x "$CRON_ENV_FILE"

# 启动cron服务
echo "正在启动 Cron 服务..."
/usr/sbin/crond -f & 
CRON_PID=$!

# 启动komari面板
echo "正在启动 Komari 面板..."
exec "$@"

wait $CRON_PID
