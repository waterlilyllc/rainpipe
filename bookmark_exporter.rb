require 'json'
require 'net/http'
require 'dotenv/load'
require 'fileutils'
require 'date'
require_relative 'bookmark_categorizer'

class BookmarkExporter
  # タグベースの振り分けルール
  TAG_ROUTING_RULES = {
    notion: [
      'programming', 'dev-tools', 'cloud-infra', 'ai-ml', 
      'web-development', 'security', 'data-knowledge',
      'business', 'technology', 'seo', 'ui-design'
    ],
    obsidian: [
      'entertainment', 'lifestyle', 'food-delivery', 
      'parenting', 'learning', 'psychology', 'outdoor', 
      'camping', 'nutrition', 'sustainability',
      'smartphones', 'gadgets', 'communication', 'entertainment'
    ]
  }

  def initialize
    @notion_api_key = ENV['NOTION_API_KEY']
    @notion_database_id = ENV['NOTION_DATABASE_ID']
    @obsidian_vault_path = ENV['OBSIDIAN_VAULT_PATH'] || './obsidian_export'
  end

  # ブックマークの振り分け先を判定
  def determine_destination(bookmark)
    return :none unless bookmark['tags'] && bookmark['tags'].any?
    
    tags = bookmark['tags']
    
    # Notion向けタグがあるかチェック
    notion_match = tags.any? { |tag| TAG_ROUTING_RULES[:notion].include?(tag) }
    # Obsidian向けタグがあるかチェック  
    obsidian_match = tags.any? { |tag| TAG_ROUTING_RULES[:obsidian].include?(tag) }
    
    # 両方にマッチする場合は、マッチ数が多い方を選択
    if notion_match && obsidian_match
      notion_count = tags.count { |tag| TAG_ROUTING_RULES[:notion].include?(tag) }
      obsidian_count = tags.count { |tag| TAG_ROUTING_RULES[:obsidian].include?(tag) }
      notion_count >= obsidian_count ? :notion : :obsidian
    elsif notion_match
      :notion
    elsif obsidian_match
      :obsidian
    else
      :none
    end
  end

  # Notionにエクスポート
  def export_to_notion(bookmark)
    return { success: false, error: 'Notion API key not configured' } unless @notion_api_key
    return { success: false, error: 'Notion database ID not configured' } unless @notion_database_id
    
    uri = URI('https://api.notion.com/v1/pages')
    
    # カテゴリーを判定
    categorizer = BookmarkCategorizer.new
    category = categorizer.determine_category(bookmark)
    
    # プロパティを設定（拡張版）
    properties = {
      '名前' => {
        'title' => [
          {
            'text' => {
              'content' => bookmark['title'] || 'Untitled'
            }
          }
        ]
      }
    }
    
    # URL プロパティ（存在する場合）
    properties['URL'] = { 'url' => bookmark['link'] } if bookmark['link']
    
    # タグ プロパティ（存在する場合）
    if bookmark['tags'] && bookmark['tags'].any?
      properties['タグ'] = {
        'multi_select' => bookmark['tags'].map { |tag| { 'name' => tag } }
      }
    end
    
    # 作成日プロパティ（存在する場合）
    if bookmark['created']
      properties['作成日'] = {
        'date' => {
          'start' => bookmark['created']
        }
      }
    end
    
    # 概要プロパティ（存在する場合）
    if bookmark['excerpt'] && !bookmark['excerpt'].empty?
      properties['概要'] = {
        'rich_text' => [
          {
            'text' => {
              'content' => bookmark['excerpt'][0..1999]
            }
          }
        ]
      }
    end
    
    # カテゴリプロパティ（存在する場合）
    properties['カテゴリ'] = {
      'select' => {
        'name' => category.gsub(/^[🔧🤖💼🎨👨‍👩‍👧‍👦🍳🎮🏕️📚🛍️🌿📌]\s*/, '') # 絵文字を除去
      }
    }

    # ページコンテンツは最小限に（プロパティに情報があるため）
    page_content = []
    
    # メインコンテンツとして概要のみ追加
    if bookmark['excerpt'] && !bookmark['excerpt'].empty?
      page_content << {
        'object' => 'block',
        'type' => 'quote',
        'quote' => {
          'rich_text' => [
            { 'type' => 'text', 'text' => { 'content' => bookmark['excerpt'][0..1999] } }
          ]
        }
      }
    end
    
    # Raindropからのエクスポート情報
    page_content << {
      'object' => 'block',
      'type' => 'paragraph',
      'paragraph' => {
        'rich_text' => [
          { 'type' => 'text', 'text' => { 'content' => "📌 Exported from Raindrop.io via RainPipe on #{Date.today}" } }
        ]
      }
    }
    
    request_body = {
      'parent' => { 'database_id' => @notion_database_id },
      'properties' => properties,
      'children' => page_content
    }
    
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{@notion_api_key}"
    request['Content-Type'] = 'application/json'
    request['Notion-Version'] = '2022-06-28'
    request.body = request_body.to_json
    
    begin
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end
      
      if response.code == '200'
        result = JSON.parse(response.body)
        { success: true, notion_page_id: result['id'] }
      else
        { success: false, error: "Notion API error: #{response.code} - #{response.body}" }
      end
    rescue => e
      { success: false, error: "Exception: #{e.message}" }
    end
  end

  # Obsidianにエクスポート（Markdownファイルとして）
  def export_to_obsidian(bookmark)
    # ファイル名を生成（日付_タイトル）
    created_date = Date.parse(bookmark['created'])
    safe_title = bookmark['title'].gsub(/[\/\\:*?"<>|]/, '_')[0..50]
    filename = "#{created_date.strftime('%Y%m%d')}_#{safe_title}.md"
    
    # カテゴリーを判定
    categorizer = BookmarkCategorizer.new
    category_name = determine_obsidian_category(bookmark)
    
    # 保存先ディレクトリを作成（Project Box/RainPipe/カテゴリ名）
    dir_path = File.join(@obsidian_vault_path, 'Project Box', 'RainPipe', category_name)
    FileUtils.mkdir_p(dir_path)
    
    filepath = File.join(dir_path, filename)
    
    # Markdown形式でコンテンツを生成
    content = generate_obsidian_markdown(bookmark)
    
    # ファイルに書き込み
    File.write(filepath, content)
    
    { success: true, filepath: filepath }
  rescue => e
    { success: false, error: "Failed to export to Obsidian: #{e.message}" }
  end
  
  # Obsidian用のカテゴリー名を決定（英語フォルダ名）
  def determine_obsidian_category(bookmark)
    categorizer = BookmarkCategorizer.new
    category = categorizer.determine_category(bookmark)
    
    # カテゴリー名を英語フォルダ名にマッピング
    category_mapping = {
      '🔧 技術・開発' => 'Tech',
      '🤖 AI・機械学習' => 'AI',
      '💼 ビジネス・仕事' => 'Business',
      '🎨 デザイン・UI' => 'Design',
      '👨‍👩‍👧‍👦 家庭・子育て' => 'Family',
      '🍳 料理・食事' => 'Food',
      '🎮 エンタメ・趣味' => 'Entertainment',
      '🏕️ アウトドア・旅行' => 'Outdoor',
      '📚 学習・自己啓発' => 'Learning',
      '🛍️ ショッピング・ガジェット' => 'Shopping',
      '🌿 健康・ライフスタイル' => 'Health',
      '📌 その他' => 'Others'
    }
    
    category_mapping[category] || 'Others'
  end

  # Obsidian用のMarkdownを生成
  def generate_obsidian_markdown(bookmark)
    tags = (bookmark['tags'] || []).map { |tag| "##{tag}" }.join(' ')
    
    content = <<~MARKDOWN
      ---
      title: #{bookmark['title']}
      url: #{bookmark['link']}
      created: #{bookmark['created']}
      tags: [#{(bookmark['tags'] || []).join(', ')}]
      source: Raindrop.io
      ---

      # #{bookmark['title']}

      **URL**: #{bookmark['link']}
      **Created**: #{format_date(bookmark['created'])}
      **Tags**: #{tags}

    MARKDOWN

    if bookmark['excerpt'] && !bookmark['excerpt'].empty?
      content += <<~MARKDOWN

        ## 概要
        #{bookmark['excerpt']}

      MARKDOWN
    end

    content += <<~MARKDOWN

      ---
      *Exported from Raindrop.io on #{Date.today}*
    MARKDOWN

    content
  end

  # 一括エクスポート
  def bulk_export(bookmarks, progress_callback = nil)
    results = {
      notion: { success: 0, failed: 0, errors: [] },
      obsidian: { success: 0, failed: 0, errors: [] },
      none: 0
    }
    
    bookmarks.each_with_index do |bookmark, index|
      destination = determine_destination(bookmark)
      
      progress_callback&.call(index + 1, bookmarks.length, bookmark['title'], destination)
      
      case destination
      when :notion
        result = export_to_notion(bookmark)
        if result[:success]
          results[:notion][:success] += 1
        else
          results[:notion][:failed] += 1
          results[:notion][:errors] << { title: bookmark['title'], error: result[:error] }
        end
      when :obsidian
        result = export_to_obsidian(bookmark)
        if result[:success]
          results[:obsidian][:success] += 1
        else
          results[:obsidian][:failed] += 1
          results[:obsidian][:errors] << { title: bookmark['title'], error: result[:error] }
        end
      else
        results[:none] += 1
      end
      
      # API制限対策
      sleep(0.5) if destination == :notion
    end
    
    results
  end

  private

  def format_date(date_str)
    Date.parse(date_str).strftime('%Y年%m月%d日')
  rescue
    date_str
  end
end