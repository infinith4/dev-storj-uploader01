#!/bin/bash
set -e

echo "Initializing Storj Uploader container..."

# rclone設定ディレクトリを作成
mkdir -p /root/.config/rclone

# RCLONE_CONFIG環境変数からrclone.confを生成
if [ -n "$RCLONE_CONFIG" ]; then
    RCLONE_CONFIG_PATH="/root/.config/rclone/rclone.conf"
    is_content=0
    if printf '%s' "$RCLONE_CONFIG" | grep -q $'\n'; then
        is_content=1
    fi
    if printf '%s' "$RCLONE_CONFIG" | grep -qE '^\[.+\]|type =|access_grant|satellite_address'; then
        is_content=1
    fi

    if [ "$is_content" -eq 1 ]; then
        echo "Writing rclone configuration from RCLONE_CONFIG content..."
        printf '%s' "$RCLONE_CONFIG" > "$RCLONE_CONFIG_PATH"
        # Unset RCLONE_CONFIG so rclone uses the default path
        unset RCLONE_CONFIG
        echo "✓ rclone.conf created successfully at $RCLONE_CONFIG_PATH"
    elif [ -f "$RCLONE_CONFIG" ]; then
        echo "Using rclone configuration file from RCLONE_CONFIG path: $RCLONE_CONFIG"
    else
        echo "Writing rclone configuration from RCLONE_CONFIG content..."
        printf '%s' "$RCLONE_CONFIG" > "$RCLONE_CONFIG_PATH"
        # Unset RCLONE_CONFIG so rclone uses the default path
        unset RCLONE_CONFIG
        echo "✓ rclone.conf created successfully at $RCLONE_CONFIG_PATH (RCLONE_CONFIG treated as content)"
    fi

    # 設定を検証（センシティブ情報を隠す）
    echo "Verifying rclone configuration..."
    if rclone config file; then
        echo "✓ rclone configuration is valid"
    else
        echo "✗ Warning: rclone configuration may have issues"
    fi
else
    echo "⚠ Warning: RCLONE_CONFIG environment variable not set"
    echo "  Using default or existing rclone configuration"
fi

# Azure Blob Storage設定確認
if [ -n "$AZURE_STORAGE_ACCOUNT_NAME" ]; then
    echo "✓ Azure Blob Storage configured: $AZURE_STORAGE_ACCOUNT_NAME"
else
    echo "⚠ Azure Blob Storage not configured (will use local filesystem)"
fi

# アプリケーションを起動
echo "Starting Storj Uploader application..."
exec python3 storj_uploader.py
