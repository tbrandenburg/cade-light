# CADE Minimal

A reproducible development workbench built from one Compose manifest. It runs
code-server, JupyterLab, and Node-RED in one container, with OpenCode and SRT
available from the terminal. Workspace files live in `workspace/`; the `home`
volume persists user configuration and Node-RED flows.

## Requirements

- Docker Engine with the Compose plugin
- A host capable of building the inline image (first build downloads dependencies)

## Start

```sh
make init
```

Edit `.env` and replace each placeholder with a unique, long secret. Then run:

```sh
make up
```

Endpoints are bound only to host loopback:

| Service | URL | Authentication |
| --- | --- | --- |
| code-server | <http://localhost:8080> | `PASSWORD` from `.env` |
| JupyterLab | <http://localhost:8888> | `JUPYTER_TOKEN` from `.env` |
| Node-RED | <http://localhost:1880> | No login configured |

If a default port is already in use, set `CODE_SERVER_PORT`, `JUPYTER_PORT`,
or `NODE_RED_PORT` in `.env` to an available host port. The container-side
ports remain fixed.

Node-RED has no authentication in this minimal setup. Keep the ports local; for
remote access, use SSH forwarding or an authenticated HTTPS gateway.

OpenCode is available in the integrated terminal or with:

```sh
docker compose exec workbench opencode
```

Useful commands:

```sh
make ps       # Show service status
make logs     # Follow workbench logs
make exec     # Open a workbench shell
make down     # Stop the stack
```

## Optional Redis

```sh
docker compose --profile redis up -d
```

## Extending

- Add software with `RUN` instructions under `dockerfile_inline` in
  `compose.yaml`, then rebuild using `make up`.
- Add optional containers as Compose services under a profile.
- Put application configuration in small files under `scripts/`.

## SRT policy

The sample policy is mounted read-only at `/etc/srt-settings.json`; it is not
automatically applied to OpenCode. To invoke the sandbox explicitly:

```sh
docker compose exec workbench \
  srt --settings /etc/srt-settings.json echo sandbox-ok
```

This policy is illustrative, not evidence that sandboxing is effective. SRT
uses bubblewrap, and its sandbox may not work under unprivileged Docker. Verify
the behavior in your environment before relying on it.

## State and portability

The manifest and scripts are the machine definition. Commit them to Git, keep
`workspace/` and the named `home` volume backed up according to your needs, and
transfer `.env` secrets securely. The workspace contents and `.env` are ignored
by Git.
