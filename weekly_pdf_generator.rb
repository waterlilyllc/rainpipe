require 'prawn'
require 'prawn/table'
require 'date'
require 'json'
require_relative 'raindrop_client'
require_relative 'bookmark_content_manager'
require_relative 'weekly_summary_generator'
require_relative 'bookmark_content_fetcher'

class WeeklyPDFGenerator
  FONT_PATH = '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc'
  SUMMARY_DIR = './data/weekly_summaries'

  def initialize
    @client = RaindropClient.new
    @content_manager = BookmarkContentManager.new
    @content_fetcher = BookmarkContentFetcher.new
    @summary_generator = WeeklySummaryGenerator.new if ENV['OPENAI_API_KEY']
  end

  # 先週のPDFを生成
  # @param output_path [String] 出力先パス
  # @return [String] 生成されたPDFのパス
  def generate_last_week_pdf(output_path = nil)
    # 先週の月曜〜日曜を計算（月曜開始）
    today = Date.today
    this_monday = today - (today.wday - 1) % 7  # 今週の月曜
    last_monday = this_monday - 7                # 先週の月曜
    last_sunday = last_monday + 6                # 先週の日曜

    generate_weekly_pdf(last_monday, last_sunday, output_path)
  end

  # 指定週のPDFを生成
  # @param week_start [Date] 週の開始日（月曜）
  # @param week_end [Date] 週の終了日（日曜）
  # @param output_path [String] 出力先パス
  # @return [String] 生成されたPDFのパス
  def generate_weekly_pdf(week_start, week_end, output_path = nil)
    # ブックマークを取得
    bookmarks = @client.get_weekly_bookmarks(week_start, week_end)

    # 本文データを付加
    bookmarks = enrich_bookmarks_with_content(bookmarks)

    # 週次サマリーを取得または生成
    summary_data = load_or_generate_summary(week_start)

    # 出力パスの決定（キーワードをファイル名に含める）
    if output_path.nil?
      keywords = extract_keywords_for_filename(summary_data)
      if keywords.any?
        keyword_str = keywords.first(3).join('_')
        output_path = "data/#{week_start.strftime('%m%d')}_#{keyword_str}.pdf"
      else
        output_path = "data/weekly_#{week_start.strftime('%Y%m%d')}.pdf"
      end
    end

    # PDF生成
    generate_pdf(bookmarks, week_start, week_end, output_path, summary_data)

    output_path
  end

  private

  # ファイル名用のキーワードを抽出
  def extract_keywords_for_filename(summary_data)
    return [] unless summary_data

    keywords = []

    # keywordsから取得
    if summary_data['keywords'] && summary_data['keywords'].is_a?(Hash)
      keywords += summary_data['keywords'].keys
    end

    # primary_interestsからも取得
    if summary_data['primary_interests'] && summary_data['primary_interests'].is_a?(Array)
      summary_data['primary_interests'].each do |interest|
        keyword = interest['keyword'] || interest[:keyword]
        keywords << keyword if keyword
      end
    end

    # 重複を除去、ファイル名に使えない文字を除去
    keywords.uniq.map { |k| k.gsub(/[\/\\:*?"<>|]/, '') }
  end

  def load_or_generate_summary(week_start)
    summary_file = File.join(SUMMARY_DIR, "summary_#{week_start.strftime('%Y-%m-%d')}.json")

    if File.exist?(summary_file)
      puts "📊 既存のサマリーを読み込み: #{summary_file}"
      JSON.parse(File.read(summary_file))
    elsif @summary_generator
      puts "✨ 週次サマリーを生成中..."
      @summary_generator.generate_weekly_summary(week_start.to_s)
      # 生成後、ファイルからリロードして文字列キーに統一
      if File.exist?(summary_file)
        JSON.parse(File.read(summary_file))
      else
        nil
      end
    else
      puts "⚠️ サマリー生成をスキップ（OPENAI_API_KEY未設定）"
      nil
    end
  rescue => e
    puts "⚠️ サマリー取得失敗: #{e.message}"
    nil
  end

  def setup_japanese_font(pdf)
    # 日本語フォントパスの候補（優先順位順）
    font_candidates = [
      '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
      '/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc',
      '/usr/share/fonts/opentype/ipafont-gothic/ipag.ttf',
      '/usr/share/fonts/opentype/ipafont-mincho/ipam.ttf',
      '/usr/share/fonts/truetype/fonts-japanese-gothic.ttf',
      '/usr/share/fonts/truetype/fonts-japanese-mincho.ttf'
    ]

    font_path = font_candidates.find { |f| File.exist?(f) }

    if font_path
      pdf.font_families.update(
        'Japanese' => {
          normal: font_path,
          bold: font_path,   # boldもnormalと同じフォントを使用
          italic: font_path,  # italicもnormalと同じフォントを使用
          bold_italic: font_path
        }
      )
      pdf.font 'Japanese'
      puts "✅ 日本語フォントを使用: #{File.basename(font_path)}"
    else
      puts "⚠️ 日本語フォントが見つかりません"
      raise "日本語フォントが必要です。sudo apt-get install fonts-ipafont-gothic"
    end
  end

  def enrich_bookmarks_with_content(bookmarks)
    return [] if bookmarks.nil? || bookmarks.empty?

    # 本文がないブックマークを検出してクロールジョブを作成
    missing_content_bookmarks = []
    bookmarks.each do |bookmark|
      content = @content_manager.get_content(bookmark['_id'])
      if content.nil?
        missing_content_bookmarks << bookmark
      end
    end

    # 本文がないブックマークがあれば、クロールジョブを作成
    if missing_content_bookmarks.any?
      puts "⚠️  本文未取得のブックマークが#{missing_content_bookmarks.length}件あります"
      puts "📥 本文取得ジョブを並列作成中（時間差オーダーで phantom UUID 回避）..."
      puts ""

      created_jobs = []
      jobs_mutex = Mutex.new

      # 並列だが時間差でジョブ作成（phantom UUID 対策）
      threads = missing_content_bookmarks.map.with_index do |bookmark, i|
        Thread.new do
          # スレッド開始時に時間差を入れる（0.2秒ずつ）
          sleep(i * 0.2)

          jobs_mutex.synchronize do
            puts "[#{i+1}/#{missing_content_bookmarks.length}] #{bookmark['title'][0..60]}..."
          end

          job_uuid = @content_fetcher.fetch_content(bookmark['_id'], bookmark['link'])

          if job_uuid
            jobs_mutex.synchronize do
              puts "  ✅ ジョブ作成完了: #{job_uuid}"
              created_jobs << { raindrop_id: bookmark['_id'], job_uuid: job_uuid }
              puts ""
            end
          else
            jobs_mutex.synchronize do
              puts "  ⚠️  ジョブ作成スキップまたは失敗"
              puts ""
            end
          end
        end
      end

      # 全スレッド完了を待つ
      threads.each(&:join)

      # Gatherly API で完了を待つ（最大10分）
      if created_jobs.any?
        puts "⏳ Gatherly クロール完了を待機中（最大10分）..."
        puts ""

        wait_for_gatherly_completion(created_jobs, timeout: 600)

        # 完了したジョブの結果を直接取得
        puts ""
        puts "📥 Gatherly API から結果を直接取得中..."
        puts ""

        fetch_completed_job_results(created_jobs)

        # ChatGPT で要約生成
        puts ""
        puts "📝 ChatGPT で要約生成中..."
        puts ""

        summarize_new_contents(created_jobs.map { |j| j[:raindrop_id] })
      end
    end

    # コンテンツがあるが要約されていないブックマークも要約対象にする
    unsummarized_ids = []
    bookmarks.each do |bookmark|
      content = @content_manager.get_content(bookmark['_id'])
      if content && content['content'] && content['content'].length > 100
        # 箇条書き形式でなければ未要約
        unless content['content'].strip.start_with?('- ')
          unsummarized_ids << bookmark['_id']
        end
      end
    end

    if unsummarized_ids.any?
      puts ""
      puts "📝 未要約コンテンツ #{unsummarized_ids.length}件 をChatGPTで要約中..."
      puts ""
      summarize_new_contents(unsummarized_ids)
    end

    # 本文データを付加
    bookmarks.map do |bookmark|
      content = @content_manager.get_content(bookmark['_id'])
      bookmark['content_data'] = content if content
      bookmark
    end
  end

  # Gatherly API でジョブ完了を待つ
  def wait_for_gatherly_completion(jobs, timeout: 600)
    require_relative 'gatherly_client'
    gatherly = GatherlyClient.new

    start_time = Time.now
    remaining_jobs = jobs.dup
    check_interval = 5

    while remaining_jobs.any? && (Time.now - start_time) < timeout
      sleep check_interval

      remaining_jobs.reject! do |job|
        result = gatherly.get_job_status(job[:job_uuid])

        if result[:error]
          puts "  ❌ Job #{job[:job_uuid]}: API Error"
          true # エラーの場合は諦める
        elsif result[:status] == 'completed'
          puts "  ✅ Job #{job[:job_uuid]}: completed"
          true
        else
          false
        end
      end

      elapsed = (Time.now - start_time).to_i
      if remaining_jobs.any? && elapsed % 30 == 0
        puts "  待機中... (経過: #{elapsed}秒, 残り: #{remaining_jobs.length}件)"
      end
    end

    if remaining_jobs.any?
      puts ""
      puts "⚠️  #{remaining_jobs.length}件のジョブがタイムアウトしました"
    else
      puts ""
      puts "✅ 全てのジョブが完了しました"
    end
  end

  # Gatherly API から完了したジョブの結果を並列取得
  def fetch_completed_job_results(jobs)
    require_relative 'gatherly_client'
    require 'sqlite3'

    gatherly = GatherlyClient.new

    success_count = 0
    failed_count = 0
    mutex = Mutex.new

    puts "並列で #{jobs.length}件の結果を取得中..."
    puts ""

    # 並列でAPI結果取得（ジョブ作成と違って安全）
    threads = jobs.map.with_index do |job, i|
      Thread.new do
        raindrop_id = job[:raindrop_id]
        job_uuid = job[:job_uuid]

        mutex.synchronize { puts "[#{i+1}/#{jobs.length}] Job #{job_uuid}" }

        result = gatherly.get_job_result(job_uuid)

        if result[:error]
          mutex.synchronize do
            puts "  ❌ 結果取得失敗: #{result[:error]}"
            puts ""
            failed_count += 1
          end
          next
        end

        if result[:items].nil? || result[:items].empty?
          mutex.synchronize do
            puts "  ⚠️  結果が空です"
            puts ""
            failed_count += 1
          end
          next
        end

        first_item = result[:items].first
        content = first_item.dig(:body, :content)

        if content.nil? || content.empty?
          mutex.synchronize do
            puts "  ⚠️  コンテンツが空です"
            puts ""
            failed_count += 1
          end
          next
        end

        mutex.synchronize { puts "  ✅ コンテンツ取得: #{content.length} chars" }

        # データベースに保存（スレッドセーフ）
        data = {
          content: content,
          title: first_item.dig(:body, :title),
          url: first_item[:external_id],
          content_type: 'text',
          word_count: content.length,
          extracted_at: first_item[:fetched_at]
        }

        db = SQLite3::Database.new('data/rainpipe.db')

        if @content_manager.save_content(raindrop_id, data)
          mutex.synchronize { puts "  ✅ DB保存成功" }

          # ジョブステータスを更新
          db.execute(
            "UPDATE crawl_jobs SET status = 'success', updated_at = datetime('now') WHERE job_id = ?",
            [job_uuid]
          )

          mutex.synchronize do
            success_count += 1
            puts ""
          end
        else
          mutex.synchronize do
            puts "  ❌ DB保存失敗"
            puts ""
            failed_count += 1
          end
        end

        db.close
      end
    end

    # 全スレッド完了を待つ
    threads.each(&:join)

    puts "結果: 保存成功 #{success_count}/#{jobs.length}, 失敗 #{failed_count}/#{jobs.length}"
  end

  # ChatGPT で要約生成（並列）
  def summarize_new_contents(raindrop_ids)
    require 'net/http'
    require 'json'
    require 'uri'
    require 'sqlite3'

    api_key = ENV['OPENAI_API_KEY']
    unless api_key
      puts "⚠️  OPENAI_API_KEY が設定されていません。要約をスキップします。"
      return
    end

    success_count = 0
    failed_count = 0
    summary_mutex = Mutex.new

    puts "並列で #{raindrop_ids.length}件を要約中..."
    puts ""

    # 並列で要約生成（時間差オーダー）
    threads = raindrop_ids.map.with_index do |raindrop_id, i|
      Thread.new do
        # 時間差を入れる（OpenAI API レート制限対策：0.5秒ずつ）
        sleep(i * 0.5)

        db = SQLite3::Database.new('data/rainpipe.db')
        db.results_as_hash = true

        row = db.get_first_row(
          "SELECT raindrop_id, title, content FROM bookmark_contents WHERE raindrop_id = ?",
          [raindrop_id]
        )

        unless row
          summary_mutex.synchronize do
            puts "[#{i+1}/#{raindrop_ids.length}] ❌ ID #{raindrop_id}: データなし"
            puts ""
            failed_count += 1
          end
          db.close
          next
        end

        content = row['content']
        title = row['title']

        # コンテンツがない場合はスキップ
        if content.nil? || content.strip.empty?
          summary_mutex.synchronize do
            puts "[#{i+1}/#{raindrop_ids.length}] ⏭️  ID #{raindrop_id}: コンテンツなし"
            puts ""
            failed_count += 1
          end
          db.close
          next
        end

        # 既に要約済みかチェック
        if content.strip.start_with?('- ')
          summary_mutex.synchronize do
            puts "[#{i+1}/#{raindrop_ids.length}] ⏭️  ID #{raindrop_id}: 既に要約済み"
            puts ""
            success_count += 1
          end
          db.close
          next
        end

        summary_mutex.synchronize do
          puts "[#{i+1}/#{raindrop_ids.length}] 📄 ID #{raindrop_id}"
          puts "  Title: #{title[0..60]}..."
        end

        # OpenAI APIで要約
        summary = summarize_with_openai(content, title, api_key)

        if summary
          summary_mutex.synchronize { puts "  ✅ 要約完了" }

          db.execute(
            "UPDATE bookmark_contents SET content = ?, updated_at = datetime('now') WHERE raindrop_id = ?",
            [summary, raindrop_id]
          )

          summary_mutex.synchronize do
            success_count += 1
            puts ""
          end
        else
          summary_mutex.synchronize do
            puts "  ❌ 要約失敗"
            puts ""
            failed_count += 1
          end
        end

        db.close
      end
    end

    # 全スレッド完了を待つ
    threads.each(&:join)

    puts "要約結果: 成功 #{success_count}/#{raindrop_ids.length}, 失敗 #{failed_count}/#{raindrop_ids.length}"
  end

  def summarize_with_openai(content, title, api_key)
    uri = URI.parse('https://api.openai.com/v1/chat/completions')

    prompt = <<~PROMPT
      以下の記事を10個程度の箇条書きで要約してください。
      各箇条書きは「- 」で始めてください。
      重要なポイントを簡潔にまとめてください。

      記事タイトル: #{title}

      記事本文:
      #{content[0..3000]}
    PROMPT

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['Authorization'] = "Bearer #{api_key}"

    request.body = {
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: 'あなたは記事を簡潔に要約する専門家です。' },
        { role: 'user', content: prompt }
      ],
      temperature: 0.3,
      max_tokens: 1000
    }.to_json

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 60

    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      result = JSON.parse(response.body)
      result.dig('choices', 0, 'message', 'content')
    else
      puts "  ❌ API Error: #{response.code} #{response.message}"
      nil
    end
  rescue => e
    puts "  ❌ Exception: #{e.message}"
    nil
  end

  def generate_pdf(bookmarks, week_start, week_end, output_path, summary_data = nil)
    Prawn::Document.generate(output_path, page_size: 'A4', margin: 40) do |pdf|
      # 日本語フォント設定
      setup_japanese_font(pdf)

      # 表紙ページ（キーワード付き）
      add_cover_page(pdf, week_start, week_end, bookmarks, summary_data)
      pdf.start_new_page

      # サマリーセクション（ある場合）
      has_keywords = summary_data && summary_data['keywords'] && !summary_data['keywords'].empty?
      has_clusters = summary_data && summary_data['related_clusters'] && summary_data['related_clusters'].any?

      puts "  [PDF] summary_data: #{summary_data.class}"
      puts "  [PDF] keywords: #{summary_data&.dig('keywords').class} = #{summary_data&.dig('keywords').inspect}"
      puts "  [PDF] related_clusters: #{summary_data&.dig('related_clusters').class} = #{summary_data&.dig('related_clusters')&.length}"
      puts "  [PDF] has_keywords=#{has_keywords}, has_clusters=#{has_clusters}"

      if has_keywords || has_clusters
        puts "  [PDF] サマリーセクションを追加します"
        add_weekly_summary(pdf, summary_data)
        pdf.start_new_page
      else
        puts "  [PDF] サマリーセクションをスキップ"
      end

      # 目次
      add_table_of_contents(pdf, bookmarks)

      # 各ブックマークの詳細
      bookmarks.each_with_index do |bookmark, index|
        pdf.start_new_page if index > 0
        add_bookmark_detail(pdf, bookmark, index + 1, bookmarks.length)
      end

      # フッター（ページ番号）
      add_page_numbers(pdf)
    end
  end

  # 表紙専用ページ
  def add_cover_page(pdf, week_start, week_end, bookmarks, summary_data = nil)
    bookmark_count = bookmarks.length
    with_summary = bookmarks.count { |b| b['content_data'] && b['content_data']['content'] }

    # 上部に余白を作って中央寄せ
    pdf.move_down 80

    # タイトル（大きく）
    pdf.text "WEEKLY", size: 48, style: :bold, align: :center, color: '333333'
    pdf.text "BOOKMARKS", size: 48, style: :bold, align: :center, color: '333333'
    pdf.text "DIGEST", size: 48, style: :bold, align: :center, color: '333333'

    pdf.move_down 30

    # 期間（大きめ）
    period_text = "#{week_start.strftime('%Y.%m.%d')} - #{week_end.strftime('%m.%d')}"
    pdf.text period_text, size: 24, align: :center, color: '555555'

    pdf.move_down 15
    pdf.text "#{bookmark_count} items", size: 18, align: :center, color: '888888'

    # キーワードを大きく表示
    if summary_data
      keywords = []

      # keywordsから取得
      if summary_data['keywords'] && summary_data['keywords'].is_a?(Hash)
        keywords += summary_data['keywords'].keys
      end

      # primary_interestsからも取得
      if summary_data['primary_interests'] && summary_data['primary_interests'].is_a?(Array)
        summary_data['primary_interests'].each do |interest|
          keyword = interest['keyword'] || interest[:keyword]
          keywords << keyword if keyword
        end
      end

      # 重複を除去し、最大6個まで
      keywords = keywords.uniq.first(6)

      if keywords.any?
        pdf.move_down 60

        # 区切り線（太め）
        pdf.line_width = 2
        pdf.stroke_horizontal_rule
        pdf.line_width = 1
        pdf.move_down 30

        # キーワードを超大きく表示（1個ずつ）
        keywords.each do |keyword|
          pdf.text keyword, size: 36, style: :bold, align: :center, color: '0055AA'
          pdf.move_down 15
        end

        pdf.move_down 15
        pdf.line_width = 2
        pdf.stroke_horizontal_rule
        pdf.line_width = 1
      end
    end
  end

  def add_table_of_contents(pdf, bookmarks)
    return if bookmarks.empty?

    pdf.text "TABLE OF CONTENTS", size: 22, style: :bold
    pdf.move_down 12

    bookmarks.each_with_index do |bookmark, index|
      title = bookmark['title'] || 'No Title'
      date = Date.parse(bookmark['created']).strftime('%m/%d')

      pdf.text "#{index + 1}. #{title}", size: 13
      pdf.indent(20) do
        pdf.text "Date: #{date}", size: 11, color: '888888'
      end
      pdf.move_down 6
    end

    pdf.move_down 10
    pdf.stroke_horizontal_rule
    pdf.move_down 20
  end

  def add_bookmark_detail(pdf, bookmark, number, total)
    title = bookmark['title'] || 'No Title'
    url = bookmark['link'] || ''
    created = Date.parse(bookmark['created']).strftime('%Y-%m-%d')

    # タイトルバー
    pdf.fill_color 'E8F4F8'
    pdf.fill_rectangle [0, pdf.cursor], pdf.bounds.width, 30
    pdf.fill_color '000000'

    pdf.move_down 8
    pdf.text "[#{number}] #{title}", size: 18, style: :bold
    pdf.move_down 15

    # メタ情報
    pdf.text "Date: #{created}", size: 12, color: '666666'
    pdf.move_down 6

    # URL（リンク付き）
    pdf.text "Link:", size: 12, color: '666666'
    pdf.indent(10) do
      if url.length > 80
        # 長いURLは折り返し
        pdf.text url, size: 10, color: '0066CC'
      else
        pdf.text url, size: 11, color: '0066CC'
      end
    end
    pdf.move_down 15

    # タグ
    if bookmark['tags'] && bookmark['tags'].any?
      tags_text = bookmark['tags'].map { |tag| "##{tag}" }.join(' ')
      pdf.text "Tags: #{tags_text}", size: 12, color: '888888'
      pdf.move_down 12
    end

    # 要約（箇条書き）
    if bookmark['content_data'] && bookmark['content_data']['content']
      content = bookmark['content_data']['content']

      puts "  [PDF生成] 要約を追加中: #{content[0..50]}..." # デバッグ

      pdf.text "Summary:", size: 15, style: :bold
      pdf.move_down 10

      # 箇条書きを整形して表示
      lines = content.split("\n").reject(&:empty?)
      puts "  [PDF生成] 行数: #{lines.length}" # デバッグ

      lines.each_with_index do |line, i|
        if line.start_with?('- ')
          pdf.text "  #{line}", size: 13, leading: 6
        else
          pdf.text "  • #{line}", size: 13, leading: 6
        end
        pdf.move_down 6
      end
    else
      puts "  [PDF生成] 要約なし" # デバッグ
      pdf.text "[Summary not available]", size: 10, color: 'AAAAAA', style: :italic
    end

    pdf.move_down 20
  end

  def estimate_content_height(pdf, content)
    lines = content.split("\n").reject(&:empty?)
    lines.length * 18 + 20  # 行数 × 行高 + パディング
  end

  def add_page_numbers(pdf)
    pdf.number_pages(
      "Page <page> / <total>",
      at: [pdf.bounds.right - 150, 0],
      align: :right,
      size: 9,
      color: '888888'
    )
  end

  def add_weekly_summary(pdf, summary_data)
    # 全体の総括
    if summary_data['overall_insights']
      pdf.text "WEEKLY INSIGHTS", size: 24, style: :bold
      pdf.move_down 15

      pdf.fill_color 'FFF8DC'
      pdf.fill_rectangle [0, pdf.cursor], pdf.bounds.width, 80
      pdf.fill_color '000000'

      pdf.move_down 12
      pdf.indent(15) do
        pdf.text summary_data['overall_insights'], size: 13, leading: 6
      end
      pdf.move_down 15
    end

    # キーワードごとのサマリー
    keywords = summary_data['keywords'] || {}
    keywords.each_with_index do |(keyword, data), index|
      pdf.move_down 10 if index > 0

      # キーワードヘッダー
      pdf.fill_color 'E8F4F8'
      pdf.fill_rectangle [0, pdf.cursor], pdf.bounds.width, 25
      pdf.fill_color '000000'

      pdf.move_down 6
      pdf.text "🔑 #{keyword}  (#{data['article_count']}記事)", size: 13, style: :bold
      pdf.move_down 12

      # サマリー
      if data['summary']
        pdf.indent(10) do
          pdf.text data['summary'], size: 10, leading: 4
        end
        pdf.move_down 8
      end

      # 参照記事リスト
      if data['articles'] && data['articles'].any?
        pdf.indent(10) do
          pdf.text "📰 参照記事:", size: 9, color: '666666'
          pdf.move_down 3
          data['articles'].first(3).each do |article|
            pdf.text "• #{article['title']}", size: 8, color: '0066CC'
            pdf.move_down 2
          end
        end
      end

      pdf.move_down 10
    end

    # 周辺キーワード（related_clusters）
    if summary_data['related_clusters'] && summary_data['related_clusters'].any?
      pdf.move_down 15
      pdf.text "PERIPHERAL KEYWORDS / RELATED TOPICS", size: 20, style: :bold
      pdf.move_down 12

      summary_data['related_clusters'].each do |cluster|
        pdf.text "• #{cluster['main_topic']}", size: 15, style: :bold, color: '0066CC'
        pdf.move_down 6

        related_words = cluster['related_words'].join(', ')
        pdf.indent(15) do
          pdf.text "Related: #{related_words}", size: 13, color: '666666'
        end
        pdf.move_down 12
      end
    end
  end
end
