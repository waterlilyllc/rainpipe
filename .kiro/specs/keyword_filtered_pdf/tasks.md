# Implementation Plan - Keyword Filtered PDF

## Task Overview
Total: **9 major tasks**, **24 sub-tasks**
All 7 requirements (1, 2, 2-1, 3, 3-1, 3-2, 3-3, 4, 5, 6, 7) fully covered

---

## Database & Storage Setup

- [x] 1. キーワード PDF 生成履歴テーブルをセットアップ
- [x] 1.1 (P) SQLite migration スクリプトを作成して keyword_pdf_generations テーブル追加
  - uuid (STRING UNIQUE)、keywords (TEXT)、date_range_start/end (DATE)、bookmark_count (INTEGER)、status (STRING: pending/processing/completed/failed)、pdf_path (TEXT)、kindle_email (TEXT)、error_message (TEXT)、gpt_overall_summary_duration_ms (INTEGER)、gpt_analysis_duration_ms (INTEGER)、gpt_keyword_extraction_duration_ms (INTEGER)、gatherly_fetch_duration_ms (INTEGER)、pdf_render_duration_ms (INTEGER)、total_duration_ms (INTEGER)、created_at/updated_at (TIMESTAMP) を含むスキーマを定義
  - 日付範囲の一貫性チェック制約を追加（date_range_start ≤ date_range_end）
  - 作成日時インデックスと status インデックスを作成してクエリ性能最適化
  - _Requirements: 5, 6_
  - ✅ **実装完了**: migrate_add_keyword_pdf_generations.rb（27/27 テスト成功）

- [x] 1.2 (P) Ruby migration 実行スクリプトで既存 SQLite データベースへのテーブル追加を実装
  - migrate_add_keyword_pdf_generations.rb ファイルを作成
  - スキーマ検証（テーブル存在確認 + カラム確認）を実装
  - ロールバック機能（テーブル削除）を追加
  - _Requirements: 5, 6_
  - ✅ **実装完了**: run_migration_keyword_pdf.rb（検証成功、テーブル追加確認）

---

## UI フォーム実装

- [x] 2. キーワード入力フォーム UI をブラウザに実装
- [x] 2.1 (P) /filtered_pdf GET ルートでキーワード入力フォームテンプレートを表示
  - フォーム要素：複数キーワード入力（textarea または複数テキスト行）
  - オプション：日付範囲ピッカー（デフォルト３ヶ月前～今日）
  - オプション：Kindle 送信チェックボックス
  - フォーム送信ボタン（「PDF を生成」）
  - views/filtered_pdf.erb テンプレートを作成
  - キーワード入力欄にプレースホルダーテキスト「キーワードを入力（複数の場合は改行または , で区切る）」を追加
  - _Requirements: 1_
  - ✅ **実装完了**: views/filtered_pdf.erb + GET /filtered_pdf ルート（9/9 テスト成功）

- [x] 2.2 (P) フォーム入力値の基本的なバリデーション機能を実装
  - キーワード非空チェック
  - 日付範囲の順序チェック（start ≤ end）
  - キーワード正規表現ベース検証（`^[a-zA-Z0-9\p{L}_\s,\-]+$`）で SQL/JSON インジェクション対策
  - バリデーション失敗時のエラーメッセージ UI に表示
  - _Requirements: 1_
  - ✅ **実装完了**: form_validator.rb + POST /filtered_pdf/generate ルート（15/15 テスト成功）

---

## コア Service クラス実装

- [x] 3. KeywordFilteredPDFService オーケストレーションクラスを実装
- [x] 3.1 RaindropClient を使用したキーワード + 日付範囲によるブックマークフィルタリング機能
  - デフォルト日付範囲：3 ヶ月前～今日（Date.today.prev_month(2) から Date.today）
  - キーワード OR マッチング：title、tags、excerpt フィールドで複数キーワードを検索
  - フィルタ後のブックマーク件数をログ出力（"📚 X 件のブックマークをフィルタ")
  - フィルタ後 0 件の場合、エラーメッセージ返却（"検索条件に合致するブックマークが見つかりません"）
  - フィルタリング対象期間をログに記録（"📅 期間: YYYY-MM-DD ～ YYYY-MM-DD"）
  - _Requirements: 2_
  - ✅ **実装完了**: keyword_filtered_pdf_service.rb（10/10 テスト成功）

