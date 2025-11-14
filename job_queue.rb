#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'sqlite3'
require 'securerandom'
require_relative 'keyword_filtered_pdf_service'
require_relative 'progress_callback'

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
    db.execute(<<-SQL, [job_id, keywords, date_start, date_end, send_to_kindle ? 1 : 0, kindle_email])
      INSERT INTO keyword_pdf_generations
        (uuid, keywords, date_start, date_end, send_to_kindle, kindle_email, status, current_percentage, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, 'pending', 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
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
    db.execute(<<-SQL, [pdf_path, 100, 'completed', job_id])
      UPDATE keyword_pdf_generations
      SET pdf_path = ?, current_percentage = ?, status = ?, updated_at = CURRENT_TIMESTAMP
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

      # Create PDF generation service with callback
      service = KeywordFilteredPDFService.new(
        progress_callback: callback
      )

      # Execute PDF generation
      result = service.generate(
        keywords: keywords,
        date_start: date_start,
        date_end: date_end,
        send_to_kindle: send_to_kindle,
        kindle_email: kindle_email,
        job_id: job_id
      )

      # Mark job as completed
      mark_completed(job_id, result[:pdf_path])
      db.close
    rescue => e
      # Task 4.1: Handle uncaught exceptions
      error_message = "#{e.class}: #{e.message}"
      mark_failed(job_id, error_message)

      # Log error to progress logs
      db = SQLite3::Database.new(@db_path)
      db.execute(<<-SQL, [job_id, 'error', error_message])
        INSERT INTO keyword_pdf_progress_logs
          (job_id, stage, event_type, percentage, message, timestamp)
        VALUES (?, 'error', ?, 0, ?, CURRENT_TIMESTAMP)
      SQL
      db.close

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
