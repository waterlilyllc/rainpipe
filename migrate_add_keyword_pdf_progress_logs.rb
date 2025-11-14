#!/usr/bin/env ruby
# Migration: keyword_pdf_progress_logs テーブル追加
#
# 目的: Rainpipe の SQLite データベースに keyword_pdf_progress_logs テーブルを追加する
#       このテーブルはキーワード指定 PDF 生成中の進捗ログを記録する。
#
# スキーマ:
#   - id: PRIMARY KEY
#   - job_id: Foreign key to keyword_pdf_generations.uuid
#   - stage: Processing stage (filtering, content_fetching, summarization, pdf_generation, email_sending, event)
#   - event_type: Log event type (stage_update, retry, warning, info, error)
#   - percentage: Progress percentage (0-100, nullable for events)
#   - message: User-friendly log message
#   - details: JSON blob with stage-specific metrics
#   - timestamp: Log entry timestamp (defaults to CURRENT_TIMESTAMP)
#
# 制約:
#   - job_id は keyword_pdf_generations.uuid への外部キー
#   - stage は enum チェック制約
#   - event_type は enum チェック制約
#
# インデックス:
#   - (job_id, timestamp DESC) - ジョブ別ログ取得用
#   - (timestamp DESC) - 全ログ検索用

require 'sqlite3'

class Migration
  def initialize(db)
    @db = db
  end

  # テーブル作成（アップ）
  def up
    puts "📝 keyword_pdf_progress_logs テーブルを作成中..."

    @db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS keyword_pdf_progress_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        job_id TEXT NOT NULL,
        stage TEXT NOT NULL,
        event_type TEXT DEFAULT 'stage_update',
        percentage INTEGER,
        message TEXT NOT NULL,
        details JSON,
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,

        FOREIGN KEY (job_id) REFERENCES keyword_pdf_generations(uuid),
        CONSTRAINT stage_enum CHECK (stage IN ('filtering', 'content_fetching', 'summarization', 'pdf_generation', 'email_sending', 'event')),
        CONSTRAINT event_enum CHECK (event_type IN ('stage_update', 'retry', 'warning', 'info', 'error'))
      );
    SQL

    puts "📊 インデックスを作成中..."

    @db.execute "CREATE INDEX IF NOT EXISTS idx_keyword_pdf_progress_logs_job_id ON keyword_pdf_progress_logs(job_id, timestamp DESC);"
    @db.execute "CREATE INDEX IF NOT EXISTS idx_keyword_pdf_progress_logs_timestamp ON keyword_pdf_progress_logs(timestamp DESC);"

    puts "✅ テーブル作成完了！"
  end

  # テーブル削除（ダウン）
  def down
    puts "🗑️  keyword_pdf_progress_logs テーブルを削除中..."
    @db.execute "DROP TABLE IF EXISTS keyword_pdf_progress_logs;"
    puts "✅ テーブル削除完了！"
  end
end

# スクリプトとして直接実行された場合
if __FILE__ == $0
  db_path = File.join(File.dirname(__FILE__), 'rainpipe.db')
  puts "📦 データベース: #{db_path}"

  db = SQLite3::Database.new(db_path)
  migration = Migration.new(db)

  case ARGV[0]
  when 'up'
    migration.up
  when 'down'
    migration.down
  else
    puts "使用方法: ruby #{File.basename(__FILE__)} [up|down]"
    puts "  up   - テーブルを作成"
    puts "  down - テーブルを削除（ロールバック）"
  end

  db.close
end