- [x] 3.2 入力キーワードのトリム処理と正規化
  - 各キーワードの前後空白削除（.strip）
  - 空のキーワードをフィルタリング
  - 重複キーワード排除
  - _Requirements: 1, 2_
  - ✅ **実装完了**: keyword_filtered_pdf_service.rb（10/10 テスト成功）

- [x] 3.3 (P) ContentChecker クラスを使用してサマリー未取得ブックマークの検出
  - 各ブックマークの summary フィールド有無を確認
  - summary が nil または empty の場合をカウント
  - サマリー欠落数をログ出力（"⚠️ X 件のブックマークのサマリーが未取得）
  - 未取得ブックマークのリストを service に返却
  - _Requirements: 2-1_
  - ✅ **実装完了**: content_checker.rb（10/10 テスト成功）

- [x] 3.4 キーワード定義の一貫性確保
  - フィルタリング時のキーワード定義と PDF 出力時で同じキーワード set を使用
  - キーワード定義の変更がないことを assert で検証
  - _Requirements: 5_
  - ✅ **実装完了**: keyword_filtered_pdf_service.rb（10/10 テスト成功）

- [x] 3.5 UTC ベース日付処理
  - ユーザー入力日付を UTC に変換（Time.now.utc.iso8601）
  - RaindropClient への日付パラメータは UTC で渡す
  - ログ出力時のタイムスタンプは UTC ISO8601 形式
  - _Requirements: 2, 5_
  - ✅ **実装完了**: keyword_filtered_pdf_service.rb（10/10 テスト成功）

---

## Gatherly API 統合（本文取得）

- [x] 4. Gatherly API 経由の本文取得ジョブ管理機能を実装
- [x] 4.1 (P) サマリー未取得ブックマークのバッチ本文取得ジョブ作成
  - 未取得ブックマークを 15 件ずつのバッチに分割
  - 各バッチごとに GatherlyClient.create_crawl_job を呼び出し
  - ジョブ UUID を記録（"🌐 本文取得ジョブを作成: job_uuid_xxx"）
  - 最大バッチ数に制限（例：最大 10 バッチまで）して API 乱用防止
  - _Requirements: 2-1_
  - ✅ **実装完了**: gatherly_batch_fetcher.rb（18/18 テスト成功）

- [x] 4.2 (P) Gatherly ジョブのポーリングと完了待機（5 分タイムアウト）
  - 2-3 秒間隔でジョブ状態を確認（GatherlyClient.get_job_status）
  - ジョブ完了（status='completed'）まで待機
  - 5 分経過時点でタイムアウト判定（スタートから 300 秒）
  - タイムアウト時は warning log を出力して処理継続（"⏱️ 本文取得ジョブがタイムアウト。サマリー未取得として継続"）
  - _Requirements: 2-1_
  - ✅ **実装完了**: gatherly_job_poller.rb（9/9 テスト成功）

- [x] 4.3 (P) Gatherly ジョブ結果の取得と本文マージ
  - ジョブ完了後、GatherlyClient.get_job_result で記事内容を取得
  - 取得した content を対応するブックマークの summary フィールドに統合
  - マージ失敗（null content など）の場合は "summary unavailable" マーカーを設定
  - サマリー取得状況（成功・失敗数）をログ（"✓ X 件のサマリーを取得、✗ Y 件失敗"）
  - _Requirements: 2-1_
  - ✅ **実装完了**: gatherly_result_merger.rb（8/8 テスト成功）

- [x] 4.4 (P) ジョブ実行時間計測
  - Gatherly 本文取得の開始～完了時刻を計測
  - gatherly_fetch_duration_ms を DB に記録
  - パフォーマンス分析用に "🕐 本文取得時間: XXX 秒" をログ
  - _Requirements: 7_
  - ✅ **実装完了**: gatherly_timing.rb（12/12 テスト成功）

---

## GPT コンテンツ生成

