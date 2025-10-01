FROM ghcr.io/komari-monitor/komari:latest

# 安装 Komari 备份脚本所需依赖:
RUN apk add --no-cache bash curl wget git sqlite jq tar dcron

# 拷贝备份脚本到 /app/data 目录
COPY komari_bak.sh /app/data/komari_bak.sh
RUN chmod +x /app/data/komari_bak.sh

# 设置为 UTC 时间 20:00 (即北京时间 04:00) 执行备份任务
RUN echo "0 20 * * * root /app/data/komari_bak.sh bak" > /etc/crontabs/root

# 容器启动命令
CMD ["/bin/sh", "-c", "/usr/sbin/crond -f & exec /app/komari server"]
