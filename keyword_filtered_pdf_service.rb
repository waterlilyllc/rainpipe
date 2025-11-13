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

class KeywordFilteredPDFService
  # 初期化
  # @param keywords [String, Array] キーワード（カンマまたは改行区切り、または配列）
  # @param date_start [Date, String] フィルタ開始日（nil の場合は 3 ヶ月前）
  # @param date_end [Date, String] フィルタ終了日（nil の場合は今日）
  def initialize(keywords:, date_start: nil, date_end: nil)
    @original_keywords = keywords
    @date_start = date_start
    @date_end = date_end

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
    puts "🔍 キーワード別 PDF 生成開始"
    puts "📝 キーワード: #{@normalized_keywords.join(', ')}"
    puts "📅 期間: #{@date_range[:start]} ～ #{@date_range[:end]}"

    # Task 3.1: RaindropClient を使用したフィルタリング
    unless filter_bookmarks_by_keywords_and_date
      return error_result
    end

    # Task 3.3: ContentChecker でサマリー未取得を検出
    detect_missing_summaries

    {
      status: 'success',
      bookmarks: @filtered_bookmarks,
      missing_summaries: @bookmarks_without_summary,
      keywords: @normalized_keywords,
      date_range: @date_range
    }
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
    puts "📅 期間: #{@date_range[:start]} ～ #{@date_range[:end]}"
    puts "📚 #{@filtered_bookmarks.length} 件のブックマークをフィルタ"

    # エラーチェック
    if @filtered_bookmarks.empty?
      @error = "検索条件に合致するブックマークが見つかりません"
      return false
    end

    true
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
      puts "⚠️  #{count} 件のブックマークのサマリーが未取得"
    else
      puts "✅ すべてのブックマークのサマリーが取得済み"
    end
  end
end
