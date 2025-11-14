// LogPanel - Task 6.1: Real-time execution log display UI
// Displays execution logs with auto-scroll and performance optimization for large log sets

class LogPanel {
  constructor(container) {
    this.container = container;
    this.logs = [];
    this._render();
  }

  // Task 6.1: Initialize HTML structure
  _render() {
    this.container.innerHTML = `
      <div class="log-panel card">
        <div class="card-body">
          <h5 class="card-title">Execution Logs</h5>

          <!-- Task 6.1: Scrollable log container with monospace font -->
          <div class="log-container sticky-bottom" style="
            max-height: 400px;
            overflow-y: auto;
            background-color: #f8f9fa;
            border: 1px solid #dee2e6;
            border-radius: 4px;
            padding: 10px;
            font-family: 'Courier New', monospace;
            font-size: 12px;
            line-height: 1.5;
          ">
            <table class="log-entries" style="width: 100%; border-collapse: collapse;">
              <tbody>
                <!-- Dynamically populated -->
              </tbody>
            </table>
          </div>

          <small class="text-muted mt-2 d-block">
            Latest logs shown first. Auto-scrolls to bottom.
          </small>
        </div>
      </div>
    `;

    this.logContainer = this.container.querySelector('.log-container');
    this.logEntries = this.container.querySelector('.log-entries tbody');
  }

  // Task 6.1: Update progress display with new logs
  // @param logs [Array] Array of log entries from API
  // Each entry: { timestamp, stage, message, event_type, percentage }
  update(logs) {
    this.logs = logs || [];
    this._renderLogs();
    this._autoScroll();
  }

  // Task 6.1: Render log entries in reverse chronological order (newest first)
  _renderLogs() {
    this.logEntries.innerHTML = '';

    // Sort logs by timestamp, newest first
    const sortedLogs = [...this.logs].sort((a, b) => {
      const timeA = new Date(a.timestamp || 0);
      const timeB = new Date(b.timestamp || 0);
      return timeB - timeA;  // Descending order (newest first)
    });

    // Render each log entry
    sortedLogs.forEach(log => {
      const row = document.createElement('tr');
      row.className = 'log-entry';
      row.style.cssText = 'border-bottom: 1px solid #e0e0e0; padding: 4px 0;';

      // Task 6.1: Display timestamp in ISO 8601 format, stage, and message
      const timestamp = log.timestamp || '';
      const stage = log.stage || 'unknown';
      const message = log.message || '';
      const eventType = log.event_type || 'info';

      // Color code by event type
      let rowColor = '#f8f9fa';
      if (eventType === 'error') rowColor = '#fff5f5';
      if (eventType === 'warning') rowColor = '#fffaf0';
      if (eventType === 'retry') rowColor = '#f0f7ff';

      row.style.backgroundColor = rowColor;

      row.innerHTML = `
        <td style="padding: 4px 8px; width: 180px; min-width: 180px;">
          <span class="log-timestamp" style="color: #666;">${this._escapeHtml(timestamp)}</span>
        </td>
        <td style="padding: 4px 8px; width: 120px; min-width: 120px;">
          <span class="log-stage" style="color: #0066cc; font-weight: bold;">${this._escapeHtml(stage)}</span>
        </td>
        <td style="padding: 4px 8px; flex: 1; word-break: break-word;">
          <span class="log-message" style="color: #333;">${this._escapeHtml(message)}</span>
        </td>
      `;

      this.logEntries.appendChild(row);
    });
  }

  // Task 6.1: Auto-scroll to bottom when new logs arrive (smooth scroll)
  _autoScroll() {
    // Use requestAnimationFrame for smooth scroll
    requestAnimationFrame(() => {
      this.logContainer.scrollTop = this.logContainer.scrollHeight;
    });
  }

  // Escape HTML special characters for security (XSS prevention)
  _escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  // Public method: Clear logs
  clear() {
    this.logs = [];
    this._renderLogs();
  }

  // Public method: Get current logs
  getLogs() {
    return this.logs;
  }
}

// Export for Node.js/module testing
if (typeof module !== 'undefined' && module.exports) {
  module.exports = LogPanel;
}
