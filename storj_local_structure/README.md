# Storj Local Structure Organizer

ローカルファイルを日付別フォルダ（YYYYMM形式）に整理し、Storjの構造と比較するDockerコンテナです。

## 機能

- **日付別整理**: ファイルの作成日時・更新日時で最も古い日付を基にYYYYMM形式のフォルダに移動
- **ファイル名解析**: ファイル名からの日付抽出もサポート（例：2024-09-26_14-30-00_file.jpg）
- **構造比較**: storj_mount_driveの仮想構造と比較してアップロード状況を確認
- **重複処理**: 同名ファイルがある場合は自動的に番号を付与

## セットアップ

### 1. コンテナの起動

```bash
cd storj_local_structure/
docker-compose up -d

# ログを確認
docker-compose logs file-organizer
```

### 2. ファイルの準備

整理したいファイルを`source_files/`ディレクトリに配置：

```bash
# 例：ファイルをコピー
cp /path/to/your/files/* source_files/
```

## 使用方法

### 基本コマンド

```bash
# ステータス確認
docker-compose exec file-organizer python file_organizer.py status

# ファイル整理実行
docker-compose exec file-organizer python file_organizer.py organize

# Storj構造との比較
docker-compose exec file-organizer python file_organizer.py compare
```

### プロファイルを使用した実行

```bash
# ファイル整理実行
docker-compose --profile organize up file-organizer-run

# 構造比較実行
docker-compose --profile compare up file-organizer-compare
```

## ディレクトリ構造

```
storj_local_structure/
├── source_files/           # 整理対象のファイルを配置
├── organized_files/        # 整理後のファイル（YYYYMM/形式）
│   ├── 202409/
│   ├── 202410/
│   └── ...
├── file_organizer.py       # メインスクリプト
├── docker-compose.yml      # Docker設定
├── Dockerfile
└── README.md
```

## 日付の決定方法

ファイルの日付は以下の優先順位で決定されます：

1. **ファイル名からの抽出**: `YYYY-MM-DD_HH-MM-SS`パターン
2. **ファイルシステム日付**: 作成日時と更新日時の古い方

## 構造比較機能

storj_mount_driveの仮想構造と比較して以下を確認できます：

- **共通フォルダ**: ローカルとStorj両方に存在
- **ローカル専用**: ローカルにのみ存在（未アップロード）
- **Storj専用**: Storjにのみ存在（ローカルにない）
- **ファイル一致率**: フォルダごとのファイル一致率

### 比較例

```bash
$ docker-compose exec file-organizer python file_organizer.py compare

Comparing local structure with Storj structure...

Folder comparison:
  Common folders: 3
  Local only: 1
  Storj only: 0
  Local only folders: ['202411']

  202409/:
    Matching files: 45
    Local only: 2
    Storj only: 0

  202410/:
    Matching files: 38
    Local only: 0
    Storj only: 3

Overall file comparison:
  Total matching files: 83
  Total local only files: 2
  Total Storj only files: 3
  Match percentage: 94.3%
```

## トラブルシューティング

### 権限エラー
```bash
# ディレクトリの権限を修正
sudo chown -R $USER:$USER source_files/ organized_files/
```

### Storj構造が見つからない
```bash
# storj_mount_driveを先に同期
cd ../storj_mount_drive/
docker-compose exec storj-virtual-drive python storj_virtual_drive.py sync
```

### ファイルが見つからない
```bash
# source_filesの内容を確認
ls -la source_files/

# コンテナ内の状況を確認
docker-compose exec file-organizer ls -la /app/source_files/
```

## 注意事項

- ファイル整理は移動操作です（元の場所からファイルが削除されます）
- 同名ファイルは自動的に番号が付与されます（例：file_1.jpg, file_2.jpg）
- 構造比較にはstorj_mount_driveの仮想構造が必要です
- 大量のファイルを処理する場合は時間がかかる場合があります

## 開発・カスタマイズ

### ローカル開発
```bash
# Python環境で直接実行
python file_organizer.py status

# 依存関係インストール
pip install -r requirements.txt
```

### 設定の変更
- `docker-compose.yml`: ボリュームマウントとコンテナ設定
- `file_organizer.py`: 日付抽出ロジックと整理機能