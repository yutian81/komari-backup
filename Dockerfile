FROM ghcr.io/komari-monitor/komari:latest

RUN apk add --no-cache bash curl wget git sqlite jq tar dcron

COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

COPY komari_bak.sh /app/data/komari_bak.sh
RUN chmod +x /app/data/komari_bak.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["/app/komari", "server"]
