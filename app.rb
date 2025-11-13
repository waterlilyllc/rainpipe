require 'sinatra'
require 'dotenv/load'
require_relative 'raindrop_client'
require_relative 'helpers'
require_relative 'weekly_summarizer'
require_relative 'bookmark_exporter'
require_relative 'bookmark_categorizer'
require_relative 'interest_manager'
require_relative 'interest_scorer'
require_relative 'archive_manager'
require_relative 'weekly_summary_generator'
require_relative 'bookmark_content_manager'
require_relative 'form_validator'
require_relative 'keyword_filtered_pdf_service'
require_relative 'gpt_content_generator'
require_relative 'keyword_pdf_generator'
require_relative 'kindle_email_sender'
require_relative 'pdf_generation_history'

set :port, 4567
set :bind, '0.0.0.0'
disable :protection
set :server, 'webrick'

# CORS対応とセキュリティ設定
configure do
  set :protection, :except => [:frame_options, :json_csrf]
  set :allow_origin, :any
  set :allow_methods, [:get, :post, :options]
  set :allow_credentials, true
end

before do
  headers['Access-Control-Allow-Origin'] = '*'
end

get '/' do
  erb :index
end

get '/week/:date' do
  @week_start = Date.parse(params[:date]).beginning_of_week_monday
  @week_end = @week_start + 6
  @bookmarks = RaindropClient.new.get_weekly_bookmarks(@week_start, @week_end)
  @bookmarks = enrich_bookmarks_with_content(@bookmarks)
  @exporter = BookmarkExporter.new

  # 週サマリーを取得または生成
  summarizer = WeeklySummarizer.new
  @weekly_summary = summarizer.get_saved_summary(@week_start)

  # サマリーがなければ生成
  if @weekly_summary.nil? && !@bookmarks.empty?
    @weekly_summary = summarizer.generate_summary(@bookmarks, @week_start)
  end

  erb :week
end

get '/weekly' do
  @week_start = Date.today.beginning_of_week_monday
  @week_end = @week_start + 6
  @bookmarks = RaindropClient.new.get_weekly_bookmarks(@week_start, @week_end)
  @bookmarks = enrich_bookmarks_with_content(@bookmarks)

  # 週サマリーを取得または生成
  summarizer = WeeklySummarizer.new
  @weekly_summary = summarizer.get_saved_summary(@week_start)

  # サマリーがなければ生成
  if @weekly_summary.nil? && !@bookmarks.empty?
    @weekly_summary = summarizer.generate_summary(@bookmarks, @week_start)
  end

  erb :week
end

get '/monthly' do
  @month_start = Date.today.beginning_of_month
  @month_end = @month_start.next_month - 1
  bookmarks = RaindropClient.new.get_monthly_bookmarks(@month_start, @month_end)
  
  # カテゴリー別に整理
  categorizer = BookmarkCategorizer.new
  @categorized_bookmarks = categorizer.categorize_bookmarks(bookmarks)
  
  erb :month
end

get '/monthly/:year/:month' do
  @month_start = Date.new(params[:year].to_i, params[:month].to_i, 1)
  @month_end = @month_start.next_month - 1
  bookmarks = RaindropClient.new.get_monthly_bookmarks(@month_start, @month_end)
  
  # カテゴリー別に整理
  categorizer = BookmarkCategorizer.new
  @categorized_bookmarks = categorizer.categorize_bookmarks(bookmarks)
  
  erb :month
end

get '/search' do
  @query = params[:q]
  @bookmarks = @query && !@query.empty? ? RaindropClient.new.search_bookmarks(@query) : []
  @bookmarks = enrich_bookmarks_with_content(@bookmarks)
  erb :search
end

get '/tag/:tag' do
  @tag = params[:tag]
  @bookmarks = RaindropClient.new.get_bookmarks_by_tag(@tag)
  @bookmarks = enrich_bookmarks_with_content(@bookmarks)
  erb :week
end

# 新着ブックマーク再取得API（差分更新）
post '/refresh' do
  content_type :json
  
  begin
    client = RaindropClient.new
    result = client.update_bookmarks_data
    result.to_json
    
  rescue => e
    { success: false, message: "エラー: #{e.message}" }.to_json
  end
end

# 取得状況確認API
get '/refresh/status' do
  content_type :json
  # 簡単な実装：常に準備完了を返す
  { ready: true }.to_json
end

# タグ一覧API
get '/tags' do
  content_type :json
  
  begin
    all_bookmarks = RaindropClient.new.send(:load_all_bookmarks)
    
    # タグの集計
    tag_counts = Hash.new(0)
    all_bookmarks.each do |bookmark|
      if bookmark['tags'] && bookmark['tags'].any?
        bookmark['tags'].each { |tag| tag_counts[tag] += 1 }
      end
    end
    
    # 使用回数順でソート
    sorted_tags = tag_counts.sort_by { |_, count| -count }.map do |tag, count|
      { name: tag, count: count }
    end
    
    { success: true, tags: sorted_tags }.to_json
    
  rescue => e
    { success: false, message: "エラー: #{e.message}" }.to_json
  end
