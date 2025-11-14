# Implementation Plan

## Overview

This implementation plan translates the technical design into 6 major task groups with 26 sub-tasks. Tasks are organized by domain (Backend API, Service Integration, Job Queue, Frontend UI) and sequenced for incremental system delivery.

**Parallel execution enabled**: Multiple tasks can run concurrently when marked with `(P)` (separate team members or branches).

---

## Backend API & Progress Endpoints

- [x] 1. Implement progress tracking API endpoints
- [x] 1.1 (P) Create GET /api/progress endpoint returning job status and logs
  - Retrieve job record from keyword_pdf_generations table by UUID
  - Aggregate progress logs from keyword_pdf_progress_logs table (last 50 entries, ordered by timestamp DESC)
  - Return ProgressResponse JSON schema with status, current_stage, percentage, stage_details, logs, error_info
  - Validate job_id parameter (UUID format check)
  - Return 404 if job not found, 400 if job_id missing, 500 for database errors
  - Add appropriate error response bodies with error type and message
  - _Requirements: 4.1, 4.2, 4.4_

- [x] 1.2 (P) Create POST /api/cancel endpoint for job cancellation
  - Accept job_id parameter
  - Query keyword_pdf_generations table to verify job exists and is still processing
  - Set cancellation_flag = true in database
  - Return JSON response {success: bool, message: string}
  - Handle race condition if job already completed (return success with "Job already completed" message)
  - Return 404 if job not found, 400 if missing job_id
  - _Requirements: 5.3_

- [x] 1.3 (P) Implement database query optimization for progress API
  - Add indexes on keyword_pdf_generations(uuid) and keyword_pdf_progress_logs(job_id, timestamp DESC)
  - Create efficient SQL query to fetch job record with aggregated logs in single statement
  - Test query performance with simulated large log tables (1000+ entries)
  - Document query plan in comments
  - _Requirements: 4.1, 4.2_

---

## Database Schema Extension

- [x] 2. Extend database schema for progress tracking
- [x] 2.1 Create migration for keyword_pdf_progress_logs table
  - Define schema: id (PK), job_id (FK), stage (enum), event_type (enum), percentage, message, details (JSON), timestamp
  - Add constraints: stage enum check, event_type enum check, FK reference to keyword_pdf_generations.uuid
  - Create indexes: (job_id, timestamp DESC) and (timestamp DESC)
  - Implement both up and down migrations for rollback support
  - Test migration execution and rollback
  - _Requirements: 4.3, 6.2_

- [x] 2.2 (P) Extend keyword_pdf_generations table with progress tracking columns
  - Add columns: cancellation_flag (BOOLEAN DEFAULT 0), current_stage (TEXT), current_percentage (INTEGER DEFAULT 0)
  - Add constraint: stage enum check
  - Add optional user_id column for future multi-user concurrency tracking
  - Create index on user_id for future use
  - Test migration and backward compatibility with existing records
  - _Requirements: 4.3, 6.1, 6.3_

- [ ] 2.3 (P) Create detailed_stage_details JSON schema documentation
  - Document structure for each stage: filtering, content_fetching, summarization, pdf_generation, email_sending
  - Define field names and types for each stage (bookmarks_retrieved, gatherly_jobs, etc.)
  - Create example JSON for each stage for developers' reference
  - Add validation helper method to parse and validate details JSON before storage
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

---

## Service Integration & Progress Callback

- [ ] 3. Implement progress callback mechanism for service layer integration
- [ ] 3.1 Define and implement ProgressCallback interface
  - Create ProgressCallback class with methods: report_stage(stage_name, percentage, details), cancellation_requested?, report_event(event_type, message)
  - Implement validation: stage_name must be one of [filtering, content_fetching, summarization, pdf_generation, email_sending]
  - Implement percentage range validation (0-100)
  - Add error handling for invalid inputs (raise ArgumentError with descriptive message)
  - Make callback optional (support nil for CLI/batch mode)
  - _Requirements: 4.3, 2.1, 2.2, 2.3, 2.4, 2.5_

