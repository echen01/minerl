# Docker Workflow Notes

This image is meant to capture the MineRL repo, Python dependencies, Java 8,
and the generated MCP/Minecraft runtime.

## Local build

```bash
DOCKER_BUILDKIT=1 docker build -t minerl:dev .
```

The first build is slow because it clones MCP-Reborn and downloads Gradle and
Minecraft assets. Later builds should reuse Docker cache unless package source,
MCP scripts, or dependency files changed.

## Smoke test

```bash
docker run --rm minerl:dev
```

## Interactive shell

```bash
docker run --rm -it minerl:dev bash
```

The project and dependencies are already installed in `/app/.venv`. Do not
bind-mount the repository over `/app` unless you intentionally want to replace
the installed application and virtualenv.

For an image built before this entrypoint behavior, bypass the entrypoint:

```bash
docker run --rm -it --entrypoint bash minerl:dev
```

## Run a headless collection script

Bind-mount outputs instead of writing replay buffers inside the container:

```bash
mkdir -p runs
docker run --rm \
  -v "$PWD/runs:/runs" \
  minerl:dev \
  python experiments/collect.py --out /runs/worker-0
```

For multiple collectors, use one container per worker and give each worker a
separate output directory. Merge or sample from those files in a separate
training job.

The image starts commands under Xvfb automatically when `DISPLAY` is unset.
If you override the entrypoint, wrap MineRL commands manually with
`xvfb-run -a`.
