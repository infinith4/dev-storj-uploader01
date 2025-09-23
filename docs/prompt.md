# 要件

- devcontainer を作成(	mcr.microsoft.com/devcontainers/base ubuntu 24.04)
- rclone でのstorj のBucket作成
- bucket が存在しない場合は作成、存在する場合は何もしない
- bucket にrclone ファイルでアップロード
- bucket 内は YYYYMM形式のディレクトリを作成してファイルをアップロードする
- アップロード元のディレクトリはupload_target として、uploaded フォルダにアップロード後は移動する。

