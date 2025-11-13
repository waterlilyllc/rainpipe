#!/usr/bin/env ruby

require 'dotenv/load'
require_relative 'raindrop_client'

puts "🌧️  Rainpipe API Test"
puts "=" * 30

# Check if API token is set
token = ENV['RAINDROP_API_TOKEN']
if token.nil? || token.empty? || token == 'your_test_token_here'
  puts "❌ RAINDROP_API_TOKEN not set or still placeholder"
  puts "Please set your API token in .env file"
  exit 1
end

puts "✅ API token found"

# Test API connection
begin
  client = RaindropClient.new
  puts "🔍 Testing API connection..."
  
  # Get recent bookmarks (no date filter)
  bookmarks = client.send(:get_raindrops)
  
  if bookmarks.any?
    puts "✅ API connection successful!"
    puts "📚 Found #{bookmarks.length} recent bookmarks"
    puts
    puts "Latest bookmarks:"
    bookmarks.first(3).each_with_index do |bookmark, i|
      puts "  #{i+1}. #{bookmark['title']}"
      puts "     #{bookmark['link']}"
      puts "     Created: #{bookmark['created']}"
      puts
    end
  else
    puts "⚠️  API connected but no bookmarks found"
  end
  
rescue => e
  puts "❌ API test failed: #{e.message}"
  exit 1
end

puts "🎉 All tests passed!"