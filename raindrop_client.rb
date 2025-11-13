require 'net/http'
require 'json'
require 'uri'
require 'date'
require_relative 'auto_tagger'
require_relative 'bookmark_content_fetcher'

class RaindropClient
  API_BASE = 'https://api.raindrop.io/rest/v1'
  
  def initialize
    @api_token = ENV['RAINDROP_API_TOKEN']
    raise 'RAINDROP_API_TOKEN not found in environment' unless @api_token
  end

  def get_weekly_bookmarks(start_date, end_date)
    # ローカルファイルから取得してフィルタリング
    all_bookmarks = load_all_bookmarks
    filter_by_date_range(all_bookmarks, start_date, end_date)
  end

  def get_monthly_bookmarks(start_date, end_date)
    # ローカルファイルから取得してフィルタリング
    all_bookmarks = load_all_bookmarks
    filter_by_date_range(all_bookmarks, start_date, end_date)
  end

  def get_bookmarks_by_date_range(start_date, end_date)
    # ローカルファイルから取得してフィルタリング
    all_bookmarks = load_all_bookmarks
    filter_by_date_range(all_bookmarks, start_date, end_date)
  end

  def load_all_bookmarks
    # data/ディレクトリから最新のJSONファイルを読み込み
    data_dir = File.join(File.dirname(__FILE__), 'data')
    puts "🔍 データディレクトリ確認: #{data_dir}"
    
    unless Dir.exist?(data_dir)
      puts "❌ データディレクトリが存在しません"
      return get_raindrops_with_pagination(nil, 0, 50)
    end
    
    json_files = Dir.glob(File.join(data_dir, 'all_bookmarks_*.json'))
    puts "📁 見つかったファイル: #{json_files}"
    
    if json_files.empty?
      puts "❌ JSONファイルが見つかりません"
      return get_raindrops_with_pagination(nil, 0, 50)
    end
    
    # 最新のファイルを使用
    latest_file = json_files.max_by { |f| File.mtime(f) }
    puts "📚 読み込み: #{File.basename(latest_file)} (#{JSON.parse(File.read(latest_file)).length}件)"
    
    JSON.parse(File.read(latest_file))
  rescue => e
    puts "❌ ブックマークファイル読み込みエラー: #{e.message}"
    # フォールバック: APIから少しだけ取得
    get_raindrops_with_pagination(nil, 0, 50)
  end

  def get_new_bookmarks_only
    # 既存データの最新日付を取得
    existing_data = load_all_bookmarks
    if existing_data.empty?
      puts "📚 既存データなし、全件取得します"
      return get_all_bookmarks
    end
    
    # 最新ブックマークの日付を取得
    latest_created = existing_data.map { |b| DateTime.parse(b['created']) }.max
    puts "📅 既存データの最新日付: #{latest_created}"
    
    # その日付以降の新着のみ取得
    new_bookmarks = []
    page = 0
    
    loop do
      puts "📄 新着確認 ページ #{page + 1}..."
      bookmarks = get_raindrops_with_pagination(nil, page, 50)
      
      if bookmarks.empty?
        puts "✅ API終端に到達"
        break
      end
      
      # 日付でフィルタリング
      page_new_bookmarks = bookmarks.select do |bookmark|
        bookmark_created = DateTime.parse(bookmark['created'])
        bookmark_created > latest_created
      end
      
      new_bookmarks.concat(page_new_bookmarks)
      
      # このページに古いデータが含まれていたら終了
      if page_new_bookmarks.length < bookmarks.length
        puts "📊 古いデータに到達、取得終了"
        break
      end
      
      page += 1
      sleep(0.3) # API制限対策
    end
    
    puts "🎉 新着 #{new_bookmarks.length} 件を取得"
    new_bookmarks
  end

  def update_bookmarks_data(enable_auto_tagging: true, enable_content_fetch: true)
    new_bookmarks = get_new_bookmarks_only

    if new_bookmarks.empty?
      return { success: true, new_count: 0, message: "新着ブックマークはありません" }
    end

    # 🏷️ 自動タグ付けを実行
    if enable_auto_tagging && ENV['OPENAI_API_KEY']
      puts "🤖 自動タグ付けを開始..."
      auto_tagger = AutoTagger.new

      tagged_count = 0
      failed_count = 0

      new_bookmarks.each_with_index do |bookmark, index|
        puts "\n[#{index + 1}/#{new_bookmarks.length}] 処理中..."

        result = auto_tagger.process_bookmark_with_tags(bookmark)

        if result[:success]
          tagged_count += 1
        else
          failed_count += 1
        end

        # API制限対策で少し待機
        sleep(1) if index < new_bookmarks.length - 1
      end

      puts "\n🎉 自動タグ付け完了!"
      puts "   成功: #{tagged_count}件"
      puts "   失敗: #{failed_count}件" if failed_count > 0
    else
      puts "⚠️ 自動タグ付けはスキップされました"
      puts "   理由: #{ENV['OPENAI_API_KEY'] ? '無効化されています' : 'OPENAI_API_KEYが設定されていません'}"
    end

    # 📄 本文取得ジョブを作成
    if enable_content_fetch && ENV['GATHERLY_API_KEY']
      puts "\n📚 本文取得ジョブを作成中..."
      fetcher = BookmarkContentFetcher.new

      job_count = 0
      skipped_count = 0
      new_bookmarks.each do |bookmark|
        next unless bookmark['link'] && !bookmark['link'].empty?

        begin
          job_uuid = fetcher.fetch_content(bookmark['_id'], bookmark['link'])
          if job_uuid
            job_count += 1
            print "."
          else
            skipped_count += 1
          end
        rescue => e
          puts "\n⚠️ ジョブ作成失敗 (ID:#{bookmark['_id']}): #{e.message}"
        end

        # API制限対策
        sleep(0.5)
      end

      puts "\n✅ 本文取得ジョブ作成完了: #{job_count}件"
      puts "   ⏭️  スキップ: #{skipped_count}件（失敗済みまたは既存）" if skipped_count > 0
      puts "   ℹ️ 本文はバックグラウンドで取得されます（数分後に完了）"
    else
      puts "\n⚠️ 本文取得はスキップされました"
      puts "   理由: #{ENV['GATHERLY_API_KEY'] ? '無効化されています' : 'GATHERLY_API_KEYが設定されていません'}"
    end
    
    # 既存データと結合
    existing_data = load_all_bookmarks
    updated_data = new_bookmarks + existing_data
    
    # 重複除去（IDベース）
    unique_data = updated_data.uniq { |bookmark| bookmark['_id'] }
    
    # 日付順にソート（新しい順）
    sorted_data = unique_data.sort_by { |b| DateTime.parse(b['created']) }.reverse
    
    # 新しいファイルに保存
    data_dir = File.join(File.dirname(__FILE__), 'data')
    Dir.mkdir(data_dir) unless Dir.exist?(data_dir)
    
    filename = File.join(data_dir, "all_bookmarks_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json")
    File.write(filename, JSON.pretty_generate(sorted_data))
    
    puts "💾 更新完了: #{filename} (#{sorted_data.length}件)"
    
    {
      success: true,
      new_count: new_bookmarks.length,
      total_count: sorted_data.length,
      message: "#{new_bookmarks.length}件の新着ブックマークを取得しました#{enable_auto_tagging ? '（自動タグ付け済み）' : ''}"
    }
  end

  def filter_by_date_range(bookmarks, start_date, end_date)
    require 'date'
    # 文字列の場合はDateオブジェクトに変換
    start_date = Date.parse(start_date) if start_date.is_a?(String)
    end_date = Date.parse(end_date) if end_date.is_a?(String)
    
    bookmarks.select do |bookmark|
      created_date = Date.parse(bookmark['created'])
      created_date >= start_date && created_date <= end_date
    end
  end

  def search_bookmarks(query)
    get_raindrops(query)
  end

  def get_bookmarks_by_tag(tag)
    query = "##{tag}"
    get_raindrops(query)
  end
  
  def get_bookmark_by_id(bookmark_id)
    all_bookmarks = load_all_bookmarks
    all_bookmarks.find { |bookmark| bookmark['_id'].to_s == bookmark_id.to_s }
  end

  def get_all_bookmarks
    all_bookmarks = []
    page = 0
    per_page = 50

    loop do
      puts "📄 ページ #{page + 1} を取得中... (#{all_bookmarks.length} 件取得済み)"
      
      bookmarks = get_raindrops_with_pagination(nil, page, per_page)
      
      if bookmarks.empty?
        puts "✅ 全てのブックマークを取得完了"
        break
      end
      
      all_bookmarks.concat(bookmarks)
      page += 1
      
      # API レート制限対策
      sleep(0.5)
    end
    
    puts "🎉 合計 #{all_bookmarks.length} 件のブックマークを取得しました"
    all_bookmarks
  end

  private

  def get_raindrops(query = nil)
    get_raindrops_with_pagination(query, 0, 25)
  end

  def get_raindrops_with_pagination(query = nil, page = 0, per_page = 25)
    uri = URI("#{API_BASE}/raindrops/0")
    
    params = { page: page, perpage: per_page }
    params[:search] = query if query
    
    uri.query = URI.encode_www_form(params)

    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{@api_token}"
    request['Content-Type'] = 'application/json'

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.code == '200'
      data = JSON.parse(response.body)
      data['items'] || []
    else
      puts "API Error: #{response.code} - #{response.body}"
      []
    end
  rescue => e
    puts "Error fetching raindrops: #{e.message}"
    []
  end
end