#!/usr/bin/env ruby
require 'erb'
require 'date'

class TestFilteredPdfForm
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
    puts "🧪 Filtered PDF フォームテストを実行中...\n"

    test_template_file_exists
    test_form_contains_keywords_input
    test_form_contains_date_range_inputs
    test_form_contains_kindle_checkbox
    test_form_contains_submit_button
    test_placeholder_text_present
    test_form_method_is_post
    test_form_has_proper_structure
    test_default_date_values

    puts "\n" + "=" * 50
    puts "📊 テスト結果: #{@tests_passed} 成功, #{@tests_failed} 失敗"
    puts "=" * 50

    exit(@tests_failed > 0 ? 1 : 0)
  end

  def test_template_file_exists
    template_path = File.join(File.dirname(__FILE__), 'views', 'filtered_pdf.erb')
    assert(File.exist?(template_path), "views/filtered_pdf.erb テンプレートが存在すること")
  end

  def test_form_contains_keywords_input
    template_content = read_template
    contains_textarea = template_content.include?('<textarea') && template_content.include?('keywords')
    contains_input = template_content.include?('<input') && template_content.include?('keywords')

    assert(contains_textarea || contains_input, "キーワード入力フィールド（textarea または input）が存在すること")
  end

  def test_form_contains_date_range_inputs
    template_content = read_template
    contains_date_start = template_content.include?('date_start') || template_content.include?('date_range_start')
    contains_date_end = template_content.include?('date_end') || template_content.include?('date_range_end')

    assert(contains_date_start && contains_date_end, "日付範囲入力フィールド（start, end）が存在すること")
  end

  def test_form_contains_kindle_checkbox
    template_content = read_template
    contains_checkbox = template_content.include?('checkbox') && template_content.include?('kindle')

    assert(contains_checkbox, "Kindle 送信チェックボックスが存在すること")
  end

  def test_form_contains_submit_button
    template_content = read_template
    contains_submit = template_content.include?('type="submit"') || template_content.include?('button')

    assert(contains_submit, "フォーム送信ボタンが存在すること")
  end

  def test_placeholder_text_present
    template_content = read_template
    contains_placeholder = template_content.include?('キーワードを入力') || template_content.include?('改行')

    assert(contains_placeholder, "プレースホルダーテキストが存在すること")
  end

  def test_form_method_is_post
    template_content = read_template
    assert(template_content.include?('POST') || template_content.include?('post'), "フォームメソッドが POST であること")
  end

  def test_form_has_proper_structure
    template_content = read_template
    has_header = template_content.include?('<header') || template_content.include?('<!DOCTYPE')
    has_nav = template_content.include?('<nav') || template_content.include?('nav-')
    has_form = template_content.include?('<form')

    assert(has_header && has_nav && has_form, "フォームが適切なページ構造を持つこと（header, nav, form）")
  end

  def test_default_date_values
    template_content = read_template
    # テンプレート内で値がバインドされていることを確認
    contains_value_binding = template_content.include?('value=') || template_content.include?('<%= ')

    assert(contains_value_binding, "デフォルト日付値がバインドされていること")
  end

  private

  def read_template
    template_path = File.join(File.dirname(__FILE__), 'views', 'filtered_pdf.erb')
    if File.exist?(template_path)
      File.read(template_path)
    else
      ""
    end
  end
end

# テスト実行
runner = TestFilteredPdfForm.new
runner.run_all_tests
