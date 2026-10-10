# Opt-in SRT / Bubblewrap containment

CADE Light installs `srt` by default but does **not** silently change Docker
confinement. The default container may prevent nested Linux user namespaces.
Use `compose.srt.yaml` only after reviewing the host-specific security impact.

## Provenance and trust boundary

Security profiles copied from [CADE seccomp](https://github.com/tbrandenburg/cade/blob/main/coder/security-profiles/seccomp-bwrap-userns.json)
and [CADE AppArmor](https://github.com/tbrandenburg/cade/blob/main/coder/security-profiles/apparmor-bwrap-workspace)
(Issues #23–#40, MIT licensed). CADE reported successful live SRT execution
and filesystem restriction checks in its environment. Only the AppArmor
profile name was changed to `cade-light-bwrap-workspace` (including peer rules),
so these projects do not overwrite each other's host profile on shared hosts.
**This does not prove compatibility with another host or SRT 0.0.79.**

The opt-in overlay changes three Docker security layers:
- scoped seccomp allowances for Bubblewrap's namespace and mount operations;
- a host-loaded, named AppArmor profile with Bubblewrap-specific allowances;
- `systempaths=unconfined`, disabling Docker's extra protected-path masking
  because nested procfs mounts otherwise fail. This is a **security trade-off**,
  mitigated in CADE by independent AppArmor denials for sensitive /proc and /sys
  paths. Review and test these on your kernel/AppArmor version.

Never replace these with `privileged:true`, `apparmor=unconfined`, or
`seccomp=unconfined`. Do not disable system-wide namespace restrictions.

## Host preparation (manual administrator action)

Requires a Linux Docker host with usable AppArmor and user namespace support.
The AppArmor profile cannot be activated from the application container.
It must be loaded on the actual Docker Engine host, and may require reloading
after reboot or when policies change.

```sh
components/workbench/security/load-apparmor.sh --dry-run
sudo components/workbench/security/load-apparmor.sh

docker compose -f compose.yaml -f compose.srt.yaml config --quiet
docker compose -f compose.yaml -f compose.srt.yaml up -d --build

# Tests: successful sandbox launch + read/write denials, not merely exit code
docker compose -f compose.yaml -f compose.srt.yaml exec workbench verify-srt
```

If the AppArmor profile is unavailable, Docker should fail container creation,
not silently fall back to its default profile.

## User policy and limitations

`config/srt-settings.json` is user-editable, mounted read-only at
`/etc/srt-settings.json`. Invoke explicitly:

```sh
docker compose -f compose.yaml -f compose.srt.yaml exec workbench \
  srt --settings /etc/srt-settings.json opencode
```

OpenCode, Jupyter, Node-RED and Node-RED agent nodes are **not automatically
sandboxed**. SRT 0.0.79 still mandatorily prevents writing project-local
`.claude/commands` and `.claude/agents` directories; workflows needing
those writes can fail. The `@tbrandenburg/node-red-agents` agent-server
node documents that its SRT execution mode is not functional.

`allowAllUnixSockets: false` is deliberate: the original CADE policy had
this set to true for its bridge design, but that permits overly broad socket
access in a general-purpose workbench. `enableWeakerNestedSandbox` is not
enabled by default: test the stricter mode first.

SRT filesystem restrictions do not make credentials passed in the shared
container's environment secret from a code-running agent. For agents that
execute untrusted content, use separate containers and scoped credentials.

## Troubleshooting

```sh
docker info --format '{{json .SecurityOptions}}'
cat /proc/sys/user/max_user_namespaces
test -r /proc/sys/kernel/unprivileged_userns_clone &&
  cat /proc/sys/kernel/unprivileged_userns_clone
test -r /proc/sys/kernel/apparmor_restrict_unprivileged_userns &&
  cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns
sudo aa-status | grep cade-light-bwrap-workspace
sudo journalctl -k | grep -E 'apparmor|DENIED|seccomp'
```

Do not apply global sysctl changes as an automatic fix. To return to standard
container confinement, start without `-f compose.srt.yaml`.
