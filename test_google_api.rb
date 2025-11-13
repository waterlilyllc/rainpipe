#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'
require 'dotenv'
Dotenv.load('/var/git/rainpipe/.env')

# テスト検索
query = 'AI 最新ニュース'
uri = URI('https://www.googleapis.com/customsearch/v1')
params = {
  key: ENV['GOOGLE_API_KEY'],
  cx: ENV['GOOGLE_CUSTOM_SEARCH_CX'],
  q: query,
  num: 3,
  dateRestrict: 'd1',
  lr: 'lang_ja'
}
uri.query = URI.encode_www_form(params)

puts "🔍 Google Custom Search APIをテスト中..."
puts "API Key: #{ENV['GOOGLE_API_KEY'][0..10]}..." if ENV['GOOGLE_API_KEY']
puts "Search Engine ID: #{ENV['GOOGLE_CUSTOM_SEARCH_CX']}"

response = Net::HTTP.get_response(uri)
puts "\nStatus: #{response.code}"

if response.code == '200'
  data = JSON.parse(response.body)
  puts "\n✅ Google API接続成功！"
  puts "検索結果数: #{data['items']&.length || 0}件"
  
  if data['items']
    puts "\n検索結果サンプル:"
    data['items'].each_with_index do |item, idx|
      puts "\n#{idx + 1}. #{item['title']}"
      puts "   URL: #{item['link']}"
      puts "   #{item['snippet'][0..100]}..." if item['snippet']
    end
  end
else
  puts "\n❌ エラー:"
  error_data = JSON.parse(response.body) rescue response.body
  puts JSON.pretty_generate(error_data)
end