# Research & Design Decisions

## Summary
- **Feature**: `monthly-pdf-email-summary`
- **Discovery Scope**: Extension (既存システムの拡張)
- **Key Findings**:
  - 既存の週次レポート機能（WeeklyPDFGenerator）が存在し、同様のパターンを踏襲可能
  - BookmarkCategorizerによるカテゴリー分類機能が既に実装済み
  - スケジューリングは現在cronシェルスクリプトで実装されており、同様の方式を採用可能

## Research Log

### スケジューリング方式の選択

**Context**: 月次レポートを自動実行するためのスケジューリング機構が必要

**Sources Consulted**:
- GitHub: jmettraux/rufus-scheduler
- The Ruby Toolbox: Scheduling category
- 既存コード: weekly_pdf_generator.sh
- WebSearch: Ruby cron scheduling best practices 2025

**Findings**:
- **rufus-scheduler**: インプロセス・インメモリのスケジューラー。プロセスが停止するとスケジュールも消失
- **whenever**: cron DSLを提供し、システムcronに永続的にスケジュールを登録
- **System cron + Shell script**: 現在の週次レポートで採用されている方式。再起動に対して堅牢

**Implications**:
- 既存の週次レポートと同様、**システムcron + Shellスクリプト**方式を採用
- 理由: 再起動に対する堅牢性、既存パターンとの一貫性、追加ライブラリ不要
- 実装: `/var/git/rainpipe/monthly_pdf_generator.sh` + cron設定（毎月1日 0:00実行）

### 既存機能の再利用可能性

**Context**: 月次レポート機能で再利用できる既存コンポーネントの特定

**Sources Consulted**:
- `bookmark_categorizer.rb`: カテゴリー分類ロジック
- `weekly_pdf_generator.rb`: 週次PDF生成の実装パターン
- `keyword_pdf_generator.rb`: PDF生成エンジン
- `gpt_content_generator.rb`: AIサマリー生成
- `kindle_email_sender.rb`: メール送信機能
- `raindrop_client.rb`: ブックマーク取得API
- `job_queue.rb`: バックグラウンドジョブ管理
- `progress_reporter.rb`: 進捗報告機能

**Findings**:
- **BookmarkCategorizer**: 11カテゴリーの分類ロジックが完全に実装済み
- **KeywordPDFGenerator**: Prawnベースの日本語PDF生成機能が利用可能
- **GPTContentGenerator**: OpenAI GPT-4o-miniを使用したサマリー生成が実装済み
- **KindleEmailSender**: Gmail SMTP経由のメール送信が実装済み
- **JobQueue**: バックグラウンド実行とキューイングが実装済み
- **ProgressReporter & ProgressCallback**: 進捗追跡とログ記録が実装済み

**Implications**:
- 新規コンポーネントは最小限に抑え、既存機能を最大限活用
- 必要な新規実装:
  - `MonthlyPDFGenerator`: WeeklyPDFGeneratorをベースに月次対応とカテゴリー別レイアウトを実装
  - `CategorySummaryGenerator`: カテゴリーごとのAIサマリー生成（GPTContentGeneratorを活用）
  - `MonthlyReportScheduler`: スケジュール設定と実行履歴管理（UIとDB管理）

### データベース設計の統合

**Context**: 月次レポートの設定・履歴をどのように永続化するか

**Sources Consulted**:
- 既存DBスキーマ: `keyword_pdf_generations`, `keyword_pdf_progress_logs`
- SQLite3データベース: `rainpipe.db`

**Findings**:
- 既存の`keyword_pdf_generations`テーブルは汎用的なPDF生成履歴を記録
- `keyword_pdf_progress_logs`は進捗ログを記録
- 月次レポート固有のメタデータを格納する新テーブルが必要

**Implications**:
- 新規テーブル設計:
  - `monthly_report_configs`: スケジュール設定、送信先メールアドレス、フィルタ設定
  - `monthly_report_executions`: 実行履歴（開始/終了時刻、ステータス、対象期間、生成件数、PDFパス、エラーメッセージ）
- 既存テーブルとの連携:
  - `monthly_report_executions.pdf_generation_id` (FK) → `keyword_pdf_generations.id`
  - 進捗ログは既存の`keyword_pdf_progress_logs`を活用

### カテゴリー別AIサマリーのプロンプト設計

**Context**: 各カテゴリーのブックマークから有意義なサマリーを生成する方法

**Sources Consulted**:
- 既存の`gpt_content_generator.rb`のプロンプト設計
- BookmarkCategorizerのカテゴリー定義

**Findings**:
- 既存のGPTContentGeneratorは`generate_overall_summary`、`extract_related_keywords`、`generate_analysis`を提供
- カテゴリーサマリーは新規メソッドが必要: `generate_category_summary(category_name, bookmarks)`

**Implications**:
- GPTContentGeneratorに`generate_category_summary`メソッドを追加
- プロンプト構成:
  - カテゴリー名とその説明
  - ブックマークのタイトルとURL一覧
  - 要求事項: 主要トピック、注目記事、傾向分析を300-500文字で生成
