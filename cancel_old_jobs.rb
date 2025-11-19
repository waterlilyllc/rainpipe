#!/usr/bin/env ruby
require 'dotenv/load'
require_relative 'gatherly_client'
require_relative 'crawl_job_manager'

client = GatherlyClient.new
job_manager = CrawlJobManager.new

# Pending jobsを全て取得
pending_jobs = job_manager.get_pending_jobs

puts "🔍 Pending jobs: #{pending_jobs.length}件"
puts ""

if pending_jobs.empty?
  puts "キャンセル対象のジョブはありません"
  exit 0
end

puts "これらのジョブをGatherlyでキャンセルします..."
puts ""

cancelled = 0
failed = 0

pending_jobs.each do |job|
  job_id = job['job_id']
  raindrop_id = job['raindrop_id']

  print "キャンセル中: #{job_id[0..8]}... (raindrop: #{raindrop_id})"

  result = client.cancel_crawl_job(job_id)

  if result[:success]
    # DBでも failed に更新
    job_manager.update_job_status(job_id, 'failed', 'Manually cancelled')
    puts " ✅"
    cancelled += 1
  else
    puts " ❌ #{result[:error]}"
    failed += 1
  end

  sleep 0.1 # APIレート制限対策
end

puts ""
puts "=" * 60
puts "✅ キャンセル完了: #{cancelled}件"
puts "❌ キャンセル失敗: #{failed}件" if failed > 0
puts "=" * 60
