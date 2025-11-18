# Requirements Document

## Project Description (Input)
月次のサマリーをpdfにして、メールで送る

## Introduction
本機能は、既存のRainpipeシステムにおいて、月次でブックマークのサマリーレポートをPDF形式で自動生成し、指定されたメールアドレスに送信する機能を提供します。これにより、ユーザーは定期的なレポート配信を自動化でき、手動でのPDF生成とメール送信の手間を削減できます。

## Requirements

### Requirement 1: 月次レポートのスケジュール設定
**Objective:** As a ユーザー, I want 月次レポートの生成スケジュールを設定する, so that 毎月自動的にサマリーPDFが生成される

#### Acceptance Criteria
1. The MonthlyReportScheduler shall 毎月1日午前0時にレポート生成ジョブを実行する
2. When ユーザーがスケジュール設定を変更する, the MonthlyReportScheduler shall 新しいスケジュールを永続化する
3. The MonthlyReportScheduler shall 実行日時（日付と時刻）をカスタマイズ可能にする
4. If スケジュール実行が失敗する, then the MonthlyReportScheduler shall エラーログを記録し次回実行を試みる
5. The MonthlyReportScheduler shall 前回の実行履歴と次回実行予定日時を表示する

### Requirement 2: 月次レポートデータの集計とカテゴリー分類
**Objective:** As a システム, I want 指定された月のブックマークデータを集計しカテゴリー別に分類する, so that 正確な月次サマリーをカテゴリーごとに生成できる

#### Acceptance Criteria
1. When 月次レポート生成ジョブが実行される, the MonthlyReportService shall 前月1日から前月末日までのブックマークを取得する
2. The MonthlyReportService shall RaindropClientを使用してブックマークを集計する
3. The MonthlyReportService shall BookmarkCategorizerを使用してブックマークをカテゴリー別に分類する
4. The MonthlyReportService shall 既存の11カテゴリー（技術・開発、AI・機械学習、ビジネス・仕事、デザイン・UI、家庭・子育て、料理・食事、エンタメ・趣味、アウトドア・旅行、学習・自己啓発、ショッピング・ガジェット、健康・ライフスタイル）を使用する
5. If ブックマークが1件も存在しない, then the MonthlyReportService shall レポート生成をスキップしログに記録する
6. The MonthlyReportService shall 集計対象期間（年月）をレポートに明記する
7. The MonthlyReportService shall 対象期間のブックマーク総数とカテゴリー別件数を記録する

### Requirement 3: カテゴリー別AIサマリーの生成
**Objective:** As a ユーザー, I want 各カテゴリーごとにAIによるサマリーを生成する, so that カテゴリーごとの活動傾向を把握できる

#### Acceptance Criteria
1. The CategorySummaryGenerator shall 各カテゴリー内のブックマークからAIサマリーを生成する
2. The CategorySummaryGenerator shall GPTContentGeneratorを使用してカテゴリーごとのサマリーを生成する
3. The CategorySummaryGenerator shall 各カテゴリーサマリーに以下を含める：主要トピック、注目記事、傾向分析
4. If カテゴリー内のブックマークが3件未満である, then the CategorySummaryGenerator shall サマリー生成をスキップする
5. When カテゴリーサマリー生成が失敗する, the CategorySummaryGenerator shall エラーログを記録し次のカテゴリーに進む
6. The CategorySummaryGenerator shall 各カテゴリーサマリーを300-500文字に制限する

### Requirement 4: 月次PDFレポートの生成
**Objective:** As a システム, I want 集計されたブックマークから月次PDFレポートを生成する, so that ユーザーが月次の活動を確認できる

#### Acceptance Criteria
1. The MonthlyPDFGenerator shall KeywordPDFGeneratorをベースにカテゴリー別レイアウトを実装する
2. The MonthlyPDFGenerator shall PDFのタイトルに「月次サマリーレポート (YYYY年MM月)」を含める
3. The MonthlyPDFGenerator shall 全体サマリー、カテゴリー別セクション（カテゴリー名、AIサマリー、ブックマーク詳細）を含める
4. The MonthlyPDFGenerator shall 各カテゴリーセクションを視覚的に区切る（背景色、セパレーター等）
5. If GPTによるサマリー生成が失敗する, then the MonthlyPDFGenerator shall 既存のコンテンツのみでPDFを生成する
6. The MonthlyPDFGenerator shall 生成されたPDFを `data/monthly_report_YYYYMM.pdf` として保存する
7. The MonthlyPDFGenerator shall PDFファイルサイズが25MB以下であることを確認する

