# Implementation Tasks

## Progress Display on Filtered PDF

### Overview
Implement comprehensive progress reporting throughout the PDF generation pipeline by integrating the ProgressReporter utility into all service layers. Tasks are organized by service domain with parallel execution opportunity where applicable.

---

## Task Breakdown

- [ ] 1. Integrate progress reporting into KeywordFilteredPDFService (orchestrator)

- [ ] 1.1 (P) Add progress reporting for bookmark filtering stage
  - Report when Raindrop.io retrieval begins
  - Display count of bookmarks retrieved
  - Display count of bookmarks after filtering
  - Report filtering completion with summary emoji
  - _Requirements: 1.1, 1.2, 2.1, 2.2_

- [ ] 1.2 (P) Add progress reporting for content fetching stage
  - Report when Gatherly API job is created
  - Report job UUID and initial polling status
  - Pass ProgressReporter to GatherlyJobPoller for polling progress
  - Report content fetch completion or errors
  - _Requirements: 1.1, 1.2, 2.3_

- [ ] 1.3 (P) Add progress reporting for GPT summarization stage
  - Report summarization start with bookmark count
  - Pass ProgressReporter to GPTContentGenerator for per-bookmark progress
  - Report summarization completion or errors
  - _Requirements: 1.1, 1.2, 2.4_

- [ ] 1.4 (P) Add progress reporting for PDF generation stage
  - Report PDF generation start
  - Pass ProgressReporter to KeywordPDFGenerator for page/size reporting
  - Report PDF file size and completion
  - _Requirements: 1.1, 1.2, 2.5_

- [ ] 1.5 (P) Add progress reporting for email delivery stage
  - Report email send initiation with recipient
  - Pass ProgressReporter to KindleEmailSender for send status
  - Report email delivery success or failure with details
  - _Requirements: 1.1, 1.2, 1.3, 2.6_

- [ ] 1.6 Add error handling and reporting for all stages
  - Catch and report errors from each service with ProgressReporter.error
  - Display actionable error messages with context
  - Ensure error messages propagate without hiding root cause
  - _Requirements: 1.3_

---

- [ ] 2. Integrate progress reporting into GatherlyJobPoller (content fetching)

- [ ] 2.1 (P) Add polling progress reporting
  - Report job status on each polling attempt
  - Display attempt count and current status (processing/completed/failed)
  - Use counter format for readability (attempt N/max_attempts)
  - _Requirements: 1.2, 2.3_

- [ ] 2.2 (P) Add completion and timeout error reporting
  - Report when polling completes successfully
  - Report timeout with attempt count and duration
  - Report API errors with error details
  - _Requirements: 1.3_

---

- [ ] 3. Integrate progress reporting into GPTContentGenerator (summarization)

- [ ] 3.1 (P) Add per-bookmark progress reporting
  - Report current bookmark number and total count (counter format)
  - Display bookmark title in progress message
  - Use loop indicator emoji for processing state
  - _Requirements: 1.2, 2.4_

- [ ] 3.2 (P) Add overall summary and analysis progress
  - Report when overall summary generation starts
  - Report when keyword extraction starts
  - Report when analysis generation starts
  - Use consistent emoji indicators for each sub-task
  - _Requirements: 1.2, 2.4_

- [ ] 3.3 (P) Add GPT API error reporting
  - Catch and report API rate limits with details
  - Report authentication failures clearly
  - Report timeout errors with recovery guidance
  - _Requirements: 1.3_

---

- [ ] 4. Integrate progress reporting into KeywordPDFGenerator (PDF rendering)

- [ ] 4.1 (P) Add PDF generation stage reporting
  - Report PDF generation start
  - Report page count as pages are added (optional: per-page progress)
  - Report memory usage if approaching limits
  - _Requirements: 1.2, 2.5_

- [ ] 4.2 (P) Add PDF completion reporting
  - Report final file path
  - Report final file size in MB
  - Report PDF generation success or failure
  - _Requirements: 2.5_