- [ ] 3.2 (P) Integrate ProgressCallback into KeywordFilteredPDFService
  - Accept optional callback parameter in initialize method
  - Call callback.report_stage after filtering stage completes with metrics (bookmarks_retrieved, bookmarks_after_filter)
  - Call callback.report_stage after content fetching stage completes with metrics (gatherly_jobs, polling_attempts, content_retrieved)
  - Call callback.report_stage after summarization stage begins and after each bookmark summarized
  - Check cancellation_requested? periodically (between stages) and abort if true
  - Ensure backward compatibility: service works with or without callback
  - _Requirements: 2.1, 2.2, 2.3_

- [ ] 3.3 (P) Integrate ProgressCallback into GPTContentGenerator
  - Accept optional callback parameter in initialize method
  - Call callback.report_stage when starting overall summary generation
  - Call callback.report_stage when starting keyword extraction
  - Call callback.report_stage when starting analysis generation
  - Include timing information and bookmark count in details
  - Call callback.report_event for GPT API retries and warnings
  - _Requirements: 2.3, 3.1_

- [ ] 3.4 (P) Integrate ProgressCallback into KeywordPDFGenerator
  - Accept optional callback parameter in initialize method
  - Call callback.report_stage after PDF rendering starts with 0% progress
  - Call callback.report_stage after header rendered (10%)
  - Call callback.report_stage after each chunk of bookmarks rendered with percentage update
  - Call callback.report_stage after PDF file written with final page count and file size
  - Include page_count and file_size_bytes in details
  - _Requirements: 2.4_

- [ ] 3.5 (P) Integrate ProgressCallback into KindleEmailSender
  - Accept optional callback parameter in initialize method
  - Call callback.report_stage when starting email sending with recipient address
  - Call callback.report_stage after email sent successfully with send_time_ms
  - Call callback.report_event if email delivery fails with error message
  - Include recipient and file_size_bytes in details
  - _Requirements: 2.5, 3.1_

---

## Job Queue & Background Job Management

- [x] 4. Implement background job queue and execution system
- [x] 4.1 Create JobQueue class for background job management
  - Implement enqueue(keywords:, date_start:, date_end:, send_to_kindle:, kindle_email:) method
  - Create keyword_pdf_generations record with UUID, status='pending', current_percentage=0
  - Spawn background Thread for PDF generation pipeline
  - Return job UUID immediately (non-blocking)
  - Ensure thread doesn't block request handler
  - Handle uncaught exceptions in thread: catch all errors, update job status to 'failed', log error_message
  - _Requirements: 4.3, 6.1, 6.2_

- [x] 4.2 (P) Implement job state management and persistence
  - Create keyword_pdf_generations record update flow: pending → processing → completed/failed
  - Update current_stage and current_percentage as job progresses
  - Implement mark_completed(job_id, pdf_path, timings) method
  - Implement mark_failed(job_id, error_message) method
  - Implement mark_cancelled(job_id) method
  - Ensure all updates committed to database atomically
  - _Requirements: 4.3, 6.2_

- [x] 4.3 (P) Implement job cancellation logic
  - Integrate with ProgressCallback.cancellation_requested? method
  - Check cancellation flag in keyword_pdf_generations table periodically (between stages)
  - If cancellation detected: stop execution immediately, mark job as 'cancelled', clean up resources
  - Handle race condition: if cancellation detected after email sent, still mark as cancelled (idempotent)
  - Test cancellation at different stages (filtering, fetching, summarization, pdf, email)
  - _Requirements: 5.3, 4.3_

