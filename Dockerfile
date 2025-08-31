FROM alpine:3.19

RUN apk add --no-cache bash dcron jq \
    && mkdir -p /app

COPY run.sh /app/run.sh
COPY app/config_parser.sh /app/config_parser.sh
RUN chmod +x /app/run.sh /app/config_parser.sh

WORKDIR /app

HEALTHCHECK CMD pgrep crond || exit 1

ENTRYPOINT ["/app/run.sh"]
