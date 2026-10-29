#!/usr/bin/env sh
set -eu

if [ "$#" -gt 0 ]; then
  env_file=$1
  if [ ! -f "$env_file" ]; then
    echo "env file not found: $env_file" >&2
    exit 1
  fi
  set -a
  # shellcheck disable=SC1090
  . "$env_file"
  set +a
fi

network_name=${WISEPEN_NETWORK_NAME:-wisepen-net}
network_subnet=${WISEPEN_NETWORK_SUBNET:-}

if docker network inspect "$network_name" >/dev/null 2>&1; then
  echo "network already exists: $network_name"
  exit 0
fi

if [ -n "$network_subnet" ]; then
  docker network create --driver bridge --subnet "$network_subnet" "$network_name"
else
  docker network create --driver bridge "$network_name"
fi

echo "network created: $network_name"
