#!/usr/bin/env ruby
require 'date'
require_relative 'keyword_filtered_pdf_service'
require_relative 'content_checker'

class TestKeywordFilteredPDFService
  def initialize
    @tests_passed = 0
    @tests_failed = 0
  end

  def assert(condition, message)
    if condition
      @tests_passed += 1
      puts "✓ #{message}"
    else
      @tests_failed += 1
      puts "✗ #{message}"
    end
  end

  def run_all_tests
    puts "🧪 KeywordFilteredPDFService テストを実行中...\n"

    test_keyword_normalization
    test_keyword_normalization_with_array
    test_keyword_normalization_empty
    test_date_range_default
    test_date_range_custom
    test_content_checker_present
    test_content_checker_missing
    test_content_checker_empty_string
    test_service_initialization
    test_keyword_consistency

    puts "\n" + "=" * 50
    puts "📊 テスト結果: #{@tests_passed} 成功, #{@tests_failed} 失敗"
    puts "=" * 50

    exit(@tests_failed > 0 ? 1 : 0)
  end

  def test_keyword_normalization
    # Task 3.2: カンマ区切りのキーワード正規化
    service = KeywordFilteredPDFService.new(keywords: "Claude, AI, 機械学習")
    assert(service.instance_variable_get(:@normalized_keywords) == ["Claude", "AI", "機械学習"],
           "カンマ区切りキーワードが正規化されること")
  end

  def test_keyword_normalization_with_array
    # Task 3.2: 配列形式のキーワード正規化
    service = KeywordFilteredPDFService.new(keywords: ["Claude", "AI"])
    assert(service.instance_variable_get(:@normalized_keywords) == ["Claude", "AI"],
           "配列形式のキーワードが正規化されること")
  end

  def test_keyword_normalization_empty
    # Task 3.2: 空キーワード削除
    service = KeywordFilteredPDFService.new(keywords: " Claude , , AI ")
    normalized = service.instance_variable_get(:@normalized_keywords)
    assert(normalized == ["Claude", "AI"] && !normalized.include?(""),
           "空のキーワードが削除されること")
  end

  def test_date_range_default
    # Task 3.5: デフォルト日付範囲（3 ヶ月前～今日）
    service = KeywordFilteredPDFService.new(keywords: "Claude")
    date_range = service.instance_variable_get(:@date_range)

    # 3 ヶ月前の日付を計算
    three_months_ago = Date.today.prev_month(2).to_s
    today = Date.today.to_s

    assert(date_range[:start] == three_months_ago && date_range[:end] == today,
           "デフォルト日付範囲が 3 ヶ月前～今日であること")
  end

  def test_date_range_custom
    # Task 3.5: カスタム日付範囲
    service = KeywordFilteredPDFService.new(
      keywords: "Claude",
      date_start: "2025-10-01",
      date_end: "2025-11-01"
    )
    date_range = service.instance_variable_get(:@date_range)

    assert(date_range[:start] == "2025-10-01" && date_range[:end] == "2025-11-01",
           "カスタム日付範囲が設定されること")
  end

  def test_content_checker_present
    # Task 3.3: サマリー有り
    bookmarks = [
      { 'id' => 1, 'title' => 'Test', 'summary' => 'This is a summary' },
      { 'id' => 2, 'title' => 'Test 2', 'content' => 'This is content' }
    ]

    checker = ContentChecker.new
    missing = checker.find_missing_summaries(bookmarks)

    assert(missing.empty?, "サマリーがあるブックマークは未取得リストに含まれないこと")
  end

  def test_content_checker_missing
    # Task 3.3: サマリー無し
    bookmarks = [
      { 'id' => 1, 'title' => 'Test', 'summary' => nil },
      { 'id' => 2, 'title' => 'Test 2' },
      { 'id' => 3, 'title' => 'Test 3', 'summary' => 'This is a summary' }
    ]

    checker = ContentChecker.new
    missing = checker.find_missing_summaries(bookmarks)

    assert(missing.length == 2, "サマリーが nil のブックマークが未取得として検出されること")
  end

  def test_content_checker_empty_string
    # Task 3.3: 空文字列のサマリー
    bookmarks = [
      { 'id' => 1, 'title' => 'Test', 'summary' => '   ' },  # 空白のみ
      { 'id' => 2, 'title' => 'Test 2', 'summary' => 'Valid' }
    ]

    checker = ContentChecker.new
    missing = checker.find_missing_summaries(bookmarks)

    assert(missing.length == 1, "空白のみのサマリーが未取得として検出されること")
  end

  def test_service_initialization
    # Service が初期化できること
    service = KeywordFilteredPDFService.new(keywords: "Claude")
    assert(!service.nil?, "KeywordFilteredPDFService が初期化されること")
  end

  def test_keyword_consistency
    # Task 3.4: キーワード定義の一貫性確保
    service1 = KeywordFilteredPDFService.new(keywords: " Claude , AI, 機械学習 ")
    service2 = KeywordFilteredPDFService.new(keywords: ["Claude", "AI", "機械学習"])

    keywords1 = service1.instance_variable_get(:@normalized_keywords)
    keywords2 = service2.instance_variable_get(:@normalized_keywords)

    assert(keywords1 == keywords2, "異なる入力形式でも正規化後のキーワードが一致すること")
  end
end

# テスト実行
runner = TestKeywordFilteredPDFService.new
runner.run_all_tests
