# Rainpipe - Product Steering

## Vision
Rainpipe is an intelligent bookmark management and PDF generation system that transforms curated bookmarks into actionable insights through AI-powered analysis and beautifully formatted PDF reports.

## Core Purpose
Enable users to:
1. **Filter bookmarks by keywords and date ranges** - Organize content from Raindrop.io
2. **Enrich content with AI analysis** - Generate summaries, extract insights using GPT-4o-mini
3. **Create professional PDF reports** - Format bookmark collections with summaries and analysis
4. **Deliver to Kindle** - Email PDFs to Kindle email addresses for reading

## Key Capabilities

### 1. Keyword-Based Filtering
- Filter bookmarks using keyword matching (case-insensitive)
- Support date range filtering (configurable defaults: last 90 days)
- Case-insensitive matching across title, tags, and excerpts

### 2. Content Enrichment
- **Gatherly API Integration**: Fetch full article content (batch processing with job polling)
- **GPT Summarization**: Convert raw content into concise 300-char summaries
- **Related Keywords**: Extract topic clusters using AI analysis
- **Analysis Generation**: Create insights and future outlook

### 3. PDF Generation
- Professional layout with Japanese font support
- Sections: header, overall summary, related topics, analysis, table of contents, bookmark details
- Dynamic sizing and Markdown formatting removal
- Memory-efficient batch processing (50-item chunks)

### 4. Email Delivery
- Gmail SMTP integration with app-specific passwords
- Send PDFs directly to Kindle email addresses
- File size validation (max 25MB)

## Value Proposition
Transform scattered bookmarks into focused, AI-analyzed PDF reports ready for consumption on Kindle devices.

## Technical Scope
- Language: Ruby
- Framework: Sinatra (web application)
- APIs: Raindrop.io, OpenAI GPT, Gatherly, Gmail
- Storage: SQLite, Obsidian vault integration
- Output: PDF (Prawn gem), Email (Mail gem)
