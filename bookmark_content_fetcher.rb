require_relative 'gatherly_client'
require_relative 'crawl_job_manager'
require_relative 'bookmark_content_manager'
require_relative 'content_summarizer'

class BookmarkContentFetcher
  attr_reader :gatherly_client, :job_manager, :content_manager, :summarizer

  def initialize(db_path = nil)
    @gatherly_client = GatherlyClient.new
    @job_manager = CrawlJobManager.new(db_path)
    @content_manager = BookmarkContentManager.new(db_path)

    # 要約機能（OPENAI_API_KEYがあれば有効化）
    @summarizer = ENV['OPENAI_API_KEY'] ? ContentSummarizer.new : nil
  end

  # 本文取得ジョブを作成
  # @param raindrop_id [Integer] RaindropブックマークID
  # @param url [String] URL
  # @return [String, nil] job_uuid または nil（失敗時）
  def fetch_content(raindrop_id, url)
    # 既にコンテンツ取得済みの場合はスキップ
    if @content_manager.content_exists?(raindrop_id)
      puts "⏭️  Content already exists for raindrop_id: #{raindrop_id}"
      return nil
    end

    # 既に取得失敗済みの場合はスキップ
    if @content_manager.fetch_failed?(raindrop_id)
      puts "⏭️  Skipping permanently failed URL for raindrop_id: #{raindrop_id}"
      return nil
    end

    # 既にジョブが存在する場合はスキップ
    if @job_manager.job_exists_for_bookmark?(raindrop_id)
      puts "⏭️  Job already exists for raindrop_id: #{raindrop_id}"
      return nil
    end

    # Gatherly APIにジョブ作成
    result = @gatherly_client.create_crawl_job(url)

    if result[:error]
      puts "❌ Failed to create crawl job for #{url}: #{result[:error]}"
      return nil
    end

    job_uuid = result[:job_uuid]
    puts "✅ Created crawl job: #{job_uuid} for #{url}"

    # DBにジョブ記録
    success = @job_manager.create_job(raindrop_id, url, job_uuid)

    success ? job_uuid : nil
  end

  # 保留中のジョブのステータスを更新
  # @return [Hash] 処理結果の統計
  def update_pending_jobs
    pending_jobs = @job_manager.get_pending_jobs

    stats = {
      checked: 0,
      completed: 0,
      still_pending: 0,
      failed: 0
    }

    puts "\n📊 Checking #{pending_jobs.length} pending jobs..."

    pending_jobs.each do |job|
      stats[:checked] += 1
      job_id = job['job_id']

      # Gatherly APIでステータス確認
      status_result = @gatherly_client.get_job_status(job_id)

      if status_result[:error]
        error_msg = status_result[:error].to_s
        # 404 = ジョブが存在しない（期限切れ）
        if error_msg.include?('404') || error_msg.include?('Not Found')
          puts "   ❌ Job expired (404): #{job_id[0..8]}..."
          @job_manager.update_job_status(job_id, 'failed', 'Job expired on Gatherly API')
          stats[:failed] += 1
        # Processing failed = Gatherly側で失敗
        elsif error_msg.include?('Processing failed') || error_msg.include?('No data returned')
          puts "   ❌ Processing failed: #{job_id[0..8]}..."
          @job_manager.update_job_status(job_id, 'failed', 'Gatherly processing failed')
          stats[:failed] += 1
        else
          puts "⚠️ Error checking job #{job_id}: #{error_msg}"
        end
        next
      end

      api_status = status_result[:status]
      puts "   Job #{job_id[0..8]}... status: #{api_status}"

      case api_status
      when 'success', 'completed'
        # 結果を取得して保存
        if save_job_result(job_id)
          stats[:completed] += 1
        else
          stats[:failed] += 1
        end

      when 'failed'
        # 失敗として記録
        error_msg = status_result[:error] || 'Unknown error'
        @job_manager.update_job_status(job_id, 'failed', error_msg)
        stats[:failed] += 1
        puts "   ❌ Job failed: #{error_msg}"

      when 'running', 'pending', 'queued'
        # まだ実行中/待機中
        @job_manager.update_job_status(job_id, 'pending')
        stats[:still_pending] += 1

      else
        puts "   ⚠️ Unknown status: #{api_status}"
        @job_manager.update_job_status(job_id, 'pending')
        stats[:still_pending] += 1
      end

      # API負荷軽減のため少し待機
      sleep 0.5
    end

    puts "\n📈 Update summary:"
    puts "   Checked: #{stats[:checked]}"
    puts "   ✅ Completed: #{stats[:completed]}"
    puts "   ⏳ Still pending: #{stats[:still_pending]}"
    puts "   ❌ Failed: #{stats[:failed]}"

    stats
  end

  # 完了したジョブの結果を保存
  # @param job_id [String] ジョブID
  # @return [Boolean] 成功/失敗
  def save_job_result(job_id)
    job = @job_manager.get_job(job_id)
    unless job
      puts "❌ Job not found: #{job_id}"
      return false
    end

    raindrop_id = job['raindrop_id']

    # Gatherly APIから結果取得
    result = @gatherly_client.get_job_result(job_id)

    if result[:error]
      puts "❌ Failed to get result for #{job_id}: #{result[:error]}"
      @job_manager.update_job_status(job_id, 'failed', result[:error])
      return false
    end

    items = result[:items] || []

    if items.empty?
      puts "⚠️ No items found for job #{job_id}"
      @job_manager.update_job_status(job_id, 'failed', 'No items returned')
      return false
    end

    # 最初のアイテムから本文を取得
    item = items.first
    body = item[:body] || {}

    # 本文データを準備
    original_content = body[:text] || body['text'] || body[:content] || body['content']
    title = body[:title] || body['title']

    # 要約を生成（有効な場合）
    content_to_save = original_content
    if @summarizer && original_content && original_content.length > 200
      puts "📝 要約を生成中..."
      summary = @summarizer.summarize_to_bullet_points(original_content, title: title)
      if summary
        content_to_save = summary
        puts "✅ 要約完了: #{original_content.length}文字 → #{summary.length}文字"
      else
        puts "⚠️ 要約失敗、元の本文を保存します"
      end
    end

    content_data = {
      url: job['url'],
      title: title,
      content: content_to_save,
      content_type: 'text',
      word_count: content_to_save&.length || 0
    }

    # 本文を保存
    if @content_manager.save_content(raindrop_id, content_data)
      @job_manager.update_job_status(job_id, 'success')
      puts "✅ Saved content for raindrop_id: #{raindrop_id} (#{content_data[:word_count]} chars)"
      true
    else
      @job_manager.update_job_status(job_id, 'failed', 'Failed to save content')
      false
    end
  rescue => e
    puts "❌ Exception in save_job_result: #{e.message}"
    puts e.backtrace.first(3).join("\n")
    @job_manager.update_job_status(job_id, 'failed', e.message)
    false
  end

  # 失敗したジョブをリトライ
  # @return [Integer] リトライしたジョブ数
  def retry_failed_jobs
    failed_jobs = @job_manager.get_failed_jobs_for_retry
    retried_count = 0
    permanently_failed_count = 0

    puts "\n🔄 Retrying #{failed_jobs.length} failed jobs..."

    failed_jobs.each do |job|
      raindrop_id = job['raindrop_id']
      url = job['url']
      retry_count = job['retry_count']
      max_retries = job['max_retries']

      # 最大リトライ回数に達した場合は失敗フラグを立てる
      if retry_count >= max_retries
        puts "   ⛔ Max retries reached for #{url}"
        @content_manager.mark_fetch_failed(raindrop_id, url)
        permanently_failed_count += 1
        next
      end

      puts "   Retry #{retry_count + 1}/#{max_retries} for #{url}"

      # 新しいジョブを作成
      result = @gatherly_client.create_crawl_job(url)

      if result[:error]
        puts "   ❌ Retry failed: #{result[:error]}"
        # リトライカウントはインクリメント
        @job_manager.increment_retry_count(job['job_id'])
        next
      end

      new_job_uuid = result[:job_uuid]

      # 古いジョブのリトライカウントをインクリメント
      @job_manager.increment_retry_count(job['job_id'])

      # 新しいジョブをDBに記録
      @job_manager.create_job(raindrop_id, url, new_job_uuid)

      retried_count += 1
      puts "   ✅ Created retry job: #{new_job_uuid}"

      sleep 0.5
    end

    puts "🔄 Retried #{retried_count} jobs"
    puts "⛔ Permanently failed: #{permanently_failed_count} jobs" if permanently_failed_count > 0
    retried_count
  end

  # タイムアウトしたジョブを処理
  # @return [Integer] タイムアウト処理したジョブ数
  def handle_timeout_jobs
    timeout_jobs = @job_manager.get_timeout_jobs
    timeout_count = 0

    return 0 if timeout_jobs.empty?

    puts "\n⏱️  Handling #{timeout_jobs.length} timeout jobs..."

    timeout_jobs.each do |job|
      job_id = job['job_id']
      @job_manager.update_job_status(job_id, 'failed', 'Timeout after 24 hours')
      timeout_count += 1
      puts "   ⏱️  Timeout: #{job_id}"
    end

    puts "⏱️  Marked #{timeout_count} jobs as timeout"
    timeout_count
  end

  # 統計情報を取得して表示
  # @return [Hash]
  def print_stats
    job_stats = @job_manager.get_stats
    content_stats = @content_manager.get_stats

    puts "\n📊 Statistics:"
    puts "   Jobs:"
    puts "     Total: #{job_stats[:total]}"
    puts "     Success: #{job_stats[:success]} (#{job_stats[:success_rate]}%)"
    puts "     Failed: #{job_stats[:failed]}"
    puts "     Pending: #{job_stats[:pending]}"
    puts "     Running: #{job_stats[:running]}"
    puts "\n   Contents:"
    puts "     Total: #{content_stats[:total_contents]}"
    puts "     Avg words: #{content_stats[:avg_word_count]}"
    puts "     Recent week: #{content_stats[:recent_week_count]}"

    # 成功率が50%以下なら警告
    if job_stats[:success_rate] < 50 && job_stats[:total] > 10
      puts "\n⚠️  WARNING: Success rate is below 50%! Investigation needed."
    end

    {
      jobs: job_stats,
      contents: content_stats
    }
  end

  def close
    @job_manager.close
    @content_manager.close
  end
end
