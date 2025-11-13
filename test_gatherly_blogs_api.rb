#!/usr/bin/env ruby
require 'dotenv/load'
require 'net/http'
require 'json'
require 'uri'

puts "🧪 Gatherly Blogs API テスト\n\n"

API_URL = ENV['GATHERLY_API_URL'] || 'http://nas.taileef971.ts.net:3002'
API_KEY = ENV['GATHERLY_API_KEY'] || 'dev_api_key_12345'

# テスト用URL
TEST_URL = 'https://example.com'

puts "=" * 70
puts "1. クロールジョブ作成テスト (blogs)"
puts "=" * 70
puts "API URL: #{API_URL}"
puts "Test URL: #{TEST_URL}\n\n"

# ジョブ作成
uri = URI.parse("#{API_URL}/api/v1/crawl_jobs")
request = Net::HTTP::Post.new(uri)
request['Content-Type'] = 'application/json'
request['Authorization'] = "Bearer #{API_KEY}"
request.body = {
  source_type: 'blogs',
  source_payload: {
    urls: [TEST_URL]
  }
}.to_json

puts "Request:"
puts JSON.pretty_generate(JSON.parse(request.body))

http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = (uri.scheme == 'https')
response = http.request(request)

puts "\nResponse (#{response.code}):"
result = JSON.parse(response.body)
puts JSON.pretty_generate(result)

if response.code == '202' || response.code == '200'
  job_uuid = result['job_uuid']
  puts "\n✅ ジョブ作成成功: #{job_uuid}"

  # ステータス確認
  puts "\n" + "=" * 70
  puts "2. ジョブステータス確認"
  puts "=" * 70

  sleep 2

  status_uri = URI.parse("#{API_URL}/api/v1/crawl_jobs/#{job_uuid}")
  status_request = Net::HTTP::Get.new(status_uri)
  status_request['Authorization'] = "Bearer #{API_KEY}"

  status_response = http.request(status_request)
  status_result = JSON.parse(status_response.body)

  puts "Status: #{status_result['status']}"
  puts "Error: #{status_result['error']}" if status_result['error']

  # 結果取得（完了している場合）
  if status_result['status'] == 'success'
    puts "\n" + "=" * 70
    puts "3. 結果取得"
    puts "=" * 70

    items_uri = URI.parse("#{API_URL}/api/v1/crawl_jobs/#{job_uuid}/items")
    items_request = Net::HTTP::Get.new(items_uri)
    items_request['Authorization'] = "Bearer #{API_KEY}"

    items_response = http.request(items_request)
    items_result = JSON.parse(items_response.body)

    puts "\nItems count: #{items_result['items']&.length || 0}"

    if items_result['items']&.any?
      item = items_result['items'].first
      puts "\nFirst item:"
      puts "  ID: #{item['id']}"
      puts "  Body keys: #{item['body']&.keys&.join(', ')}"

      if item['body']
        puts "\n  Body structure:"
        item['body'].each do |key, value|
          preview = value.to_s[0..100]
          puts "    #{key}: #{preview}#{value.to_s.length > 100 ? '...' : ''}"
        end
      end
    end
  else
    puts "\n⏳ ジョブはまだ実行中です (status: #{status_result['status']})"
    puts "   後でもう一度確認してください："
    puts "   curl -H 'Authorization: Bearer #{API_KEY}' #{API_URL}/api/v1/crawl_jobs/#{job_uuid}/items"
  end
else
  puts "\n❌ ジョブ作成失敗"
end
