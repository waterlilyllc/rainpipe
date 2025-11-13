require 'net/http'
require 'json'
require 'uri'

class AutoTagger
  OPENAI_API_URL = 'https://api.openai.com/v1/chat/completions'
  
  # タグ分類体系
  TAG_CATEGORIES = {
    'ai-ml' => '🤖 AI・機械学習',
    'dev-tools' => '🛠️ 開発ツール', 
    'cloud-infra' => '☁️ クラウド・インフラ',
    'programming' => '💻 プログラミング',
    'data-knowledge' => '📊 データ・ナレッジ',
    'ui-design' => '🎨 UI・デザイン',
    'learning' => '📚 学習・教育',
    'entertainment' => '🌐 その他・エンタメ'
  }
  
  def initialize
    @openai_api_key = ENV['OPENAI_API_KEY']
    @raindrop_token = ENV['RAINDROP_API_TOKEN']
    
    unless @openai_api_key
      raise 'OPENAI_API_KEY not found in environment'
    end
    
    unless @raindrop_token
      raise 'RAINDROP_API_TOKEN not found in environment'
    end
  end

  def generate_tags(bookmark)
    # ChatGPT用のプロンプトを構築
    prompt = build_classification_prompt(bookmark)
    
    # ChatGPT APIを呼び出し
    response = call_chatgpt_api(prompt)
    
    # レスポンスからタグを抽出
    extract_tags_from_response(response)
  end

  def update_bookmark_tags(bookmark_id, tags)
    # Raindrop.io APIでタグを更新
    uri = URI("https://api.raindrop.io/rest/v1/raindrop/#{bookmark_id}")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Put.new(uri)
    request['Authorization'] = "Bearer #{@raindrop_token}"
    request['Content-Type'] = 'application/json'
    request.body = { tags: tags }.to_json
    
    response = http.request(request)
    
    if response.code == '200'
      puts "✅ タグ更新成功: #{bookmark_id} → #{tags.join(', ')}"
      true
    else
      puts "❌ タグ更新失敗: #{response.code} - #{response.body}"
      false
    end
  rescue => e
    puts "❌ タグ更新エラー: #{e.message}"
    false
  end

  def process_bookmark_with_tags(bookmark)
    begin
      puts "🏷️ タグ生成中: #{bookmark['title'][0..60]}..."
      
      # タグを生成
      tags = generate_tags(bookmark)
      
      if tags.any?
        # Raindrop.ioに反映
        success = update_bookmark_tags(bookmark['_id'], tags)
        
        if success
          # ローカルデータも更新
          bookmark['tags'] = tags
          puts "🎉 タグ付け完了: #{tags.join(', ')}"
        end
        
        return { success: success, tags: tags }
      else
        puts "⚠️ タグが生成されませんでした"
        return { success: false, tags: [] }
      end
      
    rescue => e
      puts "❌ タグ付けエラー: #{e.message}"
      return { success: false, tags: [], error: e.message }
    end
  end

  private

  def build_classification_prompt(bookmark)
    title = bookmark['title'] || ''
    link = bookmark['link'] || ''
    excerpt = bookmark['excerpt'] || ''
    
    categories_desc = TAG_CATEGORIES.map { |key, desc| "#{key}: #{desc}" }.join("\n")
    
    <<~PROMPT
      以下のWebページブックマークを分析して、適切なタグを1-3個選んでください。

      【ブックマーク情報】
      タイトル: #{title}
      URL: #{link}
      概要: #{excerpt}

      【利用可能なタグカテゴリ】
      #{categories_desc}

      【ルール】
      1. 最も適切なカテゴリを1-3個選択
      2. 技術系の場合は詳細なサブタグも追加可能（例：javascript, react, claude, chatgpt等）
      3. 日本語と英語どちらでもOK
      4. 簡潔で検索しやすいタグにする

      【回答形式】
      JSON形式で回答してください：
      {"tags": ["tag1", "tag2", "tag3"], "confidence": 0.9, "reasoning": "選択理由"}

      回答:
    PROMPT
  end

  def call_chatgpt_api(prompt)
    uri = URI(OPENAI_API_URL)
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{@openai_api_key}"
    request['Content-Type'] = 'application/json'
    
    request.body = {
      model: 'gpt-3.5-turbo',
      messages: [
        {
          role: 'system',
          content: 'あなたはWebページのコンテンツ分類の専門家です。与えられた情報を基に適切なタグを提案してください。'
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      max_tokens: 500,
      temperature: 0.3
    }.to_json
    
    response = http.request(request)
    
    if response.code == '200'
      data = JSON.parse(response.body)
      content = data.dig('choices', 0, 'message', 'content')
      return content
    else
      puts "❌ ChatGPT API エラー: #{response.code} - #{response.body}"
      return nil
    end
  rescue => e
    puts "❌ ChatGPT API 呼び出しエラー: #{e.message}"
    return nil
  end

  def extract_tags_from_response(response)
    return [] unless response
    
    begin
      # JSONレスポンスをパース
      # ChatGPTが```json```で囲む場合があるので対応
      json_content = response.gsub(/```json\n?|```/, '').strip
      
      parsed = JSON.parse(json_content)
      tags = parsed['tags'] || []
      confidence = parsed['confidence'] || 0.0
      
      puts "🎯 信頼度: #{(confidence * 100).round}% | タグ: #{tags.join(', ')}"
      
      # 信頼度が低い場合は警告
      if confidence < 0.7
        puts "⚠️ 低信頼度タグ（要確認）"
      end
      
      return tags.map(&:strip).reject(&:empty?)
      
    rescue JSON::ParserError => e
      puts "❌ JSON パースエラー: #{e.message}"
      puts "レスポンス: #{response}"
      
      # フォールバック: 基本的なキーワード抽出
      fallback_tags = extract_fallback_tags(response)
      puts "🔄 フォールバックタグ: #{fallback_tags.join(', ')}" if fallback_tags.any?
      
      return fallback_tags
    end
  end

  def extract_fallback_tags(text)
    # ChatGPTの回答が不正な場合のフォールバック
    # 基本的なキーワードマッチング
    fallback_tags = []
    
    text_lower = text.downcase
    
    # AI関連
    fallback_tags << 'ai-ml' if text_lower.match?(/ai|chatgpt|claude|llm|機械学習/)
    
    # 開発ツール
    fallback_tags << 'dev-tools' if text_lower.match?(/github|vscode|cursor|開発|ツール/)
    
    # プログラミング
    fallback_tags << 'programming' if text_lower.match?(/javascript|python|ruby|プログラミング|コード/)
    
    return fallback_tags.uniq
  end
end