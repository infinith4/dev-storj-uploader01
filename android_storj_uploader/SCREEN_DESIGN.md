# 画面設計書

## 画面構成

このアプリは単一画面（MainActivity）で構成されており、画面遷移はありません。すべての機能が1つの画面に統合されています。

## メイン画面（MainActivity）

### 画面レイアウト

```
┌─────────────────────────────────────────┐
│                                         │
│  Storj Photo Uploader (git-hash)       │
│                                         │
│  ┌──────────────────┐  ┌────────┐     │
│  │ Bearer Token     │  │  Save  │     │
│  │ **************** │  └────────┘     │
│  └──────────────────┘                  │
│                                         │
│  Status: Ready - Auto-upload active    │
│                                         │
│  ┌────────────────────────────────┐   │
│  │████████████░░░░░░░░░░░░░░░░░░░│   │ ← プログレスバー
│  └────────────────────────────────┘   │
│  15 / 30 photos uploaded               │
│                                         │
│  ┌────────────────────────────────┐   │
│  │    Upload Photos Now           │   │
│  └────────────────────────────────┘   │
│                                         │
├─────────────────────────────────────────┤ ← 区切り線
│                                         │
│  Upload History                        │
│                                         │
│  ┌───────────────────────────────┐    │
│  │ ┌───┐  image_001.jpg          │    │
│  │ │img│  2024-11-09 10:30       │    │
│  │ └───┘  Success ✓              │    │
│  └───────────────────────────────┘    │
│  ┌───────────────────────────────┐    │
│  │ ┌───┐  image_002.jpg          │    │
│  │ │img│  2024-11-09 10:29       │    │
│  │ └───┘  Success ✓              │    │
│  └───────────────────────────────┘    │
│  ┌───────────────────────────────┐    │
│  │ ┌───┐  image_003.jpg          │    │
│  │ │img│  2024-11-09 10:28       │    │
│  │ └───┘  Failed ✗               │    │
│  └───────────────────────────────┘    │
│  ...                                   │
└─────────────────────────────────────────┘
```

### 画面構成要素

#### 上部エリア（1/4画面）- アップロード制御

| 要素 | 説明 |
|------|------|
| **タイトル** | `Storj Photo Uploader (git-hash)` - アプリ名とコミットハッシュ |
| **Bearer Token入力** | パスワード形式のテキストフィールド |
| **Saveボタン** | Tokenを保存し、自動アップロードを有効化 |
| **ステータステキスト** | 現在の状態を表示 |
| **プログレスバー** | アップロード進捗（0-100%） |
| **プログレステキスト** | `X / Y photos uploaded` |
| **Upload Photos Nowボタン** | 手動アップロードを実行 |

#### 下部エリア（3/4画面）- アップロード履歴

| 要素 | 説明 |
|------|------|
| **Upload Historyタイトル** | セクションタイトル |
| **RecyclerView** | スクロール可能なリスト表示 |
| **SwipeRefreshLayout** | 下にスワイプで履歴を更新 |

#### 履歴アイテム（item_upload_history.xml）

各履歴アイテムは以下の情報を表示：

```
┌─────────────────────────────────────┐
│ ┌───────┐                           │
│ │       │  image_20241109_103045.jpg│
│ │ 80x80 │  2024-11-09 10:30:45      │
│ │ thumb │  Success                  │
│ └───────┘                           │
└─────────────────────────────────────┘
```

- **サムネイル**: 80x80pxの画像プレビュー
- **ファイル名**: 最大1行、超過時は省略
- **アップロード時刻**: YYYY-MM-DD HH:MM形式
- **ステータス**: Success（緑）/ Failed（赤）

## 状態遷移図

```mermaid
stateDiagram-v2
    [*] --> 未設定: アプリ起動
    未設定 --> Token保存済み: Bearer Token保存
    Token保存済み --> 権限要求中: 写真アクセス権限チェック
    権限要求中 --> 権限拒否: ユーザーが拒否
    権限要求中 --> 待機中: 権限許可
    権限拒否 --> 権限要求中: ユーザーが設定から許可
    待機中 --> アップロード中: "Upload Photos Now"タップ
    待機中 --> 自動アップロード中: 15分経過（バックグラウンド）
    アップロード中 --> アップロード完了: 成功
    アップロード中 --> アップロード失敗: エラー発生
    自動アップロード中 --> 待機中: 完了
    アップロード完了 --> 待機中: OK
    アップロード失敗 --> 待機中: OK

    note right of 未設定
        ステータス: "Please configure Bearer Token"
        Upload Nowボタン: 無効
    end note

    note right of 待機中
        ステータス: "Auto-upload active (every 15 min)"
        Upload Nowボタン: 有効
    end note

    note right of アップロード中
        プログレスバー表示
        Upload Nowボタン: 無効
    end note
```

## 機能フロー図