### Requirement 5: 月次レポートのメール送信
**Objective:** As a ユーザー, I want 生成された月次PDFレポートをメールで受け取る, so that Kindleや他のデバイスで閲覧できる

#### Acceptance Criteria
1. When PDFレポートが生成完了する, the MonthlyEmailSender shall 指定されたメールアドレスにPDFを添付して送信する
2. The MonthlyEmailSender shall KindleEmailSenderの既存メール送信機能を再利用する
3. The MonthlyEmailSender shall メール件名に「月次サマリーレポート (YYYY年MM月)」を設定する
4. The MonthlyEmailSender shall 複数の送信先メールアドレスをサポートする（カンマ区切り）
5. If メール送信が失敗する, then the MonthlyEmailSender shall 最大3回までリトライする
6. When メール送信が成功する, the MonthlyEmailSender shall 送信履歴をデータベースに記録する

### Requirement 6: 月次レポート設定の管理
**Objective:** As a ユーザー, I want 月次レポートの設定を管理する, so that 自分のニーズに合わせてレポートをカスタマイズできる

#### Acceptance Criteria
1. The MonthlyReportConfig shall スケジュール実行の有効/無効を切り替え可能にする
2. The MonthlyReportConfig shall 送信先メールアドレスリストを保存する
3. The MonthlyReportConfig shall キーワードフィルタ（オプション）を設定可能にする
4. When ユーザーが設定を更新する, the MonthlyReportConfig shall 変更内容をデータベースに永続化する
5. The MonthlyReportConfig shall デフォルト設定（全ブックマーク対象、Kindleメール送信）を提供する

### Requirement 7: 月次レポート実行履歴の記録
**Objective:** As a ユーザー, I want 月次レポートの実行履歴を確認する, so that 過去のレポート生成状況を把握できる

#### Acceptance Criteria
1. The MonthlyReportHistory shall 各実行の開始日時、終了日時、ステータス（成功/失敗）を記録する
2. The MonthlyReportHistory shall 対象期間、生成されたブックマーク数、PDFファイルパスを記録する
3. When レポート生成が失敗する, the MonthlyReportHistory shall エラーメッセージを記録する
4. The MonthlyReportHistory shall 過去12ヶ月分の実行履歴を保持する
5. The MonthlyReportHistory shall Web UIで実行履歴を表示する

### Requirement 8: 手動での月次レポート実行
**Objective:** As a ユーザー, I want 任意のタイミングで月次レポートを手動実行する, so that スケジュール以外でもレポートを生成できる

#### Acceptance Criteria
1. The MonthlyReportUI shall 手動実行ボタンを提供する
2. When ユーザーが手動実行を開始する, the MonthlyReportService shall 対象年月を指定可能にする
3. When 手動実行が開始される, the MonthlyReportUI shall 進捗状況を表示する
4. The MonthlyReportUI shall 既存のProgressPanelとLogPanelを再利用して進捗を表示する
5. When レポート生成が完了する, the MonthlyReportUI shall PDFダウンロードリンクを表示する

### Requirement 9: 既存機能との統合
**Objective:** As a システム, I want 既存のRainpipe機能を最大限再利用する, so that 重複コードを避け保守性を高める

#### Acceptance Criteria
1. The MonthlyReportService shall RaindropClientを使用してブックマークを取得する
2. The MonthlyReportService shall BookmarkCategorizerを使用してカテゴリー分類を実施する
3. The MonthlyReportService shall GPTContentGeneratorを使用してサマリーと分析を生成する
4. The MonthlyReportService shall KeywordPDFGeneratorを使用してPDFをレンダリングする
5. The MonthlyReportService shall KindleEmailSenderを使用してメールを送信する
6. The MonthlyReportService shall 既存のジョブキューシステム（JobQueue）を使用してバックグラウンド実行する
7. The MonthlyReportService shall ProgressReporterとProgressCallbackを使用して進捗を報告する
