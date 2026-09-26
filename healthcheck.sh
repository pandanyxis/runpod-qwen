#!/usr/bin/env bash
set -e
curl --fail --silent http://127.0.0.1:8080/health >/dev/null
if [[ "${ENABLE_WEBUI:-true}" == "true" ]]; then
  curl --fail --silent http://127.0.0.1:3000/health >/dev/null
fi
