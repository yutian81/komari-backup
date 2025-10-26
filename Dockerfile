FROM ghcr.io/komari-monitor/komari:latest

RUN apk add --no-cache bash curl wget git sqlite jq tar dcron

COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

COPY komari_bak.sh /app/data/komari_bak.sh
RUN chmod +x /app/data/komari_bak.sh

# UTC时间 20:00 即北京时间凌晨四点启动备份任务
RUN echo "0 20 * * * . /etc/cron_env.sh && /app/data/komari_bak.sh bak" > /etc/crontabs/root

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["/app/komari", "server"]
