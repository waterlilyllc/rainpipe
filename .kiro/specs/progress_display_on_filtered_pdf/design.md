# Design Document - Progress Display on Filtered PDF

## Overview

This feature enhances the existing `filtered_pdf` execution by adding comprehensive progress reporting at each stage of the PDF generation pipeline. Users will see real-time updates for:
- Bookmark retrieval and filtering
- Content fetching from Gatherly API
- GPT-based summarization
- PDF generation
- Email delivery

**Target Users**: Users executing PDF generation via CLI or batch jobs who want visibility into long-running operations.

**Impact**: Transforms the filtered_pdf execution from a "black box" to an observable process with clear stage-based reporting.

### Goals
- Display real-time progress for each major stage (filtering, content fetch, GPT processing, PDF render, email send)
- Use consistent emoji-based indicators (✅, ❌, ⚠️, 🔍, 📧) already established in codebase
- Provide actionable error messages when stages fail
- Maintain compatibility with existing services (no breaking changes)

### Non-Goals
- Web UI or WebSocket-based progress dashboard
- Progress history persistence or database logging
- Custom progress bar graphics or terminal UI frameworks
- Mobile/API-level progress reporting

## Architecture

### Existing Architecture Analysis

The current system is organized as a service-oriented pipeline:
- `KeywordFilteredPDFService`: Main orchestrator
- `GatherlyBatchFetcher`, `GatherlyJobPoller`, `GatherlyResultMerger`: Content fetching
- `GPTContentGenerator`: Summarization and analysis
- `KeywordPDFGenerator`: PDF rendering
- `KindleEmailSender`: Email delivery

Each service already uses `puts` statements with emoji indicators. This feature standardizes and enhances this pattern.

### Architecture Pattern & Boundary Map

```
┌─────────────────────────────────────────────────────────────┐
│ KeywordFilteredPDFService (Orchestrator)                    │
│ - Progress Reporter (new): Tracks stage completion          │
│ - Calls each service and logs progress                      │
└──────────────────────────────┬──────────────────────────────┘
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
   ┌────▼────┐        ┌───────▼────────┐      ┌─────▼────┐
   │ Gatherly │        │ GPT Content    │      │ Keyword  │
   │ Fetcher  │        │ Generator      │      │ PDF      │
   │ (stages) │        │ (stages)       │      │ Generator│
   └──────────┘        └────────────────┘      │ (stages) │
                                               └──────────┘
                                                     │
                                               ┌─────▼────────┐
                                               │ Kindle Email │
                                               │ Sender       │
                                               │ (stages)     │
                                               └──────────────┘
```

**Key Decisions**:
- **Minimal Breaking Changes**: Enhance existing `puts` calls, don't refactor
- **Progress Reporter Pattern**: New utility class for consistent progress output formatting
- **Service-Level Logging**: Each service responsible for its own stage reporting
- **Stage-Based Structure**: Define clear milestones (start, in-progress, complete, error)

### Technology Stack

| Layer | Choice | Role |
|-------|--------|------|
| CLI Output | STDOUT via `puts` | Real-time progress display |
| Progress Tracking | ProgressReporter (new) | Standardize emoji/formatting |
| Error Display | STDERR via `puts` | Error visibility |
| State | In-Memory Counters | Track current/total for each stage |

## System Flows

### Overall Progress Flow

```
User executes send_final_pdf.rb
│
├─ [STAGE 1: FILTERING] ──────────────────┐
│  - 🔍 Raindrop.io から取得開始          │
│  - 📚 N件ブックマークをフィルタ          │
│  - ✅ フィルタリング完了                 │
│                                         │
├─ [STAGE 2: CONTENT FETCH] ──────────────┤
│  - 🌐 Gatherly API ジョブ作成            │
│  - ⏳ ジョブポーリング (N回)              │
│  - ✅ 本文取得完了                      │
│                                         │
├─ [STAGE 3: GPT SUMMARIZATION] ──────────┤
│  - 🔄 要約生成開始                      │
│  - [1/N] サマリー生成 (current)          │
│  - [N/N] サマリー生成 (complete)         │
│  - ✅ 要約生成完了                      │
│                                         │
├─ [STAGE 4: PDF GENERATION] ─────────────┤
│  - 📄 PDF生成開始                       │
│  - ✅ PDF生成完了                       │
│                                         │
└─ [STAGE 5: EMAIL SEND] ─────────────────┤
   - 📧 Kindle メール送信中                 │
   - ✅ メール送信成功                    │
```

## Components and Interfaces

### Summary Table

| Component | Domain | Intent | Requirements | Dependencies |
|-----------|--------|--------|--------------|--------------|
| ProgressReporter | Utility | Standardize progress output formatting | 3.1, 3.2, 3.3 | None |
| KeywordFilteredPDFService (enhanced) | Service | Add progress reporting calls at each stage | 1.1, 1.2, 1.3, 2.1-2.6 | ProgressReporter |
| GatherlyJobPoller (enhanced) | Service | Report polling progress | 2.3 | ProgressReporter |
| GPTContentGenerator (enhanced) | Service | Report summarization progress | 2.4 | ProgressReporter |
| KeywordPDFGenerator (enhanced) | Service | Report PDF generation progress | 2.5 | ProgressReporter |
| KindleEmailSender (enhanced) | Service | Report email send progress | 2.6 | ProgressReporter |

