#!/usr/bin/env ruby

require 'dotenv'
Dotenv.load('/var/git/rainpipe/.env')

require 'json'
require 'net/http'
require 'uri'
require 'time'

class KiroArticleFetcher
  GOOGLE_API_URL = 'https://www.googleapis.com/customsearch/v1'
  
  def fetch_latest_articles
    query = "Kiro IDE AWS 仕様駆動開発"
    
    uri = URI(GOOGLE_API_URL)
    params = {
      key: ENV['GOOGLE_API_KEY'],
      cx: ENV['GOOGLE_CUSTOM_SEARCH_CX'],
      q: query,
      num: 10,
      dateRestrict: 'd7', # 過去7日間
      lr: 'lang_ja'
    }
    uri.query = URI.encode_www_form(params)
    
    puts "🔍 Kiroの最新記事を検索中..."
    response = Net::HTTP.get_response(uri)
    
    if response.code == '200'
      data = JSON.parse(response.body)
      articles = parse_articles(data)
      save_articles(articles)
      articles
    else
      puts "❌ エラー: #{response.body}"
      []
    end
  end
  
  private
  
  def parse_articles(data)
    items = data['items'] || []
    
    items.map do |item|
      {
        title: item['title'],
        url: item['link'],
        snippet: item['snippet'],
        source: extract_source(item),
        fetched_at: Time.now.iso8601
      }
    end
  end
  
  def extract_source(item)
    if item['displayLink']
      item['displayLink']
    elsif item['link']
      URI.parse(item['link']).host rescue 'unknown'
    else
      'unknown'
    end
  end
  
  def save_articles(articles)
    data = {
      keyword: 'Kiro',
      fetched_at: Time.now.iso8601,
      total_articles: articles.length,
      articles: articles
    }
    
    Dir.mkdir('./data/kiro_articles') unless Dir.exist?('./data/kiro_articles')
    
    filename = "./data/kiro_articles/kiro_articles_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"
    File.write(filename, JSON.pretty_generate(data))
    
    # 最新版も保存
    File.write('./data/kiro_articles/latest.json', JSON.pretty_generate(data))
    
    puts "✅ #{articles.length}件の記事を保存しました"
  end
end

# 実行
if __FILE__ == $0
  fetcher = KiroArticleFetcher.new
  articles = fetcher.fetch_latest_articles
  
  if articles.any?
    puts "\n📰 Kiroの最新記事:"
    articles.each_with_index do |article, idx|
      puts "\n#{idx + 1}. #{article[:title]}"
      puts "   URL: #{article[:url]}"
      puts "   Source: #{article[:source]}"
    end
  end
end