# progress_callback.rb
#
# ProgressCallback - サービスレイヤーへの進捗更新インターフェース
#
# 責務:
#   - サービスからの進捗更新を DB に記録
#   - キャンセルリクエストの検出
#   - イベントログ（エラー、警告、再試行）の記録
#
# 使用方法:
#   1. Web UI: ProgressCallback.new(job_id, db) で DB-backed callback を作成
#   2. CLI/Batch: ProgressCallback.null_callback() で no-op callback を使用

require 'json'
require 'time'

class ProgressCallback
  # 有効なステージ定義
  VALID_STAGES = %w[filtering content_fetching summarization pdf_generation email_sending].freeze

  # 有効なイベントタイプ定義
  VALID_EVENT_TYPES = %w[stage_update retry warning info error].freeze

  # 初期化: DB-backed callback
  # @param job_id [String] 進捗を追跡するジョブ ID (keyword_pdf_generations.uuid)
  # @param db [SQLite3::Database] SQLite DB コネクション
  def initialize(job_id, db)
    @job_id = job_id
    @db = db
    @is_null = false
  end

  # ステージ進捗を報告
  # @param stage_name [String] ステージ名 (filtering, content_fetching, summarization, pdf_generation, email_sending)
  # @param percentage [Integer] 進捗パーセンテージ (0-100)
  # @param details [Hash] ステージ固有の詳細情報 (JSON で DB に保存)
  # @return [void]
  # @raise [ArgumentError] 無効なステージ名またはパーセンテージ範囲
  def report_stage(stage_name, percentage, details = {})
    # バリデーション
    validate_stage_name(stage_name)
    validate_percentage(percentage)

    # ステージ進捗ログを記録
    log_progress_entry(stage_name, 'stage_update', percentage, stage_name_to_message(stage_name, percentage), details)

    # ジョブレコードを更新 (current_stage, current_percentage)
    update_job_record(stage_name, percentage)
  end

  # イベントログを記録（再試行、警告、エラーなど）
  # @param event_type [String] イベントタイプ (retry, warning, info, error)
  # @param message [String] ユーザーフレンドリーなメッセージ
  # @param details [Hash] オプション詳細情報
  # @return [void]
  # @raise [ArgumentError] 無効なイベントタイプ
  def report_event(event_type, message, details = {})
    validate_event_type(event_type)
    log_progress_entry('event', event_type, nil, message, details)
  end

  # キャンセルリクエストを確認
  # @return [Boolean] ユーザーがキャンセルを要求した場合 true
  def cancellation_requested?
    return false if @is_null

    result = @db.execute(
      'SELECT cancellation_flag FROM keyword_pdf_generations WHERE uuid = ? LIMIT 1',
      [@job_id]
    )

    return false if result.empty?

    result[0]['cancellation_flag'] == 1
  end

  # NULL callback を返す（CLI/Batch モード用）
  # @return [ProgressCallback] 何もしない callback インスタンス
  def self.null_callback
    callback = new(nil, nil)
    callback.instance_variable_set(:@is_null, true)
    callback
  end

  private

  # ステージ名をバリデーション
  # @raise [ArgumentError] 無効なステージ名
  def validate_stage_name(stage_name)
    unless VALID_STAGES.include?(stage_name)
      raise ArgumentError,
            "Invalid stage: #{stage_name}. Must be one of: #{VALID_STAGES.join(', ')}"
    end
  end

  # パーセンテージをバリデーション
  # @raise [ArgumentError] 範囲外のパーセンテージ
  def validate_percentage(percentage)
    unless percentage.is_a?(Integer) && percentage >= 0 && percentage <= 100
      raise ArgumentError, "Percentage must be an integer between 0-100, got: #{percentage}"
    end
  end

  # イベントタイプをバリデーション
  # @raise [ArgumentError] 無効なイベントタイプ
  def validate_event_type(event_type)
    unless VALID_EVENT_TYPES.include?(event_type)
      raise ArgumentError,
            "Invalid event_type: #{event_type}. Must be one of: #{VALID_EVENT_TYPES.join(', ')}"
    end
  end

  # 進捗ログエントリを記録
  # @param stage [String, nil] ステージ名（イベント時は nil）
  # @param event_type [String] イベントタイプ
  # @param percentage [Integer, nil] パーセンテージ（イベント時は nil）
  # @param message [String] ログメッセージ
  # @param details [Hash] JSON 詳細情報
  def log_progress_entry(stage, event_type, percentage, message, details = {})
    return if @is_null

    # 詳細情報を JSON に変換
    details_json = details.empty? ? nil : details.to_json

    # ログエントリを挿入
    @db.execute(
      <<-SQL,
        INSERT INTO keyword_pdf_progress_logs
        (job_id, stage, event_type, percentage, message, details, timestamp)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      SQL
      [@job_id, stage, event_type, percentage, message, details_json, Time.now.utc.iso8601]
    )
  end

  # ジョブレコードを更新
  # @param stage [String] 現在のステージ
  # @param percentage [Integer] 現在のパーセンテージ
  def update_job_record(stage, percentage)
    return if @is_null

    @db.execute(
      'UPDATE keyword_pdf_generations SET current_stage = ?, current_percentage = ?, updated_at = ? WHERE uuid = ?',
      [stage, percentage, Time.now.utc.iso8601, @job_id]
    )
  end

  # ステージ名を人間が読める形式のメッセージに変換
  # @param stage [String] ステージ名
  # @param percentage [Integer] パーセンテージ
  # @return [String] メッセージ
  def stage_name_to_message(stage, percentage)
    stage_labels = {
      'filtering' => 'ブックマークをフィルタリング中',
      'content_fetching' => 'コンテンツを取得中',
      'summarization' => 'サマリーを生成中',
      'pdf_generation' => 'PDF を生成中',
      'email_sending' => 'メールを送信中'
    }

    "#{stage_labels[stage] || stage} (#{percentage}%)"
  end
end
