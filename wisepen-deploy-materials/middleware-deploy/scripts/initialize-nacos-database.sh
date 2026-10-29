#!/usr/bin/env sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <env-file>" >&2
  exit 1
fi

env_file=$1
if [ ! -f "$env_file" ]; then
  echo "env file not found: $env_file" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$env_file"
set +a

: "${MYSQL_ROOT_PASSWORD:?请填写 MYSQL_ROOT_PASSWORD}"
: "${NACOS_DB_NAME:?请填写 NACOS_DB_NAME}"
: "${NACOS_DB_USERNAME:?请填写 NACOS_DB_USERNAME}"
: "${NACOS_DB_PASSWORD:?请填写 NACOS_DB_PASSWORD}"
: "${NACOS_USERNAME:?请填写 NACOS_USERNAME}"
: "${NACOS_PASSWORD:?请填写 NACOS_PASSWORD}"

case "$NACOS_DB_NAME" in
  *[!A-Za-z0-9_]*)
    echo "NACOS_DB_NAME 只能包含字母、数字和下划线" >&2
    exit 1
    ;;
esac

case "$NACOS_DB_USERNAME" in
  *[!A-Za-z0-9_]*)
    echo "NACOS_DB_USERNAME 只能包含字母、数字和下划线" >&2
    exit 1
    ;;
esac

case "$NACOS_USERNAME" in
  *[!A-Za-z0-9_]*)
    echo "NACOS_USERNAME 只能包含字母、数字和下划线" >&2
    exit 1
    ;;
esac

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
schema_file="$script_dir/../template-data/nacos-init-database/nacos-schema.sql"
if [ ! -f "$schema_file" ]; then
  echo "Nacos schema not found: $schema_file" >&2
  exit 1
fi

attempt=0
until docker exec -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql \
  mysqladmin ping -h 127.0.0.1 -uroot --silent >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 60 ]; then
    echo "MySQL did not become ready in time" >&2
    exit 1
  fi
  sleep 2
done

escaped_password=$(printf '%s' "$NACOS_DB_PASSWORD" | sed "s/'/''/g")

docker exec -i -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql mysql -uroot <<SQL
CREATE DATABASE IF NOT EXISTS \`$NACOS_DB_NAME\`
  DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER IF NOT EXISTS '$NACOS_DB_USERNAME'@'%' IDENTIFIED BY '$escaped_password';
ALTER USER '$NACOS_DB_USERNAME'@'%' IDENTIFIED BY '$escaped_password';
GRANT ALL PRIVILEGES ON \`$NACOS_DB_NAME\`.* TO '$NACOS_DB_USERNAME'@'%';
FLUSH PRIVILEGES;
SQL

schema_exists=$(docker exec -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql \
  mysql -N -s -uroot -e \
  "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$NACOS_DB_NAME' AND table_name = 'config_info';")

if [ "$schema_exists" = "0" ]; then
  docker exec -i -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql \
    mysql -uroot "$NACOS_DB_NAME" < "$schema_file"
  echo "Nacos schema imported: $NACOS_DB_NAME"
else
  echo "Nacos schema already exists; import skipped: $NACOS_DB_NAME"
fi

# Nacos 2.3.2 使用 BCrypt 保存控制台/API 登录密码。
# 通过一次性工具容器从明文 NACOS_PASSWORD 生成 cost=10 的 Hash
nacos_password_hash=$(
  printf '%s\n' "$NACOS_PASSWORD" |
    docker run --rm -i httpd:2.4.63-alpine \
      htpasswd -niBC 10 "$NACOS_USERNAME" |
    cut -d: -f2- |
    tr -d '\r\n'
)

case "$nacos_password_hash" in
  '$2a$'*|'$2b$'*|'$2y$'*) ;;
  *)
    echo "failed to generate Nacos BCrypt password hash" >&2
    exit 1
    ;;
esac

escaped_nacos_password_hash=$(printf '%s' "$nacos_password_hash" | sed "s/'/''/g")

remove_default_user_sql=""
if [ "$NACOS_USERNAME" != "nacos" ]; then
  remove_default_user_sql="DELETE FROM roles WHERE username = 'nacos'; DELETE FROM users WHERE username = 'nacos';"
fi

docker exec -i -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql \
  mysql -uroot "$NACOS_DB_NAME" <<SQL
INSERT INTO users (username, password, enabled)
VALUES ('$NACOS_USERNAME', '$escaped_nacos_password_hash', TRUE)
ON DUPLICATE KEY UPDATE password = VALUES(password), enabled = VALUES(enabled);

INSERT IGNORE INTO roles (username, role)
VALUES ('$NACOS_USERNAME', 'ROLE_ADMIN');

$remove_default_user_sql
SQL

unset nacos_password_hash escaped_nacos_password_hash

echo "Nacos login account updated: $NACOS_USERNAME"
echo "Nacos database ready: $NACOS_DB_NAME"
