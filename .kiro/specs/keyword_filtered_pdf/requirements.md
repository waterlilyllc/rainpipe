# Requirements Document - Keyword Filtered PDF

## Project Description (Input)
特定のワードに絞ったブックマークでPDFを作成する機能

## Introduction
Rainpipe ブックマーク管理システムにおいて、ユーザーが特定のキーワードで絞ったブックマークを PDF 形式で生成・配布できる機能を実装する。現在の週次 Kindle 配信は全ブックマークを対象としているため、特定トピックに限定したレポート生成により、関心領域に焦点を当てた情報提供が可能になる。

## Requirements

### Requirement 1: キーワード入力インターフェース
**Objective:** ユーザーとして、検索対象のキーワードを複数入力できる方法を得たい。これにより、関心のある特定トピックに限定したレポートを生成できる。

#### Acceptance Criteria
1. When ユーザーが PDF 生成画面にアクセスした時、PDF Generation Service は キーワード入力フォームを表示する
2. When ユーザーが複数のキーワードを入力した時、PDF Generation Service は 全キーワードを受け取る
3. The PDF Generation Service shall キーワードの空白を許容する（オプション検索）
4. The PDF Generation Service shall 入力されたキーワードをトリム処理する

### Requirement 2: ブックマークフィルタリングと準備
**Objective:** ユーザーとして、入力したキーワードに該当するブックマークのみを取得したい。また、PDF生成前にすべてのブックマークのサマリーが揃っていることを確認したい。

#### Acceptance Criteria
1. When PDF 生成が開始された時、PDF Generation Service は キーワードに基づいてブックマークをフィルタリングする
2. When ブックマークのタイトル・タグ・説明いずれかにキーワードが含まれている場合、PDF Generation Service は そのブックマークを対象に含める
3. If キーワードが複数指定されている場合、PDF Generation Service は OR 条件でマッチングを行う（いずれかのキーワードに合致するもの）
4. The PDF Generation Service shall フィルタ済みブックマークの件数をログに記録する
5. If フィルタ後のブックマークが 0 件の場合、PDF Generation Service は ユーザーに警告を表示する
6. The PDF Generation Service shall デフォルトで過去３ヶ月のブックマークを対象とする
7. When ユーザーが日付範囲を指定した時、PDF Generation Service は 指定範囲内のブックマークをフィルタリングする
8. The PDF Generation Service shall フィルタリング対象期間をレポートに表示する

### Requirement 2-1: サマリー準備
**Objective:** PDF 生成前に、すべてのフィルタ済みブックマークのサマリーが揃っていることを確認し、不足分を取得したい。これにより、PDF に完全な情報を含められる。

#### Acceptance Criteria
1. When フィルタリング完了直後、PDF Generation Service は フィルタ済みブックマークの全件についてサマリー有無を確認する
2. If サマリーが取得されていないブックマークが存在する場合、PDF Generation Service は Gatherly API を通じて本文取得ジョブを作成する
3. The PDF Generation Service shall 本文取得ジョブが完了するまで待機する（タイムアウト：最大 5 分）
4. The PDF Generation Service shall サマリー取得状況（成功・失敗）をログに記録する
5. If タイムアウト後もサマリーが取得できないブックマークがある場合、PDF Generation Service は「サマリー未取得」として処理を継続する
6. The PDF Generation Service shall 本文取得完了後、フィルタ済みブックマークのサマリー生成を実行する
7. The PDF Generation Service shall サマリー生成完了まで PDF ファイルの生成を開始しない

### Requirement 3: PDF 構成とコンテンツ生成
**Objective:** ユーザーとして、フィルタ済みブックマークを整形済み PDF として出力したい。週次レポートと同様の構成で、全体的な洞察と関連情報を含めることで、より深い理解が得られる。

#### Acceptance Criteria
1. When フィルタリングが完了した時、PDF Generation Service は PDF ファイルを生成する
2. The PDF Generation Service shall PDF に以下のセクションを含める（順序：全体サマリー → 関連ワード → 考察 → ブックマーク詳細）
3. The PDF Generation Service shall フィルタ済みブックマークのタイトル・URL・要約を含める
4. The PDF Generation Service shall PDF ファイル名に生成日時とキーワードを含める（例: filtered_pdf_20251113_Claude.pdf）
5. While PDF 生成処理が実行中である時、PDF Generation Service は 進捗状況をユーザーに表示する
6. If PDF 生成に失敗した場合、PDF Generation Service は エラーメッセージを表示して失敗の理由を記載する

### Requirement 3-1: 全体サマリーセクション
**Objective:** ユーザーとして、フィルタ済みブックマークの全体的な傾向や洞察を得たい。

#### Acceptance Criteria
1. The PDF Generation Service shall GPT による分析を実行してキーワード領域の全体サマリーを生成する
2. The PDF Generation Service shall サマリーには、該当キーワード領域の傾向・重要なポイント・実用的な洞察を含める
3. The PDF Generation Service shall 生成したサマリーを「全体サマリー」セクションとしてレポート冒頭に配置する

