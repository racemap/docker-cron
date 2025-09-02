FROM alpine:latest

# Version build argument
ARG VERSION=unknown
LABEL version=${VERSION}
LABEL maintainer="racemap"

# Install cron and other dependencies
RUN apk add --no-cache dcron tzdata

# Copy application files
COPY . /app
WORKDIR /app

# Make scripts executable
RUN chmod +x version.sh

# Set version in environment
ENV APP_VERSION=${VERSION}

# Default command
CMD ["crond", "-f", "-d", "8"]