end

# タグページ
# 関心ワードのダッシュボード
get '/interests' do
  @interest_manager = InterestManager.new
  @latest_analysis = @interest_manager.get_latest_analysis
  
  if @latest_analysis
    @keyword_ranking = @interest_manager.get_keyword_ranking
    @keywords_by_category = @interest_manager.get_keywords_by_category
    @emerging_keywords = @interest_manager.get_emerging_keywords
    @tech_stack = @interest_manager.get_technology_stack
    @insights = @interest_manager.get_insights
    @generated_at = @latest_analysis['generated_at']
  end
  
  erb :interests
end

# キーワード詳細ページ
get '/interests/keyword/:keyword' do
  @interest_manager = InterestManager.new
  @keyword = params[:keyword]
  @history = @interest_manager.get_keyword_history(@keyword)
  @latest_analysis = @interest_manager.get_latest_analysis
  
  if @latest_analysis
    # core_interestsから検索
    interests = @latest_analysis.dig('analysis', 'core_interests') || []
    @keyword_data = interests.find { |i| i['keyword'].downcase == @keyword.downcase }
    
    # emerging_interestsからも検索
    if !@keyword_data
      emerging = @latest_analysis.dig('analysis', 'emerging_interests') || []
      emerging_data = emerging.find { |i| i['keyword'].downcase == @keyword.downcase }
      
      # emerging_interestsのデータ構造をcore_interestsと合わせる
      if emerging_data
        @keyword_data = {
          'keyword' => emerging_data['keyword'],
          'category' => 'emerging',
          'importance' => 7, # 新興キーワードなので固定値
          'frequency' => 1,
          'context' => "新興キーワード - #{emerging_data['potential']}ポテンシャル"
        }
      end
    end
    
    # 関連ブックマークを検索
    if @keyword_data && @keyword_data['examples']
      client = RaindropClient.new
      all_bookmarks = client.send(:load_all_bookmarks)
      
      @example_bookmarks = @keyword_data['examples'].map do |example_title|
        # タイトルの一部で検索
        bookmark = all_bookmarks.find { |b| 
          b['title'] && b['title'].include?(example_title[0..30])
        }
        bookmark || example_title # 見つからない場合はタイトルのみ
      end
    end
  end
  
  # キーワードに関連する記事を読み込み
  @related_articles = []
  keyword_lower = @keyword.downcase
  
  # Gemini CLI関連の記事をチェック
  if keyword_lower.include?('gemini') || keyword_lower == 'gemini cli'
    gemini_file = '/var/git/rainpipe/data/gemini_articles/latest.json'
    if File.exist?(gemini_file)
      data = JSON.parse(File.read(gemini_file))
      @related_articles.concat(data['articles'] || [])
    end
  end
  
  # Kiro関連の記事をチェック
  if keyword_lower == 'kiro'
    kiro_file = '/var/git/rainpipe/data/kiro_articles/latest.json'
    if File.exist?(kiro_file)
      data = JSON.parse(File.read(kiro_file))
      @related_articles.concat(data['articles'] || [])
    end
  end
  
  # Claude関連の記事をチェック
  if keyword_lower == 'claude'
    claude_file = '/var/git/rainpipe/data/claude_articles/latest.json'
    if File.exist?(claude_file)
      data = JSON.parse(File.read(claude_file))
      @related_articles.concat(data['articles'] || [])
    end
  end
  
  erb :keyword_detail
end

# 分析履歴
get '/interests/history' do
  @interest_manager = InterestManager.new
  @analyses = @interest_manager.get_all_analyses
  erb :interest_history
end

# スコア順の関心ワードページ
get '/interests/scores' do
  @scorer = InterestScorer.new
  @scored_interests = @scorer.calculate_scores
  @statistics = @scorer.calculate_statistics
  erb :interest_scores
end

# アーカイブページ
get '/interests/archives' do
  @archive_manager = ArchiveManager.new
  @archives = @archive_manager.get_all_archives
  erb :interest_archives
end

# キーワードの全履歴（アーカイブ含む）
get '/interests/keyword/:keyword/full-history' do
  @archive_manager = ArchiveManager.new
  @keyword = params[:keyword]
  @full_history = @archive_manager.get_keyword_full_history(@keyword)
  @observations = @archive_manager.get_keyword_observations(@keyword)
  erb :keyword_full_history
end

