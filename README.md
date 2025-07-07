# Rainpipe

Rainpipe は、Raindrop.io に保存したブックマークを週ごとにまとめて一覧表示し、静かに振り返るための軽量 Web アプリケーションです。  
Sinatra をベースに構築されており、API 経由でリンクを取得し、週単位で見やすく整理・表示します。

---

## 📌 概要

- **目的**：日々 Raindrop.io に保存している情報を、週ごとに整理・可視化して振り返るため
- **特徴**：
  - 毎週のブックマークを一覧で自動表示
  - 非公開・自分用のまとめ閲覧ページとして活用
  - 後からメモや分類ができる設計（予定）

---

## 🧠 コンセプト

> 情報の「雨粒（Raindrop）」を静かに集め、週ごとに「雨樋（Rainpipe）」として流して可視化する。

---

## 🏗 技術構成

- **フレームワーク**: Sinatra（Ruby）
- **API連携**: Raindrop.io API v1
- **テンプレート**: ERB または Slim（未定）
- **デプロイ**: ローカル or 任意のVPS（将来的に Netlify 静的生成も視野）

---

## 📁 ディレクトリ構成（予定）

```
rainpipe/
├── app.rb               # Sinatra 本体（ルーティング）
├── raindrop_client.rb   # Raindrop API とのやりとり
├── views/
│   └── week.erb         # 週ごとのリンク表示テンプレート
├── public/              # CSS や画像
├── helpers.rb           # 日付処理や共通ロジック
├── config.ru            # Rack 起動用
└── .env                 # APIキーなどの環境変数（gitignore推奨）
```

---

## 🔐 認証・APIキー

- Raindrop.io の API トークンは `.env` に記述し、アプリ内部から読み込みます。
- 認証は「Private token」（personal access token）を使用します。
- `.env` 例：

```
RAINDROP_API_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxx
```

---

## 📅 対応機能（初期予定）

| 機能 | 内容 |
|------|------|
| `/` | 今週分の保存リンク一覧 |
| `/week/2025-07-01` | 指定週のリンクを表示 |
| `/tag/ai` | 特定タグのリンクだけ表示（予定） |
| JSONキャッシュ | Raindrop API への過剰リクエストを避けるためのキャッシュ機構（予定） |

---

## ⏳ 今後の拡張構想

- タグやメモの表示
- お気に入り（★）マークでのピックアップ
- PDF or Markdown 出力機能（週報のように）
- SlackやLINEへの定期通知
- プライベートギャラリーとしての共有モード
- Weekly Digest メール送信

---

## 🛠 起動方法（ローカル）

```bash
bundle install
ruby app.rb
# または rackup config.ru
```

---

## 🤖 補足（Devin.ai等向け仕様整理）

- APIレスポンスは `/raindrops` エンドポイントで取得（query: `created: week_range`）
- データ構造はJSON形式、主に以下フィールドを使用：
  - `title`：リンクタイトル
  - `link`：URL本体
  - `tags`：分類タグ
  - `excerpt`：ユーザーによるメモ（オプション）
- 日付計算は `Time.now.beginning_of_week` などで制御
- 表示テンプレートはループで整形、未加工のデータ表示を優先

---

## ✍️ 名前の由来

「Rainpipe」は雨樋（あまどい）を意味し、Raindrop.io に保存した情報の流れを“週ごとに整えながら流す”というイメージから名付けました。

---

## 👤 Author

Kosuke (2025)
https://github.com/yourname (←必要に応じて差し替え)

---

## 🔒 ライセンス

MIT License