```mermaid
flowchart TD
    Start([アプリ起動]) --> LoadToken{Token<br/>保存済み?}
    LoadToken -->|No| ShowTokenInput[Token入力を促す]
    LoadToken -->|Yes| LoadTokenData[Tokenを読み込み]

    ShowTokenInput --> InputToken[ユーザーがToken入力]
    InputToken --> SaveToken[Saveボタンタップ]
    SaveToken --> StoreToken[SharedPreferencesに保存]

    LoadTokenData --> CheckPerm{写真アクセス<br/>権限あり?}
    StoreToken --> CheckPerm

    CheckPerm -->|No| RequestPerm[権限リクエスト]
    CheckPerm -->|Yes| SetupAutoUpload[自動アップロード設定]

    RequestPerm --> PermResult{権限<br/>許可?}
    PermResult -->|No| ShowPermError[エラー表示]
    PermResult -->|Yes| SetupAutoUpload

    SetupAutoUpload --> ScheduleWork[WorkManager<br/>15分周期設定]
    ScheduleWork --> Ready[待機状態]

    Ready --> ManualTrigger{Upload Nowボタン<br/>タップ?}
    Ready --> AutoTrigger{15分<br/>経過?}

    ManualTrigger -->|Yes| GetPhotos[最近24時間の写真取得]
    AutoTrigger -->|Yes| BgGetPhotos[バックグラウンドで<br/>写真取得]

    GetPhotos --> CheckPhotos{写真あり?}
    BgGetPhotos --> CheckPhotos

    CheckPhotos -->|No| NoPhotos[「写真なし」表示]
    CheckPhotos -->|Yes| BatchUpload[5枚ずつバッチアップロード]

    NoPhotos --> Ready

    BatchUpload --> ShowProgress[プログレス更新]
    ShowProgress --> UploadAPI[Storj API呼び出し]

    UploadAPI --> CheckResult{アップロード<br/>成功?}

    CheckResult -->|Yes| AddSuccess[履歴に成功記録]
    CheckResult -->|No| AddFailed[履歴に失敗記録]

    AddSuccess --> MoreBatch{次のバッチ<br/>あり?}
    AddFailed --> MoreBatch

    MoreBatch -->|Yes| BatchUpload
    MoreBatch -->|No| ShowResult[結果をToast表示]

    ShowResult --> UpdateHistory[履歴リスト更新]
    UpdateHistory --> Ready

    style Start fill:#e1f5ff
    style Ready fill:#c8e6c9
    style ShowProgress fill:#fff9c4
    style ShowResult fill:#f8bbd0
```

## ユーザーインタラクション

### 1. 初回起動フロー

```mermaid
sequenceDiagram
    participant User as ユーザー
    participant App as アプリ
    participant Storage as SharedPreferences
    participant System as Android System

    User->>App: アプリを起動
    App->>Storage: Bearer Token取得
    Storage-->>App: null（未設定）
    App->>User: "Please configure Bearer Token"

    User->>App: Bearer Token入力
    User->>App: Saveボタンタップ
    App->>Storage: Token保存
    Storage-->>App: 保存完了
    App->>User: "Token saved successfully"

    App->>System: 写真アクセス権限チェック
    System->>User: 権限リクエストダイアログ
    User->>System: 許可
    System-->>App: 権限付与

    App->>App: WorkManager設定（15分周期）
    App->>User: "Auto-upload active (every 15 min)"
```

### 2. 手動アップロードフロー

```mermaid
sequenceDiagram
    participant User as ユーザー
    participant UI as MainActivity
    participant Repo as PhotoRepository
    participant API as Storj API
    participant Storage as SharedPreferences

    User->>UI: "Upload Photos Now"タップ
    UI->>UI: ボタン無効化
    UI->>UI: プログレスバー表示

    UI->>Repo: getRecentPhotos(24時間)
    Repo->>Repo: MediaStoreから写真取得
    Repo-->>UI: 写真URIリスト（30枚）

    UI->>UI: 5枚ずつバッチ分割

    loop 各バッチ（6回）
        UI->>Repo: uploadPhotos(batch, token)
        Repo->>API: POST /upload（multipart）
        API-->>Repo: 200 OK
        Repo-->>UI: Success

        UI->>Storage: 履歴に追加
        UI->>UI: プログレス更新（17%→33%→50%...）
        UI->>UI: "5 / 30 photos uploaded"
    end

    UI->>UI: プログレスバー非表示
    UI->>UI: ボタン有効化
    UI->>User: "Uploaded 30 of 30 photos"
    UI->>UI: 履歴リスト更新
```

### 3. 自動アップロードフロー（バックグラウンド）

