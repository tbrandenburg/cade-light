# Repository Guide

## Purpose

CADE Light is a small Docker Compose development workbench. It brings
code-server, JupyterLab, and Node-RED together in a shared workspace, with
OpenCode and the optional SRT confinement setup available from the terminal.
The stack is managed directly with Docker Compose; it does not require a Coder
control plane or Terraform.

## Make targets

| Target | Purpose |
| --- | --- |
| `make help` | Print the available convenience commands. |
| `make init` | Create `.env` from `.env.example` if needed, create `workspace/`, and remind you to review placeholder secrets. |
| `make build` | Build the workbench image. |
| `make up` | Build and start the default Compose stack in the background. |
| `make down` | Stop the Compose stack without removing persistent volumes. |
| `make logs` | Follow workbench logs. |
| `make ps` | Show Compose service status. |
| `make exec` | Open a Bash shell in the workbench container. |
| `make config` | Validate the default merged Compose configuration. |
| `make config-srt` | Validate the Compose configuration with the opt-in SRT overlay. |
| `make up-srt` | Build and start the stack with the SRT overlay. |
| `make verify-srt` | Run the SRT sandbox enforcement check in the workbench. |

The SRT targets use host-dependent security profiles. Review `docs/SRT.md`
before using them.