- エラーハンドリング: カテゴリー内ブックマークが3件未満の場合はスキップ

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Service-Oriented (現行パターン) | MonthlyPDFGeneratorを新規サービスとして実装し、既存サービス（BookmarkCategorizer、GPTContentGenerator、KeywordPDFGenerator等）を呼び出す | 既存パターンとの一貫性、保守性、テスト容易性 | なし（既存アーキテクチャとの整合性が高い） | steering/structure.mdのService-Oriented Architectureに完全準拠 |
| Scheduler-Driven Architecture | rufus-schedulerやwheneverを導入してRubyプロセス内でスケジューリング | Rubyコード内で完結 | プロセス再起動時のスケジュール喪失リスク、追加ライブラリの導入 | 現行の週次レポートがcronスクリプトを採用しているため不採用 |

## Design Decisions

### Decision: `System Cron + Shell Scriptによるスケジューリング`

**Context**: 月次レポートを毎月1日午前0時に自動実行する機構が必要

**Alternatives Considered**:
1. **rufus-scheduler** — Rubyプロセス内でスケジューリング
2. **whenever** — cron DSLを提供してシステムcronに登録
3. **System cron + Shell script** — 既存の週次レポートと同じ方式

**Selected Approach**: System cron + Shell script

**Rationale**:
- 既存の週次レポート（`weekly_pdf_generator.sh`）と同じパターンを踏襲
- 再起動に対する堅牢性が最も高い
- 追加のGem依存なし
- 運用チーム（ユーザー自身）がcronに慣れている

**Trade-offs**:
- **利点**: シンプル、堅牢、既存パターンとの一貫性
- **欠点**: cron設定は手動（ただし、これは週次レポートでも同様）

**Follow-up**:
- crontab設定手順をドキュメント化
- ログローテーション戦略を実装（14日保持）

### Decision: `CategorySummaryGeneratorの実装`

**Context**: カテゴリーごとにAIサマリーを生成する新機能が必要

**Alternatives Considered**:
1. **GPTContentGeneratorに直接実装** — 既存クラスにメソッド追加
2. **独立したCategorySummaryGenerator** — 新規サービスクラスを作成

**Selected Approach**: GPTContentGeneratorに`generate_category_summary`メソッドを追加

**Rationale**:
- 単一責任原則: GPTContentGeneratorは既にGPT APIとのインタラクションを担当
- コード重複を避ける: リトライロジック、エラーハンドリング、API設定を共有
- 既存のテスト基盤を活用可能

**Trade-offs**:
- **利点**: 既存機能との統合が容易、コード重複なし
- **欠点**: GPTContentGeneratorクラスの責務が若干増加（ただし、依然として「GPT APIとのインタラクション」という単一責任内）

**Follow-up**:
- カテゴリーサマリー専用のプロンプトテンプレートを設計
- 3件未満のカテゴリーをスキップするロジックを実装

### Decision: `MonthlyPDFGeneratorのレイアウト設計`

**Context**: カテゴリー別セクションを視覚的に区切る必要がある

**Alternatives Considered**:
1. **KeywordPDFGeneratorを拡張** — 既存クラスに月次専用メソッドを追加
2. **MonthlyPDFGeneratorを新規作成** — KeywordPDFGeneratorを継承またはコンポジション

**Selected Approach**: MonthlyPDFGeneratorを新規作成し、KeywordPDFGeneratorの一部メソッドを再利用

**Rationale**:
- 週次と月次でレイアウト要件が異なる（カテゴリー別セクション、背景色、セパレーター）
- 継承ではなくコンポジションを採用: KeywordPDFGeneratorの共通メソッド（`strip_markdown`、`add_bookmarks`等）を呼び出す
- 単一責任原則: 月次固有のレイアウトロジックを分離

**Trade-offs**:
- **利点**: 月次固有のレイアウトを柔軟に実装可能、既存機能への影響なし
- **欠点**: 新規クラスの追加（ただし、複雑度は低い）

**Follow-up**:
- カテゴリーセクションの背景色定義（例: 薄いグレー `#F5F5F5`）
- セパレーター線の実装（Prawnの`stroke_horizontal_line`）

## Risks & Mitigations

- **Risk 1: GPT APIレート制限によるカテゴリーサマリー生成失敗**
  - Mitigation: 既存のリトライロジック（exponential backoff）を活用、失敗したカテゴリーはスキップしてログ記録

- **Risk 2: PDF生成時のメモリ不足（大量ブックマークの場合）**
  - Mitigation: 既存のチャンク処理（50件ずつ）を踏襲、GC.startトリガーを適切に配置

- **Risk 3: cronジョブの実行失敗検知が遅れる**
  - Mitigation: 実行ログを`logs/monthly_pdf_YYYYMMDD.log`に記録、エラー時のログレベルを適切に設定

- **Risk 4: カテゴリー分類の精度低下（新しいタグやキーワードに対応できない）**
  - Mitigation: BookmarkCategorizerの定義は既存機能で運用実績あり、必要に応じて将来的にカテゴリー定義を拡張可能

## References

- [rufus-scheduler GitHub](https://github.com/jmettraux/rufus-scheduler) — Rubyスケジューラーライブラリ（今回は不採用）
- [The Ruby Toolbox: Scheduling](https://www.ruby-toolbox.com/categories/scheduling) — Rubyスケジューリングライブラリの比較
- 既存コード: `weekly_pdf_generator.rb`, `weekly_pdf_generator.sh` — 週次レポートの実装パターン
- 既存コード: `bookmark_categorizer.rb` — カテゴリー分類ロジック
- 既存コード: `keyword_pdf_generator.rb` — PDF生成エンジン
- 既存コード: `gpt_content_generator.rb` — GPT APIインタラクション
- steering: `structure.md`, `tech.md`, `product.md` — プロジェクトアーキテクチャとパターン
