# Carapace Queue Daemon on cyberstorm-citadel (9157ddeb) — Design

**Context:** Deploy the Carapace queue daemon as a managed container on `cyberstorm-citadel` (UUID `9157ddeb-cb6d-4d55-8252-9db358f5d932`) via infra-registry GitOps. The daemon should poll Gitea and publish the ready queue into Redis.

**Assumptions / clarifications**
- Container image published from the merged PR is available at `ghcr.io/cyberstorm-dev/carapace:latest` (public pull). If the tag differs, adjust in implementation.
- Reuse existing host Redis (passworded) and Gitea token already present for woodpecker on the same host; no new secrets need to be created.
- DNS name `citadel` should resolve; add `extra_hosts` pointing to `100.73.228.90` if needed for the Redis URL requirement.

## Approaches considered
1) **Add a managed service to the per-host compose template (Recommended)** — Add a `carapace` service to `hosts/9157ddeb.../docker-compose.yml.j2` with restart policy, env vars, and command. Self-deploy will template and keep it running. Minimal surface area and consistent with existing GitOps flow.
2) Systemd/cron wrapper outside compose — More bespoke scripting, diverges from repo patterns, harder to maintain and secrets handling; rejected.
3) Separate worker host — Adds new host/config complexity and cross-host Redis access without benefit; rejected.

## Design (chosen approach)
- **Service definition:**
  - Image: `ghcr.io/cyberstorm-dev/carapace:latest`
  - Command: `carapace queue --daemon --poll-interval 60`
  - Restart policy: `always`
  - Depends on: `redis`
  - Extra hosts: map `citadel` → `100.73.228.90` to satisfy the required `REDIS_URL` host string.
- **Environment:**
  - `REDIS_URL=redis://:<_9157ddeb_redis_password>@citadel:6379/0`
  - `GITEA_URL=http://100.73.228.90:3000`
  - `GITEA_TOKEN={{ _9157ddeb_gitea_token }}` (reuse existing)
  - `GITEA_REPO=openclaw/nisto-home`
  - `POLL_INTERVAL=60`
- **Secrets:** No new secrets expected. Uses existing `_9157ddeb_redis_password` and `_9157ddeb_gitea_token` (already fetched by self-deploy via BWS projects `cyberstorm-infra` + `relaxgg-infra` per host metadata).
- **Manifest:** Add `carapace` to the host service list in `hosts/9157ddeb.../manifest.yml` for bookkeeping/validation.
- **Validation:** Use `scripts/render_compose.py --uuid 9157ddeb...` to confirm templating, and ensure `docker compose config` passes. Deployment handled by host self-deploy cron; manual `docker compose up -d` optional for fast start.

## Testing/verification plan
- Render compose locally and check service block.
- After push/PR merge, wait for self-deploy or trigger manually; verify container running on host and logs show queue polling without auth/redis errors.
- Confirm Redis key `carapace:queue:openclaw/nisto-home` populates (can be checked on host if needed) and no crashloop.
