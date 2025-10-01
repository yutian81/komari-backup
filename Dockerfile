FROM ghcr.io/komari-monitor/komari:latest

# 安装 Komari 备份脚本所需依赖:
RUN apk add --no-cache bash curl wget git sqlite jq tar dcron

# 拷贝备份脚本到 /app/data 目录
COPY komari_bak.sh /app/data/komari_bak.sh
RUN chmod +x /app/data/komari_bak.sh

# 设置每日凌晨 4 点执行备份任务，日志输出到 /var/log/cron.log
RUN echo "0 4 * * * root /app/data/komari_bak.sh bak >> /var/log/cron.log 2>&1" > /etc/crontabs/root

# 容器启动命令
CMD ["/bin/sh", "-c", "/usr/sbin/crond -f -L /var/log/cron.log & exec /app/komari server"]
