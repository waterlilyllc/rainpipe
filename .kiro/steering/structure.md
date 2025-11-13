# Rainpipe - Structure & Organization

## Directory Layout

```
rainpipe/
├── .kiro/                           # Project specifications & steering
│   ├── steering/                    # Project memory & patterns
│   └── specs/                       # Feature specifications
├── app.rb                           # Sinatra web application
├── Gemfile                          # Ruby dependencies
├── .env                             # Environment variables (API keys, secrets)
├── data/                            # Generated PDFs and cache
├── CLAUDE.md                        # AI development guidelines
├── WINDOWS_ACCESS.md                # Documentation
└── *.rb                             # Service & utility files
```

## Service Architecture

### Core Services

#### 1. KeywordFilteredPDFService
**Responsibility**: Orchestrate the entire PDF generation pipeline
- Filter bookmarks by keywords and date range
- Detect missing summaries
- Fetch content via Gatherly API
- Generate bookmark summaries via GPT
- Coordinate all downstream services

**Key Methods**:
- `execute()`: Main orchestration method
- `filter_bookmarks_by_keywords_and_date()`: RaindropClient filtering
- `fetch_bookmarks_content_from_gatherly()`: Batch content fetching
- `generate_bookmark_summaries()`: GPT summarization loop

#### 2. GPTContentGenerator
**Responsibility**: All OpenAI GPT API interactions
- Generate overall summaries from bookmark collections
- Extract related keywords and topic clusters
- Generate analytical insights
- Summarize individual bookmark content

**Key Methods**:
- `generate_overall_summary()`: Create full PDF summary
- `extract_related_keywords()`: Topic extraction via GPTKeywordExtractor
- `generate_analysis()`: Generate insights section
- `generate_bookmark_summary()`: Summarize individual content
- `retry_with_backoff()`: Error handling with exponential backoff

#### 3. KeywordPDFGenerator
**Responsibility**: PDF rendering and layout
- Initialize Prawn document with Japanese fonts
- Render all PDF sections
- Handle memory-efficient batch processing
- Validate file size

**Key Methods**:
- `generate()`: Main PDF generation
- `render_bookmarks()`: Batch render bookmark details
- `add_header()`, `add_overall_summary()`, `add_analysis()`: Section rendering
- `strip_markdown()`: Remove formatting characters

#### 4. KindleEmailSender
**Responsibility**: Email delivery
- Configure SMTP settings
- Send PDF to Kindle email address
- Validate credentials and file size
- Handle email-specific errors

**Key Methods**:
- `send_pdf()`: Main email sending method
- `validate_credentials!()`: Check environment variables
- `configure_mail()`: SMTP setup

#### 5. RaindropClient
**Responsibility**: Raindrop.io API integration
- Fetch all bookmarks
- Filter by date range
- Handle API authentication

### Supporting Services

#### Gatherly Integration
- `GatherlyBatchFetcher`: Create batch jobs for content fetching
- `GatherlyJobPoller`: Poll job status until completion
- `GatherlyResultMerger`: Merge fetched content with bookmarks
- `GatherlyClient`: Low-level API wrapper
- `GatherlyTiming`: Performance measurement

#### Utility Services
- `ContentChecker`: Identify bookmarks without summaries
- `BookmarkSummaryGenerator`: Legacy summary generation
- `GPTKeywordExtractor`: Topic cluster extraction (used by GPTContentGenerator)

## Data Flow

```
Raindrop.io Bookmarks
        ↓
[KeywordFilteredPDFService.filter_bookmarks_by_keywords_and_date]
        ↓
Filtered Bookmarks (by keyword + date)
        ↓
[GatherlyBatchFetcher] → [GatherlyJobPoller] → [GatherlyResultMerger]
        ↓
Bookmarks with Content (from Gatherly API)
        ↓
[GPTContentGenerator.generate_bookmark_summary] (for each bookmark)
        ↓
Bookmarks with AI-Generated Summaries
        ↓
[GPTContentGenerator.generate_overall_summary]
[GPTContentGenerator.extract_related_keywords]
[GPTContentGenerator.generate_analysis]
        ↓
PDF Content (summaries + analysis + clusters)
        ↓
[KeywordPDFGenerator.generate]
        ↓
PDF File
        ↓
[KindleEmailSender.send_pdf]
        ↓
Kindle Device
```

## File Organization Patterns

### Service Files
- **Naming**: `{service_name}_service.rb`
- **Examples**: `keyword_filtered_pdf_service.rb`, `weekly_summary_generator.rb`

### Client Files
- **Naming**: `{api_name}_client.rb`
- **Examples**: `raindrop_client.rb`, `gatherly_client.rb`

### Test Files
- **Location**: Same directory as source
- **Naming**: `test_{module_name}.rb`
- **Example**: `test_keyword_filtered_pdf_service.rb`

### Utility/Helper Files
- **Purpose**: One-off scripts or utilities
- **Examples**: `debug_date_filter.rb`, `show_stats.rb`

## Configuration & Secrets

### Environment Variables (.env)
```
# Raindrop.io
RAINDROP_API_TOKEN=...

# OpenAI
OPENAI_API_KEY=...
GPT_MODEL=gpt-4o-mini

# Gmail
GMAIL_ADDRESS=...
GMAIL_APP_PASSWORD=...
KINDLE_EMAIL=...

# Gatherly API
GATHERLY_API_URL=...
GATHERLY_API_KEY=...
GATHERLY_CALLBACK_BASE_URL=...

# Other
NOTION_API_KEY=...
OBSIDIAN_VAULT_PATH=...
```

## Key Integration Points

### 1. Raindrop.io
- API token via `RAINDROP_API_TOKEN`
- Date range filtering (UTC-based)
- Returns bookmarks with title, URL, tags, excerpt

### 2. OpenAI GPT-4o-mini
- API key via `OPENAI_API_KEY`
- Retry logic with exponential backoff (3 max retries)
- Temperature: 0.7, Max tokens: 1500

### 3. Gatherly API
- Custom API for full article content fetching
- Batch job model (create → poll → retrieve)
- Timeout: 300 seconds per job

### 4. Gmail SMTP
- App-specific password (not main Gmail password)
- TLS on port 587
- File size limit: 25MB

## Naming Conventions

### Classes & Services
- PascalCase for class names
- `{Action}{Object}` pattern: `KeywordFilteredPDFService`, `GatherlyJobPoller`

### Methods
- snake_case for all methods
- Descriptive names: `fetch_bookmarks_content_from_gatherly`, `generate_bookmark_summary`

### Variables
- snake_case for local and instance variables
- `@` prefix for instance variables

### Constants
- UPPER_SNAKE_CASE for constants
- Example: `MAX_RETRIES`, `CHUNK_SIZE`, `FONT_CANDIDATES`

## Error Handling Pattern

- **No Dummy Data**: Errors are raised properly (not swallowed)
- **Retryable Errors**: Network timeouts use exponential backoff
- **Non-Retryable Errors**: Authentication, validation errors fail fast
- **Logging**: All errors logged with context-specific emoji indicators
