# Kaiho Zukan プロジェクト

Kaiho Zukan は、学習者が問題を解き、解説を投稿し、AI を活用しながら復習サイクルを回せる学習支援プラットフォームです。本リポジトリはバックエンド (FastAPI) とフロントエンド (Flutter) を同居させたモノレポ構成になっています。

## リポジトリ構成
- backend/ : FastAPI ベースの REST API・AI サービス。詳細は backend/README.md を参照してください。
- frontend/ : Flutter 製の Web / モバイル クライアント。詳細は frontend/README.md を参照してください。
- backend/docker-compose.yml : MySQL / API / phpMyAdmin をまとめて立ち上げる Compose 定義。
- .env 系ファイル : 各サービスの環境変数サンプル。

## 主な機能
- JWT 認証を用いたユーザー登録・ログイン・プロフィール編集
- 問題・選択肢・模範解答・画像アップロードの管理
- 解説投稿、いいね、誤答フラグ付け、AI による自動判定・解説生成
- スペースドリピティションに基づく復習スケジュールと学習履歴
- ランキング、カテゴリ別ナビゲーション、ユーザー別の可視化

## クイックスタート
### バックエンド (FastAPI)
1. cd backend
2. 必要に応じて .env, .env.db, mysql.env を調整
3. docker compose up --build
4. API: http://localhost:8000 / ドキュメント: /docs

### フロントエンド (Flutter)
1. cd frontend
2. flutter pub get
3. frontend/.env の API_BASE_URL をバックエンドに合わせて設定
4. flutter run -d chrome で Web 版を起動

より詳しい手順や環境変数の説明は、各 README を参照してください。

## 参考ドキュメント
- バックエンド: backend/README.md
- フロントエンド: frontend/README.md
- API 定義: http://localhost:8000/docs（バックエンド起動時）

課題や改善点があれば issue / PR で気軽に共有してください。