- [x] 5. GPT API を使用した 3 段階コンテンツ生成を実装
- [x] 5.1 (P) 全体サマリーセクション生成（GPT 呼び出し）
  - フィルタ済みブックマークの title + excerpt から context を構築
  - プロンプト：「以下のキーワード領域のブックマークを分析して、傾向・重要ポイント・実用的な洞察を含むサマリーを生成してください」（日本語）
  - OpenAI gem を使用して gpt-4o-mini モデルで呼び出し
  - 生成テキスト（全体サマリー）を Service に保持
  - API 呼び出し時間を計測（gpt_overall_summary_duration_ms）
  - GPT API 失敗時は placeholder "（全体サマリー生成に失敗しました）" を使用して処理継続
  - _Requirements: 3-1_
  - ✅ **実装完了**: gpt_content_generator.rb（17/17 テスト成功）

- [x] 5.2 (P) 関連ワード抽出セクション生成（GPTKeywordExtractor）
  - GPTKeywordExtractor.extract_keywords_from_bookmarks を呼び出し
  - 返却された related_clusters を取得（各要素は { main_topic: String, related_words: [String] }）
  - API 呼び出し時間を計測（gpt_keyword_extraction_duration_ms）
  - 抽出失敗時は empty array として処理継続
  - _Requirements: 3-2_
  - ✅ **実装完了**: gpt_content_generator.rb（17/17 テスト成功）

- [x] 5.3 (P) 考察セクション生成（GPT 呼び出し、キャッシュなし）
  - フィルタ済みブックマークの context から動的生成
  - プロンプト：「キーワード領域での今後の注目点・実装への示唆・ベストプラクティスを含める考察を生成」（日本語）
  - キャッシュなし（毎回実行時に生成） - Requirement 3-3 で動的生成を厳密に実装
  - OpenAI gem で gpt-4o-mini モデルで呼び出し
  - API 呼び出し時間を計測（gpt_analysis_duration_ms）
  - GPT API 失敗時は placeholder "（考察生成に失敗しました）" を使用
  - _Requirements: 3-3_
  - ✅ **実装完了**: gpt_content_generator.rb（17/17 テスト成功）

- [x] 5.4 (P) GPT API エラーハンドリングと exponential backoff
  - OpenAI::APIError 捕捉して最大 3 回リトライ
  - リトライ間隔：1 秒、2 秒、4 秒（exponential backoff）
  - 最終的に失敗時は log WARN して placeholder text で処理継続
  - _Requirements: 3-1, 3-3_
  - ✅ **実装完了**: gpt_content_generator.rb（17/17 テスト成功）

---

## PDF 生成（Prawn）

- [x] 6. KeywordPDFGenerator クラスで Prawn を使用した PDF レンダリング実装
- [x] 6.1 (P) Prawn ドキュメント初期化と日本語フォントセットアップ
  - Prawn::Document.new で新規 PDF 作成
  - NotoSansCJK-Regular.ttc フォント（/usr/share/fonts/opentype/noto/ から）を登録
  - フォール バック：フォント見つからない場合は Courier に変更（log WARN）
  - PDF メタデータ設定（title、subject、author="Rainpipe"、creation_date=UTC now）
  - Prawn compression オプション有効化（compress: true）
  - _Requirements: 3_
  - ✅ **実装完了**: keyword_pdf_generator.rb（11/11 テスト成功）

- [x] 6.2 (P) PDF セクション構成：全体サマリー → 関連ワード → 考察 → ブックマーク詳細
  - セクション順序の厳密な実装
  - 各セクション間に区切り線（Prawn stroke_horizontal_line）を追加
  - セクションヘッダー（日本語）を太字で表示
  - _Requirements: 3_
  - ✅ **実装完了**: keyword_pdf_generator.rb（11/11 テスト成功）

- [x] 6.3 (P) 全体サマリーセクションの PDF レンダリング
  - ヘッダー「全体サマリー」を配置
  - GPT 生成テキストを wrap text で段落レイアウト
  - _Requirements: 3-1_
  - ✅ **実装完了**: keyword_pdf_generator.rb（11/11 テスト成功）

- [x] 6.4 (P) 関連ワードセクションの PDF レンダリング
  - ヘッダー「関連ワード」を配置
  - related_clusters 配列を反復
  - 各 cluster を「• main_topic: related_words1, related_words2, ...」の形式で出力
  - _Requirements: 3-2_
  - ✅ **実装完了**: keyword_pdf_generator.rb（11/11 テスト成功）