# Kiroの最新記事
get '/kiro/articles' do
  articles_file = '/var/git/rainpipe/data/kiro_articles/latest.json'
  if File.exist?(articles_file)
    data = JSON.parse(File.read(articles_file))
    @articles = data['articles']
    @fetched_at = data['fetched_at']
  else
    @articles = []
    @fetched_at = nil
  end
  erb :kiro_articles
end

# Gemini CLIの最新記事
get '/gemini/articles' do
  articles_file = '/var/git/rainpipe/data/gemini_articles/latest.json'
  if File.exist?(articles_file)
    data = JSON.parse(File.read(articles_file))
    @articles = data['articles']
    @fetched_at = data['fetched_at']
  else
    @articles = []
    @fetched_at = nil
  end
  erb :gemini_articles
end

get '/tags/:tag' do
  @tag = params[:tag]
  @bookmarks = RaindropClient.new.get_bookmarks_by_tag(@tag)
  erb :tag_view
end

# ブックマークエクスポートAPI
post '/export/:bookmark_id' do
  content_type :json
  
  begin
    bookmark_id = params[:bookmark_id]
    destination = params[:destination] # 'notion' or 'obsidian'
    
    # ブックマークを取得
    client = RaindropClient.new
    bookmark = client.get_bookmark_by_id(bookmark_id)
    
    unless bookmark
      return { success: false, error: 'Bookmark not found' }.to_json
    end
    
    exporter = BookmarkExporter.new
    
    # 送信先に応じてエクスポート
    result = case destination
    when 'notion'
      exporter.export_to_notion(bookmark)
    when 'obsidian'
      exporter.export_to_obsidian(bookmark)
    else
      { success: false, error: 'Invalid destination' }
    end
    
    result.to_json
  rescue => e
    { success: false, error: e.message }.to_json
  end
end

# 週次サマリーページ
get '/weekly/:date/summary' do
  @week_start = params[:date]
  @week_end = (Date.parse(@week_start) + 6).to_s
  
  # サマリーファイルの存在確認
  summary_file = "./data/weekly_summaries/summary_#{@week_start}.json"
  @summary_exists = File.exist?(summary_file)
  
  if @summary_exists
    @summary_data = JSON.parse(File.read(summary_file))
  end
  
  erb :weekly_summary
end

# サマリー生成API
post '/weekly/:date/generate-summary' do
  content_type :json
  
  begin
    week_start = params[:date]
    generator = WeeklySummaryGenerator.new
    
    # バックグラウンドで生成（本来は非同期処理が望ましい）
    summary = generator.generate_weekly_summary(week_start)
    
    if summary
      { success: true, message: 'サマリーを生成しました' }.to_json
    else
      { success: false, error: 'サマリー生成に失敗しました' }.to_json
    end
  rescue => e
    { success: false, error: e.message }.to_json
  end
end

# デイリー観測サマリーページ
get "/daily/summary" do
  summary_file = "./data/daily_observations/latest_observation.json"
  
  if File.exist?(summary_file)
    data = JSON.parse(File.read(summary_file))
    @observation_data = data
    @daily_summary = data["daily_summary"]
    @observations = data["observations"]
  else
    @observation_data = nil
    @daily_summary = nil
    @observations = []
  end
  
  erb :daily_summary
end

# キーワード別 PDF 生成フォーム表示（Task 2.1）
get '/filtered_pdf' do
  # デフォルト値を設定
  @keywords = params[:keywords] || ''
  @date_start = params[:date_start] || (Date.today.prev_month(2)).to_s
  @date_end = params[:date_end] || Date.today.to_s
  @send_to_kindle = params[:send_to_kindle] == 'true'

  @error_message = nil
  @success_message = nil

  erb :filtered_pdf
end

# Task 9.5: 生成履歴表示（GET /filtered_pdf/history）
get '/filtered_pdf/history' do
  history = PDFGenerationHistory.new('rainpipe.db')
  @records = history.fetch_history(20)

  erb :filtered_pdf_history
end

