# Kaiho Zukan Frontend (Flutter)

学習用の問題・解説プラットフォームのフロントエンドです。Flutter（Web/モバイル）で動作し、バックエンド FastAPI と通信します。

## 必要環境

- Flutter 3.x（stable）
- Dart（Flutter 同梱）

確認例:

```
flutter --version
```

## 環境変数

起動時に `.env`（開発時）または `.env.production`（リリースビルド時）を読み込みます。

- `API_BASE_URL`: 接続先バックエンドのベース URL（例: `http://localhost:8000`）
  - 未設定の場合、リリースビルドでは既定で `https://es4.eedept.kobe-u.ac.jp/kaihou-back`、開発時は `http://localhost:8000` に接続します。

例: `frontend/.env`

```
API_BASE_URL=http://localhost:8000
```

## 開発（ローカル実行）

```
flutter pub get
flutter run -d chrome   # Web（Chrome）
# または
flutter run             # 接続中のデバイス/エミュレータ
```

バックエンドが `http://localhost:8000` で起動していることを確認してください。

## ビルド

Web ビルド:

```
flutter build web
# GitHub Pages などサブパスに配置する場合:
flutter build web --base-href "/kaihou-zukan/"
```

モバイルビルド（例: Android APK）:

```
flutter build apk --release
```

## 主要画面/機能

- 認証: `login_register.dart`
- ホーム: `home.dart`
- 問題を解く: `solve_screen.dart`（カテゴリ選択、出題、回答、解説表示、いいね）
- 問題作成/編集: `post_problem_form.dart`（画像/選択肢/解説/模範解答、編集/解説のみ編集モード）
- 解説を作る: `explain_create.dart`（単元「すべて」での絞り込み対応）
- 振り返り（レビュー）: `review_screen.dart`（統計/履歴、問題詳細で解答→解説の順に表示）
- 自分の問題一覧/削除: `my_problems.dart`
- ランキング: `ranking.dart`
