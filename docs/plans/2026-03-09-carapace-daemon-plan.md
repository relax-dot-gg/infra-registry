# Carapace Queue Daemon Deployment Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a managed Carapace queue daemon container to cyberstorm-citadel (9157ddeb) via infra-registry.

**Architecture:** Extend the host docker-compose template with a `carapace` service that uses the published image, connects to the existing Redis and Gitea on citadel, and runs the queue daemon on a 60s polling interval. Self-deploy will render and start it.

**Tech Stack:** Docker Compose (templated via Jinja), GitOps self-deploy scripts, Bitwarden for secrets, Gitea.

---

### Task 1: Review current host config and secrets references

**Files:**
- Read: `hosts/9157ddeb-cb6d-4d55-8252-9db358f5d932/docker-compose.yml.j2`
- Read: `hosts/9157ddeb-cb6d-4d55-8252-9db358f5d932/manifest.yml`
- Read: `docs/plans/2026-03-09-carapace-daemon-design.md`

**Step 1:** Open the compose template and note existing secrets/redis variables.
**Step 2:** Confirm manifest service list and host metadata.
**Step 3:** Ensure design doc assumptions still hold (image tag, secret keys available).

### Task 2: Add carapace service entry to host manifest

**Files:**
- Modify: `hosts/9157ddeb-cb6d-4d55-8252-9db358f5d932/manifest.yml`

**Step 1:** Add `carapace` to the `services:` list for host `9157ddeb-cb6d-4d55-8252-9db358f5d932` (keep YAML formatting).

### Task 3: Add carapace service to docker-compose template

**Files:**
- Modify: `hosts/9157ddeb-cb6d-4d55-8252-9db358f5d932/docker-compose.yml.j2`

**Step 1:** Insert a `carapace` service block near related app services.
**Step 2:** Set image `ghcr.io/cyberstorm-dev/carapace:latest`.
**Step 3:** Set command `carapace queue --daemon --poll-interval 60`.
**Step 4:** Set env vars:
- `REDIS_URL=redis://:{{ _9157ddeb_redis_password }}@citadel:6379/0`
- `GITEA_URL=http://100.73.228.90:3000`
- `GITEA_TOKEN={{ _9157ddeb_gitea_token }}`
- `GITEA_REPO=openclaw/nisto-home`
- `POLL_INTERVAL=60`
**Step 5:** Add `extra_hosts` entry mapping `citadel:100.73.228.90` to satisfy Redis URL host requirement.
**Step 6:** Add `restart: always` and `depends_on: [redis]`.

### Task 4: Validate template rendering

**Files:**
- Use: `scripts/render_compose.py`

**Step 1:** Run `python3 scripts/render_compose.py --uuid 9157ddeb-cb6d-4d55-8252-9db358f5d932 --output /tmp/citadel-compose.yml`.
**Step 2:** Run `docker compose -f /tmp/citadel-compose.yml config >/tmp/citadel-compose.resolved.yml` to ensure syntax validity.

### Task 5: Commit and push

**Files:**
- All touched files

**Step 1:** `git status` to review changes.
**Step 2:** `git add docs/plans/2026-03-09-carapace-daemon-design.md docs/plans/2026-03-09-carapace-daemon-plan.md hosts/9157ddeb-cb6d-4d55-8252-9db358f5d932/manifest.yml hosts/9157ddeb-cb6d-4d55-8252-9db358f5d932/docker-compose.yml.j2`
**Step 3:** `git commit -m "feat: add carapace queue daemon on citadel"`
**Step 4:** Push a branch and open PR/merge per access level.

### Task 6: Deployment verification (post-merge)

**Files:**
- N/A (runtime checks)

**Step 1:** After CI/self-deploy, check on `cyberstorm-citadel` that the container is running (`docker ps | grep carapace`).
**Step 2:** Inspect logs `docker logs carapace` to confirm queue polling without auth/redis errors.
**Step 3:** If possible, check Redis key `carapace:queue:openclaw/nisto-home` is populated.
**Step 4:** Close Gitea issue #281 once deployment verified.
