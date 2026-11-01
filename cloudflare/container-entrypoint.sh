#!/bin/sh
set -eu

: "${R2_ACCOUNT_ID:?Set R2_ACCOUNT_ID in Worker secrets/vars}"
: "${R2_BUCKET_NAME:?Set R2_BUCKET_NAME in Worker vars}"
: "${AWS_ACCESS_KEY_ID:?Set AWS_ACCESS_KEY_ID in Worker secrets}"
: "${AWS_SECRET_ACCESS_KEY:?Set AWS_SECRET_ACCESS_KEY in Worker secrets}"

DATA_DIR=/mnt/nameless-data
mkdir -p "$DATA_DIR"

if ! mountpoint -q "$DATA_DIR"; then
  /usr/local/bin/tigrisfs \
    --endpoint "https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com" \
    --region auto \
    -o allow_other,uid=33,gid=33 \
    -f "$R2_BUCKET_NAME" "$DATA_DIR" &
  FUSE_PID=$!
  attempt=0
  until mountpoint -q "$DATA_DIR"; do
    if ! kill -0 "$FUSE_PID" 2>/dev/null; then
      echo "R2 filesystem exited before mounting" >&2
      exit 1
    fi
    attempt=$((attempt + 1))
    if [ "$attempt" -ge 45 ]; then
      echo "Timed out mounting the NamelessMC R2 bucket" >&2
      exit 1
    fi
    sleep 1
  done
fi

mkdir -p "$DATA_DIR/config" "$DATA_DIR/uploads" "$DATA_DIR/sessions"

# Seed the persistent uploads bucket once with the fork's bundled defaults.
if [ -z "$(find "$DATA_DIR/uploads" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
  cp -a /var/www/html/uploads/. "$DATA_DIR/uploads/"
fi

# Keep user-generated content, the installed configuration and PHP sessions
# outside the disposable container filesystem.
if [ -d /var/www/html/uploads ] && [ ! -L /var/www/html/uploads ]; then
  rm -rf /var/www/html/uploads
fi
ln -sfn "$DATA_DIR/uploads" /var/www/html/uploads

if [ -e /var/www/html/core/config.php ] && [ ! -L /var/www/html/core/config.php ]; then
  cp -n /var/www/html/core/config.php "$DATA_DIR/config/config.php" || true
  rm -f /var/www/html/core/config.php
fi
ln -sfn "$DATA_DIR/config/config.php" /var/www/html/core/config.php

chown -R www-data:www-data /var/www/html/cache 2>/dev/null || true
cat > /usr/local/etc/php/conf.d/zz-nameless-cloudflare.ini <<EOF
session.save_path = "$DATA_DIR/sessions"
upload_max_filesize = 64M
post_max_size = 64M
max_execution_time = 300
max_input_time = 300
memory_limit = 512M
EOF

exec "$@"
