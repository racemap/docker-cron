FROM alpine:3.19

RUN apk add --no-cache bash dcron \
    && mkdir -p /app

COPY run.sh /app/run.sh
RUN chmod +x /app/run.sh

WORKDIR /app

HEALTHCHECK CMD pgrep crond || exit 1

ENTRYPOINT ["/app/run.sh"]
