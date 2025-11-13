#!/usr/bin/env ruby
# run_migration_keyword_pdf.rb
#
# 目的: 既存の Rainpipe SQLite データベースに keyword_pdf_generations テーブルを追加する
#       スキーマ検証を行い、安全にロールバック可能にする。
#
# 使用法:
#   ruby run_migration_keyword_pdf.rb up    # マイグレーション実行
#   ruby run_migration_keyword_pdf.rb down  # ロールバック
#   ruby run_migration_keyword_pdf.rb verify  # スキーマ検証のみ

require 'sqlite3'
require 'fileutils'
require_relative 'migrate_add_keyword_pdf_generations'

class MigrationRunner
  DB_PATH = File.join(File.dirname(__FILE__), 'rainpipe.db')
  BACKUP_SUFFIX = '.backup'

  def initialize
    @db = nil
  end

  # データベースへの接続
  def connect
    unless File.exist?(DB_PATH)
      puts "❌ エラー: データベースファイルが見つかりません: #{DB_PATH}"
      exit 1
    end

    @db = SQLite3::Database.new(DB_PATH)
    @db.results_as_hash = true
    puts "✅ データベースに接続しました: #{DB_PATH}"
  end

  # マイグレーション実行（up）
  def run_up
    puts "\n📈 マイグレーション実行..."

    # バックアップ作成
    backup_path = DB_PATH + BACKUP_SUFFIX
    if File.exist?(DB_PATH)
      FileUtils.cp(DB_PATH, backup_path)
      puts "💾 バックアップを作成しました: #{backup_path}"
    end

    begin
      connect
      migration = Migration.new(@db)
      migration.up
      @db.close

      puts "✅ マイグレーション完了！"
      puts "📝 テーブル 'keyword_pdf_generations' が追加されました。"
    rescue => e
      puts "❌ マイグレーション失敗: #{e.message}"
      puts "⏮️  ロールバック中..."

      # バックアップから復元
      if File.exist?(backup_path)
        FileUtils.rm(DB_PATH) if File.exist?(DB_PATH)
        FileUtils.mv(backup_path, DB_PATH)
        puts "✅ バックアップから復元しました"
      end

      exit 1
    end
  end

  # ロールバック実行（down）
  def run_down
    puts "\n⬇️  ロールバック実行..."

    begin
      connect
      migration = Migration.new(@db)
      migration.down
      @db.close

      puts "✅ ロールバック完了！"
      puts "🗑️  テーブル 'keyword_pdf_generations' が削除されました。"
    rescue => e
      puts "❌ ロールバック失敗: #{e.message}"
      exit 1
    end
  end

  # スキーマ検証
  def verify_schema
    puts "\n🔍 スキーマ検証中..."

    begin
      connect

      # テーブル存在確認
      tables = @db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='keyword_pdf_generations';")

      if tables.empty?
        puts "❌ keyword_pdf_generations テーブルが見つかりません"
        return false
      end

      # カラム確認
      columns = @db.execute("PRAGMA table_info(keyword_pdf_generations);").map { |col| col['name'] }
      required_columns = [
        'id', 'uuid', 'keywords', 'date_range_start', 'date_range_end',
        'bookmark_count', 'status', 'pdf_path', 'kindle_email', 'error_message',
        'gpt_overall_summary_duration_ms', 'gpt_analysis_duration_ms',
        'gpt_keyword_extraction_duration_ms', 'gatherly_fetch_duration_ms',
        'pdf_render_duration_ms', 'total_duration_ms', 'created_at', 'updated_at'
      ]

      missing_columns = required_columns - columns
      if missing_columns.any?
        puts "❌ 不足しているカラム: #{missing_columns.join(', ')}"
        return false
      end

      # インデックス確認
      indexes = @db.execute("SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='keyword_pdf_generations';").map { |idx| idx['name'] }
      required_indexes = ['idx_keyword_pdf_generations_created_at', 'idx_keyword_pdf_generations_status']

      missing_indexes = required_indexes - indexes
      if missing_indexes.any?
        puts "⚠️  不足しているインデックス: #{missing_indexes.join(', ')}"
      end

      @db.close

      puts "✅ スキーマ検証成功！"
      puts "   テーブル: keyword_pdf_generations"
      puts "   カラム数: #{columns.length}"
      puts "   インデックス数: #{indexes.length}"
      return true
    rescue => e
      puts "❌ 検証失敗: #{e.message}"
      return false
    end
  end

  def close
    @db.close if @db
  end
end

# エントリーポイント
if __FILE__ == $0
  runner = MigrationRunner.new

  case ARGV[0]
  when 'up'
    runner.run_up
  when 'down'
    runner.run_down
  when 'verify'
    runner.verify_schema
  when nil, 'help', '-h', '--help'
    puts "使用法: ruby #{File.basename(__FILE__)} [command]"
    puts ""
    puts "Commands:"
    puts "  up       - マイグレーション実行（テーブル追加）"
    puts "  down     - ロールバック実行（テーブル削除）"
    puts "  verify   - スキーマ検証（テーブル・カラム・インデックス確認）"
    puts "  help     - このメッセージを表示"
    puts ""
    puts "例："
    puts "  ruby #{File.basename(__FILE__)} up"
    puts "  ruby #{File.basename(__FILE__)} verify"
    puts "  ruby #{File.basename(__FILE__)} down"
  else
    puts "❌ 未知のコマンド: #{ARGV[0]}"
    puts "ヘルプ: ruby #{File.basename(__FILE__)} help"
    exit 1
  end
end