- [x] 6.5 (P) 考察セクションの PDF レンダリング
  - ヘッダー「今週の考察」を配置
  - GPT 生成分析テキストを wrap text で出力
  - _Requirements: 3-3_
  - ✅ **実装完了**: keyword_pdf_generator.rb（11/11 テスト成功）

- [x] 6.6 (P) ブックマーク詳細セクションのメモリ効率的なレンダリング
  - ヘッダー「ブックマーク詳細」を配置
  - ブックマークを 50 件単位のチャンクで処理（メモリ効率化）
  - 各ブックマークを「タイトル → URL → サマリー」の順序で出力
  - サマリー未取得時は「（サマリー未取得）」マーカー表示
  - 各ブックマーク間に軽い区切り表示
  - GC ヒント（GC.start）を 50 件ごとに呼び出し
  - _Requirements: 3, 7_
  - ✅ **実装完了**: keyword_pdf_generator.rb（11/11 テスト成功）

- [x] 6.7 (P) PDF ファイル名生成
  - フォーマット：filtered_pdf_{timestamp}_{keywords_joined}.pdf
  - timestamp：YYYYMMDD_HHmmss（UTC）
  - keywords_joined：キーワードをアンダースコアで結合（スペース/カンマは除去）
  - 例：filtered_pdf_20251113_133045_Claude_AI.pdf
  - _Requirements: 3_
  - ✅ **実装完了**: keyword_pdf_generator.rb（11/11 テスト成功）

- [x] 6.8 (P) PDF ファイルサイズチェックと警告
  - 出力ファイルサイズを確認（File.size）
  - 20MB 超過時は log WARN で警告
  - 25MB 超過時は error 返却（Kindle 送信不可）
  - _Requirements: 4_
  - ✅ **実装完了**: keyword_pdf_generator.rb（11/11 テスト成功）

- [x] 6.9 (P) PDF レンダリング時間計測
  - 開始～完了時刻を計測
  - pdf_render_duration_ms を計測
  - "🕐 PDF レンダリング時間: XXX 秒" をログ
  - _Requirements: 7_
  - ✅ **実装完了**: keyword_pdf_generator.rb（11/11 テスト成功）

---

## ブックマークサマリー生成（フィルタ済みセット向け）

- [ ] 7. (P) フィルタ済みブックマークのサマリー生成を実装
  - BookmarkContentManager または既存サマリー生成ロジックを活用
  - Gatherly で取得した content から，GPT でサマリーを生成
  - 完了後の content_summary フィールド更新
  - _Requirements: 2-1_

---

## ファイル出力と Kindle 送信

- [ ] 8. ファイル出力と配布機能を実装
- [ ] 8.1 (P) /filtered_pdf/generate POST ルートで PDF 生成リクエスト処理
  - フォーム param から keywords、date_start、date_end、send_to_kindle を取得
  - KeywordFilteredPDFService インスタンス作成 + execute 呼び出し
  - 生成 status を確認（success/error）
  - _Requirements: 6_

- [ ] 8.2 (P) PDF ダウンロードレスポンス実装
  - send_to_kindle が false 時、PDF ファイルをブラウザで download
  - Sinatra send_file で ファイルパス指定
  - Content-Type: application/pdf
  - attachment header で強制 download（Content-Disposition: attachment; filename="..."）
  - _Requirements: 4_

- [ ] 8.3 (P) Kindle メール送信機能統合
  - send_to_kindle が true 時、KindleEmailSender を call
  - KindleEmailSender.send_pdf(pdf_path) で PDF 送信
  - 成功時：HTML レスポンスで「Kindle に送信しました」確認メッセージ表示
  - 失敗時：エラーメッセージを HTML で表示（「メール送信に失敗しました：...」）
  - _Requirements: 4_

- [ ] 8.4 (P) エラーレスポンス処理
  - Service が error status 返却時、HTML error message を返す
  - エラー理由を含める（「フィルタに合致するブックマークが見つかりません」など）
  - _Requirements: 6_

---

## 生成履歴追跡と並行実行制限

