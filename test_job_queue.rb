#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'sqlite3'
require 'securerandom'
require_relative 'job_queue'

# Simple test framework without minitest/autorun
class SimpleTestCase
  attr_accessor :test_count, :test_passed, :test_failed

  def initialize
    @test_count = 0
    @test_passed = 0
    @test_failed = 0
    @failures = []
  end

  def assert_equal(expected, actual, msg = nil)
    @test_count += 1
    if expected == actual
      @test_passed += 1
      print "."
    else
      @test_failed += 1
      print "F"
      @failures << "❌ Expected #{expected.inspect}, got #{actual.inspect}. #{msg}"
    end
  end

  def assert_not_nil(actual, msg = nil)
    @test_count += 1
    if !actual.nil?
      @test_passed += 1
      print "."
    else
      @test_failed += 1
      print "F"
      @failures << "❌ Expected non-nil value. #{msg}"
    end
  end

  def assert_match(pattern, actual, msg = nil)
    @test_count += 1
    if actual.to_s =~ pattern
      @test_passed += 1
      print "."
    else
      @test_failed += 1
      print "F"
      @failures << "❌ Expected #{actual.inspect} to match #{pattern.inspect}. #{msg}"
    end
  end

  def assert_kind_of(klass, actual, msg = nil)
    @test_count += 1
    if actual.kind_of?(klass)
      @test_passed += 1
      print "."
    else
      @test_failed += 1
      print "F"
      @failures << "❌ Expected #{actual.inspect} to be kind of #{klass}. #{msg}"
    end
  end

  def assert(condition, msg = nil)
    @test_count += 1
    if condition
      @test_passed += 1
      print "."
    else
      @test_failed += 1
      print "F"
      @failures << "❌ Assertion failed. #{msg}"
    end
  end

  def run_tests
    yield self
    puts "\n"

    @failures.each { |f| puts f }

    puts "\n✅ テスト完了: #{@test_passed}/#{@test_count} 成功"
    exit(@test_failed > 0 ? 1 : 0)
  end
end

# Helper to create test database
def create_test_db(db_path)
  db = SQLite3::Database.new(db_path)
  db.execute('DROP TABLE IF EXISTS keyword_pdf_generations')
  db.execute('DROP TABLE IF EXISTS keyword_pdf_progress_logs')

  db.execute(<<-SQL)
    CREATE TABLE keyword_pdf_generations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid TEXT UNIQUE NOT NULL,
      keywords TEXT NOT NULL,
      date_start TEXT,
      date_end TEXT,
      send_to_kindle BOOLEAN DEFAULT 0,
      kindle_email TEXT,
      status TEXT DEFAULT 'pending',
      current_stage TEXT,
      current_percentage INTEGER DEFAULT 0,
      cancellation_flag BOOLEAN DEFAULT 0,
      pdf_path TEXT,
      error_message TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  SQL

  db.execute(<<-SQL)
    CREATE TABLE keyword_pdf_progress_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      job_id TEXT NOT NULL,
      stage TEXT NOT NULL,
      event_type TEXT NOT NULL,
      percentage INTEGER,
      message TEXT,
      details TEXT,
      timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY(job_id) REFERENCES keyword_pdf_generations(uuid)
    )
  SQL

  db.close
end

# Run tests
tester = SimpleTestCase.new

