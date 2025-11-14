# progress_reporter.rb
#
# ProgressReporter - Standardized progress output formatting
#
# 責務:
#   - emoji インジケータ付きの進捗メッセージをフォーマット
#   - カウンター式進捗（n/m）の表示
#   - インデント付きマルチラインメッセージ
#   - エラーメッセージと詳細情報

class ProgressReporter
  # emoji マッピング
  INDICATORS = {
    success: '✅',
    error: '❌',
    warning: '⚠️',
    info: '🔍',
    email: '📧',
    wait: '⏳',
    folder: '📚',
    loop: '🔄',
    document: '📄',
    globe: '🌐'
  }.freeze

  # 進捗メッセージを出力（emoji インジケータ付き）
  # @param stage [String] ステージ名
  # @param message [String] メッセージ
  # @param indicator [Symbol] emoji インジケータ（:success, :error, :warning, :info, :email, :wait, :folder, :loop, :document, :globe）
  def self.progress(stage, message, indicator = :info)
    emoji = INDICATORS[indicator] || INDICATORS[:info]
    puts "#{emoji} #{message}"
  end

  # カウンター付き進捗を出力（n/m 形式）
  # @param current [Integer] 現在の数
  # @param total [Integer] 合計数
  # @param message [String] メッセージ
  # @param indicator [Symbol] emoji インジケータ
  def self.counter(current, total, message, indicator = :info)
    emoji = INDICATORS[indicator] || INDICATORS[:info]
    puts "#{emoji} [#{current}/#{total}] #{message}"
  end

  # インデント付きメッセージを出力
  # @param message [String] メッセージ
  # @param prefix [String] インデント文字列（デフォルト: "  "）
  def self.indented(message, prefix = "  ")
    puts "#{prefix}#{message}"
  end

  # 成功メッセージ
  # @param message [String] メッセージ
  def self.success(message)
    progress(nil, message, :success)
  end

  # エラーメッセージ
  # @param message [String] メッセージ
  # @param details [String] 詳細情報（オプション）
  def self.error(message, details = nil)
    progress(nil, message, :error)
    indented(details, "   ") if details
  end

  # 警告メッセージ
  # @param message [String] メッセージ
  def self.warning(message)
    progress(nil, message, :warning)
  end

  # チェック付きインデントメッセージ
  # @param message [String] メッセージ
  def self.check(message)
    puts "  ✓ #{message}"
  end

  # ステップ完了メッセージ
  # @param count [Integer] 完了した数
  # @param indicator [Symbol] emoji インジケータ
  def self.completed(message, indicator = :success)
    progress(nil, message, indicator)
  end
end
