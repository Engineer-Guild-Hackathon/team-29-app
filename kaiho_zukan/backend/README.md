# Kaiho Zukan Backend (FastAPI)

学習用の問題・解説プラットフォームのバックエンドです。FastAPI + SQLAlchemy + MySQL を使用しています。画像アップロード対応、解説・問題の「いいね」、AI による解説/模範解答の生成（任意）などを提供します。

## セットアップ

- 推奨: Docker / Docker Compose で起動
- 代替: ローカルの Python + MySQL

### 1) Docker で起動（推奨）

- 事前準備
  - `.env` / `.env.db` / `mysql.env` は同梱済み（必要に応じて編集）
- 起動
  - `docker compose up --build`
- アクセス
  - API: `http://localhost:8000`
  - 自動ドキュメント: `http://localhost:8000/docs`
  - phpMyAdmin: `http://localhost:8080`（サービス名 `pma`）。`MYSQL_USER`/`MYSQL_PASSWORD` または `root`/`MYSQL_ROOT_PASSWORD` でログイン可。
- 停止
  - `docker compose down`

データは以下のボリュームに永続化されます。
- MySQL: `dbdata`
- アップロード画像: `api_uploads`（コンテナ内の `/data/uploads`）

### 2) ローカル実行（Python + MySQL）

前提:
- Python 3.11 以上
- MySQL 8.x

手順:
- 依存インストール: `pip install -r requirements.txt`
- 環境変数を設定（例）:
  - `DATABASE_URL=mysql+pymysql://app:app@127.0.0.1:3306/learn`
  - `JWT_SECRET=...`（必須）
  - `UPLOAD_DIR=./uploads`（任意）
  - `OPENAI_ENABLED=false`（任意）
- 実行: `uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload`

起動時に DB 接続確認・テーブル作成・カテゴリのシードを自動実行します。

## 環境変数

`.env` / `.env.db` / `mysql.env` を参照。

- DB / 認証
  - `DATABASE_URL`: SQLAlchemy 形式の接続文字列（例: `mysql+pymysql://app:app@db:3306/learn`）
  - `JWT_SECRET`: JWT 署名鍵（必須）
  - `JWT_EXPIRES_MIN`: アクセストークンの有効分数（デフォルト 10080=7日）
- CORS/アップロード
  - `CORS_ALLOW_ALL`: `true` で全許可
  - `UPLOAD_DIR`: 画像保存先（デフォルト `/data/uploads`）。`/uploads` パスで配信されます。
- AI（任意）
  - `OPENAI_ENABLED`: `true` で AI 生成を有効化
  - `OPENAI_API_KEY`: OpenAI API Key
  - `OPENAI_MODEL`: 例 `gpt-4o-mini`

## 主なエンドポイント

- 認証
  - `POST /auth/register`（username/password/nickname）
  - `POST /auth/login`
  - `GET /me`
  - `POST /me/categories`（ユーザーの学習カテゴリ設定）
- カテゴリ
  - `GET /categories/tree`（親→子→孫）
- 問題
  - `POST /problems`（multipart、画像/選択肢/解説/模範解答 対応）
  - `PUT /problems/{pid}`（multipart、同上）
  - `GET /problems/{pid}`（詳細）
  - `GET /problems/for-explain`（解説作成対象の一覧）
  - `GET /problems/next`（出題）
  - `DELETE /problems/{pid}`（作成者のみ）
- 回答 / いいね
  - `POST /problems/{pid}/answer`（選択 or 記述、正誤オプション）
  - `POST /problems/{pid}/like` / `DELETE /problems/{pid}/like`
  - `POST /problems/{pid}/explanations/like` / `DELETE /problems/{pid}/explanations/like`
- 解説
  - `GET /problems/{pid}/explanations?sort=likes`
  - `POST /problems/{pid}/explanations`
  - `DELETE /problems/{pid}/my-explanations`（自分の解説のみ一括削除）
- 模範解答（複数ユーザー/AI）
  - `POST /problems/{pid}/model-answer`（自身の模範解答を upsert、空文字で削除）
  - `GET /problems/{pid}/model-answer`（自分の）
  - `GET /problems/{pid}/model-answers`（全体一覧：ユーザー/AI）
- 振り返り（レビュー）
  - `GET /review/stats` / `GET /review/history` / `GET /review/item`
  - `POST /review/mark`（正誤手動記録）

## 画像アップロード

- `POST /problems`/`PUT /problems/{pid}` の multipart で `images` を複数送信可
- 保存先: `UPLOAD_DIR`（既定 `/data/uploads`）。`/uploads` で配信

## メモ

- 例外ログ: バリデーションエラーは 422 の詳細をログ出力
- 文字コード: MySQL は `utf8mb4_0900_ai_ci` を使用（接続ごとに `SET NAMES` 実行）
- 参照整合性: 問題削除時は関連レコード・画像ファイルを先に削除
