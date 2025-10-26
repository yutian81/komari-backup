FROM ghcr.io/komari-monitor/komari:latest

RUN apk add --no-cache bash curl wget git sqlite jq tar dcron

COPY komari_bak.sh /app/data/komari_bak.sh
RUN chmod +x /app/data/komari_bak.sh

# 设置备份任务
RUN echo "0 20 * * * /app/data/komari_bak.sh bak" > /etc/crontabs/root

CMD ["/bin/sh", "-c", "/usr/sbin/crond -f & exec /app/komari server"]
