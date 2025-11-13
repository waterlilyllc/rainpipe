#!/usr/bin/env ruby

require 'dotenv/load'
require 'net/http'
require 'json'
require 'uri'

puts "🔍 Raindrop.io API 直接呼び出しテスト"
puts "=" * 50

API_BASE = 'https://api.raindrop.io/rest/v1'
token = ENV['RAINDROP_API_TOKEN']

# 1. フィルタなし（最新25件）
puts "\n📄 1. フィルタなし:"
uri = URI("#{API_BASE}/raindrops/0")
uri.query = URI.encode_www_form({ perpage: 3 })
puts "   URL: #{uri}"

request = Net::HTTP::Get.new(uri)
request['Authorization'] = "Bearer #{token}"
response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
data = JSON.parse(response.body)
puts "   件数: #{data['items'].length}"
data['items'].each { |item| puts "   - #{item['title'][0..50]}... (#{item['created']})" }

# 2. 日付フィルタあり（今週）
puts "\n📄 2. 日付フィルタ (2025-07-07..2025-07-13):"
uri = URI("#{API_BASE}/raindrops/0")
uri.query = URI.encode_www_form({ search: "created:2025-07-07..2025-07-13", perpage: 3 })
puts "   URL: #{uri}"

request = Net::HTTP::Get.new(uri)
request['Authorization'] = "Bearer #{token}"
response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
data = JSON.parse(response.body)
puts "   件数: #{data['items'].length}"
data['items'].each { |item| puts "   - #{item['title'][0..50]}... (#{item['created']})" }

# 3. 日付フィルタあり（古い日付）
puts "\n📄 3. 日付フィルタ (2025-05-05..2025-05-11):"
uri = URI("#{API_BASE}/raindrops/0")
uri.query = URI.encode_www_form({ search: "created:2025-05-05..2025-05-11", perpage: 3 })
puts "   URL: #{uri}"

request = Net::HTTP::Get.new(uri)
request['Authorization'] = "Bearer #{token}"
response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
data = JSON.parse(response.body)
puts "   件数: #{data['items'].length}"
if data['items'].any?
  data['items'].each { |item| puts "   - #{item['title'][0..50]}... (#{item['created']})" }
else
  puts "   → 該当なし"
end