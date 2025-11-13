# form_validator.rb
#
# キーワード別 PDF 生成フォームのバリデーション機能
#
# 責務:
#   - キーワード入力値の検証
#   - 日付範囲の検証
#   - セキュリティ（SQL インジェクション、JSON インジェクション対策）

require 'date'

class FormValidator
  # 正規表現：キーワード検証（英数字、日本語、アンダースコア、スペース、カンマ、ハイフン、全角コンマ）
  # Unicode マルチバイト対応で日本語を含む
  KEYWORD_PATTERN = /\A[\w\p{L}\p{N}\s,\-、]+\z/u

  # バリデーションエラーを保持
  attr_reader :errors

  def initialize
    @errors = []
  end

  # フォーム全体を検証
  # @param keywords [String] キーワード（複数の場合はカンマまたは改行で区切る）
  # @param date_start [String] 開始日（YYYY-MM-DD 形式）
  # @param date_end [String] 終了日（YYYY-MM-DD 形式）
  # @return [Boolean] バリデーション成功時は true
  def validate(keywords:, date_start: nil, date_end: nil)
    @errors = []

    validate_keywords(keywords)
    validate_date_range(date_start, date_end)

    @errors.empty?
  end

  # バリデーション成功時のメッセージ
  def success?
    @errors.empty?
  end

  # キーワード検証
  private

  def validate_keywords(keywords)
    keywords_str = keywords.to_s.strip

    # 空チェック
    if keywords_str.empty?
      @errors << "キーワードを入力してください"
      return
    end

    # 正規表現チェック（インジェクション対策）
    unless keywords_str.match?(KEYWORD_PATTERN)
      @errors << "キーワードに無効な文字が含まれています。英数字、日本語、スペース、カンマ、ハイフンのみが使用可能です"
      return
    end

    # キーワード長チェック
    if keywords_str.length > 500
      @errors << "キーワードは 500 文字以内にしてください"
      return
    end
  end

  def validate_date_range(date_start, date_end)
    # 両方が空の場合は OK（デフォルト値を使用）
    return if date_start.to_s.empty? && date_end.to_s.empty?

    # 片方だけ指定された場合はエラー
    if date_start.to_s.empty? || date_end.to_s.empty?
      @errors << "開始日と終了日の両方を指定するか、両方とも指定しないでください"
      return
    end

    begin
      start_date = Date.parse(date_start.to_s)
      end_date = Date.parse(date_end.to_s)

      # 日付順序チェック
      if start_date > end_date
        @errors << "開始日は終了日より前である必要があります"
        return
      end

      # 日付範囲チェック（1年以上先の範囲は不許可）
      if (end_date - start_date).to_i > 365
        @errors << "日付範囲は 1 年以内である必要があります"
        return
      end
    rescue ArgumentError
      @errors << "日付形式が無効です（YYYY-MM-DD 形式で指定してください）"
      return
    end
  end

  # エラーメッセージを結合
  def error_messages
    @errors.join("\n")
  end
end
