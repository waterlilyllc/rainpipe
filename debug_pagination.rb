#!/usr/bin/env ruby

require 'dotenv/load'
require 'json'
require_relative 'raindrop_client'

puts "🔍 Raindrop.io API ページネーション検証"
puts "=" * 50

client = RaindropClient.new

# 最初の3ページを取得してレスポンスを確認
3.times do |page|
  puts "\n📄 ページ #{page} のテスト:"
  
  uri = URI("#{RaindropClient::API_BASE}/raindrops/0")
  params = { page: page, perpage: 5 }  # 5件ずつで確認
  uri.query = URI.encode_www_form(params)
  
  puts "   URL: #{uri}"
  
  request = Net::HTTP::Get.new(uri)
  request['Authorization'] = "Bearer #{ENV['RAINDROP_API_TOKEN']}"
  request['Content-Type'] = 'application/json'

  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(request)
  end

  if response.code == '200'
    data = JSON.parse(response.body)
    items = data['items'] || []
    
    puts "   件数: #{items.length}"
    puts "   レスポンスキー: #{data.keys}"
    puts "   count: #{data['count']}" if data['count']
    puts "   page: #{data['page']}" if data['page']
    puts "   perpage: #{data['perpage']}" if data['perpage']
    
    if items.any?
      puts "   最初のタイトル: #{items.first['title'][0..50]}..."
      puts "   最後のタイトル: #{items.last['title'][0..50]}..."
      puts "   最初のID: #{items.first['_id']}"
      puts "   最後のID: #{items.last['_id']}"
    end
  else
    puts "   エラー: #{response.code} - #{response.body}"
  end
end