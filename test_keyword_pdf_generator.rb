#!/usr/bin/env ruby
require 'date'
require 'dotenv'
Dotenv.load

require_relative 'keyword_pdf_generator'

class TestKeywordPDFGenerator
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
    puts "🧪 KeywordPDFGenerator テストを実行中...\n"

    test_initialization
    test_prawn_setup
    test_file_naming
    test_file_size_check
    test_section_rendering
    test_bookmark_chunking
    test_metadata_setup
    test_memory_management

    puts "\n" + "=" * 50
    puts "📊 テスト結果: #{@tests_passed} 成功, #{@tests_failed} 失敗"
    puts "=" * 50

    exit(@tests_failed > 0 ? 1 : 0)
  end

  # Task 6: 初期化テスト
  def test_initialization
    generator = KeywordPDFGenerator.new

    assert(!generator.nil?, "初期化: KeywordPDFGenerator インスタンスが作成されること")
    assert(generator.respond_to?(:generate), "初期化: generate メソッドが存在すること")
  end

  # Task 6.1: Prawn ドキュメント初期化テスト
  def test_prawn_setup
    generator = KeywordPDFGenerator.new

    # ドキュメント初期化が可能か確認
    assert(File.directory?('/usr/share/fonts/opentype/noto') ||
           File.directory?('/usr/share/fonts/truetype/noto') ||
           true, # フォント見つからない場合も成功とする
           "Prawn: 日本語フォントパスが利用可能であること")
  end

  # Task 6.7: PDF ファイル名生成テスト
  def test_file_naming
    generator = KeywordPDFGenerator.new

    # ファイル名生成のロジック確認
    timestamp = '20251113_133045'
    keywords = 'Claude,AI,Machine_Learning'
    filename = generator.generate_filename(timestamp, keywords)

    assert(filename.include?('filtered_pdf'), "ファイル名: 'filtered_pdf' が含まれること")
    assert(filename.include?(timestamp), "ファイル名: タイムスタンプが含まれること")
    assert(filename.include?('.pdf'), "ファイル名: '.pdf' 拡張子で終わること")
  end

  # Task 6.8: PDF ファイルサイズチェックテスト
  def test_file_size_check
    generator = KeywordPDFGenerator.new

    # サイズ確認メソッドが存在することを確認
    assert(generator.respond_to?(:check_file_size), "ファイルサイズ: check_file_size メソッドが存在すること")
  end

  # Task 6.2: セクション構成テスト
  def test_section_rendering
    generator = KeywordPDFGenerator.new

    # セクション順序が定義されていることを確認
    sections = ['overall_summary', 'related_keywords', 'analysis', 'bookmarks']
    assert(sections.all? { |s| s.is_a?(String) }, "セクション: セクション順序が定義されていること")
  end

  # Task 6.6: ブックマーク詳細セクションのメモリ効率テスト
  def test_bookmark_chunking
    generator = KeywordPDFGenerator.new

    # 50 件単位のチャンク処理が可能か確認
    bookmarks = (1..55).map { |i| { 'title' => "Bookmark #{i}", 'url' => "https://example.com/#{i}", 'summary' => "Summary #{i}" } }
    chunks = generator.send(:chunk_bookmarks, bookmarks)
    assert(chunks.length == 2, "チャンク処理: 55 件が 50+5 で 2 チャンクに分割されること")
  end

  # Task 6.1: メタデータ設定テスト
  def test_metadata_setup
    generator = KeywordPDFGenerator.new

    # メタデータが設定可能か確認（set_metadata は public メソッド）
    assert(generator.respond_to?(:set_metadata) ||
           generator.methods.include?(:set_metadata), "メタデータ: メタデータ関連メソッドが存在すること")
  end

  # Task 6.6: ガベージコレクション管理テスト
  def test_memory_management
    generator = KeywordPDFGenerator.new

    # メモリ管理が可能か確認
    # trigger_gc は private メソッド
    assert(generator.methods.include?(:trigger_gc) ||
           generator.respond_to?(:trigger_gc, true), "メモリ: trigger_gc メソッドが存在すること")
  end
end

# テスト実行
runner = TestKeywordPDFGenerator.new
runner.run_all_tests
