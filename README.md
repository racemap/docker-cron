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

The image is based on Alpine Linux and installs the `bash` shell, the `dcron` scheduler, `jq`, and the
Docker CLI with the Compose plugin. Typical runtime memory consumption is below 10&nbsp;MB and CPU usage
is negligible outside of scheduled jobs.

## Running Docker and Docker Compose tasks

The container can execute Docker commands on the host by mounting the Docker socket and any required
Compose files.

1. **Build the image**

   ```sh
   docker build -t docker-cron .
   ```

2. **Run with access to the host Docker daemon**

   ```sh
   docker run \
     -v /var/run/docker.sock:/var/run/docker.sock \
     -v $(pwd)/docker-compose.yml:/docker-compose.yml \
     -e CMD_1="docker compose -f /docker-compose.yml up -d" \
     -e INTERVAL_1="0 * * * *" \
     docker-cron
   ```

This example brings up services defined in `docker-compose.yml` every hour. Cron jobs may invoke any
`docker` or `docker compose` commands needed for your workflows.
