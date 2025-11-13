#!/usr/bin/env ruby
require 'date'
require_relative 'form_validator'

class TestFormValidator
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
    puts "🧪 Form Validator テストを実行中...\n"

    test_valid_keyword_input
    test_empty_keyword_input
    test_invalid_characters_in_keywords
    test_keyword_length_limit
    test_valid_date_range
    test_invalid_date_range_order
    test_missing_one_date
    test_invalid_date_format
    test_date_range_too_long
    test_special_characters_blocked
    test_japanese_keywords_allowed
    test_comma_separated_keywords
    test_multiple_validation_errors
    test_success_flag

    puts "\n" + "=" * 50
    puts "📊 テスト結果: #{@tests_passed} 成功, #{@tests_failed} 失敗"
    puts "=" * 50

    exit(@tests_failed > 0 ? 1 : 0)
  end

  def test_valid_keyword_input
    validator = FormValidator.new
    result = validator.validate(keywords: "Claude")
    assert(result == true && validator.errors.empty?, "有効なキーワード入力が通過すること")
  end

  def test_empty_keyword_input
    validator = FormValidator.new
    result = validator.validate(keywords: "")
    assert(result == false && validator.errors.include?("キーワードを入力してください"), "空キーワードが拒否されること")
  end

  def test_invalid_characters_in_keywords
    validator = FormValidator.new
    result = validator.validate(keywords: "Claude; DROP TABLE;")
    assert(result == false && !validator.errors.empty?, "SQL インジェクション文字が拒否されること")
  end

  def test_keyword_length_limit
    validator = FormValidator.new
    long_keyword = "a" * 501
    result = validator.validate(keywords: long_keyword)
    assert(result == false && validator.errors.any? { |e| e.include?("500") }, "500 文字超過が拒否されること")
  end

  def test_valid_date_range
    validator = FormValidator.new
    result = validator.validate(
      keywords: "Claude",
      date_start: "2025-10-01",
      date_end: "2025-11-01"
    )
    assert(result == true && validator.errors.empty?, "有効な日付範囲が通過すること")
  end

  def test_invalid_date_range_order
    validator = FormValidator.new
    result = validator.validate(
      keywords: "Claude",
      date_start: "2025-11-01",
      date_end: "2025-10-01"
    )
    assert(result == false && validator.errors.any? { |e| e.include?("前である必要") }, "逆順日付が拒否されること")
  end

  def test_missing_one_date
    validator = FormValidator.new
    result = validator.validate(
      keywords: "Claude",
      date_start: "2025-10-01",
      date_end: nil
    )
    assert(result == false && validator.errors.any? { |e| e.include?("両方") }, "片方の日付が拒否されること")
  end

  def test_invalid_date_format
    validator = FormValidator.new
    result = validator.validate(
      keywords: "Claude",
      date_start: "invalid-date",
      date_end: "2025-11-01"
    )
    assert(result == false && validator.errors.any? { |e| e.include?("形式") }, "無効な日付形式が拒否されること")
  end

  def test_date_range_too_long
    validator = FormValidator.new
    result = validator.validate(
      keywords: "Claude",
      date_start: "2024-01-01",
      date_end: "2025-12-31"
    )
    assert(result == false && validator.errors.any? { |e| e.include?("1 年") }, "1 年超の範囲が拒否されること")
  end

  def test_special_characters_blocked
    validator = FormValidator.new
    result = validator.validate(keywords: "Claude; OR 1=1")
    assert(result == false, "セミコロンが拒否されること")
  end

  def test_japanese_keywords_allowed
    validator = FormValidator.new
    result = validator.validate(keywords: "クロード、機械学習")
    assert(result == true && validator.errors.empty?, "日本語キーワードが許可されること")
  end

  def test_comma_separated_keywords
    validator = FormValidator.new
    result = validator.validate(keywords: "Claude, AI, 機械学習")
    assert(result == true && validator.errors.empty?, "カンマ区切りキーワードが許可されること")
  end

  def test_multiple_validation_errors
    validator = FormValidator.new
    result = validator.validate(
      keywords: "",
      date_start: "2025-11-01",
      date_end: "2025-10-01"
    )
    assert(result == false && validator.errors.length > 1, "複数のエラーが報告されること")
  end

  def test_success_flag
    validator = FormValidator.new
    validator.validate(keywords: "Claude")
    assert(validator.success? == true, "success? メソッドが true を返すこと")

    validator2 = FormValidator.new
    validator2.validate(keywords: "")
    assert(validator2.success? == false, "success? メソッドが false を返すこと")
  end
end

# テスト実行
runner = TestFormValidator.new
runner.run_all_tests
