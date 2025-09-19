# Kaiho Zukan フロントエンド (Flutter)

## 概要
Kaiho Zukan のフロントエンドは Flutter (Web / Android / iOS / デスクトップ) を利用したクロスプラットフォームアプリです。バックエンド FastAPI と連携し、ユーザーのログイン、問題演習、解説投稿、復習、ランキング表示などの学習体験を提供します。

## 必要環境
- Flutter 3.3 以上（stable チャネル推奨）
- Dart SDK （Flutter に同梱）
- Chrome または対象プラットフォーム向けのデバイス/エミュレーター

動作確認:
flutter --version


## 環境変数
flutter_dotenv を利用しており、ビルド時に .env（開発用）または .env.production（本番用）を読み込みます。

| 変数 | 用途 | 例 |
| ---- | ---- | --- |
| API_BASE_URL | バックエンド API のベース URL | 開発: http://localhost:8000 / 本番: https://example.com/api |

frontend/.env
API_BASE_URL=http://localhost:8000

## セットアップ & 起動
flutter pub get
flutter run -d chrome          # Web (Chrome)
# もしくは接続済みデバイスに対して
flutter devices
flutter run -d <device_id>

バックエンドが API_BASE_URL で起動していることを確認してください。

## ビルド
- Web: flutter build web
  - サブパス配信時は flutter build web --base-href "/kaiho-zukan/"
- Android APK: flutter build apk --release
- iOS: flutter build ipa （要 macOS / Xcode）

## ディレクトリ構成（抜粋）
- lib/main.dart : エントリーポイント（MaterialApp / ルーティング設定）
- lib/services/api.dart : HTTP クライアント・API ラッパー
- lib/screens/ : 画面群（ログイン、ホーム、出題/解説、レビュー、ランキングなど）
- lib/widgets/ : 共通ウィジェット（AppBar、サイドバー、ダイアログ等）
- lib/models/ : 型定義・DTO（存在する場合）
- assets/ : 画像・アイコン（必要に応じて配置）

## 開発時のヒント
- flutter analyze で静的解析
- flutter test でウィジェットテスト
- API モックが必要な場合は lib/services/api.dart を差し替えや DI できるように構造化されています。
- lib/screens/explain_* など AI 補助機能画面では、バックエンドの OpenAI 設定が必要です。

問題が発生した際は、flutter clean の後に再ビルドを試してください。
