require 'net/http'
require 'json'
require 'uri'

class RaindropClient
  API_BASE = 'https://api.raindrop.io/rest/v1'
  
  def initialize
    @api_token = ENV['RAINDROP_API_TOKEN']
    raise 'RAINDROP_API_TOKEN not found in environment' unless @api_token
  end

  def get_weekly_bookmarks(start_date, end_date)
    query = "created:#{start_date.strftime('%Y-%m-%d')}..#{end_date.strftime('%Y-%m-%d')}"
    get_raindrops(query)
  end

  def get_bookmarks_by_tag(tag)
    query = "##{tag}"
    get_raindrops(query)
  end

  private

  def get_raindrops(query = nil)
    uri = URI("#{API_BASE}/raindrops/0")
    uri.query = URI.encode_www_form({ search: query }) if query

    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{@api_token}"
    request['Content-Type'] = 'application/json'

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.code == '200'
      data = JSON.parse(response.body)
      data['items'] || []
    else
      puts "API Error: #{response.code} - #{response.body}"
      []
    end
  rescue => e
    puts "Error fetching raindrops: #{e.message}"
    []
  end
end