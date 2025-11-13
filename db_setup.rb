#!/usr/bin/env ruby
require 'sqlite3'

# データベースファイルのパス
DB_PATH = File.join(File.dirname(__FILE__), 'data', 'rainpipe.db')

def setup_database
  # dataディレクトリが存在しない場合は作成
  data_dir = File.dirname(DB_PATH)
  Dir.mkdir(data_dir) unless Dir.exist?(data_dir)

  puts "📦 データベースを作成中: #{DB_PATH}"

  db = SQLite3::Database.new(DB_PATH)

  # bookmark_contents テーブル作成
  puts "📝 bookmark_contents テーブル作成中..."
  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS bookmark_contents (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      raindrop_id INTEGER UNIQUE NOT NULL,
      url TEXT NOT NULL,
      title TEXT,
      content TEXT,
      content_type VARCHAR(20),
      word_count INTEGER,
      extracted_at DATETIME,
      fetch_attempted BOOLEAN DEFAULT 0,
      fetch_failed BOOLEAN DEFAULT 0,
      last_fetch_attempt DATETIME,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
  SQL

  db.execute "CREATE INDEX IF NOT EXISTS idx_bookmark_contents_raindrop_id ON bookmark_contents(raindrop_id);"
  db.execute "CREATE INDEX IF NOT EXISTS idx_bookmark_contents_url ON bookmark_contents(url);"

  # crawl_jobs テーブル作成
  puts "📝 crawl_jobs テーブル作成中..."
  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS crawl_jobs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      job_id VARCHAR(100) UNIQUE NOT NULL,
      raindrop_id INTEGER,
      url TEXT NOT NULL,
      status VARCHAR(20) NOT NULL,
      error_message TEXT,
      retry_count INTEGER DEFAULT 0,
      max_retries INTEGER DEFAULT 3,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      completed_at DATETIME
    );
  SQL

  db.execute "CREATE INDEX IF NOT EXISTS idx_crawl_jobs_job_id ON crawl_jobs(job_id);"
  db.execute "CREATE INDEX IF NOT EXISTS idx_crawl_jobs_status ON crawl_jobs(status);"
  db.execute "CREATE INDEX IF NOT EXISTS idx_crawl_jobs_raindrop_id ON crawl_jobs(raindrop_id);"

  puts "✅ データベースセットアップ完了！"

  # テーブル一覧を表示
  tables = db.execute("SELECT name FROM sqlite_master WHERE type='table';")
  puts "\n📊 作成されたテーブル:"
  tables.each do |table|
    puts "  - #{table[0]}"
  end

  db.close
end

if __FILE__ == $0
  setup_database
end
