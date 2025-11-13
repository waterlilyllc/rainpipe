# Rainpipe - Technology Steering

## Technology Stack

### Core Framework
- **Language**: Ruby 3.x
- **Web Framework**: Sinatra (lightweight HTTP server)
- **PDF Generation**: Prawn (PDF library with Japanese font support)
- **Email**: Mail gem with Gmail SMTP

### APIs & External Services
- **Raindrop.io API**: Bookmark management and retrieval
- **OpenAI GPT-4o-mini**: Content summarization and analysis
- **Gatherly API**: Full article content fetching (custom, internal)
- **Gmail SMTP**: Email delivery via app-specific passwords

### Database
- **SQLite**: Historical generation records and cache
- **Obsidian Vault**: Integration with local Markdown notes

### Libraries & Tools
- `prawn`: PDF rendering with Japanese support (ipag.ttf)
- `mail`: SMTP email sending
- `json`: API response parsing
- `dotenv`: Environment variable management (API keys, credentials)

## Key Technical Decisions

### 1. Batch Processing for Content Fetching
- Gatherly API uses job-based batch processing
- GatherlyJobPoller: Polls job status until completion (300s timeout, exponential backoff)
- GatherlyResultMerger: Merges fetched content back to bookmarks by URL matching

### 2. Error Handling Strategy
- **No Fallback Data**: Errors are properly raised (normalized error handling)
- **Exponential Backoff**: GPT API retries with 1s, 2s, 4s delays
- **Graceful Degradation**: Missing content doesn't block PDF generation

### 3. PDF Generation Patterns
- Memory-efficient chunk processing (50 items per batch)
- Automatic page breaks and GC triggers
- Dynamic layout: box heights calculated based on content
- Markdown stripping: Remove formatting characters before rendering

### 4. Keyword Matching
- Case-insensitive matching: `.downcase` normalization
- Multi-field search: title, tags, excerpt combined
- OR logic: Match if ANY keyword matches ANY field

### 5. Date Range Handling
- UTC-based processing (ISO 8601 format)
- Default: Last 90 days from today
- Time range: 00:00:00 to 23:59:59 UTC

## Coding Conventions

### Service-Oriented Architecture
- Services handle single responsibility:
  - `KeywordFilteredPDFService`: Orchestration and filtering
  - `GPTContentGenerator`: GPT API calls (summary, analysis, keywords)
  - `KeywordPDFGenerator`: PDF rendering
  - `KindleEmailSender`: Email delivery
  - `GatherlyBatchFetcher`, `GatherlyJobPoller`, `GatherlyResultMerger`: Content fetching

### Method Organization
- Public methods first, private methods at end
- Clear responsibility separation with `private` keyword
- Instance variables for shared state within service

### Logging & Output
- `puts` for user-facing messages with emoji indicators:
  - `✅`: Success
  - `❌`: Error/Failure
  - `⚠️`: Warning
  - `🔍`: Info/Search
  - `📧`: Email operations

## Security Considerations
- API keys stored in `.env` file (never committed)
- Gmail app-specific passwords (not main password)
- Kindle email validation (format check only)
- No sensitive data logged

## Performance Patterns

### Memory Management
- Chunk processing with GC triggers (50-item chunks)
- Iterator pattern for large bookmark sets
- File streaming for PDF output

### API Optimization
- Batch job creation for Gatherly (multiple URLs per job)
- Job polling with exponential backoff
- Timeout handling (300s default)

### PDF Optimization
- Compress flag enabled
- Image-free rendering (text only)
- Margin-based layout (40px default)