### Requirement 3-2: 関連ワード抽出
**Objective:** ユーザーとして、メインキーワード以外の関連トピックや周辺キーワードを認識したい。これにより、発見的な閲覧が可能になる。

#### Acceptance Criteria
1. The PDF Generation Service shall GPT Keyword Extractor を使用して related_clusters を抽出する
2. The PDF Generation Service shall 関連ワード（周辺キーワード）を「関連ワード」セクションとして表示する
3. The PDF Generation Service shall 関連ワードは main_topic と related_words の形式で表示する
4. The PDF Generation Service shall 関連ワードセクションを全体サマリーの直後に配置する

### Requirement 3-3: 考察セクション
**Objective:** ユーザーとして、フィルタ済みブックマークセットに対する深掘り分析を得たい。

#### Acceptance Criteria
1. The PDF Generation Service shall GPT による考察を生成し、キーワード領域での今後の注目点・実装への示唆・ベストプラクティスを含める
2. The PDF Generation Service shall 考察セクションを「今週の考察」または「分析と推奨」として配置する
3. The PDF Generation Service shall 考察は実行時に動的に生成する（キャッシュ不可）
4. The PDF Generation Service shall 考察セクションをブックマーク詳細の直前に配置する

### Requirement 4: ファイル出力
**Objective:** ユーザーとして、生成された PDF をダウンロード、またはメール送信できたい。これにより、柔軟な配布が可能になる。

#### Acceptance Criteria
1. The PDF Generation Service shall ユーザーにダウンロードオプションを提供する
2. When ユーザーが Kindle 送信を選択した時、PDF Generation Service は Kindle Email Service と連携して PDF を送信する
3. The PDF Generation Service shall メール送信完了後、確認メッセージを表示する
4. If ファイルサイズが制限を超えた場合、PDF Generation Service は 警告を表示する

### Requirement 5: データ品質
**Objective:** システムとして、フィルタリングと PDF 生成が一貫性を持つ必要がある。これにより、ユーザーが信頼できるレポートを取得できる。

#### Acceptance Criteria
1. The PDF Generation Service shall フィルタリング時と PDF 出力時で同じキーワード定義を使用する
2. The PDF Generation Service shall ブックマークの要約がない場合でも PDF を生成する（要約なしマークを表示）
3. The PDF Generation Service shall 生成ログを記録して監査可能にする
4. When タイムゾーンが異なる環境で実行された時、PDF Generation Service は UTC ベースで統一する

### Requirement 6: 実行モデル
**Objective:** ユーザーとして、必要な時だけオンデマンドで PDF 生成を実行したい。これにより、柔軟で効率的なレポート生成が可能になる。

#### Acceptance Criteria
1. The PDF Generation Service shall ワンショット実行（手動トリガー）をサポートする
2. When ユーザーが PDF 生成ボタンをクリックした時、PDF Generation Service は 即座に処理を開始する
3. The PDF Generation Service shall バッチスケジュール実行には対応しない（自動定期実行なし）
4. The PDF Generation Service shall 生成履歴を記録して、過去の実行状況を確認できるようにする
5. The PDF Generation Service shall 同時実行を制限し、前の生成が完了していない場合は警告を表示する

### Requirement 7: パフォーマンス
**Objective:** システムとして、大量のブックマーク数でも応答性を失わない必要がある。

#### Acceptance Criteria
1. The PDF Generation Service shall 1000 件以下のブックマークは 10 秒以内に処理する
2. While 大量のブックマークを処理している時、PDF Generation Service は メモリ効率的にストリーミング処理を行う
3. The PDF Generation Service shall 処理時間をログに記録する

---

## Requirements Verification Checklist
- [ ] キーワード入力が正しく機能するか
- [ ] フィルタリング結果が期待通りか（３ヶ月デフォルト、カスタム範囲対応）
- [ ] PDF 生成前にサマリーなし記事が検出されるか
- [ ] 本文取得ジョブが正常に作成・完了するか
- [ ] サマリー生成が PDF 生成前に完了しているか
- [ ] タイムアウト（５分）の仕組みが機能するか
- [ ] 全体サマリーが動的に生成されるか
- [ ] 関連ワード（周辺キーワード）が抽出・表示されるか
- [ ] 考察セクションが実行時に生成されるか
- [ ] PDF セクション順序が正しいか（サマリー → 関連ワード → 考察 → 詳細）
- [ ] PDF ファイルが正常に生成されるか
- [ ] PDF ファイル名が適切か
- [ ] Kindle 送信が正常に動作するか
- [ ] ワンショット実行（手動トリガー）が機能するか
- [ ] エラーハンドリングが適切か
- [ ] パフォーマンスが許容範囲か
