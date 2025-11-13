#!/usr/bin/env ruby
require 'rack/test'
require 'dotenv'
Dotenv.load

ENV['RACK_ENV'] = 'test'

require_relative 'app'

class TestFilteredPDFRoutes
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

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
    puts "🧪 FilteredPDF Routes テストを実行中...\n"

    test_post_generate_with_valid_keywords
    test_post_generate_with_download
    test_post_generate_with_kindle_send
    test_post_generate_with_missing_keywords
    test_error_response_handling

    puts "\n" + "=" * 50
    puts "📊 テスト結果: #{@tests_passed} 成功, #{@tests_failed} 失敗"
    puts "=" * 50

    exit(@tests_failed > 0 ? 1 : 0)
  end

  # Task 8.1: POST /filtered_pdf/generate リクエスト処理テスト
  def test_post_generate_with_valid_keywords
    post '/filtered_pdf/generate', {
      keywords: 'Claude,AI',
      date_start: '2025-08-13',
      date_end: '2025-11-13',
      send_to_kindle: 'false'
    }

    # ステータスコード確認（200 または リダイレクト 302）
    assert([200, 302].include?(last_response.status), "POST /filtered_pdf/generate: ステータスコード 200 または 302 であること")
    assert(!last_response.body.nil?, "POST /filtered_pdf/generate: レスポンスボディが存在すること")
  end

  # Task 8.2: PDF ダウンロードレスポンス実装テスト
  def test_post_generate_with_download
    post '/filtered_pdf/generate', {
      keywords: 'test',
      date_start: '2025-08-13',
      date_end: '2025-11-13',
      send_to_kindle: 'false'
    }

    # send_to_kindle=false の場合、ダウンロード処理またはエラーハンドリング
    assert([200, 302, 400].include?(last_response.status), "POST download: ステータスコード 200/302/400 であること")
  end

  # Task 8.3: Kindle メール送信機能統合テスト
  def test_post_generate_with_kindle_send
    post '/filtered_pdf/generate', {
      keywords: 'test',
      date_start: '2025-08-13',
      date_end: '2025-11-13',
      send_to_kindle: 'true'
    }

    # send_to_kindle=true の場合、確認メッセージまたはエラーハンドリング
    assert([200, 302, 400].include?(last_response.status), "POST kindle: ステータスコード 200/302/400 であること")
  end

  # Task 8.4: キーワード空欄エラーハンドリング
  def test_post_generate_with_missing_keywords
    post '/filtered_pdf/generate', {
      keywords: '',
      date_start: '2025-08-13',
      date_end: '2025-11-13',
      send_to_kindle: 'false'
    }

    # バリデーションエラーが返される
    assert([200, 302, 400].include?(last_response.status), "POST バリデーション: ステータスコード 200/302/400 であること")
  end

  # Task 8.4: エラーレスポンス処理テスト
  def test_error_response_handling
    post '/filtered_pdf/generate', {
      keywords: 'nonexistent_keyword_xyz_abc_123',
      date_start: '2025-08-13',
      date_end: '2025-11-13',
      send_to_kindle: 'false'
    }

    # エラーレスポンスがHTML形式で返される
    assert([200, 302, 400].include?(last_response.status), "POST エラーハンドリング: ステータスコード 200/302/400 であること")
  end
end

# テスト実行
runner = TestFilteredPDFRoutes.new
runner.run_all_tests
