require 'sqlite3'
require 'time'

class CrawlJobManager
  attr_reader :db

  def initialize(db_path = nil)
    db_path ||= File.join(File.dirname(__FILE__), 'data', 'rainpipe.db')
    @db = SQLite3::Database.new(db_path)
    @db.results_as_hash = true
  end

  # ジョブを作成
  # @param raindrop_id [Integer] RaindropブックマークID
  # @param url [String] クロール対象URL
  # @param job_uuid [String] GatherlyのジョブUUID
  # @return [Boolean] 成功/失敗
  def create_job(raindrop_id, url, job_uuid)
    now = Time.now.utc.iso8601

    @db.execute(
      <<-SQL,
        INSERT INTO crawl_jobs
        (job_id, raindrop_id, url, status, created_at, updated_at)
        VALUES (?, ?, ?, 'pending', ?, ?)
      SQL
      job_uuid,
      raindrop_id,
      url,
      now,
      now
    )

    true
  rescue SQLite3::ConstraintException => e
    puts "⚠️ Job already exists: #{job_uuid}"
    false
  rescue => e
    puts "❌ Error creating job: #{e.message}"
    false
  end

  # ジョブを取得
  # @param job_id [String] ジョブID
  # @return [Hash, nil]
  def get_job(job_id)
    @db.get_first_row(
      'SELECT * FROM crawl_jobs WHERE job_id = ?',
      job_id
    )
  end

  # ジョブのステータスを更新
  # @param job_id [String] ジョブID
  # @param status [String] 新しいステータス
  # @param error_message [String, nil] エラーメッセージ（オプション）
  # @return [Boolean]
  def update_job_status(job_id, status, error_message = nil)
    now = Time.now.utc.iso8601

    if status == 'success' || status == 'failed'
      # 完了時はcompleted_atも設定
      @db.execute(
        <<-SQL,
          UPDATE crawl_jobs
          SET status = ?,
              error_message = ?,
              updated_at = ?,
              completed_at = ?
          WHERE job_id = ?
        SQL
        status,
        error_message,
        now,
        now,
        job_id
      )
    else
      @db.execute(
        <<-SQL,
          UPDATE crawl_jobs
          SET status = ?,
              error_message = ?,
              updated_at = ?
          WHERE job_id = ?
        SQL
        status,
        error_message,
        now,
        job_id
      )
    end

    true
  rescue => e
    puts "❌ Error updating job status: #{e.message}"
    false
  end

  # 保留中のジョブを取得
  # @return [Array<Hash>]
  def get_pending_jobs
    @db.execute(
      "SELECT * FROM crawl_jobs WHERE status IN ('pending', 'running') ORDER BY created_at ASC"
    )
  end

  # リトライ対象の失敗ジョブを取得
  # @return [Array<Hash>]
  def get_failed_jobs_for_retry
    @db.execute(
      <<-SQL
        SELECT * FROM crawl_jobs
        WHERE status = 'failed'
          AND retry_count < max_retries
        ORDER BY updated_at ASC
      SQL
    )
  end

  # タイムアウトしたジョブを取得（24時間経過）
  # @return [Array<Hash>]
  def get_timeout_jobs
    cutoff_time = (Time.now - 24 * 60 * 60).utc.iso8601

    @db.execute(
      <<-SQL,
        SELECT * FROM crawl_jobs
        WHERE status IN ('pending', 'running')
          AND created_at < ?
      SQL
      cutoff_time
    )
  end

  # リトライカウントをインクリメント
  # @param job_id [String] ジョブID
  # @return [Boolean]
  def increment_retry_count(job_id)
    @db.execute(
      'UPDATE crawl_jobs SET retry_count = retry_count + 1, updated_at = ? WHERE job_id = ?',
      Time.now.utc.iso8601,
      job_id
    )
    true
  rescue => e
    puts "❌ Error incrementing retry count: #{e.message}"
    false
  end

  # ジョブ統計を取得
  # @return [Hash]
  def get_stats
    total = @db.get_first_value('SELECT COUNT(*) FROM crawl_jobs')
    pending = @db.get_first_value("SELECT COUNT(*) FROM crawl_jobs WHERE status = 'pending'")
    running = @db.get_first_value("SELECT COUNT(*) FROM crawl_jobs WHERE status = 'running'")
    success = @db.get_first_value("SELECT COUNT(*) FROM crawl_jobs WHERE status = 'success'")
    failed = @db.get_first_value("SELECT COUNT(*) FROM crawl_jobs WHERE status = 'failed'")

    success_rate = total > 0 ? (success.to_f / total * 100).round(2) : 0

    {
      total: total,
      pending: pending,
      running: running,
      success: success,
      failed: failed,
      success_rate: success_rate
    }
  end

  # raindrop_idに対するジョブが存在するか確認
  # @param raindrop_id [Integer]
  # @return [Boolean]
  def job_exists_for_bookmark?(raindrop_id)
    result = @db.get_first_value(
      'SELECT COUNT(*) FROM crawl_jobs WHERE raindrop_id = ?',
      raindrop_id
    )
    result > 0
  end

  # raindrop_idからジョブを取得（最新）
  # @param raindrop_id [Integer]
  # @return [Hash, nil]
  def get_job_by_raindrop_id(raindrop_id)
    @db.get_first_row(
      'SELECT * FROM crawl_jobs WHERE raindrop_id = ? ORDER BY created_at DESC LIMIT 1',
      raindrop_id
    )
  end

  # ジョブを削除
  # @param job_id [String] ジョブID
  # @return [Boolean]
  def delete_job(job_id)
    @db.execute(
      'DELETE FROM crawl_jobs WHERE job_id = ?',
      job_id
    )
    true
  rescue => e
    puts "❌ Error deleting job: #{e.message}"
    false
  end

  def close
    @db.close if @db
  end
end
