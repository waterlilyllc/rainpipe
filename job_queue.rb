#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'sqlite3'
require 'securerandom'
require 'date'
require_relative 'keyword_filtered_pdf_service'
require_relative 'progress_callback'
require_relative 'gpt_content_generator'
require_relative 'keyword_pdf_generator'

# Task 4.1-4.4: JobQueue class for background job management
# Manages PDF generation job queueing and background thread execution

class JobQueue
  def initialize(db_path: 'rainpipe.db')
    @db_path = db_path
    @jobs = {}  # Track active job threads
    @mutex = Mutex.new  # Thread-safe access to job tracking
  end

  # Task 4.1: Enqueue a new PDF generation job
  # @param keywords [String] Keywords to filter bookmarks
  # @param date_start [String] Start date for filtering (YYYY-MM-DD format)
  # @param date_end [String] End date for filtering (YYYY-MM-DD format)
  # @param send_to_kindle [Boolean] Whether to send PDF to Kindle
  # @param kindle_email [String] Kindle email address
  # @return [String] Job UUID
  def enqueue(keywords:, date_start:, date_end:, send_to_kindle:, kindle_email:)
    # Generate unique job UUID
    job_id = SecureRandom.uuid

    # Create database record for job
    db = SQLite3::Database.new(@db_path)
    db.execute(<<-SQL, [job_id, keywords, date_start, date_end, 0, kindle_email])
      INSERT INTO keyword_pdf_generations
        (uuid, keywords, date_range_start, date_range_end, bookmark_count, status, kindle_email, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, 'pending', ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
    db.close

    # Spawn background thread for job execution (non-blocking)
    thread = Thread.new do
      execute_job(
        job_id: job_id,
        keywords: keywords,
        date_start: date_start,
        date_end: date_end,
        send_to_kindle: send_to_kindle,
        kindle_email: kindle_email
      )
    end

    # Track the thread
    @mutex.synchronize do
      @jobs[job_id] = thread
    end

    # Return job_id immediately (non-blocking)
    job_id
  end

  # Task 4.2: Mark job as completed
  # @param job_id [String] Job UUID
  # @param pdf_path [String] Path to generated PDF file
  # @param timings [Hash] Execution timing information
  def mark_completed(job_id, pdf_path, timings = {})
    db = SQLite3::Database.new(@db_path)
    db.execute(<<-SQL, [pdf_path, 'completed', job_id])
      UPDATE keyword_pdf_generations
      SET pdf_path = ?, status = ?, updated_at = CURRENT_TIMESTAMP
      WHERE uuid = ?
    SQL
    db.close
  end

  # Task 4.2: Mark job as failed
  # @param job_id [String] Job UUID
  # @param error_message [String] Error message
  def mark_failed(job_id, error_message)
    db = SQLite3::Database.new(@db_path)
    db.execute(<<-SQL, [error_message, 'failed', job_id])
      UPDATE keyword_pdf_generations
      SET error_message = ?, status = ?, updated_at = CURRENT_TIMESTAMP
      WHERE uuid = ?
    SQL
    db.close
  end

  # Task 4.2: Mark job as cancelled
  # @param job_id [String] Job UUID
  def mark_cancelled(job_id)
    db = SQLite3::Database.new(@db_path)
    db.execute(<<-SQL, [job_id])
      UPDATE keyword_pdf_generations
      SET status = 'cancelled', updated_at = CURRENT_TIMESTAMP
      WHERE uuid = ?
    SQL
    db.close
  end

  # Task 4.3: Get cancellation status for a job
  # @param job_id [String] Job UUID
  # @return [Boolean] true if cancellation requested, false otherwise
  def cancellation_requested?(job_id)
    db = SQLite3::Database.new(@db_path)
    db.results_as_hash = true
    result = db.execute('SELECT cancellation_flag FROM keyword_pdf_generations WHERE uuid = ? LIMIT 1', [job_id])[0]
    db.close

    return false unless result
    result['cancellation_flag'] == 1
  end

  # Internal: Execute job in background thread
  # Task 4.1: Handle uncaught exceptions in thread
  # Task 4.4: Create ProgressCallback and report progress
  private def execute_job(job_id:, keywords:, date_start:, date_end:, send_to_kindle:, kindle_email:)
    begin
      # Task 4.4: Create progress callback for this job
      db = SQLite3::Database.new(@db_path)
      callback = ProgressCallback.new(job_id, db)

      # Step 1: Create PDF generation service with callback
      service = KeywordFilteredPDFService.new(
        keywords: keywords,
        date_start: date_start,
        date_end: date_end,
        progress_callback: callback
      )

      # Step 2: Filter bookmarks and generate summaries
      result = service.execute

      # Handle filtering/summarization errors
      if result[:status] == 'error'
        error_message = result[:error] || 'Unknown error during filtering'
        mark_failed(job_id, error_message)
        db.close
        return
      end

      # Handle no matching bookmarks
      bookmarks = result[:bookmarks]
      if bookmarks.empty?
        error_message = 'No bookmarks matched the filter'
        mark_failed(job_id, error_message)
        db.close
        return
      end

      # Step 3: Generate GPT content
      gpt_generator = GPTContentGenerator.new(ENV['OPENAI_API_KEY'], false)
      summary_result = gpt_generator.generate_overall_summary(bookmarks, keywords)
      keywords_result = gpt_generator.extract_related_keywords(bookmarks)
      analysis_result = gpt_generator.generate_analysis(bookmarks, keywords)

      # Step 4: Generate PDF file
      pdf_content = {
        overall_summary: summary_result[:summary],
        summary: summary_result[:summary],
        related_clusters: keywords_result[:related_clusters],
        analysis: analysis_result[:analysis],
        bookmarks: bookmarks,
        keywords: keywords,
        date_range: result[:date_range]
      }

      pdf_generator = KeywordPDFGenerator.new
      output_path = File.join('data', "filtered_pdf_#{Time.now.utc.strftime('%Y%m%d_%H%M%S')}_#{keywords.gsub(/[^a-zA-Z0-9]/, '_')}.pdf")
      pdf_result = pdf_generator.generate(pdf_content, output_path)

      # Step 5: Mark job as completed
      callback.report_stage('pdf_generation', 100, { pdf_path: pdf_result[:pdf_path] })
      mark_completed(job_id, pdf_result[:pdf_path])
      db.close

      # Step 6: Send to Kindle if requested
      if send_to_kindle && kindle_email
        begin
          email_sender = KindleEmailSender.new
          email_sender.send_pdf(pdf_result[:pdf_path], subject: "キーワード PDF: #{keywords}")
        rescue => e
          # Log warning but don't fail the job
          db = SQLite3::Database.new(@db_path)
          db.execute(<<-SQL, [job_id, 'warning', "Failed to send to Kindle: #{e.message}"])
            INSERT INTO keyword_pdf_progress_logs
              (job_id, stage, event_type, percentage, message, timestamp)
            VALUES (?, 'email_sending', ?, 100, ?, CURRENT_TIMESTAMP)
          SQL
          db.close
        end
      end

    rescue => e
      # Task 4.1: Handle uncaught exceptions
      error_message = "#{e.class}: #{e.message}"
      mark_failed(job_id, error_message)

      # Log error to progress logs
      begin
        db = SQLite3::Database.new(@db_path)
        db.execute(<<-SQL, [job_id, 'error', error_message])
          INSERT INTO keyword_pdf_progress_logs
            (job_id, stage, event_type, percentage, message, timestamp)
          VALUES (?, 'error', ?, 0, ?, CURRENT_TIMESTAMP)
        SQL
        db.close
      rescue => _
        # Ignore if we can't log the error
      end

      # Re-raise for monitoring (optional - can be logged elsewhere)
      # puts "Background job #{job_id} failed: #{error_message}"
    ensure
      # Clean up thread reference
      @mutex.synchronize do
        @jobs.delete(job_id)
      end
    end
  end
end
