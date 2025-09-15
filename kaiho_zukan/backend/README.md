# 解法図鑑 バックエンド（FastAPI）

学習用の問題・解説プラットフォームのバックエンドです。FastAPI + SQLAlchemy + MySQL を採用し、画像アップロード、問題/解説の「いいね」、AI による解説生成・誤り判定を提供します。

## 主な機能

- 認証（JWT）/ユーザー情報/学習カテゴリ設定
- 問題の作成・編集・削除、画像添付、選択肢、模範解答、解説（全体/選択肢別）
- いいね（問題・問題全体の解説）/ 回答履歴 / 振り返り（統計・履歴）
- ランキング（作問数/解説数/いいね/ポイント）
- AI 連携（任意）: 解説の自動生成、誤り判定（AI 二値判定 + 群衆フラグ）

## セットアップ

- 推奨: Docker / Docker Compose
- 代替: ローカル（Python + MySQL）

### 1) Docker（推奨）

- 事前準備: `.env` / `.env.db` / `mysql.env` を必要に応じて編集
- 起動: `docker compose up --build`
- アクセス: API `http://localhost:8000` / Docs `http://localhost:8000/docs` / phpMyAdmin `http://localhost:8080`
- 停止: `docker compose down`

ボリューム
- MySQL: `dbdata`
- アップロード画像: `api_uploads`（コンテナ内 `/data/uploads`）

### 2) ローカル実行

前提: Python 3.11+ / MySQL 8.x

1) `pip install -r requirements.txt`
2) 環境変数（例）
   - `DATABASE_URL=mysql+pymysql://app:app@127.0.0.1:3306/learn`
   - `JWT_SECRET=...`（必須）
   - `UPLOAD_DIR=./uploads`
   - `OPENAI_ENABLED=false` / `OPENAI_API_KEY=...` / `OPENAI_MODEL=gpt-4o-mini`
3) `uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload`

起動時に DB 接続確認・テーブル作成・スキーマ保証・カテゴリ初期投入が実行されます。

## 環境変数

- DB/認証: `DATABASE_URL`, `JWT_SECRET`, `JWT_EXPIRES_MIN`（既定 10080=7日）
- CORS/アップロード: `CORS_ALLOW_ALL`, `UPLOAD_DIR`（既定 `/data/uploads`、`/uploads` で配信）
- AI: `OPENAI_ENABLED`, `OPENAI_API_KEY`, `OPENAI_MODEL`

## API 概要

- 認証/ユーザー
  - `POST /auth/register` / `POST /auth/login`
  - `GET /me` / `POST /me/categories` / `PUT /me`
  - `GET /my/problems` / `GET /my/explanations/problems`
- カテゴリ
  - `GET /categories/tree`
- 問題
  - `POST /problems` / `PUT /problems/{pid}`（multipart）
  - `GET /problems/{pid}` / `GET /problems/for-explain` / `GET /problems/next`
  - `GET /problems/{pid}/explanations?sort=likes|recent|random`
  - `GET /problems/{pid}/my-explanations` / `DELETE /problems/{pid}/my-explanations`
  - `DELETE /problems/{pid}`
- 回答/いいね
  - `POST /problems/{pid}/answer`
  - `POST/DELETE /problems/{pid}/like`
  - `POST/DELETE /problems/{pid}/explanations/like`
- 解説
  - `GET /explanations/problem/{pid}` / `POST /explanations/problem/{pid}` / `PUT /explanations/{eid}`
  - `POST/DELETE /explanations/{eid}/like` / `POST/DELETE /explanations/{eid}/wrong-flags`
- 模範解答
  - `POST /problems/{pid}/model-answer` / `GET /problems/{pid}/model-answer` / `GET /problems/{pid}/model-answers`
- 振り返り
  - `GET /review/stats` / `GET /review/history` / `GET /review/item` / `POST /review/mark`
- ランキング
  - `GET /leaderboard?metric=created_problems|created_expl|likes_problems|likes_expl|points`

## 画像アップロード

- `POST /problems` / `PUT /problems/{pid}` で `images` を複数送信可
- 保存先: `UPLOAD_DIR`（既定 `/data/uploads`） → `/uploads` で配信

## AI メタ情報（解説レスポンス）

解説の配列要素には、環境が有効な場合に次のメタが付きます:
- `ai_is_wrong`, `ai_judge_score`, `ai_judge_reason`
- `wrong_flag_count`, `flagged_wrong`, `solvers_count`, `crowd_maybe_wrong`

## メモ

- 422 は簡略化して返却（バリデーションログあり）
- MySQL は `utf8mb4_0900_ai_ci`
- 問題削除時は関連レコード・画像削除を先に実施（`AiJudgement` も明示削除）
