# Storj Uploader Frontend

React + TypeScript + Tailwind CSS で構築されたStorjアップローダーのフロントエンドアプリケーションです。

## 機能

- **📱 スマホ完全対応** - レスポンシブデザインでモバイル・タブレット・デスクトップに最適化
- **🎯 Drag & Drop対応** - ファイルをドラッグ&ドロップで簡単アップロード
- **🖼️ 画像ファイル専用アップロード** - HEIC、JPEG、PNG、WebP等に対応
- **📹 動画ファイルアップロード** - MP4、MOV、AVI、MKV等に対応
- **📁 汎用ファイルアップロード** - すべてのファイル形式に対応
- **📊 リアルタイムステータス** - アップロード進行状況とシステム状態の確認
- **🔄 バッチアップロード** - 複数ファイルの一括アップロード機能

## 技術スタック

- **React 18** - モダンなUI構築
- **TypeScript** - 型安全な開発
- **Tailwind CSS** - ユーティリティファーストCSS
- **React Dropzone** - Drag & Drop機能
- **Axios** - HTTP通信
- **Lucide React** - アイコンライブラリ

## 画面構成

### 1. 画像アップロードタブ
- 画像ファイル専用（HEIC、JPEG、PNG、WebP、BMP、TIFF）
- 画像プレビュー機能
- 最大20ファイルまでの一括アップロード

### 2. 動画アップロードタブ
- 動画ファイル専用（MP4、MOV、AVI、MKV、WMV、FLV、WebM）
- ファイル情報表示
- 最大10ファイルまでの一括アップロード

### 3. ファイルアップロードタブ
- すべてのファイル形式に対応
- 汎用ファイルアップロード
- 最大15ファイルまでの一括アップロード

### 4. システムステータスタブ
- APIサーバーの状態確認
- Storj Container Appの状態確認
- 手動・非同期アップロード実行
- ファイル数統計情報

## スマホ対応機能

- **タッチフレンドリー** - 44px以上のタッチターゲット
- **レスポンシブグリッド** - 画面サイズに応じた最適なレイアウト
- **モバイルナビゲーション** - スマホでも使いやすいタブ切り替え
- **タッチジェスチャー** - スワイプ・タップ操作に最適化
- **高密度ディスプレイ対応** - Retinaディスプレイ等での高画質表示

## セットアップ

### 1. 依存関係インストール
```bash
cd storj_uploader_frontend_container_app
npm install
```

### 2. 環境設定
```bash
# .env ファイルでAPIエンドポイントを設定
REACT_APP_API_URL=http://localhost:8010
```

### 3. 開発サーバー起動
```bash
npm start
```
http://localhost:3000 でアクセス可能（開発環境）

### 4. プロダクション用ビルド
```bash
npm run build
```

## Docker デプロイ

### 単体起動
```bash
docker build -t storj-uploader-frontend .
docker run -p 9010:80 storj-uploader-frontend
```

### Docker Compose（フロントエンド + バックエンド）
```bash
docker compose down
docker rmi storj_uploader_frontend_container_app-backend
docker rmi storj_uploader_frontend_container_app-frontend
docker-compose up --build
```

アクセス先:
- **フロントエンド**: http://localhost:9010
- **バックエンドAPI**: http://localhost:8010

## API連携

バックエンド（storj_uploader_backend_api_container_app）との連携：

### 使用APIエンドポイント
- `POST /upload` - 画像ファイル複数アップロード
- `POST /upload/single` - 画像ファイル単一アップロード
- `POST /upload/files` - 汎用ファイル複数アップロード
- `POST /upload/files/single` - 汎用ファイル単一アップロード
- `GET /health` - ヘルスチェック
- `GET /status` - システムステータス取得
- `POST /trigger-upload` - 手動Storjアップロード実行
- `POST /trigger-upload-async` - 非同期Storjアップロード実行

## UI/UX特徴

### アップロード体験
- **視覚的フィードバック** - ドラッグ中の色変化とアニメーション
- **プログレス表示** - リアルタイムアップロード進行状況
- **エラーハンドリング** - 分かりやすいエラーメッセージ
- **成功通知** - アップロード完了の明確な表示

### アクセシビリティ
- **キーボード操作** - タブ・エンター・スペースキー対応
- **フォーカス表示** - 明確なフォーカスリング
- **スクリーンリーダー対応** - セマンティックHTML
- **色覚対応** - 色以外でも状態を判別可能

### パフォーマンス
- **軽量バンドル** - Tree Shaking による最適化
- **画像プレビュー** - 効率的なObjectURL使用
- **メモリ管理** - 適切なクリーンアップ処理
- **非同期処理** - ユーザー体験を妨げない設計

## 開発

### ディレクトリ構造
```
src/
├── components/          # Reactコンポーネント
│   ├── FileDropzone.tsx # Drag & Dropコンポーネント
│   ├── FilePreview.tsx  # ファイルプレビュー
│   ├── UploaderTab.tsx  # アップロードタブ
│   └── SystemStatus.tsx # ステータス表示
├── types.ts            # TypeScript型定義
├── api.ts              # API通信
├── App.tsx             # メインアプリケーション
├── index.tsx           # エントリーポイント
└── index.css           # スタイル定義
```

### カスタマイズ

#### テーマカスタマイズ
`tailwind.config.js` でカラーパレット・スペーシング等を変更可能

#### API設定
`.env` ファイルでバックエンドエンドポイントを変更

#### アップロード制限
各コンポーネントの `maxFiles` prop で最大ファイル数を調整

## トラブルシューティング

### よくある問題

1. **CORS エラー**
   ```bash
   # バックエンドのCORS設定を確認
   # プロキシ設定でAPIアクセス
   ```

2. **大きなファイルのアップロードエラー**
   ```bash
   # nginx.conf の client_max_body_size を調整
   # バックエンドの MAX_FILE_SIZE を確認
   ```

3. **スマホでタッチ操作が効かない**
   ```css
   /* CSS の touch-action を確認 */
   touch-action: manipulation;
   ```

## ブラウザ対応

- **Chrome** 88+
- **Firefox** 85+
- **Safari** 14+
- **Edge** 88+
- **iOS Safari** 14+
- **Android Chrome** 88+

## ライセンス

MIT License