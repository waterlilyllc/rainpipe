# Research & Design Decisions - Keyword Filtered PDF

## Summary
- **Feature**: `keyword_filtered_pdf`
- **Discovery Scope**: Complex Integration (new UI + multiple existing systems)
- **Key Findings**:
  - Prawn is optimal for custom PDF generation with Japanese font support (NotoSansCJK)
  - Memory streaming approach essential for 1000+ bookmarks (compression + stream rendering)
  - Sinatra form-based pattern with background job tracking recommended for UX
  - Gatherly API v2.1 job polling with 5-minute timeout matches existing architecture
  - GPT Keyword Extractor already produces `related_clusters` structure needed for design

## Research Log

### PDF Generation Technology - Prawn
- **Context**: Need performant, font-aware PDF generation with Japanese support
- **Sources Consulted**:
  - GitHub: prawnpdf/prawn official repo
  - pdforge.com: Best Ruby PDF gems 2025 comparison
  - Stack Overflow: Prawn compression and large file handling
- **Findings**:
  - Prawn is fastest non-browser option for Ruby (no Chrome/wkhtmltopdf overhead)
  - Built-in CJK font support via NotoSansCJK-Regular.ttc (already configured in `weekly_pdf_generator.rb`)
  - `compress: true` option negligible overhead for files <10MB
  - Prawn does NOT support HTML-to-PDF; requires manual section layout
- **Implications**:
  - Use Prawn for PDF generation (proven pattern in codebase)
  - Leverage existing `WeeklyPDFGenerator` code as template
  - Manual section rendering (Overall Summary → Related Words → Analysis → Bookmarks)
  - File size <10MB acceptable for Kindle (existing limit is 25MB per `kindle_email_sender.rb`)

### Large File Handling & Memory Efficiency
- **Context**: Performance requirement: 1000 bookmarks processed in ≤10 seconds
- **Sources Consulted**:
  - DEV Community: Memory-efficient Ruby file handling
  - psdfkit.com: PDF generation memory profiles
  - Telerik: Stream processing efficiency
- **Findings**:
  - Streaming methods (`each_line`, `foreach`) preserve constant memory vs. `readlines` (memory scales with file size)
  - Chunk-based processing (4KB page sizes) optimal for large datasets
  - Prawn document buffering is incremental (not full tree in memory until render)
  - For 1000 items: ~100-200KB per bookmark content ≈ 100-200MB max (manageable with streaming)
- **Implications**:
  - Use chunked bookmark processing in PDF rendering loop
  - Process summaries in batches (50-100 items per batch) to limit memory
  - Implement progress tracking for user feedback
  - Archive completed PDF sections rather than holding all in memory

### Sinatra Form & Download Pattern
- **Context**: Need UI for keyword input + PDF generation + download/send options
- **Sources Consulted**:
  - Reintech.io: File downloads in Sinatra
  - Coderwall: File upload/download patterns
  - Treehouse: Saving text files with Sinatra
- **Findings**:
  - Sinatra `send_file` + `attachment` headers standard pattern
  - Content-Type: application/pdf required for browser PDF handling
  - Can serve dynamic content without pre-generation (inline Prawn rendering)
  - Form with `enctype="multipart/form-data"` required for file uploads (N/A for keyword input)
- **Implications**:
  - Create `/filtered_pdf` GET route to display keyword input form
  - Create `/filtered_pdf/generate` POST route to process request
  - Use `send_file` with `attachment` header for download
  - Support both download and background processing (Kindle) modes
  - Implement job tracking for async generation (progress polling via AJAX)

### Existing Codebase Patterns
- **Context**: Must align with established Rainpipe architecture
- **Sources Consulted**: Code analysis of existing implementations
- **Findings**:
  - `WeeklyPDFGenerator.rb`: PDF generation with font setup, section layout
  - `KindleEmailSender.rb`: SMTP integration, 25MB file limit, subject templating
  - `GPTKeywordExtractor.rb`: Produces `related_clusters` with `main_topic` + `related_words`
  - `WeeklySummaryGenerator.rb`: GPT-based full summary generation, keyword extraction pipeline
  - `RaindropClient.rb`: Date range filtering, bookmark loading
  - `BookmarkContentManager.rb`: Content enrichment (assumes summary field available)
  - `GatherlyClient.rb`: Job creation, status polling, result retrieval (v2.1 API)
  - `app.rb`: Sinatra routing patterns, template rendering (ERB)
- **Implications**:
  - Reuse `WeeklyPDFGenerator` as base class or shared utility
  - Follow same summary structure as `WeeklySummaryGenerator` (JSON with sections)
  - Leverage `GPTKeywordExtractor` for related words extraction
  - Use `GatherlyClient` for content fetching jobs (existing pattern)
  - Integrate via Sinatra routes in `app.rb` (no new controllers needed)
  - Store PDF generation history in database (SQLite, like weekly summaries)