```mermaid
sequenceDiagram
    participant WM as WorkManager
    participant Worker as PhotoUploadWorker
    participant Repo as PhotoRepository
    participant API as Storj API
    participant Notif as Notification

    Note over WM: 15分経過
    WM->>Worker: 実行トリガー
    Worker->>Worker: Token取得
    Worker->>Repo: getRecentPhotos(24時間)
    Repo-->>Worker: 写真リスト

    alt 写真あり
        Worker->>Notif: "Uploading photos..."
        Worker->>Repo: uploadPhotos(photos, token)
        Repo->>API: POST /upload
        API-->>Repo: Success
        Repo-->>Worker: Success
        Worker->>Notif: "Photos uploaded successfully"
        Worker-->>WM: Result.success()
    else 写真なし
        Worker->>Notif: "No new photos to upload"
        Worker-->>WM: Result.success()
    end

    Note over WM: 次回実行を15分後に予約
```

## 画面コンポーネント詳細

### UI要素の状態

| 要素 | 初期状態 | Token保存後 | アップロード中 |
|------|----------|-------------|----------------|
| Token入力フィールド | 空 | 保存済みToken表示（*で隠す） | 編集不可 |
| Saveボタン | 有効 | 有効 | 無効 |
| Upload Nowボタン | 無効 | 有効 | 無効 |
| プログレスバー | 非表示 | 非表示 | 表示（0-100%） |
| プログレステキスト | 非表示 | 非表示 | 表示 |
| ステータステキスト | "Please configure Bearer Token" | "Auto-upload active (every 15 min)" | "Uploading photos..." |

### ステータスメッセージ一覧

| ステータス | 表示タイミング |
|-----------|----------------|
| `Please configure Bearer Token` | アプリ起動時（Token未設定） |
| `Token saved` | Token保存成功時 |
| `Permission granted` | 写真アクセス権限取得時 |
| `Permission denied - Cannot access photos` | 権限拒否時 |
| `Auto-upload active (every 15 min)` | 自動アップロード設定完了時 |
| `Ready - Auto-upload active` | 待機状態（Token設定済み） |
| `Uploading photos...` | アップロード開始時 |
| `Upload successful: X photos uploaded` | アップロード完了時 |
| `Upload failed` | アップロード失敗時 |
| `No recent photos to upload` | アップロード対象なし時 |
| `Error: [エラーメッセージ]` | 例外発生時 |

## データ永続化

### SharedPreferences

| キー | 値の型 | 説明 |
|------|--------|------|
| `bearer_token` | String | Storj API認証用Bearer Token |
| `upload_history` | JSON String | アップロード履歴（最大100件） |

### アップロード履歴のJSON形式

```json
[
  {
    "id": 1699500645000,
    "photoUri": "content://media/external/images/media/12345",
    "fileName": "IMG_20241109_103045.jpg",
    "uploadTime": 1699500645000,
    "status": "SUCCESS"
  },
  {
    "id": 1699500632000,
    "photoUri": "content://media/external/images/media/12344",
    "fileName": "IMG_20241109_103032.jpg",
    "uploadTime": 1699500632000,
    "status": "FAILED"
  }
]
```

## バックグラウンド処理

### WorkManager設定

- **実行間隔**: 15分（PeriodicWorkRequest）
- **制約**: ネットワーク接続必須
- **バックオフポリシー**: LINEAR（最小間隔）
- **ユニーク性**: `PhotoUploadWork`（KEEP - 既存のワークを保持）

### Worker実行条件

1. ✅ 15分以上経過
2. ✅ ネットワーク接続あり
3. ✅ Bearer Token設定済み
4. ✅ 写真アクセス権限あり

## エラーハンドリング

| エラー種類 | 処理 |
|-----------|------|
| Token未設定 | Upload Nowボタン無効化、メッセージ表示 |
| 権限拒否 | Toastでエラー表示、自動アップロード無効 |
| ネットワークエラー | リトライ（WorkManager自動）、履歴に失敗記録 |
| API 4xx/5xxエラー | 履歴に失敗記録、Toast表示 |
| 例外発生 | ログ出力、Toast表示、履歴に失敗記録 |

## 画面サイズ対応

- **レイアウト**: LinearLayout（縦方向）
- **上部エリア**: layout_weight="1"（25%）
- **下部エリア**: layout_weight="3"（75%）
- **RecyclerView**: スクロール可能（全履歴表示）
- **アイテム**: Material CardView（elevation 4dp、corner radius 8dp）

## アクセシビリティ

- すべてのImageViewに`contentDescription`設定
- テキストサイズ: 12sp-20sp（読みやすいサイズ）
- タップ可能要素: 最小48dp
- カラーコントラスト: 成功（緑）/失敗（赤）で視覚的に区別

## まとめ

このアプリは**シングルアクティビティ**設計で、画面遷移はありません。すべての機能が1つの画面に統合され、以下の特徴があります：

- ✅ シンプルな操作フロー（Token設定→アップロード）
- ✅ 自動アップロード（15分周期のバックグラウンド処理）
- ✅ 手動アップロード（即座に実行）
- ✅ 視覚的なフィードバック（プログレスバー、ステータス）
- ✅ アップロード履歴の永続化と表示
- ✅ エラーハンドリングとリトライ機構
