# docker-cron

This container runs a cron daemon configured by environment variables or an optional `config.yml` file.

## Using a configuration file

1. Create a `config.yml` containing key-value pairs such as:
   ```
   CMD_1="echo hello"
   INTERVAL_1="*/5 * * * *"
   ```
2. Mount the file into the container and tell the parser to read it:
   ```sh
   docker run -v config.yml:/app/config.yml -e CONFIG_FILE=/app/config.yml image
   ```
3. Any variables passed with `-e` on the command line take precedence over values in `config.yml`.

## Dependencies and resource usage

The image is based on Alpine Linux and installs only the `bash` shell and the `dcron` scheduler. Typical
runtime memory consumption is below 10&nbsp;MB and CPU usage is negligible outside of scheduled jobs.
