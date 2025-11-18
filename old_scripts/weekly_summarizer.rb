require 'json'
require 'net/http'
require 'dotenv/load'

class WeeklySummarizer
  def initialize
    @api_key = ENV['OPENAI_API_KEY']
    raise "OpenAI API key not found" unless @api_key
  end

  def generate_summary(bookmarks, week_start_date)
    return nil if bookmarks.empty?
    
    # ブックマーク情報を整形
    bookmark_text = bookmarks.map { |b|
      "- #{b['title']} (#{b['tags'].join(', ') if b['tags'] && !b['tags'].empty?})"
    }.join("\n")
    
    prompt = <<~PROMPT
      以下は#{week_start_date.strftime('%Y年%m月%d日')}の週にブックマークされた記事のリストです。
      この週の主なトピックと傾向を、3-4行の簡潔な日本語で要約してください。
      技術的な内容、学習した分野、興味のあった話題などを中心にまとめてください。

      ブックマークリスト:
      #{bookmark_text}

      要約（3-4行で簡潔に）:
    PROMPT

    begin
      uri = URI('https://api.openai.com/v1/chat/completions')
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{@api_key}"
      request['Content-Type'] = 'application/json'
      
      request.body = {
        model: "gpt-3.5-turbo",
        messages: [
          {
            role: "system",
            content: "あなたは週次ブックマークの要約を作成するアシスタントです。技術的な内容を中心に、その週の主要なトピックと傾向を簡潔にまとめてください。"
          },
          {
            role: "user",
            content: prompt
          }
        ],
        temperature: 0.7,
        max_tokens: 300
      }.to_json

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      if response.code == '200'
        result = JSON.parse(response.body)
        summary = result['choices'][0]['message']['content'].strip
        
        # サマリーをファイルに保存
        save_summary(week_start_date, summary)
        
        return summary
      else
        puts "Error: #{response.code} - #{response.body}"
        return nil
      end
      
    rescue => e
      puts "Error generating summary: #{e.message}"
      return nil
    end
  end

  def save_summary(week_start_date, summary)
    summaries_file = './data/weekly_summaries.json'
    
    # 既存のサマリーを読み込む
    summaries = if File.exist?(summaries_file)
      JSON.parse(File.read(summaries_file))
    else
      {}
    end
    
    # 新しいサマリーを追加
    week_key = week_start_date.strftime('%Y-%m-%d')
    summaries[week_key] = {
      'summary' => summary,
      'generated_at' => Time.now.to_s
    }
    
    # ファイルに保存
    File.write(summaries_file, JSON.pretty_generate(summaries))
  end

  def get_saved_summary(week_start_date)
    summaries_file = './data/weekly_summaries.json'
    return nil unless File.exist?(summaries_file)
    
    summaries = JSON.parse(File.read(summaries_file))
    week_key = week_start_date.strftime('%Y-%m-%d')
    
    summaries[week_key] ? summaries[week_key]['summary'] : nil
  end
end