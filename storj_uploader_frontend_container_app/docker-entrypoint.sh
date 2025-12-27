#!/bin/sh
set -e

# デフォルト値を設定
BACKEND_URL=${BACKEND_URL:-http://localhost:8010}

echo "Configuring nginx with BACKEND_URL=${BACKEND_URL}"

# nginx設定ファイルを環境変数で置換
envsubst '${BACKEND_URL}' < /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d/default.conf

echo "nginx configuration:"
cat /etc/nginx/conf.d/default.conf

# nginxを起動
exec nginx -g 'daemon off;'