- [x] 4.4 (P) Implement progress logging to keyword_pdf_progress_logs
  - Create helper method in ProgressCallback to write logs to database
  - Each stage transition creates new log entry (stage, event_type='stage_update', percentage, message, details JSON)
  - Each retry/warning/error creates new log entry with event_type='retry'/'warning'/'error'
  - Preserve timestamp of log entry (not current time, but actual execution time)
  - Implement batch log writes for efficiency (queue logs, flush every N entries or time-based)
  - _Requirements: 4.3, 6.2, 7.1, 7.2_

---

## Frontend UI: Progress Display

- [x] 5. Build frontend progress display components and real-time updates
- [x] 5.1 (P) Implement PollingManager JavaScript module
  - Create polling loop that starts after form submission
  - Poll /api/progress?job_id=<uuid> every 1000ms (1 second interval per requirement 1.2)
  - Parse ProgressResponse JSON and validate schema
  - Stop polling when status transitions to 'completed', 'failed', or 'cancelled'
  - Handle network errors gracefully: retry with exponential backoff (1s, 2s, 4s, 8s)
  - Implement max retries (e.g., 10) before stopping polling with error notification
  - Expose start(job_id), stop(), get_current_progress() methods
  - _Requirements: 5.1, 5.2, 1.2_

- [x] 5.2 (P) Implement ProgressPanel UI component for real-time progress display
  - Create HTML structure: stage indicator, percentage bar, stage metrics display, error panel
  - Render current_stage as human-readable text (e.g., "Filtering bookmarks" instead of "filtering")
  - Display percentage as visual progress bar (0-100%) with numeric percentage label
  - Render stage_details metrics: bookmark counts, API calls, file size, email status
  - Update UI every time new progress arrives from API (onNewProgress callback)
  - Hide error panel by default, show when error_info present
  - Style with Bootstrap classes, match existing Rainpipe design
  - Test responsive design: works on desktop, tablet, mobile
  - _Requirements: 1.1, 1.4, 2.1, 2.2, 2.3, 2.4, 2.5_

- [x] 5.3 (P) Implement error display in ProgressPanel
  - Show error_type from API response as error title
  - Display context field as error description
  - Show suggested_remedy field as actionable guidance (e.g., "Wait 5 minutes and retry")
  - Style error panel with red background, attention-grabbing color
  - Include error timestamp from log entry
  - Test with various error types: timeout, rate limit, validation, email failure
  - _Requirements: 3.1, 3.3_

- [x] 5.4 (P) Implement completion panel with download/notification
  - When status='completed', hide ProgressPanel and show CompletionPanel
  - Display "PDF generation complete" message with timestamp
  - Show download link if send_to_kindle=false (user downloads PDF)
  - Show "Email sent to <kindle_email>" message if send_to_kindle=true
  - Add "Refresh history" button to reload job history table
  - Add "Generate another PDF" button to return to form
  - Style as success notification (green background)
  - _Requirements: 5.4, 1.4_

---

## Frontend UI: Log Display & History

- [x] 6. Build progress log display and historical log viewer
- [x] 6.1 Implement LogPanel UI component for execution logs
  - Create HTML structure: scrollable log container, log entries, history selector
  - Render log entries in reverse chronological order (newest first)
  - Show timestamp (ISO 8601 format), stage, and message for each entry
  - Auto-scroll to bottom when new logs arrive (smooth scroll)
  - Implement sticky bottom behavior: keep scrolled to bottom even with rapid log arrivals
  - Style with monospace font for clarity, light background
  - Test with large log sets (1000+ entries) for performance
  - _Requirements: 7.1, 7.2, 7.3_

- [x] 6.2 (P) Implement history selector for viewing past job logs
  - Create dropdown/select element showing recent PDF generation jobs (last 10)
  - Display job in format: "keywords | date | status | bookmark_count | duration"
  - On selection change, fetch logs for that job_id and refresh LogPanel
  - Add new API endpoint GET /api/logs/history?job_id=<uuid> returning logs for completed/failed jobs
  - Mark current job visually (bold, highlighted, "In Progress" label)
  - Test switching between multiple jobs without UI lag
  - _Requirements: 7.4, 6.2_