### New Component: ProgressReporter

#### ProgressReporter

| Field | Detail |
|-------|--------|
| Intent | Standardize progress output with consistent emoji indicators and formatting |
| Requirements | 3.1, 3.2, 3.3 |

**Responsibilities & Constraints**:
- Format progress messages with emoji prefixes (✅, ❌, ⚠️, 🔍, 📧, ⏳, 📚, 🔄, 📄)
- Support multi-line progress updates with proper indentation
- Provide counter methods for n-of-m stage reporting
- Maintain single responsibility: formatting only, no business logic

**Dependencies**:
- None (utility class)

**Contracts**: Service [ ]

##### Service Interface

```ruby
class ProgressReporter
  # Report progress with emoji indicator
  def self.progress(stage, message, indicator = :info)
    # indicator: :success, :error, :warning, :info, :email, :wait, :folder, :loop, :document
  end

  # Report counter-based progress (e.g., "5/10 items")
  def self.counter(stage, current, total, indicator = :info)
  end

  # Report multi-line indented output
  def self.indented(message, prefix = "  ")
  end

  # Report error with context
  def self.error(stage, message, details = nil)
  end
end
```

- **Preconditions**: Message is non-empty string
- **Postconditions**: Message printed to STDOUT/STDERR with timestamp (if enabled)
- **Invariants**: Emoji prefix always present; formatting consistent across calls

**Implementation Notes**:
- Integration: Use throughout existing services with minimal refactoring
- No database/file persistence of progress
- CLI-only output (no Web API)
- Backward compatible with existing `puts` calls

## Data Models

### Progress State (In-Memory)

```ruby
{
  stage: "filtering" | "gathering" | "gpt_summarization" | "pdf_generation" | "email_send",
  status: "started" | "in_progress" | "completed" | "failed",
  current_count: Integer,  # e.g., bookmark 5 of 10
  total_count: Integer,
  message: String,
  error: String | nil,  # error details if failed
  start_time: Time,
  end_time: Time | nil
}
```

**Consistency & Integrity**:
- No database persistence (in-memory only)
- Progress messages are informational, not authoritative
- No transaction boundaries needed
- Current implementation uses instance variables in services

## Error Handling

### Error Strategy

Progress reporting includes error visibility:

**User Errors** (validation):
- ❌ Invalid keyword format
- ❌ Invalid date range

**System Errors** (infrastructure):
- ⚠️ Gatherly API timeout
- ❌ GPT API rate limit / auth failure
- ⚠️ PDF generation memory issue
- ❌ Email send failure

### Error Categories and Responses

| Error Type | Message Format | Recovery |
|------------|---|---|
| Gatherly timeout | `⚠️ Gatherly API timeout after 300s` | Fail with explanation |
| GPT API error | `❌ GPT API error: rate_limit_exceeded` | Retry with backoff (existing) |
| PDF too large | `❌ PDF size exceeds 25MB limit` | Fail with size estimate |
| Email send fail | `❌ メール送信失敗: SMTP auth error` | Fail with auth guidance |

### Monitoring

Error tracking via console output only:
- Error messages printed with ❌ indicator
- Details include timestamp and context
- No external error tracking required

## Testing Strategy

### Unit Tests
- ProgressReporter message formatting (emoji, indentation, counters)
- Counter progression (edge cases: 0/0, 1/1, current > total)
- Error message formatting with details

### Integration Tests
- Filtering stage with progress reporting
- Gatherly polling loop progress (10+ iterations)
- GPT summarization loop with counter (5+ bookmarks)
- Full E2E flow with all stages reporting

### E2E/CLI Tests
- Verify CLI output order and completeness
- Verify no buffering delays (real-time display)
- Verify error messages include actionable guidance

## Supporting References

### Existing Patterns in Codebase

**Current emoji usage**:
```
✅ Success / completion
❌ Error / failure
⚠️ Warning
🔍 Search / info
📧 Email operations
⏳ Wait / polling
📚 Bookmark operations
🔄 Processing / loop
📄 PDF operations
```

**Current logging examples**:
```ruby
puts "✅ フィルタリング完了: #{@filtered_bookmarks.length} 件"
puts "⏳ ジョブ #{job_uuid} ステータス: processing（ポーリング #{attempt} 回）"
puts "  ✓ [#{idx + 1}/#{total}] サマリー生成: #{title[0..50]}..."
```

These patterns are already consistent; this feature standardizes them via ProgressReporter utility.

---

**Phase**: design-generated
**Status**: Ready for requirements approval
**Next Action**: `/kiro:spec-tasks progress_display_on_filtered_pdf`
