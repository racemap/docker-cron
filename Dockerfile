FROM alpine:latest

# Version build argument
ARG VERSION=unknown
LABEL version=${VERSION}
LABEL maintainer="racemap"

# Latest releases available at https://github.com/aptible/supercronic/releases
ENV SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/v0.2.34/supercronic-linux-amd64 \
    SUPERCRONIC_SHA1SUM=e8631edc1775000d119b70fd40339a7238eece14 \
    SUPERCRONIC=supercronic-linux-amd64

# Install dependencies
RUN apk add --no-cache bash jq curl wget docker docker-cli-compose inotify-tools

RUN curl -fsSLO "$SUPERCRONIC_URL" \
    && echo "${SUPERCRONIC_SHA1SUM}  ${SUPERCRONIC}" | sha1sum -c - \
    && chmod +x "$SUPERCRONIC" \
    && mv "$SUPERCRONIC" "/usr/local/bin/${SUPERCRONIC}" \
    && ln -s "/usr/local/bin/${SUPERCRONIC}" /usr/local/bin/supercronic

# Copy application files
COPY . /app
WORKDIR /app

# Set version in environment
ENV APP_VERSION=${VERSION}

# Default command
ENTRYPOINT ["/app/run.sh"]
