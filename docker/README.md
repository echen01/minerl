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

## Push to a server or registry

```bash
docker tag minerl:dev registry.example.com/minerl:dev
docker push registry.example.com/minerl:dev
```

On a single server without a registry:

```bash
docker save minerl:dev | gzip > minerl-dev.tar.gz
scp minerl-dev.tar.gz server:
ssh server 'gunzip -c minerl-dev.tar.gz | docker load'
```

## SLURM clusters

Most SLURM clusters do not allow Docker directly. They usually provide
Apptainer/Singularity. Build with Docker, push to a registry, then run via
Apptainer:

```bash
apptainer pull minerl-dev.sif docker://registry.example.com/minerl:dev
```

Minimal array job sketch:

```bash
#!/bin/bash
#SBATCH --job-name=minerl-collect
#SBATCH --array=0-31
#SBATCH --cpus-per-task=4
#SBATCH --mem=12G
#SBATCH --time=04:00:00

set -euo pipefail

OUT=/scratch/$USER/minerl-runs/${SLURM_JOB_ID}/${SLURM_ARRAY_TASK_ID}
mkdir -p "$OUT"

apptainer exec \
  --bind /scratch:/scratch \
  --env MALMO_MINECRAFT_OUTPUT_LOGDIR="$OUT/logs" \
  --env MINERL_STATUS_DIR="$OUT/performance" \
  --env MINERL_WATCHERS_DIR="$OUT/watchers" \
  minerl-dev.sif \
  python experiments/collect.py \
    --worker-id "$SLURM_ARRAY_TASK_ID" \
    --out "$OUT"
```

For GPU training jobs, ask the cluster docs whether to use Docker
`--gpus all` or Apptainer `--nv`. This base image does not install PyTorch or
CUDA; add those in a derived training image once you know the cluster CUDA
stack.
