# keyword_filtered_pdf_service.rb
#
# KeywordFilteredPDFService - キーワード別 PDF 生成オーケストレーション
#
# 責務:
#   - キーワード入力の検証と正規化（Task 3.2）
#   - RaindropClient を使用したブックマークフィルタリング（Task 3.1）
#   - ContentChecker でサマリー未取得ブックマークを検出（Task 3.3）
#   - キーワード定義の一貫性確保（Task 3.4）
#   - UTC ベース日付処理（Task 3.5）

require 'date'
require_relative 'raindrop_client'
require_relative 'content_checker'
require_relative 'bookmark_summary_generator'
require_relative 'gatherly_batch_fetcher'
require_relative 'gatherly_job_poller'
require_relative 'gatherly_result_merger'
require_relative 'progress_reporter'
require_relative 'progress_callback'

class KeywordFilteredPDFService
  # 初期化
  # @param keywords [String, Array] キーワード（カンマまたは改行区切り、または配列）
  # @param date_start [Date, String] フィルタ開始日（nil の場合は 3 ヶ月前）
  # @param date_end [Date, String] フィルタ終了日（nil の場合は今日）
  # @param progress_callback [ProgressCallback, nil] 進捗更新用コールバック（nil で無視）
  def initialize(keywords:, date_start: nil, date_end: nil, progress_callback: nil)
    @original_keywords = keywords
    @date_start = date_start
    @date_end = date_end
    @progress_callback = progress_callback || ProgressCallback.null_callback

    # Task 3.2: キーワードの正規化
    @normalized_keywords = normalize_keywords(keywords)

    # Task 3.5: UTC ベース日付処理
    @date_range = setup_date_range(date_start, date_end)

    @filtered_bookmarks = []
    @bookmarks_without_summary = []
    @error = nil
  end

  # メインの実行メソッド
  # @return [Hash] { status: 'success' or 'error', bookmarks: [], missing_summaries: [], error: String }
  def execute
    ProgressReporter.progress(nil, "キーワード別 PDF 生成開始", :info)
    ProgressReporter.indented("キーワード: #{@normalized_keywords.join(', ')}")
    ProgressReporter.indented("期間: #{@date_range[:start]} ～ #{@date_range[:end]}")

    # Task 3.1: RaindropClient を使用したフィルタリング
    unless filter_bookmarks_by_keywords_and_date
      ProgressReporter.error("フィルタリング失敗", @error)
      @progress_callback.report_event('error', "フィルタリング失敗: #{@error}")
      return error_result
    end

    # Task 3.3: ContentChecker でサマリー未取得を検出
    detect_missing_summaries

    # Task 3.2: Progress callback に filtering ステージを報告
    @progress_callback.report_stage('filtering', 25, {
      keywords: @normalized_keywords,
      bookmarks_retrieved: @filtered_bookmarks.length,
      date_range: {
        start: @date_range[:start],
        end: @date_range[:end]
      }
    })

    # Task 4.1-4.3: Gatherly で本文取得
    fetch_bookmarks_content_from_gatherly

    # Task 3.2: Progress callback に content_fetching ステージを報告
    bookmarks_with_content = @filtered_bookmarks.select { |b| b['summary'] && !b['summary'].to_s.strip.empty? }
    @progress_callback.report_stage('content_fetching', 40, {
      bookmarks_with_content: bookmarks_with_content.length,
      total_bookmarks: @filtered_bookmarks.length
    })

    # Task 7.1: Gatherly で取得した content から GPT でサマリーを生成
    generate_bookmark_summaries

    # Task 3.2: Progress callback に summarization ステージを報告
    bookmarks_with_summary = @filtered_bookmarks.select { |b| b['summary'] && b['summary'].to_s.strip.length > 10 }
    @progress_callback.report_stage('summarization', 80, {
      bookmarks_summarized: bookmarks_with_summary.length,
      total_bookmarks: @filtered_bookmarks.length
    })

    ProgressReporter.success("全処理完了")

    {
      status: 'success',
      bookmarks: @filtered_bookmarks,
      missing_summaries: @bookmarks_without_summary,
      keywords: @normalized_keywords,
      date_range: @date_range
    }
  end

  # Python PDF生成用にJSON形式でデータを出力
  # @param content [Hash] GPT生成済みのサマリー等を含むコンテンツ
  # @param output_json [String] 出力JSONパス
  def export_for_python_pdf(content, output_json)
    export_data = {
      keywords: @normalized_keywords.join(', '),
      date_range: {
        start: @date_range[:start],
        end: @date_range[:end]
      },
      summary: content[:overall_summary] || content[:summary],
      overall_summary: content[:overall_summary],
      related_clusters: content[:related_clusters] || [],
      analysis: content[:analysis],
      bookmarks: @filtered_bookmarks.map { |b|
        {
          title: b['title'],
          url: b['url'],
          summary: b['summary']
        }
      }
    }

    File.write(output_json, JSON.pretty_generate(export_data))
    puts "💾 JSON 出力: #{output_json}"
  end

  # エラー結果を返す
  def error_result
    {
      status: 'error',
      bookmarks: [],
      missing_summaries: [],
      error: @error
    }
  end

  private

  # Task 3.2: キーワード正規化（トリム、空削除、重複除去）
  def normalize_keywords(keywords)
    # 文字列の場合はカンマまたは改行で分割
    keyword_array = if keywords.is_a?(Array)
                      keywords
                    else
                      keywords.to_s.split(/[,\n]+/)
                    end

    # トリム、空キーワード削除、重複除去
    keyword_array
      .map(&:strip)
      .reject(&:empty?)
      .uniq
  end

  # Task 3.5: UTC ベース日付処理
  def setup_date_range(date_start, date_end)
    # デフォルト値の設定
    start_date = (!date_start.nil? && date_start.to_s.strip != '') ? parse_date(date_start) : Date.today.prev_month(2)
    end_date = (!date_end.nil? && date_end.to_s.strip != '') ? parse_date(date_end) : Date.today

    {
      start: start_date.to_s,
      end: end_date.to_s,
      start_time: Time.parse("#{start_date}T00:00:00Z").utc,
      end_time: Time.parse("#{end_date}T23:59:59Z").utc
    }
  end

  # 日付文字列をパース
  def parse_date(date)
    return date if date.is_a?(Date)
    Date.parse(date.to_s)
  end

  # Task 3.1: RaindropClient を使用したキーワード + 日付範囲フィルタリング
  def filter_bookmarks_by_keywords_and_date
    ProgressReporter.progress(nil, "Raindrop.io からブックマーク取得中", :folder)

    # RaindropClient でブックマークを取得
    client = RaindropClient.new
    start_date = parse_date(@date_range[:start])
    end_date = parse_date(@date_range[:end])

    all_bookmarks = client.get_bookmarks_by_date_range(start_date, end_date)

    # キーワード OR マッチング（title, tags, excerpt）
    @filtered_bookmarks = all_bookmarks.select do |bookmark|
      match_any_keyword?(bookmark)
    end

    # Task 3.1: ログ出力
    ProgressReporter.counter(@filtered_bookmarks.length, all_bookmarks.length, "ブックマークをフィルタ", :folder)

    # キャッシュから以前取得した summary を復元
    restore_cached_summaries(@filtered_bookmarks)

    # エラーチェック
    if @filtered_bookmarks.empty?
      @error = "検索条件に合致するブックマークが見つかりません"
      return false
    end

    ProgressReporter.success("フィルタリング完了: #{@filtered_bookmarks.length} 件")

    true
  end

  # キャッシュ（data/ 内の PDF データ JSON）から summary を復元
  def restore_cached_summaries(bookmarks)
    # pdf_data_*.json ファイルを探す（最新のものから）
    cache_files = Dir.glob(File.join('data', 'pdf_data_*.json')).sort_by { |f| File.mtime(f) }.reverse

    restored_count = 0

    cache_files.each do |cache_file|
      begin
        cached_data = JSON.parse(File.read(cache_file))
        cached_bookmarks = cached_data['bookmarks'] || []

        bookmarks.each do |bookmark|
          bookmark_url = bookmark['url'] || bookmark['link']
          next unless bookmark_url
          next if bookmark['summary'] && bookmark['summary'].to_s.strip.length > 10  # 既に summary がある場合スキップ

          # キャッシュから同じ URL のブックマークを探す
          cached_bookmark = cached_bookmarks.find do |cb|
            cached_url = cb['url'] || cb['link']
            cached_url && bookmark_url == cached_url
          end

          # キャッシュから summary を復元
          if cached_bookmark && cached_bookmark['summary'] && cached_bookmark['summary'].to_s.strip.length > 10
            bookmark['summary'] = cached_bookmark['summary']
            restored_count += 1
          end
        end
      rescue => e
        # キャッシュ読み込み失敗は無視
        next
      end

      # すべてのブックマークが復元できたら終了
      break if bookmarks.all? { |b| b['summary'] && b['summary'].to_s.strip.length > 10 }
    end

    if restored_count > 0
      puts "📥 キャッシュから #{restored_count} 件の summary を復元"
    end
  end

  # キーワードのいずれかに合致するかチェック
  def match_any_keyword?(bookmark)
    # Task 3.4: キーワード定義の一貫性確保
    # フィルタリング時と PDF 出力時で同じキーワード定義を使用
    @normalized_keywords.any? do |keyword|
      searchable_text = [
        bookmark['title'],
        (bookmark['tags'] || []).join(' '),
        bookmark['excerpt']
      ].join(' ').downcase

      searchable_text.include?(keyword.downcase)
    end
  end

  # Task 3.3: ContentChecker でサマリー未取得を検出
  def detect_missing_summaries
    checker = ContentChecker.new
    @bookmarks_without_summary = checker.find_missing_summaries(@filtered_bookmarks)

    count = @bookmarks_without_summary.length
    if count > 0
      ProgressReporter.warning("#{count} 件のブックマークの本文が未取得")
    else
      ProgressReporter.success("すべてのブックマークの本文が取得済み")
    end
  end

  # Task 7.1: フィルタ済みブックマークのサマリー生成
  # Gatherly で取得した content から GPT でサマリーを生成
  # @return [void]
  private

  # Task 4.1-4.3: Gatherly で本文取得
  def fetch_bookmarks_content_from_gatherly
    return if @bookmarks_without_summary.empty?

    ProgressReporter.progress(nil, "Gatherly API で本文取得開始", :globe)

    # Task 4.1: バッチ本文取得ジョブ作成
    batch_fetcher = GatherlyBatchFetcher.new
    batch_result = batch_fetcher.create_batch_jobs(@bookmarks_without_summary)
    job_uuids = batch_result[:job_uuids]

    return if job_uuids.empty?

    ProgressReporter.progress(nil, "ジョブ作成完了: #{job_uuids.length} 件", :info)

    # Task 4.2: ジョブ完了待機
    job_poller = GatherlyJobPoller.new(timeout_seconds: 300)
    polling_result = job_poller.poll_until_completed(job_uuids)
    completed_job_uuids = polling_result[:completed]

    # Note: If Gatherly API is not fully operational, content fetching will be skipped
    # but the pipeline will continue with existing content
    if completed_job_uuids.empty?
      ProgressReporter.warning("Gatherly API ジョブが完了しませんでした（開発環境では API が未実装の可能性があります）")
      ProgressReporter.progress(nil, "既存コンテンツで処理を継続します", :info)
      return
    end

    # Task 4.3: 結果をマージ
    merger = GatherlyResultMerger.new
    merge_result = merger.merge_results(completed_job_uuids, @bookmarks_without_summary)

    # マージ後のブックマークで @filtered_bookmarks を更新
    # @bookmarks_without_summary のマージ結果を @filtered_bookmarks に反映
    merged_bookmarks = merge_result[:merged_bookmarks]
    updated_count = 0

    @filtered_bookmarks.each do |bookmark|
      # URLでマッチング（url または link キーをサポート）
      bookmark_url = bookmark['url'] || bookmark['link']

      merged = merged_bookmarks.find do |b|
        merged_url = b['url'] || b['link']
        merged_url && bookmark_url && merged_url == bookmark_url
      end

      if merged && merged['summary'] && merged['summary'].to_s.strip.length > 10
        bookmark['summary'] = merged['summary']
        updated_count += 1
        ProgressReporter.indented("✓ #{bookmark['title']}: コンテンツ統合")
      end
    end

    ProgressReporter.success("本文取得完了: #{completed_job_uuids.length}/#{job_uuids.length} 成功（#{updated_count} 件統合）")
  end

  def generate_bookmark_summaries
    return if @filtered_bookmarks.empty?

    ProgressReporter.progress(nil, "ブックマークサマリー生成開始", :loop)

    # Gatherly から取得した content (summary フィールドに入っている) を確認
    bookmarks_with_content = @filtered_bookmarks.select { |b| b['summary'] && !b['summary'].to_s.strip.empty? }

    if bookmarks_with_content.empty?
      ProgressReporter.warning("コンテンツを持つブックマークがありません。サマリー生成をスキップ")
      return
    end

    # Gatherly から取得した本文を GPT でサマリーしていく
    gpt_generator = GPTContentGenerator.new(ENV['OPENAI_API_KEY'], false)

    bookmarks_with_content.each_with_index do |bookmark, idx|
      begin
        content = bookmark['summary']
        # Gatherlyから取得した本文をGPTでサマリー化
        summary = gpt_generator.generate_bookmark_summary(content)

        if summary && summary.to_s.strip.length > 10
          bookmark['summary'] = summary
          ProgressReporter.counter(idx + 1, bookmarks_with_content.length, "サマリー生成: #{bookmark['title'][0..50]}...", :loop)
        else
          ProgressReporter.warning("[#{idx + 1}/#{bookmarks_with_content.length}] サマリー生成失敗: #{bookmark['title'][0..50]}...")
        end
      rescue => e
        ProgressReporter.error("[#{idx + 1}/#{bookmarks_with_content.length}] エラー", e.message)
      end
    end

    ProgressReporter.success("サマリー生成完了: #{bookmarks_with_content.length} 件")
  end
end
