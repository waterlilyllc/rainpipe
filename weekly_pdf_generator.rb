require 'prawn'
require 'prawn/table'
require 'date'
require 'json'
require_relative 'raindrop_client'
require_relative 'bookmark_content_manager'
require_relative 'weekly_summary_generator'

class WeeklyPDFGenerator
  FONT_PATH = '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc'
  SUMMARY_DIR = './data/weekly_summaries'

  def initialize
    @client = RaindropClient.new
    @content_manager = BookmarkContentManager.new
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
    summary_file = File.join(SUMMARY_DIR, "#{week_start.strftime('%Y%m%d')}.json")

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

    bookmarks.map do |bookmark|
      content = @content_manager.get_content(bookmark['_id'])
      bookmark['content_data'] = content if content
      bookmark
    end
  end

  def generate_pdf(bookmarks, week_start, week_end, output_path, summary_data = nil)
    Prawn::Document.generate(output_path, page_size: 'A4', margin: 40) do |pdf|
      # 日本語フォント設定
      setup_japanese_font(pdf)

      # ヘッダー
      add_header(pdf, week_start, week_end, bookmarks.length)

      # サマリーセクション（ある場合）
      if summary_data && summary_data['keywords']
        add_weekly_summary(pdf, summary_data)
        pdf.start_new_page
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

  def add_header(pdf, week_start, week_end, bookmark_count)
    pdf.text "週間ブックマークサマリー", size: 24, style: :bold, align: :center
    pdf.move_down 10

    period_text = "#{week_start.strftime('%Y年%m月%d日')} - #{week_end.strftime('%m月%d日')}"
    pdf.text period_text, size: 14, align: :center, color: '555555'

    pdf.move_down 5
    pdf.text "全#{bookmark_count}件", size: 12, align: :center, color: '888888'

    pdf.move_down 20
    pdf.stroke_horizontal_rule
    pdf.move_down 20
  end

  def add_table_of_contents(pdf, bookmarks)
    return if bookmarks.empty?

    pdf.text "目次", size: 16, style: :bold
    pdf.move_down 10

    bookmarks.each_with_index do |bookmark, index|
      title = bookmark['title'] || 'タイトルなし'
      date = Date.parse(bookmark['created']).strftime('%m/%d')

      pdf.text "#{index + 1}. #{title}", size: 10
      pdf.indent(20) do
        pdf.text "登録日: #{date}", size: 8, color: '888888'
      end
      pdf.move_down 5
    end

    pdf.move_down 10
    pdf.stroke_horizontal_rule
    pdf.move_down 20
  end

  def add_bookmark_detail(pdf, bookmark, number, total)
    title = bookmark['title'] || 'タイトルなし'
    url = bookmark['link'] || ''
    created = Date.parse(bookmark['created']).strftime('%Y年%m月%d日')

    # タイトルバー
    pdf.fill_color 'E8F4F8'
    pdf.fill_rectangle [0, pdf.cursor], pdf.bounds.width, 30
    pdf.fill_color '000000'

    pdf.move_down 8
    pdf.text "#{number}/#{total}. #{title}", size: 14, style: :bold
    pdf.move_down 15

    # メタ情報
    pdf.text "登録日: #{created}", size: 9, color: '666666'
    pdf.move_down 5

    # URL（リンク付き）
    pdf.text "URL:", size: 9, color: '666666'
    pdf.indent(10) do
      if url.length > 80
        # 長いURLは折り返し
        pdf.text url, size: 8, color: '0066CC'
      else
        pdf.text url, size: 9, color: '0066CC'
      end
    end
    pdf.move_down 15

    # タグ
    if bookmark['tags'] && bookmark['tags'].any?
      tags_text = bookmark['tags'].map { |tag| "##{tag}" }.join(' ')
      pdf.text "タグ: #{tags_text}", size: 9, color: '888888'
      pdf.move_down 10
    end

    # 要約（箇条書き）
    if bookmark['content_data'] && bookmark['content_data']['content']
      content = bookmark['content_data']['content']

      pdf.text "📝 要約", size: 12, style: :bold
      pdf.move_down 8

      # 箱で囲む
      content_height = estimate_content_height(pdf, content)

      pdf.stroke_color 'CCCCCC'
      pdf.stroke_bounds do
        pdf.pad(10) do
          # 箇条書きを整形して表示
          lines = content.split("\n").reject(&:empty?)
          lines.each do |line|
            if line.start_with?('- ')
              pdf.text line, size: 10, leading: 4
              pdf.move_down 4
            else
              pdf.text "• #{line}", size: 10, leading: 4
              pdf.move_down 4
            end
          end
        end
      end
      pdf.stroke_color '000000'
    else
      pdf.text "要約なし", size: 10, color: 'AAAAAA', style: :italic
    end

    pdf.move_down 20
  end

  def estimate_content_height(pdf, content)
    lines = content.split("\n").reject(&:empty?)
    lines.length * 18 + 20  # 行数 × 行高 + パディング
  end

  def add_page_numbers(pdf)
    pdf.number_pages(
      "ページ <page> / <total>",
      at: [pdf.bounds.right - 150, 0],
      align: :right,
      size: 9,
      color: '888888'
    )
  end

  def add_weekly_summary(pdf, summary_data)
    pdf.text "📊 今週の注目キーワード", size: 18, style: :bold
    pdf.move_down 15

    # 全体の総括
    if summary_data['overall_insights']
      pdf.fill_color 'FFF8DC'
      pdf.fill_rectangle [0, pdf.cursor], pdf.bounds.width, 60
      pdf.fill_color '000000'

      pdf.move_down 10
      pdf.indent(15) do
        pdf.text "💡 今週の総括", size: 12, style: :bold
        pdf.move_down 5
        pdf.text summary_data['overall_insights'], size: 10, leading: 4
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
  end
end
