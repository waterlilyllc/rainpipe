// CompletionPanel - Task 5.4: Job completion display
// Shows download link, email confirmation, and action buttons

class CompletionPanel {
  constructor(container) {
    this.container = container;
  }

  // Task 5.4: Update completion panel
  // @param progress [Object] Progress data from API
  // @param jobInfo [Object] Job info { send_to_kindle, kindle_email, pdf_path }
  // @param callbacks [Object] { onRefreshHistory, onGenerateAnother }
  update(progress, jobInfo, callbacks) {
    callbacks = callbacks || {};
    jobInfo = jobInfo || {};

    // Task 5.4: Build completion message based on delivery method
    let contentHtml = `
      <div class="completion-panel card border-success" style="background-color: #d4edda;">
        <div class="card-body">
          <h5 class="card-title text-success">
            <i class="bi bi-check-circle"></i> PDF Generation Complete
          </h5>
          <p class="card-text">Your keyword-filtered PDF has been successfully generated.</p>
    `;

    // Task 5.4: Show download link if not sending to Kindle
    if (!jobInfo.send_to_kindle && jobInfo.pdf_path) {
      contentHtml += `
        <div class="download-section mb-3">
          <a href="${this._escapeHtml(jobInfo.pdf_path)}"
             class="download-link btn btn-primary"
             download>
            <i class="bi bi-download"></i> Download PDF
          </a>
          <small class="d-block mt-2 text-muted">
            Click to download your PDF file
          </small>
        </div>
      `;
    }

    // Task 5.4: Show email confirmation if sent to Kindle
    if (jobInfo.send_to_kindle && jobInfo.kindle_email) {
      contentHtml += `
        <div class="email-section mb-3">
          <p class="email-message text-success">
            <i class="bi bi-envelope-check"></i>
            Email sent to <strong>${this._escapeHtml(jobInfo.kindle_email)}</strong>
          </p>
          <small class="text-muted">
            Your PDF will arrive on your Kindle device shortly.
          </small>
        </div>
      `;
    }

    // Task 5.4: Action buttons
    contentHtml += `
      <div class="button-group">
        <button class="refresh-history-btn btn btn-secondary btn-sm me-2">
          <i class="bi bi-arrow-repeat"></i> Refresh History
        </button>
        <button class="generate-another-btn btn btn-primary btn-sm">
          <i class="bi bi-plus-circle"></i> Generate Another PDF
        </button>
      </div>
    </div>
    </div>
    `;

    this.container.innerHTML = contentHtml;

    // Task 5.4: Attach button click handlers
    const refreshBtn = this.container.querySelector('.refresh-history-btn');
    const anotherBtn = this.container.querySelector('.generate-another-btn');

    if (refreshBtn && callbacks.onRefreshHistory) {
      refreshBtn.addEventListener('click', callbacks.onRefreshHistory);
    }

    if (anotherBtn && callbacks.onGenerateAnother) {
      anotherBtn.addEventListener('click', callbacks.onGenerateAnother);
    }
  }

  // Escape HTML special characters
  _escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }
}

// Export for Node.js/module testing
if (typeof module !== 'undefined' && module.exports) {
  module.exports = CompletionPanel;
}