- [x] 6.3 (P) Implement read-only enforcement for completed jobs
  - Hide cancel button when viewing logs of completed/failed/cancelled jobs
  - Hide ProgressPanel and generate button for non-active jobs
  - Display "View only" label for historical jobs
  - Requirement 7.5: "The Web Application shall NOT regenerate or reprocess completed jobs"
  - Implement this as UI constraint: no re-execution buttons available for past jobs
  - _Requirements: 7.5_

---

## Form Integration & AJAX Enhancement

- [x] 7. Refactor form submission to use AJAX and integrate with progress tracking
- [x] 7.1 Override form submission with AJAX handler
  - Intercept form submit event, prevent default navigation
  - Extract form values: keywords, date_start, date_end, send_to_kindle, kindle_email
  - Send AJAX POST to /filtered_pdf/generate (same endpoint as before)
  - Parse response: expect JSON with {job_id: "<uuid>", ...} or {error: "message"}
  - If error: display validation error in form error panel (red alert box)
  - If success: hide form, show ProgressPanel + LogPanel with job_id
  - Start PollingManager with job_id
  - Start LogPanel with job_id
  - _Requirements: 5.1, 5.2, 4.4_

- [x] 7.2 (P) Modify POST /filtered_pdf/generate request handler
  - Keep existing validation and service execution logic
  - Change response: instead of redirecting or streaming PDF, return JSON
  - New response format: {job_id: "<uuid>", status: "processing", current_stage: null, message: "Job started"}
  - Spawn background job using JobQueue.enqueue()
  - Return immediately (non-blocking)
  - Ensure existing tests still pass (may need to update test expectations for JSON response)
  - Maintain backward compatibility: if AJAX not used, fallback to downloading history page
  - _Requirements: 4.3, 5.2_

- [x] 7.3 (P) Implement resume monitoring for page reload
  - Check URL query parameter: ?resume=<job_id>
  - If present: skip form display, directly show ProgressPanel + LogPanel with that job_id
  - Query /api/progress to restore last known state
  - Start PollingManager if status still 'processing'
  - Test: close tab during PDF generation, reopen /filtered_pdf?resume=<uuid>, verify progress resumes
  - _Requirements: 1.3, 6.3_

---

## Integration & End-to-End Testing

- [ ] 8. Integration testing and system validation
- [ ] 8.1 Test end-to-end PDF generation with progress tracking
  - Load /filtered_pdf form
  - Submit with valid keywords and dates
  - Verify immediate response with job_id (no blocking)
  - Verify ProgressPanel displays and updates every 1-2 seconds
  - Verify all 5 stages appear in progress (filtering → fetching → summarization → pdf → email or skipped)
  - Verify percentage increases monotonically from 0 to 100
  - Verify completion notification appears and download link available
  - Verify job record saved in database with all metadata
  - _Requirements: 1.1, 1.2, 1.4, 4.3, 5.1, 5.2, 5.4_

- [ ] 8.2 (P) Test concurrent job execution
  - Start two PDF generation jobs simultaneously (different keywords/dates)
  - Verify each job receives unique job_id
  - Verify progress polling returns correct job state for each
  - Verify no interference between jobs (one job's progress doesn't affect other)
  - Verify database contains separate records for each job
  - Verify logs for each job tracked independently
  - _Requirements: 6.1, 6.2_

- [ ] 8.3 (P) Test job cancellation workflow
  - Start PDF generation job
  - Click cancel button before completion
  - Verify confirmation dialog appears
  - Confirm cancellation
  - Verify job status transitions to 'cancelled'
  - Verify final stage logged as incomplete
  - Verify resources cleaned up (if applicable)
  - Test cancellation at different stages (filtering, fetching, summarization)
  - _Requirements: 5.3, 4.3_