# キーワード別 PDF 生成リクエスト処理（Task 2.2 検証 + Task 8.1）
post '/filtered_pdf/generate' do
  # フォーム入力値を取得
  keywords = params[:keywords] || ''
  date_start = params[:date_start] || ''
  date_end = params[:date_end] || ''
  send_to_kindle = params[:send_to_kindle] == 'on' || params[:send_to_kindle] == 'true'

  # バリデーション（Task 2.2）
  validator = FormValidator.new
  unless validator.validate(keywords: keywords, date_start: date_start, date_end: date_end)
    # バリデーション失敗時はエラーメッセージとともにフォームに戻す
    @keywords = keywords
    @date_start = date_start
    @date_end = date_end
    @send_to_kindle = send_to_kindle
    @error_message = validator.errors.join("\n")
    @success_message = nil
    return erb :filtered_pdf
  end

  # Task 9.1: PDF 生成前に DB で in-progress ステータスチェック
  history = PDFGenerationHistory.new('rainpipe.db')
  if history.has_processing_record?
    @keywords = keywords
    @date_start = date_start
    @date_end = date_end
    @send_to_kindle = send_to_kindle
    @error_message = history.get_processing_warning
    @success_message = nil
    return erb :filtered_pdf
  end

  # Task 8.1: KeywordFilteredPDFService を使用して PDF 生成リクエスト処理
  begin
    service = KeywordFilteredPDFService.new(
      keywords: keywords,
      date_start: date_start,
      date_end: date_end
    )

    result = service.execute

    # Task 9.2: 生成開始時に DB record 作成
    pdf_uuid = history.create_processing_record(
      keywords,
      { start: date_start, end: date_end },
      result[:bookmarks].length
    )

    # Task 8.4: エラー時の処理
    if result[:status] == 'error'
      # Task 9.4: エラー時に DB record を status=failed に更新
      history.mark_failed(pdf_uuid, result[:error] || "PDF 生成に失敗しました")

      @keywords = keywords
      @date_start = date_start
      @date_end = date_end
      @send_to_kindle = send_to_kindle
      @error_message = result[:error] || "PDF 生成に失敗しました"
      @success_message = nil
      return erb :filtered_pdf
    end

    # PDF ファイル生成（Task 6）
    bookmarks = result[:bookmarks]
    if bookmarks.empty?
      # Task 9.4: エラー時に DB record を status=failed に更新
      history.mark_failed(pdf_uuid, "フィルタに合致するブックマークが見つかりません")

      @keywords = keywords
      @date_start = date_start
      @date_end = date_end
      @send_to_kindle = send_to_kindle
      @error_message = "フィルタに合致するブックマークが見つかりません"
      @success_message = nil
      return erb :filtered_pdf
    end

    # GPT コンテンツ生成（Task 5）
    gpt_generator = GPTContentGenerator.new(ENV['OPENAI_API_KEY'], false)
    summary_result = gpt_generator.generate_overall_summary(bookmarks, keywords)
    keywords_result = gpt_generator.extract_related_keywords(bookmarks)
    analysis_result = gpt_generator.generate_analysis(bookmarks, keywords)

    # PDF 生成（Task 6）
    pdf_content = {
      summary: summary_result[:summary],
      related_clusters: keywords_result[:related_clusters],
      analysis: analysis_result[:analysis],
      bookmarks: bookmarks,
      keywords: keywords,
      date_range: result[:date_range]
    }

    pdf_generator = KeywordPDFGenerator.new
    output_path = File.join('data', "filtered_pdf_#{Time.now.utc.strftime('%Y%m%d_%H%M%S')}_#{keywords.gsub(/[^a-zA-Z0-9]/, '_')}.pdf")
    pdf_result = pdf_generator.generate(pdf_content, output_path)

    # Task 9.3: PDF 完成時に DB record を status=completed に更新
    total_duration = pdf_result[:duration_ms] + summary_result[:duration_ms] + keywords_result[:duration_ms] + analysis_result[:duration_ms]
    history.mark_completed(pdf_uuid, pdf_result[:pdf_path], total_duration)

    # Task 8.2 & 8.3: ダウンロード または Kindle 送信
    if send_to_kindle
      # Task 8.3: Kindle メール送信
      begin
        email_sender = KindleEmailSender.new
        email_sender.send_pdf(pdf_result[:pdf_path], nil)

        @keywords = keywords
        @date_start = date_start
        @date_end = date_end
        @send_to_kindle = send_to_kindle
        @error_message = nil
        @success_message = "✅ Kindle に PDF を送信しました！"
        erb :filtered_pdf
      rescue => e
        # Task 9.4: メール送信失敗時に DB 更新
        history.mark_failed(pdf_uuid, "メール送信に失敗: #{e.message}")

        @keywords = keywords
        @date_start = date_start
        @date_end = date_end
        @send_to_kindle = send_to_kindle
        @error_message = "メール送信に失敗しました: #{e.message}"
        @success_message = nil
        erb :filtered_pdf
      end
    else
      # Task 8.2: PDF ダウンロード
      send_file(
        pdf_result[:pdf_path],
        type: 'application/pdf',
        disposition: 'attachment',
        filename: File.basename(pdf_result[:pdf_path])
      )
    end
  rescue => e
    # Task 9.4: 予期しないエラー時に DB record を status=failed に更新
    if pdf_uuid
      history.mark_failed(pdf_uuid, e.message)
    end

    # Task 8.4: 予期しないエラーのハンドリング
    @keywords = keywords
    @date_start = date_start
    @date_end = date_end
    @send_to_kindle = send_to_kindle
    @error_message = "エラーが発生しました: #{e.message}"
    @success_message = nil
    erb :filtered_pdf
  end
end

