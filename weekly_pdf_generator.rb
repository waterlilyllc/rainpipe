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
    # 先週の月曜〜日曜を計算
    today = Date.today
    last_sunday = today - today.wday # 今週の日曜
    week_end = last_sunday - 1      # 先週の日曜
    week_start = week_end - 6       # 先週の月曜

    generate_weekly_pdf(week_start, week_end, output_path)
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

    # 出力パスの決定
    output_path ||= "data/weekly_summary_#{week_start.strftime('%Y%m%d')}.pdf"

    # PDF生成
    generate_pdf(bookmarks, week_start, week_end, output_path, summary_data)

    output_path
  end

  private

  def load_or_generate_summary(week_start)
    summary_file = File.join(SUMMARY_DIR, "summary_#{week_start.strftime('%Y-%m-%d')}.json")

    if File.exist?(summary_file)
      puts "📊 既存のサマリーを読み込み: #{summary_file}"
      JSON.parse(File.read(summary_file))
    elsif @summary_generator
      puts "✨ 週次サマリーを生成中..."
      @summary_generator.generate_weekly_summary(week_start.to_s)
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
      puts "📥 本文取得ジョブを並列作成中..."

      # 並列でジョブ作成（Rubyスレッド使用）
      threads = missing_content_bookmarks.map do |bookmark|
        Thread.new do
          puts "  クロール開始: #{bookmark['title']}"
          job_uuid = @content_fetcher.fetch_content(bookmark['_id'], bookmark['link'])

          if job_uuid
            puts "    ✅ ジョブ作成完了 (#{job_uuid})"
          else
            puts "    ⚠️  ジョブ作成スキップまたは失敗"
          end
        end
      end

      # 全スレッドの完了を待つ
      threads.each(&:join)

      puts ""
      puts "⏳ 本文取得を待機中（最大30分）..."
      puts ""

      # 本文取得完了を待つ（最大30分）
      wait_for_content_fetch(missing_content_bookmarks.map { |bm| bm['_id'] }, timeout: 1800)
    end

    # 本文データを付加
    bookmarks.map do |bookmark|
      content = @content_manager.get_content(bookmark['_id'])
      bookmark['content_data'] = content if content
      bookmark
    end
  end

  def wait_for_content_fetch(raindrop_ids, timeout: 1800)
    start_time = Time.now
    remaining_ids = raindrop_ids.dup
    check_interval = 10 # 10秒ごとにチェック

    while remaining_ids.any? && (Time.now - start_time) < timeout
      sleep check_interval

      remaining_ids.reject! do |id|
        content = @content_manager.get_content(id)
        if content
          puts "  ✅ 本文取得完了: ID #{id}"
          true
        else
          false
        end
      end

      elapsed = (Time.now - start_time).to_i
      if remaining_ids.any? && elapsed % 60 == 0
        puts "  待機中... (経過: #{elapsed / 60}分, 残り: #{remaining_ids.length}件)"
      end
    end

    if remaining_ids.any?
      puts ""
      puts "⚠️  #{remaining_ids.length}件の本文取得がタイムアウトしました"
      puts "    これらのブックマークは要約なしでPDFに含まれます"
    else
      puts ""
      puts "✅ 全ての本文取得が完了しました"
    end

    puts ""
  end

  def generate_pdf(bookmarks, week_start, week_end, output_path, summary_data = nil)
    Prawn::Document.generate(output_path, page_size: 'A4', margin: 40) do |pdf|
      # 日本語フォント設定
      setup_japanese_font(pdf)

      # ヘッダー
      add_header(pdf, week_start, week_end, bookmarks)

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

  def add_header(pdf, week_start, week_end, bookmarks)
    bookmark_count = bookmarks.length
    with_summary = bookmarks.count { |b| b['content_data'] && b['content_data']['content'] }

    pdf.text "WEEKLY BOOKMARKS DIGEST", size: 30, style: :bold, align: :center
    pdf.move_down 12

    period_text = "Period: #{week_start.strftime('%Y-%m-%d')} - #{week_end.strftime('%Y-%m-%d')}"
    pdf.text period_text, size: 18, align: :center, color: '555555'

    pdf.move_down 8
    pdf.text "Total Items: #{bookmark_count}", size: 15, align: :center, color: '888888'
    pdf.text "With Summary: #{with_summary}/#{bookmark_count}", size: 15, align: :center, color: '888888'

    pdf.move_down 20
    pdf.stroke_horizontal_rule
    pdf.move_down 20
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