- [ ] 4.3 (P) Add PDF size warning and error handling
  - Warn when PDF approaches 20MB threshold
  - Error when PDF exceeds 25MB Kindle limit
  - Suggest mitigation (fewer bookmarks, compression)
  - _Requirements: 1.3_

---

- [ ] 5. Integrate progress reporting into KindleEmailSender (email delivery)

- [ ] 5.1 (P) Add email send progress reporting
  - Report email send initiation with recipient address
  - Report attachment details (filename, size)
  - Use email indicator emoji for send operations
  - _Requirements: 1.2, 2.6_

- [ ] 5.2 (P) Add email delivery status reporting
  - Report successful send with confirmation
  - Report SMTP/auth failures with actionable guidance
  - Report retry attempts if applicable
  - _Requirements: 1.3, 2.6_

---

- [ ] 6. Integration and end-to-end testing

- [ ] 6.1 (P) Verify progress output order and consistency
  - Execute full filtered_pdf flow with test data
  - Verify all 5 stages report progress in correct sequence
  - Verify emoji indicators are consistent with design
  - Verify no progress messages are lost due to buffering
  - _Requirements: 1.1, 1.2, 3.1, 3.2, 3.3_

- [ ] 6.2 (P) Verify error reporting in all scenarios
  - Test Raindrop.io API timeout
  - Test Gatherly API timeout
  - Test GPT API rate limit
  - Test PDF size limit exceeded
  - Test email send failure
  - Verify error messages include actionable guidance
  - _Requirements: 1.3, 3.1_

- [ ] 6.3 * Unit test ProgressReporter message formatting
  - Test emoji prefix generation for all indicator types
  - Test counter format (n/m) edge cases (0/0, 1/1, current > total)
  - Test indented message formatting
  - Test error message with and without details
  - _Requirements: 3.1, 3.2, 3.3_

---

## Requirements Coverage Summary

| Requirement | Tasks |
|-------------|-------|
| 1.1 - Real-time progress visibility | 1.1, 1.2, 1.3, 1.4, 1.5, 6.1 |
| 1.2 - Progress status (start/in-progress/complete) | 1.1-1.5, 2.1-2.2, 3.1-3.2, 4.1-4.2, 5.1-5.2, 6.1 |
| 1.3 - Error visibility and cause | 1.6, 2.2, 3.3, 4.3, 5.2, 6.2 |
| 2.1 - Bookmark retrieval progress | 1.1 |
| 2.2 - Filtering results display | 1.1 |
| 2.3 - Gatherly polling progress | 1.2, 2.1-2.2 |
| 2.4 - GPT summarization progress | 1.3, 3.1-3.2 |
| 2.5 - PDF generation progress | 1.4, 4.1-4.3 |
| 2.6 - Email delivery status | 1.5, 5.1-5.2 |
| 3.1 - User-friendly emoji format | 1.1-1.5, 2.1-2.2, 3.1-3.3, 4.1-4.3, 5.1-5.2, 6.1-6.3 |
| 3.2 - Structured logging | 1.1-1.5, 2.1-2.2, 3.1-3.3, 4.1-4.3, 5.1-5.2 |
| 3.3 - Proper formatting (single/multi-line) | 1.1-1.5, 2.1-2.2, 3.1-3.3, 4.1-4.3, 5.1-5.2, 6.1-6.3 |

---

## Implementation Notes

- **ProgressReporter utility** is already implemented and available in `progress_reporter.rb`
- **Service integration** follows the architecture pattern from design.md with minimal breaking changes
- **Parallel execution** is safe for subtasks within different services (1.1-1.5, 2.1-2.2, 3.1-3.3, 4.1-4.3, 5.1-5.2) as they operate on independent service boundaries
- **Testing tasks** (6.3) marked as optional `*` since core implementation already covers acceptance criteria
- **Dependencies**: All subtasks within task groups can be executed in parallel; task groups should follow sequence 1→2→3→4→5→6 during testing/integration

---

**Phase**: tasks-generated
**Status**: Ready for implementation
**Next Action**: `/kiro:spec-impl progress_display_on_filtered_pdf`
