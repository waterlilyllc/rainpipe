#!/usr/bin/env ruby
require 'date'
require 'dotenv'
Dotenv.load

require_relative 'bookmark_summary_generator'

class TestBookmarkSummaryGenerator
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
    puts "🧪 BookmarkSummaryGenerator テストを実行中...\n"

    test_initialization
    test_single_bookmark_summary
    test_multiple_bookmarks_summary
    test_empty_content_handling
    test_batch_processing
    test_timing_measurement
    test_error_handling
    test_mock_mode

    puts "\n" + "=" * 50
    puts "📊 テスト結果: #{@tests_passed} 成功, #{@tests_failed} 失敗"
    puts "=" * 50

    exit(@tests_failed > 0 ? 1 : 0)
  end

  # Task 7.1: 初期化テスト
  def test_initialization
    generator = BookmarkSummaryGenerator.new(ENV['OPENAI_API_KEY'], true)
    assert(!generator.nil?, "初期化: BookmarkSummaryGenerator インスタンスが作成されること")
    assert(generator.respond_to?(:generate_summaries), "初期化: generate_summaries メソッドが存在すること")
  end

  # Task 7.1: 単一ブックマークのサマリー生成テスト
  def test_single_bookmark_summary
    bookmarks = [
      {
        'title' => 'Claude AI Features',
        'url' => 'https://example.com/1',
        'content' => 'Claude is an advanced AI assistant with multimodal capabilities, supporting text, image, and file analysis.'
      }
    ]

    generator = BookmarkSummaryGenerator.new(ENV['OPENAI_API_KEY'], true)
    result = generator.generate_summaries(bookmarks)

    assert(result.is_a?(Hash), "単一ブックマーク: 結果がハッシュであること")
    assert(result[:summaries].is_a?(Array), "単一ブックマーク: summaries が配列であること")
    assert(result[:summaries].length == 1, "単一ブックマーク: 1 件のサマリーが生成されること")
    assert(result[:duration_ms].is_a?(Integer), "単一ブックマーク: duration_ms が整数であること")
  end

  # Task 7.1: 複数ブックマークのサマリー生成テスト
  def test_multiple_bookmarks_summary
    bookmarks = [
      {
        'title' => 'Machine Learning Basics',
        'url' => 'https://example.com/1',
        'content' => 'Machine learning is a subset of AI that enables systems to learn from data without being explicitly programmed.'
      },
      {
        'title' => 'Deep Learning Advances',
        'url' => 'https://example.com/2',
        'content' => 'Deep learning uses neural networks with multiple layers to process complex patterns in data.'
      },
      {
        'title' => 'Transformer Models',
        'url' => 'https://example.com/3',
        'content' => 'Transformers are a breakthrough architecture that powers modern NLP systems and large language models.'
      }
    ]

    generator = BookmarkSummaryGenerator.new(ENV['OPENAI_API_KEY'], true)
    result = generator.generate_summaries(bookmarks)

    assert(result[:summaries].length == 3, "複数ブックマーク: 3 件のサマリーが生成されること")
    assert(result[:success_count] == 3, "複数ブックマーク: 3 件すべて成功していること")
  end

  # Task 7.1: 空のコンテンツ処理テスト
  def test_empty_content_handling
    bookmarks = [
      {
        'title' => 'Empty Content Bookmark',
        'url' => 'https://example.com/1',
        'content' => nil
      },
      {
        'title' => 'Valid Content',
        'url' => 'https://example.com/2',
        'content' => 'This is valid content for summarization.'
      }
    ]

    generator = BookmarkSummaryGenerator.new(ENV['OPENAI_API_KEY'], true)
    result = generator.generate_summaries(bookmarks)

    # 空のコンテンツはスキップされるので、1 件のサマリーのみ返される
    assert(result[:summaries].length == 1, "空コンテンツ: 1 件のサマリーが返されること（空のコンテンツはスキップ）")
    assert(result[:failure_count] >= 1, "空コンテンツ: 失敗件数が記録されること")
  end

  # Task 7.1: バッチ処理テスト
  def test_batch_processing
    bookmarks = (1..55).map { |i|
      {
        'title' => "Article #{i}",
        'url' => "https://example.com/#{i}",
        'content' => "Content for article #{i} with relevant information."
      }
    }

    generator = BookmarkSummaryGenerator.new(ENV['OPENAI_API_KEY'], true)
    result = generator.generate_summaries(bookmarks)

    assert(result[:summaries].length == 55, "バッチ処理: 55 件すべてのサマリーが生成されること")
  end

  # Task 7.1: 実行時間計測テスト
  def test_timing_measurement
    bookmarks = [
      {
        'title' => 'Test Article',
        'url' => 'https://example.com/1',
        'content' => 'Test content for timing measurement.'
      }
    ]

    generator = BookmarkSummaryGenerator.new(ENV['OPENAI_API_KEY'], true)
    result = generator.generate_summaries(bookmarks)

    assert(result[:duration_ms] >= 0, "実行時間: duration_ms が 0 以上であること")
    assert(result[:duration_ms].is_a?(Integer), "実行時間: duration_ms が整数であること")
  end

  # Task 7.1: エラーハンドリングテスト
  def test_error_handling
    bookmarks = [
      {
        'title' => 'Test',
        'url' => 'https://example.com/1',
        'content' => 'Test content'
      }
    ]

    generator = BookmarkSummaryGenerator.new(ENV['OPENAI_API_KEY'], true)
    result = generator.generate_summaries(bookmarks)

    assert(result.is_a?(Hash), "エラーハンドリング: エラー時も結果ハッシュが返されること")
    assert(result.key?(:summaries), "エラーハンドリング: summaries キーが存在すること")
    assert(result.key?(:success_count), "エラーハンドリング: success_count キーが存在すること")
    assert(result.key?(:failure_count), "エラーハンドリング: failure_count キーが存在すること")
  end

  # Task 7.1: モック モード テスト
  def test_mock_mode
    bookmarks = [
      {
        'title' => 'Mock Test',
        'url' => 'https://example.com/1',
        'content' => 'Mock content for testing.'
      }
    ]

    generator = BookmarkSummaryGenerator.new(ENV['OPENAI_API_KEY'], true)
    result = generator.generate_summaries(bookmarks)

    assert(result[:summaries].first.is_a?(String), "モックモード: サマリーが文字列であること")
    assert(result[:summaries].first.length > 0, "モックモード: サマリーが空でないこと")
  end
end

# テスト実行
runner = TestBookmarkSummaryGenerator.new
runner.run_all_tests
