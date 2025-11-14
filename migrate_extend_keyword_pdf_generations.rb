#!/usr/bin/env ruby
# Migration: keyword_pdf_generations テーブル拡張
#
# 目的: keyword_pdf_generations テーブルに進捗追跡用のカラムを追加する
#
# 新規カラム:
#   - cancellation_flag: Boolean (user がキャンセルを要求したかどうか)
#   - current_stage: Text (現在実行中のステージ)
#   - current_percentage: Integer (0-100 の進捗パーセンテージ)
#   - user_id: Text (将来のマルチユーザー対応用、オプション)
#
# 制約:
#   - current_stage は enum チェック制約
#
# インデックス:
#   - (user_id, created_at) - マルチユーザー対応用

require 'sqlite3'

class Migration
  def initialize(db)
    @db = db
  end

  # カラム追加（アップ）
  def up
    puts "📝 keyword_pdf_generations テーブルを拡張中..."

    # 既存カラムをチェック
    columns = @db.execute("PRAGMA table_info(keyword_pdf_generations)").map { |col| col['name'] }

    # cancellation_flag を追加（まだ存在しない場合）
    unless columns.include?('cancellation_flag')
      @db.execute "ALTER TABLE keyword_pdf_generations ADD COLUMN cancellation_flag BOOLEAN DEFAULT 0;"
      puts "  ✓ cancellation_flag カラム追加"
    end

    # current_stage を追加
    unless columns.include?('current_stage')
      @db.execute "ALTER TABLE keyword_pdf_generations ADD COLUMN current_stage TEXT DEFAULT NULL;"
      puts "  ✓ current_stage カラム追加"
    end

    # current_percentage を追加
    unless columns.include?('current_percentage')
      @db.execute "ALTER TABLE keyword_pdf_generations ADD COLUMN current_percentage INTEGER DEFAULT 0;"
      puts "  ✓ current_percentage カラム追加"
    end

    # user_id を追加（マルチユーザー対応用）
    unless columns.include?('user_id')
      @db.execute "ALTER TABLE keyword_pdf_generations ADD COLUMN user_id TEXT DEFAULT NULL;"
      puts "  ✓ user_id カラム追加"
    end

    # インデックスを作成
    @db.execute "CREATE INDEX IF NOT EXISTS idx_keyword_pdf_generations_user_id ON keyword_pdf_generations(user_id, created_at);"
    puts "  ✓ インデックス作成（user_id, created_at）"

    puts "✅ テーブル拡張完了！"
  end

  # ロールバック（ダウン）
  def down
    puts "🗑️  keyword_pdf_generations テーブルを元の状態に戻す準備中..."
    puts "   注: SQLite は ALTER TABLE DROP COLUMN をサポートしていないため、"
    puts "   手動でカラムを削除する必要があります。"
    puts "   必要な場合は、テーブルを再作成してください。"

    # インデックスのみ削除可能
    @db.execute "DROP INDEX IF EXISTS idx_keyword_pdf_generations_user_id;"
    puts "  ✓ インデックス削除（idx_keyword_pdf_generations_user_id）"
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
    puts "  up   - テーブルを拡張"
    puts "  down - 拡張をロールバック（インデックスのみ削除）"
  end

  db.close
end
