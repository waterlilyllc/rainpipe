# Research & Design Decisions - Web UI Filtered PDF Progress

---

## Summary

- **Feature**: `web_ui_filtered_pdf_progress` - Real-time progress display for filtered PDF generation in Web UI
- **Discovery Scope**: Extension (adding progress tracking to existing synchronous PDF generation pipeline)
- **Key Findings**:
  1. Current architecture is fully synchronous - all work happens in POST /filtered_pdf/generate request handler (lines 437-590 in app.rb)
  2. Existing database schema (`keyword_pdf_generations`) already tracks status progression but only after job completion
  3. No current async processing, WebSocket, or polling mechanisms exist - requires new implementation
  4. Progress Reporter utility exists for CLI logging but not integrated with Web UI layer
  5. Integration approach: Refactor service layer to support progress streaming to backend, add job queue, implement frontend polling

---

## Research Log

### Extension Point Analysis

**Context**: Feature is an extension to existing filtered PDF generation workflow, not a new parallel system.

**Sources Consulted**:
- Current implementation: `/var/git/rainpipe/app.rb` lines 437-590
- Service orchestration: `/var/git/rainpipe/keyword_filtered_pdf_service.rb` lines 44-73
- Status tracking: `/var/git/rainpipe/pdf_generation_history.rb` lines 23-96
- Database schema: `/var/git/rainpipe/migrate_add_keyword_pdf_generations.rb` lines 39-60

**Findings**:
- Current flow: POST /filtered_pdf/generate → validation → service execution → PDF file → download/email
- Execution is **fully synchronous** within request handler (can take 2-5 minutes)
- Database records status but only tracks: pending → processing → completed/failed (no intermediate stages)
- ProgressReporter utility (progress_reporter.rb) exists but outputs only to STDOUT
- Gatherly integration already uses batch job polling pattern (300s timeout with backoff)
- Five distinct processing stages already exist: filtering, content fetching, summarization, PDF generation, email sending

