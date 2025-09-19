# Kaiho Zukan バックエンド (FastAPI)

## 概要
Kaiho Zukan は、学習者が問題を投稿・解き、解説や復習サイクルを共有できるプラットフォームです。このバックエンドは FastAPI をベースに、認証、問題管理、AI を活用した判定・解説補助、ランキングなどの機能を提供します。

## 主な機能
- JWT ベースのユーザー認証と権限管理
- 問題・選択肢・模範解答・画像アップロードの CRUD API
- 解説投稿、いいね、誤りフラグ付け、レビュー履歴の管理
- スペースドリピティションを意識した復習（/review 系エンドポイント）
- OpenAI API を用いた解説生成・判定（環境変数で有効化）
- まとめやランキング、プロフィール編集 API

## 技術スタック
- Python 3.11 / FastAPI / Uvicorn
- SQLAlchemy + MySQL 8.0 (utf8mb4_0900_ai_ci)
- Pydantic (v2) によるスキーマ定義
- PyJWT によるトークン発行
- Tesseract OCR（画像からの文字抽出を想定、Dockerfile で導入）
- OpenAI API（任意機能）

## ディレクトリ構成
- app/main.py : FastAPI アプリエントリーポイント（ルーター登録）
- app/core/ : 設定 (config.py)、DB セッション (db.py)、ロガー等
- app/models/ : SQLAlchemy モデル（ユーザー、問題、解説、AI 判定など）
- app/schemas/ : Pydantic スキーマ
- app/api/ : ルーター (auth.py, problems.py, 
eview.py など)
- app/security/ : パスワードハッシュ、JWT ヘルパー
- app/services/ : AI 判定ロジックなどのドメインサービス
- app/static/ : アイコン等の静的ファイル

## セットアップ手順
### 1. Docker Compose を利用する場合（推奨）
1. backend/.env, .env.db, mysql.env を編集し、必要に応じて値を変更します。
2. docker compose up --build を実行します。
3. 起動後のアクセス先:
   - API: http://localhost:8000
   - OpenAPI ドキュメント: http://localhost:8000/docs
   - phpMyAdmin: http://localhost:8080
4. 終了は docker compose down。永続化ボリュームは dbdata（MySQL）、api_uploads（アップロードファイル）です。

### 2. ローカル環境で動かす場合
1. Python 3.11 と MySQL 8 を用意し、データベース learn を作成します。
2. 仮想環境を作成し依存関係をインストールします。
   python -m venv .venv
   .venv\\Scripts\\activate        # Windows
   source .venv/bin/activate          # macOS / Linux
   pip install -r requirements.txt
   
3. 以下の環境変数を設定します（例）。
   set DATABASE_URL=mysql+pymysql://app:app@127.0.0.1:3306/learn
   set JWT_SECRET=変更してください
   set UPLOAD_DIR=./uploads
   set OPENAI_ENABLED=false
   
4. アプリを起動します。
   uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
   
5. 画像アップロード用ディレクトリ（UPLOAD_DIR）を作成し、必要に応じて python -m app.api.init などの初期化処理を実行してください。

## 主な環境変数
| 変数 | 説明 | 既定値 |
| ---- | ---- | ------ |
| DATABASE_URL | MySQL 接続文字列 | mysql+pymysql://app:app@db:3306/learn |
| JWT_SECRET | JWT 署名キー（必須） | なし |
| JWT_EXPIRES_MIN | トークン有効期限（分） | 10080 |
| OPENAI_ENABLED | OpenAI 連携の有効化フラグ | false |
| OPENAI_API_KEY | OpenAI API キー（OPENAI_ENABLED=true の場合必須） | なし |
| OPENAI_MODEL | 利用モデル名 | gpt-4o-mini |
| UPLOAD_DIR | ファイル保存先パス | /data/uploads |

## 運用上のヒント
- /uploads エンドポイントで UPLOAD_DIR に保存されたファイルを配信します。
- API から返される 422 エラーはバリデーション失敗を表します。リクエストボディを確認してください。
- 画像 OCR が必要な場合は、Docker イメージに含まれる Tesseract を利用できます（ローカル実行時は別途インストールしてください）。
- OpenAI 連携を有効化すると、解説生成や自動判定エンドポイントが有効になります。課金設定に注意してください。
