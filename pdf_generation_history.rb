# pdf_generation_history.rb
#
# PDFGenerationHistory - PDF 生成履歴の DB 管理クラス
#
# 責務:
#   - Task 9.1: PDF 生成前に DB で in-progress ステータスチェック
#   - Task 9.2: 生成開始時に DB record 作成
#   - Task 9.3: PDF 完成時に DB record 更新
#   - Task 9.4: エラー時に DB record 更新
#   - Task 9.5: 履歴取得

require 'sqlite3'
require 'securerandom'

class PDFGenerationHistory
  def initialize(db_path = 'rainpipe.db')
    @db = SQLite3::Database.new(db_path)
    @db.results_as_hash = true
  end

  # Task 9.1: PDF 生成前に DB で in-progress ステータスチェック
  # @return [Boolean] in-progress レコードが存在する場合は true
  def has_processing_record?
    result = @db.execute("SELECT COUNT(*) as count FROM keyword_pdf_generations WHERE status = 'processing'")
    result[0]['count'] > 0
  end

  # Task 9.2: 生成開始時に DB record 作成
  # @param keywords [String] キーワード（カンマ区切り）
  # @param date_range [Hash] { start: Date, end: Date }
  # @param bookmark_count [Integer] ブックマーク件数
  # @return [String] UUID
  def create_processing_record(keywords, date_range, bookmark_count)
    uuid = SecureRandom.uuid
    now = Time.now.utc.iso8601

    @db.execute(
      "INSERT INTO keyword_pdf_generations (uuid, keywords, date_range_start, date_range_end, bookmark_count, status, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, 'processing', ?, ?)",
      [uuid, keywords, date_range[:start].to_s, date_range[:end].to_s, bookmark_count, now, now]
    )

    puts "📝 PDF 生成レコード作成: #{uuid}"
    uuid
  end

  # Task 9.3: PDF 完成時に DB record を status=completed に更新
  # @param uuid [String] UUID
  # @param pdf_path [String] PDF ファイルパス
  # @param total_duration_ms [Integer] 総実行時間（ミリ秒）
  # @return [void]
  def mark_completed(uuid, pdf_path, total_duration_ms)
    now = Time.now.utc.iso8601

    @db.execute(
      "UPDATE keyword_pdf_generations SET status = 'completed', pdf_path = ?, total_duration_ms = ?, updated_at = ?
       WHERE uuid = ?",
      [pdf_path, total_duration_ms, now, uuid]
    )

    puts "✅ PDF 生成完了: #{uuid}"
  end

  # Task 9.4: エラー時に DB record を status=failed に更新
  # @param uuid [String] UUID
  # @param error_message [String] エラーメッセージ
  # @return [void]
  def mark_failed(uuid, error_message)
    now = Time.now.utc.iso8601

    @db.execute(
      "UPDATE keyword_pdf_generations SET status = 'failed', error_message = ?, updated_at = ?
       WHERE uuid = ?",
      [error_message, now, uuid]
    )

    puts "❌ PDF 生成失敗: #{uuid} - #{error_message}"
  end

  # Task 9.5: 履歴取得（最新 20 件）
  # @return [Array<Hash>] 生成履歴レコード
  def fetch_history(limit = 20)
    @db.execute(
      "SELECT uuid, keywords, bookmark_count, status, created_at, total_duration_ms
       FROM keyword_pdf_generations
       ORDER BY created_at DESC
       LIMIT ?",
      [limit]
    )
  end

  # Task 9.1: 並行実行警告メッセージ生成
  # @return [String] 警告メッセージ
  def get_processing_warning
    "⚠️  PDF 生成処理が進行中です。数分お待ちください"
  end
end