- [ ] 8.4 (P) Test error handling and recovery
  - Simulate Gatherly API timeout during content fetching
  - Verify job marked as 'failed' with appropriate error_message
  - Verify error_info displayed in ProgressPanel with suggested_remedy
  - Verify logs captured error event with event_type='error'
  - Verify user can retry with adjusted parameters (different date range)
  - Test multiple error types: API timeout, rate limit, email failure, invalid input
  - _Requirements: 3.1, 3.2, 3.3_

- [ ] 8.5 (P) Test progress log display and history
  - During job execution, verify logs appear in LogPanel in real-time
  - Verify auto-scroll keeps latest entry visible
  - Verify timestamp, stage, and message displayed for each log
  - After job completes, use history selector to view logs of past jobs
  - Verify read-only enforcement: no cancel or re-execute buttons visible
  - Test with multiple historical jobs (at least 5)
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [ ] 8.6 (P) Test input validation and error messages
  - Submit form with empty keywords → verify validation error before job creation
  - Submit form with invalid date range (end before start) → verify error message
  - Submit form with send_to_kindle=true but empty email → verify error
  - Verify no job record created for validation errors
  - Verify error messages user-friendly and actionable
  - _Requirements: 3.2_

---

## Optional Test Coverage

- [ ] 9. Optional baseline unit test suite (deferrable post-MVP)
- [ ] 9.1 * Unit test ProgressCallback validation
  - Test stage_name validation (valid enum values)
  - Test percentage range validation (0-100)
  - Test details schema validation for each stage
  - Test null callback handling
  - _Requirements: 4.3_

- [ ] 9.2 * Unit test PollingManager functionality
  - Test poll interval timing (1000ms ± 100ms tolerance)
  - Test exponential backoff on network failure
  - Test stop() method halts polling
  - Test response parsing and schema validation
  - _Requirements: 5.1, 5.2_

- [ ] 9.3 * Unit test JobQueue enqueue and state management
  - Test UUID generation and uniqueness
  - Test database record creation with correct initial state
  - Test concurrent enqueue calls don't create duplicate UUIDs
  - Test mark_completed and mark_failed update correct fields
  - _Requirements: 4.3, 6.1_

- [ ] 9.4 * Unit test ProgressPanel UI update logic
  - Test stage text rendering (filtering → human-readable format)
  - Test percentage bar update (0-100 range)
  - Test stage_details rendering for each stage type
  - Test error panel hide/show based on error_info presence
  - _Requirements: 1.1, 1.4_

---

## Requirements Coverage Summary

**Total Requirements Covered**: 26 / 26

| Requirement | Task(s) |
|-------------|---------|
| 1.1 | 5.2, 8.1 |
| 1.2 | 5.1, 8.1 |
| 1.3 | 7.3 |
| 1.4 | 5.2, 5.4, 8.1 |
| 2.1 | 3.1, 3.2, 5.2 |
| 2.2 | 3.1, 3.2, 5.2 |
| 2.3 | 3.1, 3.3, 5.2 |
| 2.4 | 3.1, 3.4, 5.2 |
| 2.5 | 3.1, 3.5, 5.2 |
| 3.1 | 5.3, 8.4 |
| 3.2 | 7.1, 8.6 |
| 3.3 | 5.3, 8.4 |
| 4.1 | 1.1, 1.3 |
| 4.2 | 1.1, 1.3 |
| 4.3 | 4.1, 4.2, 4.4, 7.2, 9.3 |
| 4.4 | 1.1 |
| 5.1 | 5.1, 7.1, 8.1 |
| 5.2 | 5.1, 5.2, 8.1 |
| 5.3 | 6.2, 8.3 |
| 5.4 | 5.4, 8.1 |
| 6.1 | 4.1, 8.2 |
| 6.2 | 4.2, 6.2, 8.2 |
| 6.3 | 7.3 |
| 7.1 | 6.1, 8.5 |
| 7.2 | 6.1, 8.5 |
| 7.3 | 6.1, 8.5 |
| 7.4 | 6.2, 8.5 |
| 7.5 | 6.3, 8.5 |