### Gatherly API Integration
- **Context**: Fetch missing bookmark summaries before PDF generation
- **Sources Consulted**: `gatherly_client.rb` implementation + existing usage
- **Findings**:
  - API v2.1 supports bulk job creation via crawl_jobs endpoint
  - Job status endpoint returns { job_uuid, status, error } structure
  - Job result includes complete article content + metadata
  - Callback URL pattern enables async notifications (but polling also supported)
  - Timeout handling: 5-minute max per requirement (GatherlyClient timeout configurable)
- **Implications**:
  - Create batch fetch jobs for missing summaries (group by 10-20 URLs to avoid API abuse)
  - Poll job status every 2-3 seconds with 5-minute wall timeout
  - Continue PDF generation with "summary unavailable" mark for failed fetches
  - Log job IDs + results for audit trail

### GPT-based Content Generation
- **Context**: Need three GPT-generated sections (overall summary, related words, analysis)
- **Sources Consulted**: Existing `gpt_keyword_extractor.rb` + `weekly_summary_generator.rb`
- **Findings**:
  - GPT Keyword Extractor already produces `related_clusters` with correct schema
  - `WeeklySummaryGenerator` uses OpenAI gem (not direct HTTP) for stability
  - GPT-4o-mini is current model (ENV['GPT_MODEL'] fallback)
  - Prompt engineering for keyword context in req 3-1 (summary) and 3-3 (analysis)
  - No caching per requirement 3-3 (all analyses dynamically generated)
- **Implications**:
  - Use `OpenAI::Client` gem for GPT calls (consistency with `WeeklySummaryGenerator`)
  - Create specialized prompts for:
    - Overall Summary: "Summarize all filtered bookmarks in keyword context"
    - Related Words: Call `GPTKeywordExtractor.extract_keywords_from_bookmarks`
    - Analysis: "Provide actionable insights + best practices for keyword topic"
  - No caching layer needed (runtime generation acceptable for keyword-specific PDFs)

### Date Range Filtering & Timezone Handling
- **Context**: Default 3-month range with optional custom dates; UTC consistency
- **Sources Consulted**: `raindrop_client.rb` filtering patterns
- **Findings**:
  - Ruby Date class with `beginning_of_month` simplifies calculation
  - `Date.today` uses local time (UTC conversion needed for consistency)
  - SQLite stores timestamps as ISO8601 strings (compatible with Ruby DateTime)
  - Requirement 5.4 explicitly mandates UTC-based filtering
- **Implications**:
  - Default: 3 months back = `Date.today.prev_month(2)` to `Date.today`
  - Convert user input dates to UTC for filtering
  - Use `Time.now.utc.iso8601` for generation timestamp in reports
  - Filter bookmarks via `RaindropClient.get_bookmarks_by_date_range(start, end)`

### Concurrent PDF Generation Safeguards
- **Context**: Requirement 6.5 mandates concurrent execution limits with warnings
- **Sources Consulted**: Existing codebase job management patterns
- **Findings**:
  - SQLite lacks native locking; Ruby `File.lock` pattern used in some scripts
  - In-memory flag + database state check is preferred (race condition acceptable)
  - Graceful degradation: warn user rather than blocking
- **Implications**:
  - Track generation status in database table: `keyword_pdf_generations`
  - Columns: `id`, `status` (pending/processing/completed/failed), `keywords`, `created_at`, `updated_at`
  - Check for in-progress generations before starting; display warning
  - Cleanup completed records after 7 days (archive)

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Selected |
|--------|-------------|-----------|---------------------|----------|
| Monolithic Inline | All logic in single Sinatra route | Simple, minimal coupling | Hard to test, poor separation | ❌ |
| Service Class + Sinatra | Delegate to `KeywordFilteredPDFService` class | Clear boundaries, testable, reusable | Requires new file + interface | ✅ |
| Background Job Queue (Sidekiq) | Async processing with job tracking | Better UX (immediate response), scalable | Adds complexity, new dependency | Defer to Phase 2 |
| Database-Backed State Machine | Explicit state transitions with hooks | Auditability, recovery mechanism | Schema migrations, complexity | Future enhancement |

**Selected**: Service-oriented architecture with synchronous request-response for initial phase. Background job queueing deferred to Phase 2 once requirements stabilize.

## Design Decisions

### Decision: PDF Generation Service Layer
- **Context**: Multiple responsibilities (filtering, fetching, GPT calls, PDF render) need clear separation
- **Alternatives Considered**:
  1. Inline in Sinatra route — simple but untestable
  2. Service class + shared utilities — extensible and testable
  3. Command pattern with job queue — overkill for Phase 1
- **Selected Approach**: Create `KeywordFilteredPDFService` class encapsulating full workflow
- **Rationale**: Aligns with existing `WeeklySummaryGenerator` pattern; enables unit testing; clear interface for Sinatra routes
- **Trade-offs**: Adds one new file; requires mock/stub for external services during tests; slightly more boilerplate
- **Follow-up**: Verify service can complete typical workflow (100 bookmarks) in <10 seconds during spike testing

