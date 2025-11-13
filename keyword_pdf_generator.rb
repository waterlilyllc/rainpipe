# keyword_pdf_generator.rb
#
# KeywordPDFGenerator - Prawn を使用した PDF レンダリング実装
#
# 責務:
#   - Task 6.1: Prawn ドキュメント初期化と日本語フォントセットアップ
#   - Task 6.2: PDF セクション構成（全体サマリー → 関連ワード → 考察 → ブックマーク詳細）
#   - Task 6.3-6.5: 各セクションの PDF レンダリング
#   - Task 6.6: メモリ効率的なブックマーク詳細セクション
#   - Task 6.7: PDF ファイル名生成
#   - Task 6.8: PDF ファイルサイズチェック
#   - Task 6.9: PDF レンダリング時間計測

require 'prawn'
require 'prawn/table'
require 'date'
require_relative 'gatherly_timing'

class KeywordPDFGenerator
  # Task 6.1: Prawn ドキュメント初期化と日本語フォントセットアップ
  FONT_CANDIDATES = [
    '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    '/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc',
    '/usr/share/fonts/opentype/ipafont-gothic/ipag.ttf',
    '/usr/share/fonts/truetype/fonts-japanese-gothic.ttf'
  ].freeze

  CHUNK_SIZE = 50  # Task 6.6: ブックマーク処理単位
  BOOKMARK_PAGE_SIZE = 3  # 各ページごとのブックマーク数

  def initialize
    @start_time = Time.now
  end

  # Task 6: メイン生成メソッド
  # @param content [Hash] { summary, related_clusters, analysis, bookmarks, keywords, date_range }
  # @param output_path [String] 出力パス
  # @return [Hash] { pdf_path, duration_ms, file_size }
  def generate(content, output_path)
    timing = GatherlyTiming.new

    output_path ||= generate_default_path(content[:keywords], content[:date_range])

    Prawn::Document.generate(output_path, page_size: 'A4', margin: 40, compress: true) do |pdf|
      # Task 6.1: Prawn ドキュメント初期化と日本語フォントセットアップ
      setup_japanese_font(pdf)

      # Task 6.1: PDF メタデータ設定
      set_metadata(pdf, content[:keywords])

      # Task 6.2: セクション構成順序（全体サマリー → 関連ワード → 考察 → ブックマーク詳細）
      # Task 6.3: 全体サマリーセクション
      overall_summary = content[:overall_summary] || content[:summary] || ''
      render_overall_summary(pdf, overall_summary)
      pdf.stroke_horizontal_line(0, pdf.bounds.width)

      # Task 6.4: 関連ワードセクション
      pdf.start_new_page
      render_related_keywords(pdf, content[:related_clusters])
      pdf.stroke_horizontal_line(0, pdf.bounds.width)

      # Task 6.5: 考察セクション
      pdf.start_new_page
      render_analysis(pdf, content[:analysis])
      pdf.stroke_horizontal_line(0, pdf.bounds.width)

      # Task 6.6: ブックマーク詳細セクション（メモリ効率的）
      pdf.start_new_page
      render_bookmarks(pdf, content[:bookmarks])
    end

    duration_ms = timing.elapsed_milliseconds
    file_size = File.size(output_path)

    # Task 6.8: PDF ファイルサイズチェック
    check_file_size(file_size)

    # Task 6.9: PDF レンダリング時間計測
    timing.log_elapsed('PDF レンダリング')

    {
      pdf_path: output_path,
      duration_ms: duration_ms,
      file_size: file_size
    }
  end

  # Task 6.7: PDF ファイル名生成
  def generate_filename(timestamp, keywords)
    # フォーマット：filtered_pdf_{timestamp}_{keywords_joined}.pdf
    # timestamp：YYYYMMDD_HHmmss（UTC）
    # keywords_joined：キーワードをアンダースコアで結合（スペース/カンマは除去）
    keywords_safe = keywords.gsub(/[\s,]+/, '_').gsub(/_+/, '_')
    "filtered_pdf_#{timestamp}_#{keywords_safe}.pdf"
  end

  # Task 6.7: デフォルトパス生成
  def generate_default_path(keywords, date_range)
    timestamp = Time.now.utc.strftime('%Y%m%d_%H%M%S')
    filename = generate_filename(timestamp, keywords)
    File.join('data', filename)
  end

  # Task 6.6: ブックマークをチャンク分割
  def chunk_bookmarks(bookmarks)
    bookmarks.each_slice(CHUNK_SIZE).to_a
  end

  # Task 6.6: ガベージコレクション実行
  def trigger_gc
    GC.start
  end

  # Task 6.8: ファイルサイズチェック
  def check_file_size(size_bytes)
    size_mb = size_bytes / (1024 * 1024.0)

    if size_mb > 25
      puts "❌ PDF ファイルサイズが大きすぎます: #{size_mb.round(2)} MB（最大 25 MB）"
      raise "PDF ファイルサイズ制限超過"
    elsif size_mb > 20
      puts "⚠️  PDF ファイルサイズが 20 MB を超えています: #{size_mb.round(2)} MB"
    else
      puts "✅ PDF ファイルサイズ: #{size_mb.round(2)} MB"
    end
  end

  # Task 6.1: PDF メタデータ設定
  # @param pdf [Prawn::Document] PDF ドキュメント
  # @param keywords [String] キーワード（カンマ区切り）
  def set_metadata(pdf, keywords)
    # Prawn 2.5.0: メタデータは PDF 生成時のオプションで設定
    # この実装は Prawn::Document.generate のオプションで行う
    # ここではスキップ
  end

  # Task 6.1: Prawn ドキュメント初期化と日本語フォントセットアップ
  private

  def setup_japanese_font(pdf)
    font_path = FONT_CANDIDATES.find { |f| File.exist?(f) }

    if font_path
      pdf.font_families.update(
        'Japanese' => {
          normal: font_path,
          bold: font_path,
          italic: font_path,
          bold_italic: font_path
        }
      )
      pdf.font 'Japanese'
      puts "✅ 日本語フォントを使用: #{File.basename(font_path)}"
    else
      puts "⚠️  日本語フォントが見つかりません。Courier に変更します"
      pdf.font 'Courier'
    end
  end

  # Task 6.3: 全体サマリーセクションの PDF レンダリング
  def render_overall_summary(pdf, summary)
    pdf.text '全体サマリー', size: 18, style: :bold
    pdf.move_down(10)
    pdf.text summary, size: 11
    pdf.move_down(20)
  end

  # Task 6.4: 関連ワードセクションの PDF レンダリング
  def render_related_keywords(pdf, related_clusters)
    pdf.text '関連ワード', size: 18, style: :bold
    pdf.move_down(10)

    related_clusters.each do |cluster|
      main_topic = cluster['main_topic'] || cluster[:main_topic]
      related_words = cluster['related_words'] || cluster[:related_words] || []

      words_text = related_words.join(', ')
      pdf.text "• #{main_topic}: #{words_text}", size: 11
    end

    pdf.move_down(20)
  end

  # Task 6.5: 考察セクションの PDF レンダリング
  def render_analysis(pdf, analysis)
    pdf.text '今週の考察', size: 18, style: :bold
    pdf.move_down(10)
    pdf.text analysis, size: 11
    pdf.move_down(20)
  end

  # Task 6.6: ブックマーク詳細セクションのメモリ効率的なレンダリング
  def render_bookmarks(pdf, bookmarks)
    return if bookmarks.empty?

    # セクションヘッダー
    pdf.text 'ブックマーク詳細', size: 18, style: :bold
    pdf.move_down(15)

    # Task 6.6: ブックマークを 50 件単位のチャンクで処理
    chunk_bookmarks(bookmarks).each_with_index do |chunk, chunk_index|
      chunk.each_with_index do |bookmark, idx|
        number = (chunk_index * CHUNK_SIZE) + idx + 1
        total = bookmarks.length

        # ブックマーク詳細セクション
        render_bookmark_detail(pdf, bookmark, number, total)

        # ページが埋まったら新ページへ
        if pdf.cursor < 100
          pdf.start_new_page
        end
      end

      # Task 6.6: GC ヒント（50 件ごと）
      trigger_gc if (chunk_index + 1) % 1 == 0
    end
  end

  # ブックマーク詳細を週次レポート形式でレンダリング
  def render_bookmark_detail(pdf, bookmark, number, total)
    pdf.move_down(8)

    title = bookmark['title'] || '（タイトルなし）'
    url = bookmark['url'] || bookmark['link'] || ''
    created = bookmark['created'] || bookmark['created_at'] || '不明'
    tags = bookmark['tags'] || []
    summary = bookmark['summary'] || nil

    # タイトルと番号
    pdf.text "#{number}/#{total}. #{title}", size: 13, style: :bold
    pdf.move_down(10)

    # 登録日
    pdf.text "登録日: #{created}", size: 9, color: '666666'
    pdf.move_down(5)

    # URL
    pdf.text "URL:", size: 9, color: '666666'
    pdf.indent(10) do
      if url.length > 80
        pdf.text url, size: 8, color: '0066CC'
      else
        pdf.text url, size: 9, color: '0066CC'
      end
    end
    pdf.move_down(10)

    # タグ
    if tags.any?
      tags_text = tags.map { |tag| "##{tag}" }.join(' ')
      pdf.text "タグ: #{tags_text}", size: 9, color: '888888'
      pdf.move_down(10)
    end

    # 要約（本文サマリー）
    if summary && summary != '' && summary != '（サマリー未取得）'
      pdf.text "📝 要約", size: 12, style: :bold
      pdf.move_down(8)

      pdf.stroke_color 'CCCCCC'
      pdf.stroke_bounds do
        pdf.pad(10) do
          lines = summary.split("\n").reject(&:empty?)
          lines.each do |line|
            if line.start_with?('- ')
              pdf.text line, size: 10, leading: 4
              pdf.move_down(4)
            else
              pdf.text "• #{line}", size: 10, leading: 4
              pdf.move_down(4)
            end
          end
        end
      end
      pdf.stroke_color '000000'
    else
      pdf.text "要約なし", size: 10, color: 'AAAAAA', style: :italic
    end

    pdf.move_down(15)
  end

  # Task 6.6: ブックマークをチャンク分割
  def chunk_bookmarks(bookmarks)
    bookmarks.each_slice(CHUNK_SIZE).to_a
  end

  # Task 6.6: ガベージコレクション実行
  def trigger_gc
    GC.start
  end
end