**Implications for Design**:
- Must refactor synchronous execution into background job pattern to enable real-time updates
- Can leverage existing ProgressReporter for event generation
- Should extend database schema to track intermediate stage progress (not just overall status)
- Frontend polling should poll `/api/progress?job_id=<uuid>` returning current stage + percentage
- Optional: implement job queue system (Ruby's Sidekiq or similar) or simple threading model

### Technology Stack Verification

**Context**: Determining implementation technologies for job queue and real-time updates.

**Sources Consulted**:
- Rainpipe tech steering: `/var/git/rainpipe/.kiro/steering/tech.md`
- Gemfile dependencies: Ruby 3.x, Sinatra, Prawn, Mail, HTTParty for API calls
- Production constraints: No external job queue service (Sidekiq requires Redis)

**Findings**:
- Current tech stack: Ruby 3.x, Sinatra 2.x, SQLite, no async framework
- Sinatra natively supports Thread-based request handling (WEBrick supports concurrency)
- SQLite suitable for tracking job state (concurrent writes manageable for this workload)
- No Redis or external message queue in current setup - adding dependency requires justification
- Ruby has built-in Thread class, no additional gems needed for basic concurrency
- Prawn (PDF gem) is memory-efficient with chunking support already implemented
- OpenAI API calls already have retry/backoff logic in place

**Implications for Design**:
- Can use **simple threading model** without adding Sidekiq/Redis dependency
- Job state persisted in existing SQLite database (keyword_pdf_generations table)
- POST /filtered_pdf/generate spawns background thread, returns job ID immediately
- Frontend polls GET /api/progress?job_id=<uuid> for updates (standard HTTP, no WebSocket required per spec)
- Rate limiting: Poll at 1 second intervals (spec requirement 1.2)

### API Contract Definition

**Context**: Designing REST API contract for progress tracking to ensure clean separation between frontend and backend.

**Sources Consulted**:
- Existing endpoints structure: `/var/git/rainpipe/app.rb` lines 37-590
- Sinatra routing patterns: JSON responses, proper HTTP status codes
- Error handling patterns: FormValidator (form_validator.rb lines 29-96)

**Findings**:
- Current /filtered_pdf/generate returns 302 redirect or 400 error
- No JSON API exists for progress tracking - new endpoint required
- Rainpipe uses standard JSON responses for `/refresh/status` (lines 130-151)
- Error responses include error_message and validation details
- Job UUID already implemented in keyword_pdf_generations table (uuid TEXT UNIQUE)

**Implications for Design**:
- Create new GET /api/progress endpoint returning JSON with:
  - job_id (UUID)
  - status (processing, completed, failed)
  - current_stage (filtering, content_fetching, summarization, pdf_generation, email_sending)
  - percentage_complete (0-100)
  - stage_details (bookmark count, current bookmark, API calls, etc.)
  - error_info (if status=failed)
- Create new POST /api/cancel endpoint to allow job cancellation
- 404 response if job_id not found
- 200 response with job details if found

### Database Schema Extension

**Context**: Extend existing keyword_pdf_generations table to track intermediate stage progress.

**Sources Consulted**:
- Current schema: `/var/git/rainpipe/migrate_add_keyword_pdf_generations.rb` lines 39-60
- Five processing stages from requirements: filtering, content_fetching, summarization, pdf_generation, email_sending
- Each stage has measurable progress indicators

**Findings**:
- Current schema tracks: status (overall), total_duration_ms, but no intermediate stage tracking
- Five stages map to requirements section 2 (Stage-Based Reporting)
- Each stage has specific metrics: bookmark counts, API calls, page count, file size, email status
- Existing ProgressReporter supports emoji indicators for each stage

**Implications for Design**:
- Extend schema with JSON column `current_stage` and `progress_data` (or individual columns)
- Current approach: Update keyword_pdf_generations record after each stage completes
- Alternative: Store full progress history in separate log table (design can accommodate either)
- Log table schema: id, job_id, stage, timestamp, percentage, details (JSON)

### Service Layer Progress Reporting

**Context**: Integrate progress updates into existing service orchestration without breaking current functionality.

**Sources Consulted**:
- KeywordFilteredPDFService: `/var/git/rainpipe/keyword_filtered_pdf_service.rb` lines 44-73
- Service methods for each stage: lines 151-181 (filter), 260-313 (fetch content), 315-349 (summarize)
- ProgressReporter implementation: `/var/git/rainpipe/progress_reporter.rb` lines 30-76

**Findings**:
- Current ProgressReporter outputs only to console via `puts`
- Each service method already has logical boundaries (stages)
- GPTContentGenerator already has retry logic with exponential backoff
- GatherlyJobPoller already implements job polling (can serve as pattern for progress polling)

**Implications for Design**:
- Create ProgressCallback interface: simple callback object passed to services
- Services call callback after each major stage: `progress_callback.report_stage(stage_name, details)`
- Callback updates database record in background (non-blocking)
- Maintain backward compatibility: if no callback provided, use ProgressReporter for console output
- Services remain agnostic to whether progress is displayed in UI or logged to console

### Frontend Implementation Approach

**Context**: Designing UI updates without major JavaScript framework changes.

**Sources Consulted**:
- Current frontend: `/var/git/rainpipe/views/filtered_pdf.erb` lines 150-254
- HTML/CSS: Bootstrap-style classes, vanilla JavaScript
- Current interaction: Form submission → POST /filtered_pdf/generate → redirect or error

**Findings**:
- Current UI uses vanilla JavaScript, no modern framework (React/Vue/Svelte)
- Form submission is synchronous: user clicks button, waits for response
- History view already exists at `/filtered_pdf/history` with table of past jobs
- No JavaScript dependencies beyond standard DOM manipulation

**Implications for Design**:
- Override form submission with AJAX POST to capture job ID immediately
- Return job ID in JSON response instead of PDF download
- Start polling loop in client JavaScript (XMLHttpRequest or Fetch API)
- Display progress panel with stage indicators, percentage bar, log output
- Once complete, show download link or trigger Kindle email
- Keep styling consistent with existing Bootstrap design
- Polling implementation: setInterval with XHR/Fetch to /api/progress endpoint

### Concurrent Job Handling

**Context**: Current system prevents concurrent PDF generation (single-user limitation).

**Sources Consulted**:
- Current concurrency check: `/var/git/rainpipe/app.rb` lines 457-467
- Database method: `has_processing_record?` in pdf_generation_history.rb line 42-52

**Findings**:
- Current implementation: Check if any record with status='processing' exists
- If yes: Return error message "PDF generation already in progress"
- Limitation: Blocks all users from concurrent operations (not user-scoped)

**Implications for Design**:
- Refactor to allow multiple concurrent jobs (one per user or globally)
- Add user_id or session_id tracking to keyword_pdf_generations table (optional for MVP)
- Current MVP: Allow global concurrent jobs, track by job_id only
- Advanced feature: Implement user-scoped concurrency for future phase

### Job Lifecycle and State Transitions

**Context**: Define complete state machine for job execution and error handling.

**Sources Consulted**:
- Current statuses: pending, processing, completed, failed
- Error handling: `/var/git/rainpipe/app.rb` lines 486-498
- Requirement 3: Error handling and messages

**Findings**:
- Linear state progression: pending → processing → completed or failed
- Current system marks job as completed only after ALL stages complete
- No partial completion tracking or rollback capability
- Error messages stored in database but not timestamped with stage info

**Implications for Design**:
- State machine: pending → filtering → content_fetching → summarization → pdf_generation → email_sending → completed
- Alternative: Keep simple (processing vs completed/failed) with detailed stage tracking in separate log
- Cancellation state: completed (with cancellation flag) vs failed (retry possible)
- Error recovery: Log captures failure point, user can retry with improved inputs

### Requirement Coverage Analysis

**Context**: Map requirements to implementation components and identify any gaps.

**Sources Consulted**:
- Requirements document: `/var/git/rainpipe/.kiro/specs/web_ui_filtered_pdf_progress/requirements.md`
- 26 requirements across 7 functional groups

**Findings**:
- **Requirement 1.1-1.4 (Progress Display)**: Requires real-time UI updates - need polling mechanism
- **Requirement 2.1-2.5 (Stage-Based Reporting)**: Requires stage-specific metrics capture in each service
- **Requirement 3.1-3.3 (Error Handling)**: Extend error storage with context and suggestions
- **Requirement 4.1-4.4 (Backend API Integration)**: New /api/progress endpoint and job queue
- **Requirement 5.1-5.4 (Frontend Real-Time Update)**: Frontend polling + completion notification
- **Requirement 6.1-6.3 (Job Management)**: Database schema extension for concurrent jobs
- **Requirement 7.1-7.5 (Progress Log Display)**: New log table to capture execution history

**Implications for Design**:
- All requirements map directly to one or more components
- No gaps identified - scope is comprehensive
- Log display (Requirement 7) requires new database table separate from job status

---

## Architecture Pattern Evaluation

| Option | Description | Strengths | Limitations | Notes |
|--------|-------------|-----------|-------------|-------|
| **Simple Threading** | Spawn background thread for each job, poll DB for status | No external dependencies, easy integration with existing code, fast startup | Thread safety requires careful locking, SQLite concurrent writes may bottleneck, threads don't persist if server restarts | Suitable for MVP, can migrate to Sidekiq later |
| **Sidekiq/Redis** | Dedicated job queue with worker processes | Scalable, persistent job queue, worker pool management, industry standard | Requires Redis infrastructure, adds deployment complexity, external service dependency | Better for high-volume production, outside current scope |
| **Sinatra's Async** | Use Sinatra's async block support | Native to framework, no external deps | Limited error handling, debugging complexity | Possible but less idiomatic than threading |
| **Polling without Jobs** | Synchronous execution but extend timeout, client polls periodically | Minimal code changes, leverages HTTP long-polling | Will still block request handler, doesn't scale, poor UX for long operations | Not viable for 2-5 minute operations |

**Selected Approach**: Simple Threading with Database-Backed Job State

**Rationale**: Aligns with existing architecture, no external infrastructure required, can be evolved to job queue later.

---

## Design Decisions

### Decision: Background Job Execution Model

- **Context**: Current synchronous execution blocks request handler for 2-5 minutes, preventing other users from starting new PDF generations
- **Alternatives Considered**:
  1. Keep synchronous execution, extend HTTP timeout - poor UX, blocks client
  2. Use external job queue (Sidekiq) - adds infrastructure complexity
  3. Implement simple threading model - leverage Ruby's built-in concurrency
- **Selected Approach**: Background threading spawned from request handler, immediate job ID return to client
- **Rationale**: Matches user's Kindling process without infrastructure dependencies; allows concurrent operations
- **Trade-offs**:
  - Benefits: Immediate user feedback, concurrent job support, simple implementation
  - Compromise: Threads not persistent (restart loses in-flight jobs), SQLite writes may contend
- **Follow-up**: Consider Sidekiq migration if concurrency bottleneck appears in production

### Decision: Progress Update Frequency and Polling Strategy

- **Context**: Requirement 1.2 mandates updates at least once per second; WebSocket is optional
- **Alternatives Considered**:
  1. WebSocket connection - real-time but complex, not required by spec
  2. HTTP polling at 1s intervals - simpler, matches requirement
  3. Server-Sent Events (SSE) - good middle ground but adds complexity
- **Selected Approach**: HTTP polling at 1-second intervals using XMLHttpRequest or Fetch API
- **Rationale**: Meets requirement exactly, simple frontend implementation, no WebSocket infrastructure needed
- **Trade-offs**:
  - Benefits: Simple, reliable, works with existing Sinatra server
  - Compromise: Network overhead, slight delay in UI updates vs WebSocket
- **Follow-up**: Log entry timestamps enable future WebSocket upgrade if needed

### Decision: Database Schema for Progress Tracking

- **Context**: Must track fine-grained progress (stage name, metrics) alongside overall job status
- **Alternatives Considered**:
  1. Extend keyword_pdf_generations with JSON column `progress_data` - single table, denormalized
  2. Create separate `keyword_pdf_progress_logs` table with one row per stage transition - normalized
  3. Key-value store in Redis - external dependency, not viable
- **Selected Approach**: Create separate `keyword_pdf_progress_logs` table for historical logging + update current stage in job record
- **Rationale**:
  - Job record stays simple (status, current_stage, percentage)
  - Log table captures full history for requirement 7 (Progress Log Display)
  - Allows detailed post-mortem analysis of long-running jobs
- **Trade-offs**:
  - Benefits: Normalized schema, audit trail, flexible querying
  - Compromise: Slightly more complex schema, requires two writes per update
- **Follow-up**: Index log table by job_id for fast retrieval

### Decision: Service Layer Integration Point

- **Context**: Must inject progress updates into existing services without breaking current CLI/batch usage
- **Alternatives Considered**:
  1. Modify all services to write progress directly to DB - tight coupling
  2. Wrap services with decorator that logs progress - external logging
  3. Implement callback interface: services call provided callback - clean separation
- **Selected Approach**: Progress callback interface injected into services during initialization
- **Rationale**:
  - Services remain testable and framework-agnostic
  - Callback can be null (for CLI) or active (for Web UI)
  - Backward compatible with existing code
- **Trade-offs**:
  - Benefits: Clean separation of concerns, flexible
  - Compromise: Slightly more code, requires callback signature agreement
- **Follow-up**: Document callback interface thoroughly for implementers

### Decision: Error Handling and User Guidance

- **Context**: Requirement 3.1 mandates actionable error messages with remediation steps
- **Alternatives Considered**:
  1. Generic error messages - simple but unhelpful
  2. Detailed technical logs - confusing for users
  3. Categorized errors with suggested actions - user-friendly, complex
- **Selected Approach**: Error categorization with user-friendly message + suggested action
- **Rationale**:
  - Common errors: invalid inputs, API timeouts, rate limits, Kindle email issues
  - Each category has known remediation (retry, check credentials, adjust parameters)
- **Trade-offs**:
  - Benefits: Users can self-serve fixes, reduced support burden
  - Compromise: Requires error categorization logic, more complex error handling
- **Follow-up**: Populate error catalog during implementation phase

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| SQLite concurrent writes bottleneck | Medium | Job updates miss or conflict | Add database locking, consider eventual consistency, monitor in production |
| Long-running requests timeout | Medium | User sees blank page during PDF generation | Set reasonable HTTP timeout (60s+), implement keep-alive polling |
| Thread safety in Ruby services | Medium | Race conditions in shared state | Use thread-local variables, immutable data structures, test with concurrent jobs |
| Job state corruption on server restart | Low | Lost in-flight jobs without error | Document limitation in release notes, implement graceful degradation |
| Frontend polling creates traffic spike | Low | Network overhead during long jobs | Implement exponential backoff for completed jobs, cap max concurrent polls |
| Gatherly API timeout during progress display | Medium | Progress stuck at "content_fetching" stage | Add explicit timeout handling, fallback to existing content, update UI with timeout message |
| User cancels during email send | Low | Partial email delivery or duplicate sends | Implement idempotent email sending, track email job ID separately |

---

## References

- [Rainpipe Tech Steering](file:///.kiro/steering/tech.md) — Current technology stack and patterns
- [Rainpipe Structure & Organization](file:///.kiro/steering/structure.md) — Service architecture and data flow
- [Design Principles](file:///.kiro/settings/rules/design-principles.md) — Technical design standards
- [Ruby Threading Guide](https://ruby-doc.org/core/Thread.html) — Ruby Thread documentation for background jobs
- [Sinatra Framework](http://sinatrarb.com/) — Web framework patterns and routing
- [SQLite Concurrency](https://www.sqlite.org/draft/wal.html) — Write-Ahead Logging for concurrent writes
- [HTTP Polling vs WebSocket](https://stackoverflow.com/questions/30965350/polling-websockets-or-server-sent-events-sse) — Design trade-offs
