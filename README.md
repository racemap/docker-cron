# docker-cron

This container runs a cron daemon configured by environment variables or an optional `config.json` file.

## Defining jobs with environment variables

Jobs can be scheduled directly with pairs of `CMD_n` and `INTERVAL_n` variables. Each pair defines one job:

```sh
docker run \
  -e CMD_1="echo hello" -e INTERVAL_1="*/5 * * * *" \
  -e CMD_2="date"      -e INTERVAL_2="0 1 * * *" image
```

The index `n` starts at 1 and must increase sequentially with no gaps; the parser stops at the first missing pair.
Both variables of a pair are required. `INTERVAL_n` expects a standard five-field cron expression, and `CMD_n`
is any shell command.

### Overriding values from `config.json`

If a `CONFIG_FILE` is supplied, jobs from that file populate unset `CMD_n`/`INTERVAL_n` variables. Explicit
environment values override those from the file:

```json
# config.json
{
  "jobs": [
    {"cmd": "echo from file", "interval": "*/5 * * * *"}
  ]
}
```

```sh
docker run -v $(pwd)/config.json:/app/config.json -e CONFIG_FILE=/app/config.json \
  -e CMD_1="echo from env" -e INTERVAL_1="*/10 * * * *" image
```

In this example the job runs `echo from env` every ten minutes, ignoring the `cmd` and `interval` from
`config.json`.

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
