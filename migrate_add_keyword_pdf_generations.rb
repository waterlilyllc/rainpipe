#!/usr/bin/env ruby
# Migration: keyword_pdf_generations テーブル追加
#
# 目的: Rainpipe の SQLite データベースに keyword_pdf_generations テーブルを追加する
#       このテーブルはキーワード指定 PDF 生成履歴を追跡するために使用される。
#
# スキーマ:
#   - id: PRIMARY KEY
#   - uuid: ユニーク ID（ダウンロードリンク用）
#   - keywords: CSV 形式のキーワード
#   - date_range_start/end: フィルタ対象期間（UTC）
#   - bookmark_count: フィルタ後のブックマーク数
#   - status: pending | processing | completed | failed
#   - pdf_path: 生成されたファイルパス
#   - error_message: エラー時の失敗理由
#   - duration_ms: 各処理ステップの実行時間
#   - created_at/updated_at: UTC タイムスタンプ
#
# 制約:
#   - uuid は UNIQUE（重複不可）
#   - date_range_start <= date_range_end（日付順序チェック）
#
# インデックス:
#   - created_at（履歴表示用）
#   - status（並行実行制限チェック用）

require 'sqlite3'

class Migration
  def initialize(db)
    @db = db
  end

  # テーブル作成（アップ）
  def up
    puts "📝 keyword_pdf_generations テーブルを作成中..."

    @db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS keyword_pdf_generations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE NOT NULL,
        keywords TEXT NOT NULL,
        date_range_start DATE NOT NULL,
        date_range_end DATE NOT NULL,
        bookmark_count INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        pdf_path TEXT,
        kindle_email TEXT,
        error_message TEXT,
        gpt_overall_summary_duration_ms INTEGER,
        gpt_analysis_duration_ms INTEGER,
        gpt_keyword_extraction_duration_ms INTEGER,
        gatherly_fetch_duration_ms INTEGER,
        pdf_render_duration_ms INTEGER,
        total_duration_ms INTEGER,
        created_at TIMESTAMP NOT NULL,
        updated_at TIMESTAMP NOT NULL,

        CONSTRAINT date_range_check CHECK (date_range_start <= date_range_end)
      );
    SQL

    puts "📊 インデックスを作成中..."

    @db.execute "CREATE INDEX IF NOT EXISTS idx_keyword_pdf_generations_created_at ON keyword_pdf_generations(created_at);"
    @db.execute "CREATE INDEX IF NOT EXISTS idx_keyword_pdf_generations_status ON keyword_pdf_generations(status);"

    puts "✅ テーブル作成完了！"
  end

  # テーブル削除（ダウン）
  def down
    puts "🗑️  keyword_pdf_generations テーブルを削除中..."
    @db.execute "DROP TABLE IF EXISTS keyword_pdf_generations;"
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
