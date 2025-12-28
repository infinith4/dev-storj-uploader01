#!/bin/sh
set -e

# デフォルト値を設定
BACKEND_URL=${BACKEND_URL:-http://localhost:8010}

echo "Configuring application with BACKEND_URL=${BACKEND_URL}"

# nginx設定ファイルを環境変数で置換
envsubst '${BACKEND_URL}' < /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d/default.conf

echo "nginx configuration:"
cat /etc/nginx/conf.d/default.conf

# env-config.jsを生成（Reactアプリが読み込むランタイム環境変数）
if [ -f /usr/share/nginx/html/env-config.js.template ]; then
  echo "Generating env-config.js with runtime environment variables"
  envsubst '${BACKEND_URL}' < /usr/share/nginx/html/env-config.js.template > /usr/share/nginx/html/env-config.js
  echo "Generated env-config.js:"
  cat /usr/share/nginx/html/env-config.js
else
  echo "Warning: env-config.js.template not found, creating default config"
  cat > /usr/share/nginx/html/env-config.js <<ENVEOF
window.ENV = {
  REACT_APP_API_URL: '${BACKEND_URL}'
};
ENVEOF
fi

# nginxを起動
exec nginx -g 'daemon off;'
