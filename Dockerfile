FROM alpine:3.19

# Install dependencies and supercronic (container-friendly cron)
RUN apk add --no-cache bash jq docker-cli docker-cli-compose inotify-tools curl wget \
    && mkdir -p /app \
    && curl -fsSL -o /usr/local/bin/supercronic https://github.com/aptible/supercronic/releases/download/v0.2.29/supercronic-linux-amd64 \
    && chmod +x /usr/local/bin/supercronic

COPY run.sh /app/run.sh
COPY app/config_parser.sh /app/config_parser.sh
COPY app/cron_logger.sh /app/cron_logger.sh
RUN chmod +x /app/run.sh /app/config_parser.sh /app/cron_logger.sh

WORKDIR /app

HEALTHCHECK CMD pgrep supercronic || exit 1

ENTRYPOINT ["/app/run.sh"]
