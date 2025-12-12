require 'sqlite3'
require 'time'

class BookmarkContentManager
  attr_reader :db

  def initialize(db_path = nil)
    db_path ||= File.join(File.dirname(__FILE__), 'data', 'rainpipe.db')
    @db = SQLite3::Database.new(db_path)
    @db.results_as_hash = true
  end

  # 本文を取得
  # @param raindrop_id [Integer]
  # @return [Hash, nil]
  def get_content(raindrop_id)
    result = @db.get_first_row(
      'SELECT * FROM bookmark_contents WHERE raindrop_id = ?',
      [raindrop_id]
    )
    result
  end

  # 本文を保存
  # @param raindrop_id [Integer]
  # @param data [Hash] content, title, url, content_type, word_count
  # @return [Boolean]
  def save_content(raindrop_id, data)
    existing = get_content(raindrop_id)
    now = Time.now.utc.iso8601

    if existing
      # 更新
      @db.execute(
        <<-SQL,
          UPDATE bookmark_contents
          SET url = ?,
              title = ?,
              content = ?,
              content_type = ?,
              word_count = ?,
              extracted_at = ?,
              updated_at = ?
          WHERE raindrop_id = ?
        SQL
        [data[:url], data[:title], data[:content], data[:content_type] || 'text', data[:word_count], data[:extracted_at] || now, now, raindrop_id]
      )
    else
      # 新規作成
      @db.execute(
        <<-SQL,
          INSERT INTO bookmark_contents
          (raindrop_id, url, title, content, content_type, word_count, extracted_at, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        SQL
        [raindrop_id, data[:url], data[:title], data[:content], data[:content_type] || 'text', data[:word_count], data[:extracted_at] || now, now, now]
      )
    end

    true
  rescue => e
    puts "❌ Error saving content: #{e.message}"
    false
  end

  # 本文が存在するか確認
  # @param raindrop_id [Integer]
  # @return [Boolean]
  def content_exists?(raindrop_id)
    result = @db.get_first_value(
      'SELECT COUNT(*) FROM bookmark_contents WHERE raindrop_id = ?',
      [raindrop_id]
    )
    result > 0
  end

  # 古い本文を再取得すべきか判定
  # @param raindrop_id [Integer]
  # @param days [Integer] 日数（デフォルト30日）
  # @return [Boolean]
  def should_refetch?(raindrop_id, days = 30)
    content = get_content(raindrop_id)
    return true unless content # 本文がない場合は取得すべき

    extracted_at = content['extracted_at']
    return true unless extracted_at # extracted_at がない場合は取得すべき

    extracted_time = Time.parse(extracted_at)
    threshold = Time.now - (days * 24 * 60 * 60)

    extracted_time < threshold
  rescue => e
    puts "⚠️ Error in should_refetch?: #{e.message}"
    false
  end

  # 本文未取得のブックマークIDリストを取得
  # @param all_raindrop_ids [Array<Integer>] 全ブックマークのID
  # @return [Array<Integer>] 本文未取得のID
  def get_missing_content_ids(all_raindrop_ids)
    return [] if all_raindrop_ids.empty?

    placeholders = all_raindrop_ids.map { '?' }.join(',')
    existing_ids = @db.execute(
      "SELECT raindrop_id FROM bookmark_contents WHERE raindrop_id IN (#{placeholders})",
      all_raindrop_ids  # この場合は配列をそのまま渡す（splat用）
    ).map { |row| row['raindrop_id'] }

    all_raindrop_ids - existing_ids
  end

  # 統計情報を取得
  # @return [Hash]
  def get_stats
    total = @db.get_first_value('SELECT COUNT(*) FROM bookmark_contents')
    avg_word_count = @db.get_first_value('SELECT AVG(word_count) FROM bookmark_contents WHERE word_count IS NOT NULL')
    recent_count = @db.get_first_value(
      "SELECT COUNT(*) FROM bookmark_contents WHERE extracted_at > datetime('now', '-7 days')"
    )

    {
      total_contents: total,
      avg_word_count: avg_word_count&.round(2),
      recent_week_count: recent_count
    }
  end

  # 取得試行を記録（失敗時）
  # @param raindrop_id [Integer]
  # @param url [String]
  # @return [Boolean]
  def mark_fetch_attempted(raindrop_id, url)
    existing = get_content(raindrop_id)
    now = Time.now.utc.iso8601

    if existing
      @db.execute(
        <<-SQL,
          UPDATE bookmark_contents
          SET fetch_attempted = 1,
              last_fetch_attempt = ?,
              updated_at = ?
          WHERE raindrop_id = ?
        SQL
        [now, now, raindrop_id]
      )
    else
      # レコードがない場合は作成
      @db.execute(
        <<-SQL,
          INSERT INTO bookmark_contents
          (raindrop_id, url, fetch_attempted, last_fetch_attempt, created_at, updated_at)
          VALUES (?, ?, 1, ?, ?, ?)
        SQL
        [raindrop_id, url, now, now, now]
      )
    end

    true
  rescue => e
    puts "❌ Error marking fetch attempted: #{e.message}"
    false
  end

  # 取得失敗を記録（最大リトライ後）
  # @param raindrop_id [Integer]
  # @param url [String]
  # @return [Boolean]
  def mark_fetch_failed(raindrop_id, url)
    existing = get_content(raindrop_id)
    now = Time.now.utc.iso8601

    if existing
      @db.execute(
        <<-SQL,
          UPDATE bookmark_contents
          SET fetch_attempted = 1,
              fetch_failed = 1,
              last_fetch_attempt = ?,
              updated_at = ?
          WHERE raindrop_id = ?
        SQL
        [now, now, raindrop_id]
      )
    else
      # レコードがない場合は作成
      @db.execute(
        <<-SQL,
          INSERT INTO bookmark_contents
          (raindrop_id, url, fetch_attempted, fetch_failed, last_fetch_attempt, created_at, updated_at)
          VALUES (?, ?, 1, 1, ?, ?, ?)
        SQL
        [raindrop_id, url, now, now, now]
      )
    end

    true
  rescue => e
    puts "❌ Error marking fetch failed: #{e.message}"
    false
  end

  # 取得失敗済みかチェック
  # @param raindrop_id [Integer]
  # @return [Boolean]
  def fetch_failed?(raindrop_id)
    result = @db.get_first_value(
      'SELECT fetch_failed FROM bookmark_contents WHERE raindrop_id = ?',
      [raindrop_id]
    )
    result == 1
  rescue => e
    puts "⚠️ Error checking fetch_failed: #{e.message}"
    false
  end

  def close
    @db.close if @db
  end
end
