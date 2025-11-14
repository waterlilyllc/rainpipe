# Requirements Document

## Project Description (Input)
Web UI で filtered_pdf の進捗をリアルタイム表示する

## Requirements

### 1. Progress Display (進捗表示)
**1.1** When a user initiates a filtered PDF generation from the Web UI, the Web Application shall display real-time progress updates for each processing stage (filtering, content fetching, GPT summarization, PDF generation, email sending)

**1.2** While PDF generation is in progress, the Web Application shall update the progress display at least once per second to reflect the current stage and percentage completion

**1.3** When a user navigates to the `/filtered_pdf` page, the Web Application shall display the current status of any in-progress PDF generation job (if one exists)

**1.4** The Web Application shall display progress information in a user-friendly format with visual indicators (progress bars, stage completion status, percentage)

### 2. Stage-Based Reporting (ステージ別進捗報告)
**2.1** The Web Application shall display progress for the filtering stage, showing the number of bookmarks retrieved and the number of bookmarks after keyword/date filtering

**2.2** The Web Application shall display progress for the content fetching stage, showing the number of Gatherly API jobs, polling attempts, and completion status

**2.3** The Web Application shall display progress for the GPT summarization stage, showing the current bookmark number being summarized and the total number of bookmarks

**2.4** The Web Application shall display progress for the PDF generation stage, showing the page count, file size, and completion status

**2.5** The Web Application shall display progress for the email delivery stage, showing the email address, file size, and send status

### 3. Error Handling and Messages (エラー処理とメッセージ)
**3.1** If an error occurs during PDF generation, the Web Application shall display an error message with the error type, context, and suggested remediation steps

**3.2** When a user initiates PDF generation, the Web Application shall validate inputs (keywords, date range) and display validation error messages before starting the background job

**3.3** If a background PDF generation job fails, the Web Application shall preserve the error information and display it to the user with actionable guidance

### 4. Backend API Integration (バックエンド API 統合)
**4.1** The Web Application shall provide a REST API endpoint (`/api/progress`) that returns the current progress of a PDF generation job in JSON format

**4.2** The `/api/progress` endpoint shall return structured progress data including current stage, percentage completion, stage-specific details, and any error information

**4.3** The Web Application shall manage background PDF generation jobs using a job queue or background job system that persists job state

**4.4** The Web Application shall provide an endpoint to retrieve job status by job ID and return the complete progress information

### 5. Frontend Real-Time Update (フロントエンド リアルタイム更新)
**5.1** The Web UI shall use polling (recommended) or WebSocket (optional) to fetch progress updates from the backend API

**5.2** The Web UI shall automatically update the progress display without requiring user interaction while a job is in progress

**5.3** The Web UI shall allow users to cancel a running PDF generation job and display a confirmation message

**5.4** When PDF generation completes successfully, the Web UI shall display the download link and display a completion notification

### 6. Job Management (ジョブ管理)
**6.1** The Web Application shall track multiple concurrent PDF generation jobs and allow users to view the status of each job

**6.2** The Web Application shall store job metadata (job ID, status, start time, end time, error information) for historical reference

**6.3** When a user closes the browser or navigates away during PDF generation, the Web Application shall resume progress tracking when the user returns

### 7. Progress Log Display (進捗ログ表示)
**7.1** The Web Application shall display a log panel in the lower section of the `/filtered_pdf` page showing historical execution logs

**7.2** The progress log shall display log entries from each PDF generation job, showing timestamp, stage, and log message (e.g., "2025-11-14 10:30:45 [filtering] 50 bookmarks filtered")

**7.3** The progress log shall be automatically scrolled to show the latest log entries as new logs arrive during job execution

**7.4** The progress log shall display logs from previous job executions to provide historical context to the user

**7.5** The Web Application shall NOT regenerate or reprocess completed jobs; the log panel displays completed job logs for reference only

### 8. Non-Goals (スコープ外)
- Mobile app or native client progress display
- Real-time WebSocket is optional (polling is sufficient)
- Progress history or analytics dashboard
- External monitoring or alerting systems
