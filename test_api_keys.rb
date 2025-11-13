#!/usr/bin/env ruby

require 'dotenv/load'
require 'net/http'
require 'json'
require 'uri'

puts "🔧 API キー検証スクリプト"
puts "=" * 40

# 環境変数チェック
puts "\n📋 環境変数チェック:"
openai_key = ENV['OPENAI_API_KEY']
raindrop_key = ENV['RAINDROP_API_TOKEN']

if openai_key && !openai_key.empty? && openai_key != 'your_openai_api_key_here'
  puts "✅ OPENAI_API_KEY: 設定済み (#{openai_key[0..10]}...)"
else
  puts "❌ OPENAI_API_KEY: 未設定または無効"
end

if raindrop_key && !raindrop_key.empty? && raindrop_key != 'your_test_token_here'
  puts "✅ RAINDROP_API_TOKEN: 設定済み (#{raindrop_key[0..10]}...)"
else
  puts "❌ RAINDROP_API_TOKEN: 未設定または無効"
end

# OpenAI API テスト
if openai_key && openai_key != 'your_openai_api_key_here'
  puts "\n🤖 OpenAI API テスト:"
  
  begin
    uri = URI('https://api.openai.com/v1/chat/completions')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{openai_key}"
    request['Content-Type'] = 'application/json'
    
    request.body = {
      model: 'gpt-3.5-turbo',
      messages: [
        {
          role: 'user',
          content: 'Hello, this is a test. Please respond with "API connection successful"'
        }
      ],
      max_tokens: 20
    }.to_json
    
    response = http.request(request)
    
    puts "   レスポンス: #{response.code}"
    
    if response.code == '200'
      data = JSON.parse(response.body)
      content = data.dig('choices', 0, 'message', 'content')
      puts "   ✅ OpenAI API 接続成功"
      puts "   応答: #{content}"
    else
      puts "   ❌ OpenAI API エラー: #{response.code}"
      puts "   詳細: #{response.body}"
    end
    
  rescue => e
    puts "   ❌ OpenAI API 例外: #{e.message}"
  end
end

# Raindrop API テスト
if raindrop_key && raindrop_key != 'your_test_token_here'
  puts "\n💧 Raindrop.io API テスト:"
  
  begin
    uri = URI('https://api.raindrop.io/rest/v1/raindrops/0')
    uri.query = URI.encode_www_form({ perpage: 1 })
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{raindrop_key}"
    request['Content-Type'] = 'application/json'
    
    response = http.request(request)
    
    puts "   レスポンス: #{response.code}"
    
    if response.code == '200'
      data = JSON.parse(response.body)
      count = data['count'] || 0
      puts "   ✅ Raindrop API 接続成功"
      puts "   総ブックマーク数: #{count} 件"
    else
      puts "   ❌ Raindrop API エラー: #{response.code}"
      puts "   詳細: #{response.body}"
    end
    
  rescue => e
    puts "   ❌ Raindrop API 例外: #{e.message}"
  end
end

puts "\n📝 検証完了"