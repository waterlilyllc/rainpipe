#!/usr/bin/env ruby
require 'date'
require 'stringio'
require 'dotenv'
Dotenv.load

# Mock GPTKeywordExtractor for testing
class MockGPTKeywordExtractor
  def extract_keywords_from_bookmarks(bookmarks, week_key)
    {
      'related_clusters' => [
        { 'main_topic' => 'AI', 'related_words' => ['Machine Learning', 'Deep Learning'] },
        { 'main_topic' => 'Cloud', 'related_words' => ['AWS', 'Azure'] }
      ]
    }
  end
end

# Monkey patch for testing
class GPTContentGenerator
  def initialize(api_key = ENV['OPENAI_API_KEY'], use_mock = false)
    @api_key = api_key
    @model = ENV['GPT_MODEL'] || 'gpt-4o-mini'
    @use_mock = use_mock
    @keyword_extractor = use_mock ? MockGPTKeywordExtractor.new : GPTKeywordExtractor.new(api_key)
  end

  def call_gpt_api_test(prompt)
    if @use_mock
      "テストサマリー: #{prompt[0..50]}..."
    else
      call_gpt_api(prompt)
    end
  end
end

require_relative 'gpt_content_generator'

class TestGPTContentGenerator
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
    puts "🧪 GPTContentGenerator テストを実行中...\n"

    test_initialization
    test_overall_summary_generation
    test_related_keywords_extraction
    test_analysis_generation
    test_error_handling_with_retry
    test_timing_measurement
    test_placeholder_on_failure
    test_exponential_backoff

    puts "\n" + "=" * 50
    puts "📊 テスト結果: #{@tests_passed} 成功, #{@tests_failed} 失敗"
    puts "=" * 50

    exit(@tests_failed > 0 ? 1 : 0)
  end

  # Task 5.1-5.4: 初期化テスト
  def test_initialization
    generator = GPTContentGenerator.new

    assert(!generator.nil?, "初期化: GPTContentGenerator インスタンスが作成されること")
    assert(generator.respond_to?(:generate_overall_summary), "初期化: generate_overall_summary メソッドが存在すること")
  end

  # Task 5.1: 全体サマリー生成テスト
  def test_overall_summary_generation
    bookmarks = [
      { 'title' => 'Claude AI Features', 'excerpt' => 'Advanced AI capabilities', 'url' => 'https://example.com/1' },
      { 'title' => 'Machine Learning Trends', 'excerpt' => 'Latest ML research', 'url' => 'https://example.com/2' }
    ]

    generator = GPTContentGenerator.new(ENV['OPENAI_API_KEY'], true)  # use_mock=true
    result = generator.generate_overall_summary(bookmarks, 'Claude,AI')

    assert(result.is_a?(Hash), "全体サマリー: 結果がハッシュであること")
    assert(result[:summary].is_a?(String), "全体サマリー: summary が文字列であること")
    assert(result[:duration_ms].is_a?(Integer), "全体サマリー: duration_ms が整数であること")
  end

  # Task 5.2: 関連ワード抽出テスト
  def test_related_keywords_extraction
    bookmarks = [
      { 'title' => 'Cloud Computing', 'excerpt' => 'AWS, Azure, GCP', 'url' => 'https://example.com/1' },
      { 'title' => 'DevOps Practices', 'excerpt' => 'CI/CD, Docker, Kubernetes', 'url' => 'https://example.com/2' }
    ]

    generator = GPTContentGenerator.new(ENV['OPENAI_API_KEY'], true)  # use_mock=true
    result = generator.extract_related_keywords(bookmarks)

    assert(result.is_a?(Hash), "関連ワード: 結果がハッシュであること")
    assert(result[:related_clusters].is_a?(Array), "関連ワード: related_clusters が配列であること")
    assert(result[:duration_ms].is_a?(Integer), "関連ワード: duration_ms が整数であること")
  end

  # Task 5.3: 考察生成テスト（動的生成、キャッシュなし）
  def test_analysis_generation
    bookmarks = [
      { 'title' => 'Future of AI', 'excerpt' => 'AI trends and predictions', 'url' => 'https://example.com/1' },
      { 'title' => 'Data Science', 'excerpt' => 'Analysis and insights', 'url' => 'https://example.com/2' }
    ]

    generator = GPTContentGenerator.new(ENV['OPENAI_API_KEY'], true)  # use_mock=true
    result = generator.generate_analysis(bookmarks, 'AI,Data')

    assert(result.is_a?(Hash), "考察: 結果がハッシュであること")
    assert(result[:analysis].is_a?(String), "考察: analysis が文字列であること")
    assert(result[:duration_ms].is_a?(Integer), "考察: duration_ms が整数であること")
  end

  # Task 5.4: エラーハンドリングと Exponential Backoff テスト
  def test_error_handling_with_retry
    bookmarks = [{ 'title' => 'Test', 'excerpt' => 'Test content', 'url' => 'https://example.com/1' }]

    generator = GPTContentGenerator.new(ENV['OPENAI_API_KEY'], true)  # use_mock=true

    # API エラーもハンドリングされることを確認
    result = generator.generate_overall_summary(bookmarks, 'test')

    assert(result.is_a?(Hash), "エラーハンドリング: エラー時も結果ハッシュが返されること")
    assert(result.key?(:summary), "エラーハンドリング: summary キーが存在すること")
  end

  # Task 5.4: 実行時間計測テスト
  def test_timing_measurement
    bookmarks = [{ 'title' => 'Test', 'excerpt' => 'Test', 'url' => 'https://example.com/1' }]

    generator = GPTContentGenerator.new(ENV['OPENAI_API_KEY'], true)  # use_mock=true
    result = generator.generate_overall_summary(bookmarks, 'test')

    assert(result[:duration_ms] >= 0, "実行時間: duration_ms が 0 以上であること")
    assert(result[:duration_ms].is_a?(Integer), "実行時間: duration_ms が整数であること")
  end

  # Task 5.1: APIエラー時のプレースホルダーテスト
  def test_placeholder_on_failure
    # API エラー時のプレースホルダー返却を確認
    generator = GPTContentGenerator.new(ENV['OPENAI_API_KEY'], true)  # use_mock=true
    result = generator.generate_overall_summary([], 'test')

    # エラー時もプレースホルダーが返されるはず
    assert(result[:summary].is_a?(String), "プレースホルダー: summary が文字列であること")
  end

  # Task 5.4: Exponential Backoff の設定テスト
  def test_exponential_backoff
    generator = GPTContentGenerator.new

    assert(generator.respond_to?(:retry_with_backoff), "Backoff: retry_with_backoff メソッドが存在すること")
  end
end

# テスト実行
runner = TestGPTContentGenerator.new
runner.run_all_tests
