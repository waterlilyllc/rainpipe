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
require_relative 'progress_reporter'

class KeywordPDFGenerator
  # Task 6.1: Prawn ドキュメント初期化と日本語フォントセットアップ
  FONT_CANDIDATES = [
    '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    '/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc',
    '/usr/share/fonts/opentype/ipafont-gothic/ipag.ttf',
    '/usr/share/fonts/truetype/ipafont-gothic/ipag.ttf',
    '/usr/share/fonts/truetype/fonts-japanese-gothic.ttf'
  ].freeze

  CHUNK_SIZE = 50  # Task 6.6: ブックマーク処理単位
  BOOKMARK_PAGE_SIZE = 3  # 各ページごとのブックマーク数

  def initialize
    @start_time = Time.now
  end

  # Markdown フォーマットをプレーンテキストに変換
  def strip_markdown(text)
    return text unless text.is_a?(String)

    text
      .gsub(/\*\*(.+?)\*\*/, '\1')     # **太字** → 太字
      .gsub(/\*(.+?)\*/, '\1')         # *イタリック* → イタリック
      .gsub(/__(.+?)__/, '\1')         # __太字__ → 太字
      .gsub(/_(.+?)_/, '\1')           # _イタリック_ → イタリック
      .gsub(/\[(.+?)\]\(.+?\)/, '\1')  # [リンク](url) → リンク
      .gsub(/^#+\s+(.+)$/m, '\1')      # # ヘッダー → ヘッダー
      .gsub(/^- /, '• ')               # - リスト → • リスト
  end

  # Task 6: メイン生成メソッド
  # @param content [Hash] { summary, related_clusters, analysis, bookmarks, keywords, date_range }
  # @param output_path [String] 出力パス
  # @return [Hash] { pdf_path, duration_ms, file_size }
  def generate(content, output_path)
    timing = GatherlyTiming.new
    ProgressReporter.progress(nil, "PDF生成開始", :document)

    output_path ||= generate_default_path(content[:keywords], content[:date_range])

    Prawn::Document.generate(output_path, page_size: 'A4', margin: 40, compress: true) do |pdf|
      # Task 6.1: Prawn ドキュメント初期化と日本語フォントセットアップ
      setup_japanese_font(pdf)

      # Task 6.1: PDF メタデータ設定
      set_metadata(pdf, content[:keywords])

      # Task 6.2: セクション構成順序（ヘッダー → サマリー → 関連ワード → 考察 → 目次 → ブックマーク詳細 + フッター）
      # ヘッダー
      add_header(pdf, content[:keywords], content[:date_range], content[:bookmarks].length)

      # Task 6.3: 全体サマリーセクション
      overall_summary = content[:overall_summary] || content[:summary] || ''
      add_overall_summary(pdf, overall_summary)

      # Task 6.4: 関連ワードセクション
      pdf.start_new_page
      add_related_keywords(pdf, content[:related_clusters])

      # Task 6.5: 考察セクション
      pdf.start_new_page
      add_analysis(pdf, content[:analysis])

      # 目次
      pdf.start_new_page
      add_table_of_contents(pdf, content[:bookmarks])

      # Task 6.6: ブックマーク詳細セクション（メモリ効率的）
      pdf.start_new_page
      render_bookmarks(pdf, content[:bookmarks])

      # フッター（ページ番号）
      add_page_numbers(pdf)
    end

    duration_ms = timing.elapsed_milliseconds
    file_size = File.size(output_path)

    # Task 6.8: PDF ファイルサイズチェック
    check_file_size(file_size)

    # Task 6.9: PDF レンダリング時間計測
    timing.log_elapsed('PDF レンダリング')

    ProgressReporter.success("PDF生成完了: #{output_path} (#{(file_size / 1024.0).round(2)} KB)")

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
      ProgressReporter.error("PDF ファイルサイズ超過: #{size_mb.round(2)} MB（最大 25 MB）")
      raise "PDF ファイルサイズ制限超過"
    elsif size_mb > 20
      ProgressReporter.warning("PDF ファイルサイズが大きめです: #{size_mb.round(2)} MB（推奨 20 MB以下）")
    else
      ProgressReporter.success("PDF ファイルサイズ正常: #{size_mb.round(2)} MB")
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

  # ヘッダーの追加
  def add_header(pdf, keywords, date_range, bookmark_count)
    pdf.text "キーワード検索レポート", size: 28, style: :bold, align: :center, color: '1a1a1a'
    pdf.move_down(8)

    pdf.text keywords, size: 16, align: :center, color: '0066CC', style: :bold
    pdf.move_down(12)

    period_text = "期間: #{date_range[:start]} ～ #{date_range[:end]}"
    pdf.text period_text, size: 12, align: :center, color: '666666'
    pdf.move_down(4)

    pdf.text "ブックマーク件数: #{bookmark_count} 件", size: 11, align: :center, color: '666666'
    pdf.move_down(20)

    # 区切り線
    pdf.stroke_color 'CCCCCC'
    pdf.stroke_horizontal_line(0, pdf.bounds.width)
    pdf.stroke_color '000000'
    pdf.move_down(15)
  end

  # Task 6.3: 全体サマリーセクションの PDF レンダリング
  def add_overall_summary(pdf, summary)
    pdf.text 'キーワード検索 全体サマリー', size: 18, style: :bold, color: '1a1a1a'
    pdf.move_down(8)

    # 区切り線
    pdf.stroke_color 'CCCCCC'
    pdf.stroke_horizontal_line(0, pdf.bounds.width)
    pdf.stroke_color '000000'
    pdf.move_down(12)

    # Markdown フォーマットを削除
    clean_summary = strip_markdown(summary)
    pdf.text clean_summary, size: 12, color: '333333', leading: 8
    pdf.move_down(20)
  end

  # Task 6.4: 関連ワードセクションの PDF レンダリング
  def add_related_keywords(pdf, related_clusters)
    pdf.text '関連トピック', size: 18, style: :bold, color: '1a1a1a'
    pdf.move_down(8)

    # 区切り線
    pdf.stroke_color 'CCCCCC'
    pdf.stroke_horizontal_line(0, pdf.bounds.width)
    pdf.stroke_color '000000'
    pdf.move_down(12)

    related_clusters.each_with_index do |cluster, idx|
      main_topic = cluster['main_topic'] || cluster[:main_topic]
      related_words = cluster['related_words'] || cluster[:related_words] || []

      # クラスタ番号とトピック
      pdf.text "#{idx + 1}. #{main_topic}", size: 13, style: :bold, color: '0066CC'
      pdf.move_down(6)

      # 関連ワード
      words_text = related_words.join(' • ')
      pdf.text words_text, size: 11, color: '666666', leading: 7
      pdf.move_down(10)
    end

    pdf.move_down(10)
  end

  # Task 6.5: 考察セクションの PDF レンダリング
  def add_analysis(pdf, analysis)
    pdf.text '考察・インサイト', size: 18, style: :bold, color: '1a1a1a'
    pdf.move_down(8)

    # 区切り線
    pdf.stroke_color 'CCCCCC'
    pdf.stroke_horizontal_line(0, pdf.bounds.width)
    pdf.stroke_color '000000'
    pdf.move_down(12)

    # Markdown フォーマットを削除
    clean_analysis = strip_markdown(analysis)
    pdf.text clean_analysis, size: 12, color: '333333', leading: 8
    pdf.move_down(20)
  end

  # 目次の追加
  def add_table_of_contents(pdf, bookmarks)
    pdf.text '目次', size: 18, style: :bold, color: '1a1a1a'
    pdf.move_down(8)

    pdf.stroke_color 'CCCCCC'
    pdf.stroke_horizontal_line(0, pdf.bounds.width)
    pdf.stroke_color '000000'
    pdf.move_down(12)

    bookmarks.each_with_index do |bookmark, idx|
      title = bookmark['title'] || '（タイトルなし）'
      truncated_title = title.length > 70 ? title[0..67] + '...' : title
      pdf.text "#{idx + 1}. #{truncated_title}", size: 11, color: '0066CC', leading: 8
    end
  end

  # ページ番号（フッター）の追加
  def add_page_numbers(pdf)
    pdf.number_pages "<page>/<total>", { at: [pdf.bounds.right - 100, 20], align: :right, size: 10, color: '999999' }
  end

  # Task 6.6: ブックマーク詳細セクションのメモリ効率的なレンダリング
  def render_bookmarks(pdf, bookmarks)
    return if bookmarks.empty?

    # セクションヘッダー
    pdf.text 'ブックマーク詳細', size: 18, style: :bold, color: '1a1a1a'
    pdf.move_down(8)

    # 区切り線
    pdf.stroke_color 'CCCCCC'
    pdf.stroke_horizontal_line(0, pdf.bounds.width)
    pdf.stroke_color '000000'
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
    pdf.move_down(10)

    title = bookmark['title'] || '（タイトルなし）'
    url = bookmark['url'] || bookmark['link'] || ''
    created = bookmark['created'] || bookmark['created_at'] || '不明'
    tags = bookmark['tags'] || []
    summary = bookmark['summary'] || nil

    # タイトルと番号
    pdf.text "#{number}/#{total}. #{title}", size: 15, style: :bold, color: '1a1a1a'
    pdf.move_down(10)

    # 登録日
    created_date = created.is_a?(String) ? created.split('T').first : created
    pdf.text "登録日: #{created_date}", size: 11, color: '999999'
    pdf.move_down(5)

    # URL
    pdf.text "URL:", size: 11, style: :bold, color: '666666'
    pdf.indent(15) do
      if url.length > 80
        pdf.text url, size: 10, color: '0066CC', overflow: :shrink_to_fit
      else
        pdf.text url, size: 11, color: '0066CC'
      end
    end
    pdf.move_down(10)

    # タグ
    if tags.any?
      tags_text = tags.map { |tag| "##{tag}" }.join('  ')
      pdf.text tags_text, size: 11, color: '0099BB'
      pdf.move_down(10)
    end

    # 要約（本文サマリー）
    if summary && summary.to_s.strip.length > 10 && summary != '（サマリー未取得）' && summary != 'summary unavailable'
      pdf.text "本文サマリー:", size: 13, style: :bold, color: '1a1a1a'
      pdf.move_down(8)

      # 要約テキストを整形して表示
      lines = summary.split("\n").reject(&:empty?).first(15)  # 最初の15行のみ

      # 背景色付きボックス（実際のコンテンツに合わせたサイズ）
      box_height = lines.length * 9 + 20
      pdf.fill_color 'F5F5F5'
      pdf.fill_rectangle([pdf.bounds.left, pdf.cursor], pdf.bounds.width, box_height)
      pdf.fill_color '000000'

      # インデント付きで要約テキストを表示
      pdf.indent(10) do
        pdf.move_down(10)
        lines.each do |line|
          truncated_line = line.length > 100 ? line[0..97] + '...' : line
          if line.start_with?('- ') || line.start_with?('•')
            pdf.text truncated_line, size: 11, color: '333333', leading: 7
          else
            pdf.text "• #{truncated_line}", size: 11, color: '333333', leading: 7
          end
        end
      end

      pdf.move_down(box_height)
    else
      pdf.text "本文サマリー: （取得未定）", size: 12, color: 'AAAAAA', style: :italic
      pdf.move_down(8)
    end

    # 区切り線
    pdf.stroke_color 'EEEEEE'
    pdf.stroke_horizontal_line(0, pdf.bounds.width)
    pdf.stroke_color '000000'
    pdf.move_down(5)
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
