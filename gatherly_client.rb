require 'net/http'
require 'json'
require 'uri'

class GatherlyClient
  attr_reader :api_base_url, :api_key

  def initialize
    @api_base_url = ENV['GATHERLY_API_URL'] || 'http://nas.taileef971.ts.net:3002'
    @api_key = ENV['GATHERLY_API_KEY']
    @callback_base_url = ENV['GATHERLY_CALLBACK_BASE_URL'] || 'http://nas.taileef971.ts.net:4567'

    raise 'GATHERLY_API_KEY not found in environment' unless @api_key
  end

  # クロールジョブを作成（単一 URL）
  # @param url [String] クロール対象URL
  # @param options [Hash] オプション
  # @option options [String] :callback_url コールバックURL
  # @return [Hash] { job_uuid: String } または { error: String }
  def create_crawl_job(url, options = {})
    uri = URI.parse("#{@api_base_url}/api/v1/crawl_jobs")

    callback_url = options[:callback_url] || "#{@callback_base_url}/api/gatherly/callback"

    payload = {
      source_type: 'blogs',
      source_payload: {
        urls: [url]
      },
      callback_url: callback_url
    }

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['Authorization'] = "Bearer #{@api_key}"
    request.body = payload.to_json

    response = make_request(uri, request)

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body, symbolize_names: true)
    else
      {
        error: "Failed to create crawl job: #{response.code} #{response.message}",
        body: response.body
      }
    end
  rescue => e
    { error: "Exception in create_crawl_job: #{e.message}" }
  end

  # Task 4.1: クロールジョブを作成（複数 URL バッチ）
  # @param urls [Array<String>] クロール対象 URL 配列
  # @param options [Hash] オプション
  # @option options [String] :callback_url コールバックURL
  # @return [Hash] { job_uuid: String } または { error: String }
  def create_crawl_job_batch(urls, options = {})
    return { error: "URLs array is empty" } if urls.empty?

    uri = URI.parse("#{@api_base_url}/api/v1/crawl_jobs")

    callback_url = options[:callback_url] || "#{@callback_base_url}/api/gatherly/callback"

    payload = {
      source_type: 'blogs',
      source_payload: {
        urls: urls
      },
      callback_url: callback_url
    }

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['Authorization'] = "Bearer #{@api_key}"
    request.body = payload.to_json

    response = make_request(uri, request)

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body, symbolize_names: true)
    else
      {
        error: "Failed to create crawl job batch: #{response.code} #{response.message}",
        body: response.body
      }
    end
  rescue => e
    { error: "Exception in create_crawl_job_batch: #{e.message}" }
  end

  # ジョブの状態を確認
  # @param job_id [String] ジョブID (job_uuid)
  # @return [Hash] { job_uuid: String, status: String, error: String|nil }
  def get_job_status(job_id)
    uri = URI.parse("#{@api_base_url}/api/v1/crawl_jobs/#{job_id}")

    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{@api_key}"

    response = make_request(uri, request)

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body, symbolize_names: true)
    else
      {
        error: "Failed to get job status: #{response.code} #{response.message}",
        body: response.body
      }
    end
  rescue => e
    { error: "Exception in get_job_status: #{e.message}" }
  end

  # ジョブの結果を取得
  # @param job_id [String] ジョブID (job_uuid)
  # @return [Hash] { items: Array } または { error: String }
  def get_job_result(job_id)
    uri = URI.parse("#{@api_base_url}/api/v1/crawl_jobs/#{job_id}/items")

    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{@api_key}"

    response = make_request(uri, request)

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body, symbolize_names: true)
    else
      {
        error: "Failed to get job result: #{response.code} #{response.message}",
        body: response.body
      }
    end
  rescue => e
    { error: "Exception in get_job_result: #{e.message}" }
  end

  # ジョブをキャンセル
  # @param job_id [String] ジョブID (job_uuid)
  # @return [Hash] { success: Boolean } または { error: String }
  def cancel_crawl_job(job_id)
    uri = URI.parse("#{@api_base_url}/api/v1/crawl_jobs/#{job_id}/cancel")

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['Authorization'] = "Bearer #{@api_key}"

    response = make_request(uri, request)

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body, symbolize_names: true)
    else
      {
        error: "Failed to cancel crawl job: #{response.code} #{response.message}",
        body: response.body
      }
    end
  rescue => e
    { error: "Exception in cancel_crawl_job: #{e.message}" }
  end

  # ジョブを削除
  # @param job_id [String] ジョブID (job_uuid)
  # @return [Hash] { success: Boolean } または { error: String }
  def delete_crawl_job(job_id)
    uri = URI.parse("#{@api_base_url}/api/v1/crawl_jobs/#{job_id}")

    request = Net::HTTP::Delete.new(uri)
    request['Authorization'] = "Bearer #{@api_key}"

    response = make_request(uri, request)

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body, symbolize_names: true)
    else
      {
        error: "Failed to delete crawl job: #{response.code} #{response.message}",
        body: response.body
      }
    end
  rescue => e
    { error: "Exception in delete_crawl_job: #{e.message}" }
  end

  # ジョブを再実行
  # @param job_id [String] ジョブID (job_uuid)
  # @return [Hash] { job_uuid: String } または { error: String }
  def retry_crawl_job(job_id)
    uri = URI.parse("#{@api_base_url}/api/v1/crawl_jobs/#{job_id}/retry")

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['Authorization'] = "Bearer #{@api_key}"

    response = make_request(uri, request)

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body, symbolize_names: true)
    else
      {
        error: "Failed to retry crawl job: #{response.code} #{response.message}",
        body: response.body
      }
    end
  rescue => e
    { error: "Exception in retry_crawl_job: #{e.message}" }
  end

  # ジョブリストを取得
  # @param options [Hash] フィルタオプション
  # @option options [String] :status ステータス (pending, running, completed, failed)
  # @option options [Integer] :limit 取得件数
  # @option options [Integer] :offset オフセット
  # @return [Hash] { jobs: Array } または { error: String }
  def get_crawl_jobs(options = {})
    uri = URI.parse("#{@api_base_url}/api/v1/crawl_jobs")
    params = []
    params << "status=#{options[:status]}" if options[:status]
    params << "limit=#{options[:limit]}" if options[:limit]
    params << "offset=#{options[:offset]}" if options[:offset]

    uri = URI.parse("#{uri}?#{params.join('&')}") if params.any?

    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{@api_key}"

    response = make_request(uri, request)

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body, symbolize_names: true)
    else
      {
        error: "Failed to get crawl jobs: #{response.code} #{response.message}",
        body: response.body
      }
    end
  rescue => e
    { error: "Exception in get_crawl_jobs: #{e.message}" }
  end

  private

  # HTTP リクエストを実行
  # @param uri [URI] リクエスト先URI
  # @param request [Net::HTTPRequest] リクエストオブジェクト
  # @return [Net::HTTPResponse]
  def make_request(uri, request)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = 10
    http.read_timeout = 30
    http.request(request)
  end
end