- [ ] 9. 生成履歴 DB 記録と並行実行制限を実装
- [ ] 9.1 (P) PDF 生成前に DB で in-progress ステータスチェック
  - keyword_pdf_generations table から status='processing' レコードを検索
  - IN-progress レコードが存在時：warning message 表示（「PDF 生成処理が進行中です。数分お待ちください」）
  - _Requirements: 6_

- [ ] 9.2 (P) 生成開始時に DB record 作成（uuid 生成、status=processing）
  - SecureRandom.uuid で一意 ID 生成
  - keywords（カンマ区切り）、date_range_start、date_range_end、bookmark_count を記録
  - status='processing'、created_at=UTC now、updated_at=UTC now
  - _Requirements: 6_

- [ ] 9.3 (P) PDF 完成時に DB record を status=completed に更新
  - pdf_path を記録
  - total_duration_ms を計算（all sub-step の duration sum）
  - updated_at を更新
  - _Requirements: 6_

- [ ] 9.4 (P) エラー時に DB record を status=failed に更新
  - error_message に失敗理由を記録
  - updated_at を更新
  - _Requirements: 6_

- [ ] 9.5 (P) /filtered_pdf/history GET ルート実装（生成履歴表示）
  - keyword_pdf_generations table から最新 20 件を取得（order by created_at DESC）
  - HTML table で表示：keywords、bookmark_count、status、created_at、total_duration_ms
  - _Requirements: 6_

---

## 統合テスト

- [ ] 10. エンドツーエンド統合テストと検証
- [ ] 10.1 キーワード入力フォーム→フィルタリング→Gatherly fetch→PDF 生成→ダウンロード全体フロー
  - テスト用キーワード（例："Claude"）でフロー実行
  - 各段階のログ確認（フィルタリング、fetch、GPT call、PDF render）
  - 最終 PDF ファイル生成確認 + ファイルサイズ確認
  - _Requirements: 1, 2, 2-1, 3, 3-1, 3-2, 3-3, 4, 6_

- [ ] 10.2 Kindle 送信フロー検証（メール受信確認）
  - フォーム से send_to_kindle=true で送信
  - Gmail SMTP ログ確認 + Kindle メール到着確認
  - _Requirements: 4_

- [ ] 10.3 エラーハンドリング検証
  - キーワード空欄時：バリデーションエラー表示
  - マッチングブックマーク 0 件：warning メッセージ表示
  - Gatherly timeout：処理継続確認
  - GPT API 失敗：placeholder text で PDF 생성 继续
  - _Requirements: 3, 4_

- [ ] [ ]* 10.4 パフォーマンス検証（1000 件ブックマーク）
  - テストデータセット：100 件 / 500 件 / 1000 件
  - 각 규模에서 처리 시간 측정
  - 1000 件を 10 秒以内で処理확인 (외부 API 시간 제외)
  - _Requirements: 7_

- [ ] [ ]* 10.5 ユニットテスト：Service、Checker、Generator の個别テスト
  - ContentChecker.find_missing_summaries のテスト
  - KeywordFilteredPDFService の filtering ロジック
  - KeywordPDFGenerator の section rendering
  - _Requirements: 1, 2, 2-1, 3_

---

## 実装完了確認チェックリスト

- [ ] キーワード入力フォーム動作確認
- [ ] 複数キーワード入力 + OR マッチング確認
- [ ] 3 ヶ月デフォルト日付範囲確認
- [ ] カスタム日付範囲フィルタリング確認
- [ ] サマリー未取得ブックマーク検出確認
- [ ] Gatherly 本文取得ジョブ作成 + ポーリング確認
- [ ] 5 分タイムアウト動作確認
- [ ] GPT 全体サマリー生成確認
- [ ] GPT 関連ワード抽出確認
- [ ] GPT 考察生成確認
- [ ] PDF セクション順序確認（サマリー → 関連ワード → 考察 → 詳細）
- [ ] PDF ファイル名確認（日時 + キーワード含む）
- [ ] PDF ダウンロード機能確認
- [ ] Kindle メール送信確認
- [ ] 生成履歴 DB 記録確認
- [ ] 並行実行制限（warning）確認
- [ ] エラーメッセージ表示確認
- [ ] パフォーマンス確認（1000 件 ≤10 秒）
