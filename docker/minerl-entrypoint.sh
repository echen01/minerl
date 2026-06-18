#!/usr/bin/env bash
set -e

export LIBGL_ALWAYS_SOFTWARE="${LIBGL_ALWAYS_SOFTWARE:-1}"

case "${1:-}" in
    bash|/bin/bash|sh|/bin/sh)
        exec "$@"
        ;;
esac

if [ -z "${DISPLAY:-}" ]; then
    exec xvfb-run -a -s "-screen 0 ${XVFB_WHD:-1024x768x24}" "$@"
fi

exec "$@"
