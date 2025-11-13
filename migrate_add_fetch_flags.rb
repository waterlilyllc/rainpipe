#!/usr/bin/env ruby
require 'sqlite3'

DB_PATH = File.join(File.dirname(__FILE__), 'data', 'rainpipe.db')

puts "📦 データベースマイグレーション開始"
puts "   対象: #{DB_PATH}"
puts ""

db = SQLite3::Database.new(DB_PATH)

# 既存のカラムをチェック
columns = db.execute("PRAGMA table_info(bookmark_contents);")
column_names = columns.map { |col| col[1] }

puts "📋 既存のカラム:"
column_names.each { |name| puts "  - #{name}" }
puts ""

# 必要なカラムを追加
new_columns = [
  ['fetch_attempted', 'BOOLEAN DEFAULT 0'],
  ['fetch_failed', 'BOOLEAN DEFAULT 0'],
  ['last_fetch_attempt', 'DATETIME']
]

added_count = 0
new_columns.each do |col_name, col_type|
  unless column_names.include?(col_name)
    puts "➕ カラム追加: #{col_name} (#{col_type})"
    db.execute("ALTER TABLE bookmark_contents ADD COLUMN #{col_name} #{col_type};")
    added_count += 1
  else
    puts "✓ カラム既存: #{col_name}"
  end
end

puts ""
if added_count > 0
  puts "✅ マイグレーション完了！ #{added_count}個のカラムを追加しました。"
else
  puts "✅ 既に最新の状態です。"
end

db.close
