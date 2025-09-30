FROM ghcr.io/komari-monitor/komari:latest

RUN apk add --no-cache bash curl wget git sqlite jq tar dcron tzdata

WORKDIR /opt/komari

COPY komari_bak.sh /opt/komari/data/komari_bak.sh
RUN chmod +x /opt/komari/data/komari_bak.sh

RUN echo "0 4 * * * root /opt/komari/data/komari_bak.sh bak >> /var/log/cron.log 2>&1" > /etc/crontabs/root

CMD ["/bin/sh", "-c", "/usr/sbin/crond -f -L /var/log/cron.log & exec /app/komari", "server"]
