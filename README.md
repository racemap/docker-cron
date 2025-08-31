# docker-cron

This container runs a cron daemon configured by environment variables or an optional `config.json` file.

## Using a configuration file

1. Create a `config.json` containing jobs with a `cmd` and `interval`:
    ```json
    {
      "jobs": [
        {"cmd": "echo hello", "interval": "*/5 * * * *"}
      ]
    }
    ```
2. Mount the file into the container and tell the parser to read it:
    ```sh
    docker run -v config.json:/app/config.json -e CONFIG_FILE=/app/config.json image
    ```
3. Any variables passed with `-e` on the command line take precedence over values in `config.json`.

## Dependencies and resource usage

The image is based on Alpine Linux and installs only the `bash` shell and the `dcron` scheduler. Typical
runtime memory consumption is below 10&nbsp;MB and CPU usage is negligible outside of scheduled jobs.
