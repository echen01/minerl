# syntax=docker/dockerfile:1.7

FROM eclipse-temurin:8-jdk-jammy AS java8

# Official uv image with Python and uv pre-installed.
FROM ghcr.io/astral-sh/uv:python3.12-trixie-slim

ENV DEBIAN_FRONTEND=noninteractive \
    JAVA_HOME=/opt/java/openjdk \
    LIBGL_ALWAYS_SOFTWARE=1 \
    MINERL_TMP_INSTANCES=1 \
    PATH="/app/.venv/bin:/opt/java/openjdk/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_NO_DEV=1 \
    UV_PYTHON_DOWNLOADS=0 \
    UV_TOOL_BIN_DIR=/usr/local/bin \
    VIRTUAL_ENV=/app/.venv

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN groupadd --system --gid 999 nonroot \
 && useradd --system --gid 999 --uid 999 --create-home nonroot

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bash \
        build-essential \
        bzip2 \
        ca-certificates \
        curl \
        git \
        gzip \
        libasound2t64 \
        libcurl4t64 \
        libgl1 \
        libgl1-mesa-dri \
        libglx-mesa0 \
        libglib2.0-0t64 \
        libnss3 \
        libuuid1 \
        libx11-6 \
        libxcursor1 \
        libxext6 \
        libxi6 \
        libxinerama1 \
        libxrandr2 \
        libxrender1 \
        libxss1 \
        libxtst6 \
        libxxf86vm1 \
        patch \
        tar \
        unzip \
        xauth \
        xvfb \
        xz-utils \
        zip \
        zstd && \
    rm -rf /var/lib/apt/lists/*

COPY --from=java8 /opt/java/openjdk /opt/java/openjdk

WORKDIR /app

# Install third-party dependencies first so Docker can reuse this layer when
# only project source changes.
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project

# Install MineRL itself after source is available; this runs the MCP build hook.
COPY . /app
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=cache,target=/root/.gradle \
    MINERL_BUILD_MCP=1 uv sync --locked --no-editable && \
    chmod 755 /app/docker/minerl-entrypoint.sh && \
    chown -R nonroot:nonroot /app /home/nonroot

ENTRYPOINT ["/app/docker/minerl-entrypoint.sh"]
USER nonroot

CMD ["python", "-c", "import minerl; print('MineRL container ready')"]
