// ProgressPanel - Task 5.2: Real-time progress display UI
// Displays current stage, percentage bar, metrics, and errors

class ProgressPanel {
  constructor(container) {
    this.container = container;
    this.stageLabelMap = {
      'filtering': 'Filtering bookmarks',
      'content_fetching': 'Fetching content',
      'summarization': 'Generating summaries',
      'pdf_generation': 'Generating PDF',
      'email_sending': 'Sending to Kindle'
    };
    this._render();
  }

  // Task 5.2: Initialize HTML structure
  _render() {
    this.container.innerHTML = `
      <div class="progress-panel card">
        <div class="card-body">
          <h5 class="card-title">PDF Generation Progress</h5>

          <!-- Task 5.2: Stage indicator -->
          <div class="stage-indicator mb-3">
            <p class="stage-label">
              <span class="spinner-border spinner-border-sm me-2" role="status" aria-hidden="true"></span>
              <span class="stage-text">Initializing...</span>
            </p>
          </div>

          <!-- Task 5.2: Progress bar -->
          <div class="mb-3">
            <div class="progress">
              <div class="progress-bar progress-bar-animated bg-primary"
                   role="progressbar"
                   aria-valuenow="0"
                   aria-valuemin="0"
                   aria-valuemax="100"
                   style="width: 0%">
              </div>
            </div>
            <small class="percentage-label text-muted">0%</small>
          </div>

          <!-- Task 5.2: Stage details/metrics -->
          <div class="stage-details mb-3">
            <table class="table table-sm">
              <tbody>
                <!-- Dynamically populated -->
              </tbody>
            </table>
          </div>

          <!-- Task 5.3: Error panel (hidden by default) -->
          <div class="error-panel alert alert-danger" style="display: none;">
            <h6 class="alert-heading">Processing Error</h6>
            <p class="error-message"></p>
            <small class="error-timestamp"></small>
          </div>
        </div>
      </div>
    `;

    this.stageIndicator = this.container.querySelector('.stage-text');
    this.progressBar = this.container.querySelector('.progress-bar');
    this.percentageLabel = this.container.querySelector('.percentage-label');
    this.stageDetailsTable = this.container.querySelector('.stage-details tbody');
    this.errorPanel = this.container.querySelector('.error-panel');
    this.errorMessage = this.container.querySelector('.error-message');
    this.errorTimestamp = this.container.querySelector('.error-timestamp');
  }

  // Task 5.2: Update progress display
  // @param progress [Object] Progress data from API
  update(progress) {
    // Update stage indicator
    const stageName = this.stageLabelMap[progress.current_stage] || progress.current_stage;
    this.stageIndicator.textContent = stageName;

    // Update progress bar
    const percentage = Math.min(100, Math.max(0, progress.current_percentage || 0));
    this.progressBar.style.width = `${percentage}%`;
    this.progressBar.setAttribute('aria-valuenow', percentage);
    this.percentageLabel.textContent = `${percentage}%`;

    // Task 5.2: Update stage details metrics
    this._updateStageDetails(progress.stage_details);

    // Task 5.3: Update error panel if error present
    if (progress.error_info) {
      this._showError(progress.error_info, progress.logs);
    } else {
      this._hideError();
    }
  }

  // Task 5.2: Render stage-specific metrics
  _updateStageDetails(details) {
    this.stageDetailsTable.innerHTML = '';

    if (!details) {
      return;
    }

    // Display relevant metrics based on stage details
    const metricsToDisplay = [
      { key: 'keywords', label: 'Keywords' },
      { key: 'bookmark_count', label: 'Total Bookmarks' },
      { key: 'bookmarks_retrieved', label: 'Retrieved' },
      { key: 'bookmarks_with_content', label: 'With Content' },
      { key: 'bookmarks_summarized', label: 'Summarized' },
      { key: 'cluster_count', label: 'Topic Clusters' },
      { key: 'file_size_mb', label: 'File Size' },
      { key: 'page_count', label: 'Pages' }
    ];

    for (const metric of metricsToDisplay) {
      if (metric.key in details) {
        const row = document.createElement('tr');
        row.innerHTML = `
          <td class="fw-bold">${metric.label}</td>
          <td>${this._formatValue(details[metric.key], metric.key)}</td>
        `;
        this.stageDetailsTable.appendChild(row);
      }
    }
  }

  // Format metric values
  _formatValue(value, key) {
    if (key === 'file_size_mb') {
      return `${parseFloat(value).toFixed(2)} MB`;
    }
    return String(value);
  }

  // Task 5.3: Show error panel
  _showError(errorInfo, logs) {
    this.errorPanel.style.display = 'block';
    this.errorMessage.textContent = errorInfo.message || 'An error occurred';

    // Get latest log timestamp
    if (logs && logs.length > 0) {
      this.errorTimestamp.textContent = `Error at: ${logs[0].timestamp}`;
    }
  }

  // Task 5.3: Hide error panel
  _hideError() {
    this.errorPanel.style.display = 'none';
  }
}

// Export for Node.js/module testing
if (typeof module !== 'undefined' && module.exports) {
  module.exports = ProgressPanel;
}