### Decision: Synchronous PDF Generation (Phase 1)
- **Context**: Requirement 6 specifies "immediate start" on button click; unclear if async polling acceptable
- **Alternatives Considered**:
  1. Pure synchronous (blocking request) — simple, matches requirement exactly
  2. Fire-and-forget with polling endpoint — better UX, requires AJAX
  3. Background job queue (Sidekiq) — scalable but adds dependency
- **Selected Approach**: Synchronous PDF generation with streaming progress updates via server-sent events (SSE) or polling
- **Rationale**: Meets requirement 6.2; keeps scope contained; enables immediate file download
- **Trade-offs**: Long-running requests (HTTP timeout risk); no database state machine needed yet
- **Follow-up**: Implement 30-second HTTP timeout + option to async in Phase 2 if needed

### Decision: Gather Missing Content Before PDF Generation
- **Context**: Requirement 2-1 requires all summaries present before PDF render
- **Alternatives Considered**:
  1. Batch create all fetch jobs + wait in parallel — complex polling logic
  2. Sequential fetch (one job per bookmark) — slow, too many API calls
  3. Group URLs in batches (10-20 per job) + single wait loop — simple, proven pattern
- **Selected Approach**: Group missing-summary bookmarks into batches of 15, create single job per batch, wait for all jobs via polling
- **Rationale**: Reduces API call overhead; single retry loop simpler than parallel handling; aligns with existing `fetch_bookmark_contents.rb` patterns
- **Trade-offs**: Slightly slower if some batches complete early; requires careful job result aggregation
- **Follow-up**: Monitor typical batch completion time; adjust batch size if performance unacceptable

### Decision: GPT Calls for Three Separate Sections
- **Context**: Requirements 3-1, 3-2, 3-3 each need GPT output; no caching allowed (3-3)
- **Alternatives Considered**:
  1. Single unified GPT call with multi-section prompt — efficient but risky token usage
  2. Three separate calls (current approach) — clear, modular, matches requirement
  3. Cache overall summary + analysis, regenerate only for new keywords — violates 3-3 constraint
- **Selected Approach**: Three separate GPT calls with dedicated prompts per section
- **Rationale**: Requirement 3-3 forbids caching; cleaner prompts per section; failure of one section doesn't block others
- **Trade-offs**: ~45-60 seconds additional latency (3 API calls × 15-20s each); ~3 API calls per PDF (cost consideration)
- **Follow-up**: Monitor actual call durations; consider prompt optimization if >60s unacceptable

### Decision: Database Table for Generation History
- **Context**: Requirement 6.4 requires tracking past PDF generation history
- **Alternatives Considered**:
  1. File-based logging only — simple but not queryable
  2. SQLite table `keyword_pdf_generations` — queryable, integrates with existing DB
  3. JSON log file with timestamp — semi-structured, harder to query
- **Selected Approach**: SQLite table with columns: `id`, `keywords`, `date_range_start`, `date_range_end`, `bookmark_count`, `status`, `pdf_path`, `created_at`, `updated_at`, `error_message`
- **Rationale**: Aligns with existing SQLite schema; enables UI to show generation history
- **Trade-offs**: Requires migration script; table cleanup logic needed
- **Follow-up**: Implement weekly cleanup (keep 30 days of history) to prevent table bloat

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Gatherly API timeout during batch fetch | Implement 5-min timeout + graceful fallback (render PDF with "summary unavailable" marker); log failure for manual retry |
| GPT API quota/rate limit exceeded | Implement exponential backoff + user-friendly error; cache section results in session (not db) for retry |
| PDF file >25MB (Kindle limit) | Pre-calculate file size during generation; warn user if threshold exceeded; implement compression or pagination |
| Keyword input validation bypass | Sanitize keywords input (remove SQL/JSON injection); validate against regex `^[a-zA-Z0-9\p{L}_\s,\-]*$` |
| Concurrent PDF generation conflicts | Track status in DB; warn user with "PDF generation in progress"; recommend waiting 5 minutes |
| Date range picker timezone confusion | Always display UTC in UI; convert user's local time to UTC server-side |
| Memory leak during large PDF generation | Implement garbage collection hints (`GC.start`) after each section render; monitor RSS memory during load test |

## References

- [Prawn GitHub Repository](https://github.com/prawnpdf/prawn) — Official documentation and examples
- [pdforge.com: Best Ruby PDF Gems 2025](https://pdforge.com/blog/best-ruby-on-rails-gems-for-pdf-generation-in-2025) — Gem comparison and recommendations
- [Ruby Prawn Documentation](https://rubydoc.info/gems/prawn/2.2.2/Prawn/Document) — Full API reference
- [Sinatra File Download Patterns](https://reintech.io/blog/handling-file-uploads-downloads-sinatra) — Form and response handling
- Existing Rainpipe code: `weekly_pdf_generator.rb`, `kindle_email_sender.rb`, `gpt_keyword_extractor.rb`
