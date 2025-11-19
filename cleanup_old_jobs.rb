#!/usr/bin/env ruby
require 'dotenv/load'
require_relative 'crawl_job_manager'

job_manager = CrawlJobManager.new

# Pending jobsを全て取得
pending_jobs = job_manager.get_pending_jobs

puts "🔍 Pending jobs: #{pending_jobs.length}件"
puts ""

if pending_jobs.empty?
  puts "クリーンアップ対象のジョブはありません"
  exit 0
end

puts "これらのジョブをDBで 'failed' にマークします..."
puts ""

pending_jobs.each do |job|
  job_id = job['job_id']
  raindrop_id = job['raindrop_id']

  job_manager.update_job_status(job_id, 'failed', 'Cleaned up old pending job')
  puts "  ✅ #{job_id[0..8]}... (raindrop: #{raindrop_id})"
end

puts ""
puts "=" * 60
puts "✅ クリーンアップ完了: #{pending_jobs.length}件"
puts "=" * 60