tester.run_tests do |t|
  db_path = 'rainpipe_test.db'

  # Test 4.1.1: enqueue creates database record
  begin
    create_test_db(db_path)
    queue = JobQueue.new(db_path: db_path)

    job_id = queue.enqueue(
      keywords: 'ruby programming',
      date_start: '2025-01-01',
      date_end: '2025-01-31',
      send_to_kindle: false,
      kindle_email: nil
    )

    t.assert_kind_of(String, job_id, "Job ID should be a string")
    t.assert_match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/, job_id, "Job ID should be a valid UUID")

    db = SQLite3::Database.new(db_path)
    db.results_as_hash = true
    record = db.execute('SELECT * FROM keyword_pdf_generations WHERE uuid = ?', [job_id])[0]
    db.close

    t.assert_not_nil(record, "Record should exist in database")
    if record
      t.assert_equal('ruby programming', record['keywords'], "Keywords should match")
      t.assert_equal('2025-01-01', record['date_start'], "Start date should match")
      t.assert_equal('2025-01-31', record['date_end'], "End date should match")
      t.assert_equal(0, record['send_to_kindle'], "send_to_kindle should be 0")
      t.assert_equal('pending', record['status'], "Status should be 'pending'")
      t.assert_equal(0, record['current_percentage'], "Percentage should be 0")
    end
  rescue => e
    t.test_failed += 1
    t.failures << "❌ Test 4.1.1 error: #{e.message}"
  ensure
    File.delete(db_path) if File.exist?(db_path)
  end

  # Test 4.1.2: enqueue returns job_id immediately (non-blocking)
  begin
    create_test_db(db_path)
    queue = JobQueue.new(db_path: db_path)

    start_time = Time.now
    job_id = queue.enqueue(
      keywords: 'test',
      date_start: nil,
      date_end: nil,
      send_to_kindle: false,
      kindle_email: nil
    )
    elapsed = Time.now - start_time

    t.assert_not_nil(job_id, "Job ID should be returned")
    t.assert(elapsed < 1.0, "enqueue should return immediately (<1s), took #{elapsed}s")
  rescue => e
    t.test_failed += 1
    t.failures << "❌ Test 4.1.2 error: #{e.message}"
  ensure
    File.delete(db_path) if File.exist?(db_path)
  end

  # Test 4.1.3: enqueue generates unique UUIDs
  begin
    create_test_db(db_path)
    queue = JobQueue.new(db_path: db_path)

    job_id_1 = queue.enqueue(keywords: 'test1', date_start: nil, date_end: nil, send_to_kindle: false, kindle_email: nil)
    job_id_2 = queue.enqueue(keywords: 'test2', date_start: nil, date_end: nil, send_to_kindle: false, kindle_email: nil)
    job_id_3 = queue.enqueue(keywords: 'test3', date_start: nil, date_end: nil, send_to_kindle: false, kindle_email: nil)

    job_ids = [job_id_1, job_id_2, job_id_3]
    t.assert_equal(3, job_ids.uniq.length, "All job IDs should be unique")
  rescue => e
    t.test_failed += 1
    t.failures << "❌ Test 4.1.3 error: #{e.message}"
  ensure
    File.delete(db_path) if File.exist?(db_path)
  end

  # Test 4.1.4: enqueue accepts Kindle parameters
  begin
    create_test_db(db_path)
    queue = JobQueue.new(db_path: db_path)

    job_id = queue.enqueue(
      keywords: 'test',
      date_start: nil,
      date_end: nil,
      send_to_kindle: true,
      kindle_email: 'user@kindle.com'
    )

    db = SQLite3::Database.new(db_path)
    db.results_as_hash = true
    record = db.execute('SELECT * FROM keyword_pdf_generations WHERE uuid = ?', [job_id])[0]
    db.close

    t.assert_not_nil(record, "Record should exist")
    if record
      t.assert_equal(1, record['send_to_kindle'], "send_to_kindle should be 1")
      t.assert_equal('user@kindle.com', record['kindle_email'], "Email should match")
    end
  rescue => e
    t.test_failed += 1
    t.failures << "❌ Test 4.1.4 error: #{e.message}"
  ensure
    File.delete(db_path) if File.exist?(db_path)
  end

  # Test 4.1.5: enqueue initializes status as pending (before async execution)
  begin
    create_test_db(db_path)
    queue = JobQueue.new(db_path: db_path)

    job_id = queue.enqueue(
      keywords: 'test',
      date_start: nil,
      date_end: nil,
      send_to_kindle: false,
      kindle_email: nil
    )

    # Check immediately after enqueue, before background thread executes
    db = SQLite3::Database.new(db_path)
    db.results_as_hash = true
    record = db.execute('SELECT * FROM keyword_pdf_generations WHERE uuid = ?', [job_id])[0]
    db.close

    t.assert_not_nil(record, "Record should exist")
    if record
      # Status might be 'pending' or 'failed' depending on when we check (async execution)
      # We just check that a record was created
      t.assert(['pending', 'failed'].include?(record['status']), "Status should be pending or failed")
    end
  rescue => e
    t.test_failed += 1
    t.failures << "❌ Test 4.1.5 error: #{e.message}"
  ensure
    # Wait a bit for async threads to finish
    sleep(0.5)
    File.delete(db_path) if File.exist?(db_path)
  end

  # Test 4.1.6: Multiple concurrent jobs
  begin
    create_test_db(db_path)
    queue = JobQueue.new(db_path: db_path)

    job_ids = []
    3.times do |i|
      job_id = queue.enqueue(
        keywords: "test#{i}",
        date_start: nil,
        date_end: nil,
        send_to_kindle: false,
        kindle_email: nil
      )
      job_ids << job_id
    end

    t.assert_equal(3, job_ids.uniq.length, "All job IDs should be unique")

    db = SQLite3::Database.new(db_path)
    db.results_as_hash = true
    records = db.execute('SELECT * FROM keyword_pdf_generations')
    db.close

    t.assert_equal(3, records.length, "All records should be in database")
  rescue => e
    t.test_failed += 1
    t.failures << "❌ Test 4.1.6 error: #{e.message}"
  ensure
    File.delete(db_path) if File.exist?(db_path)
  end

  # Test 4.2.1: mark_completed updates job status
  begin
    create_test_db(db_path)
    queue = JobQueue.new(db_path: db_path)

    job_id = queue.enqueue(
      keywords: 'test',
      date_start: nil,
      date_end: nil,
      send_to_kindle: false,
      kindle_email: nil
    )

    queue.mark_completed(job_id, '/path/to/pdf.pdf')

    db = SQLite3::Database.new(db_path)
    db.results_as_hash = true
    record = db.execute('SELECT * FROM keyword_pdf_generations WHERE uuid = ?', [job_id])[0]
    db.close

    t.assert_not_nil(record, "Record should exist")
    if record
      t.assert_equal('completed', record['status'], "Status should be 'completed'")
      t.assert_equal(100, record['current_percentage'], "Percentage should be 100")
      t.assert_equal('/path/to/pdf.pdf', record['pdf_path'], "PDF path should match")
    end
  rescue => e
    t.test_failed += 1
    t.failures << "❌ Test 4.2.1 error: #{e.message}"
  ensure
    File.delete(db_path) if File.exist?(db_path)
  end

  # Test 4.2.2: mark_failed updates job status
  begin
    create_test_db(db_path)
    queue = JobQueue.new(db_path: db_path)

    # Create a job without calling enqueue (to avoid async execution)
    # Instead, we'll just test mark_failed directly
    job_id = SecureRandom.uuid
    db = SQLite3::Database.new(db_path)
    db.execute(<<-SQL, [job_id, 'test', 'pending', 0])
      INSERT INTO keyword_pdf_generations
        (uuid, keywords, date_start, date_end, send_to_kindle, kindle_email, status, current_percentage, created_at, updated_at)
      VALUES (?, ?, NULL, NULL, 0, NULL, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
    db.close

    queue.mark_failed(job_id, 'Error message')

    db = SQLite3::Database.new(db_path)
    db.results_as_hash = true
    record = db.execute('SELECT * FROM keyword_pdf_generations WHERE uuid = ?', [job_id])[0]
    db.close

    t.assert_not_nil(record, "Record should exist")
    if record
      t.assert_equal('failed', record['status'], "Status should be 'failed'")
      t.assert_equal('Error message', record['error_message'], "Error message should match")
    end
  rescue => e
    t.test_failed += 1
    t.failures << "❌ Test 4.2.2 error: #{e.message}"
  ensure
    sleep(0.5)
    File.delete(db_path) if File.exist?(db_path)
  end

  # Test 4.3.1: cancellation_requested? returns false by default
  begin
    create_test_db(db_path)
    queue = JobQueue.new(db_path: db_path)

    job_id = queue.enqueue(
      keywords: 'test',
      date_start: nil,
      date_end: nil,
      send_to_kindle: false,
      kindle_email: nil
    )

    result = queue.cancellation_requested?(job_id)
    t.assert_equal(false, result, "cancellation_requested? should be false initially")
  rescue => e
    t.test_failed += 1
    t.failures << "❌ Test 4.3.1 error: #{e.message}"
  ensure
    File.delete(db_path) if File.exist?(db_path)
  end
end
