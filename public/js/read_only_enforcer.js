// ReadOnlyEnforcer - Task 6.3: Completed Job Protection
// Enforces read-only mode for completed/failed/cancelled jobs per Requirement 7.5

class ReadOnlyEnforcer {
  constructor(container) {
    this.container = container;
    this.currentJobStatus = null;
  }

  // Task 6.3: Enforce read-only mode for completed/failed/cancelled jobs
  // @param status [String] Job status: pending, processing, completed, failed, cancelled
  enforceReadOnly(status) {
    this.currentJobStatus = status;

    // Task 6.3: Determine if job can be modified
    const isReadOnly = this._isReadOnlyStatus(status);

    if (isReadOnly) {
      this._hideActionButtons();
      this._hideProgressPanel();
      this._showViewOnlyLabel();
    } else {
      this._showActionButtons();
      this._showProgressPanel();
      this._hideViewOnlyLabel();
    }
  }

  // Determine if status is read-only
  _isReadOnlyStatus(status) {
    const readOnlyStatuses = ['completed', 'failed', 'cancelled'];
    return readOnlyStatuses.includes(status);
  }

  // Task 6.3: Hide cancel button when viewing completed/failed/cancelled jobs
  _hideActionButtons() {
    // Task 6.3: Hide cancel button
    const cancelBtn = this.container.querySelector('.cancel-job-btn');
    if (cancelBtn) {
      cancelBtn.style.display = 'none';
      cancelBtn.disabled = true;
    }

    // Task 6.3: Hide generate button and retry button
    const generateBtn = this.container.querySelector('.generate-another-btn');
    if (generateBtn) {
      generateBtn.style.display = 'none';
      generateBtn.disabled = true;
    }

    const retryBtn = this.container.querySelector('.retry-btn');
    if (retryBtn) {
      retryBtn.style.display = 'none';
      retryBtn.disabled = true;
    }
  }

  // Task 6.3: Show action buttons for active jobs
  _showActionButtons() {
    const cancelBtn = this.container.querySelector('.cancel-job-btn');
    if (cancelBtn) {
      cancelBtn.style.display = 'inline-block';
      cancelBtn.disabled = false;
    }

    const generateBtn = this.container.querySelector('.generate-another-btn');
    if (generateBtn) {
      generateBtn.style.display = 'inline-block';
      generateBtn.disabled = false;
    }

    const retryBtn = this.container.querySelector('.retry-btn');
    if (retryBtn) {
      retryBtn.style.display = 'inline-block';
      retryBtn.disabled = false;
    }
  }

  // Task 6.3: Hide progress panel for historical jobs
  _hideProgressPanel() {
    const progressPanel = this.container.querySelector('.progress-panel');
    if (progressPanel) {
      progressPanel.style.display = 'none';
    }
  }

  // Task 6.3: Show progress panel for active jobs
  _showProgressPanel() {
    const progressPanel = this.container.querySelector('.progress-panel');
    if (progressPanel) {
      progressPanel.style.display = 'block';
    }
  }

  // Task 6.3: Display "View only" label for historical jobs
  _showViewOnlyLabel() {
    // Remove existing label if present
    const existingLabel = this.container.querySelector('.view-only-label');
    if (existingLabel) {
      existingLabel.remove();
    }

    // Create "View only" badge
    const label = document.createElement('div');
    label.className = 'view-only-label badge badge-secondary';
    label.style.cssText = `
      display: inline-block;
      margin-bottom: 10px;
      padding: 6px 12px;
      background-color: #6c757d;
      color: white;
      border-radius: 4px;
      font-size: 12px;
      font-weight: bold;
    `;
    label.textContent = '🔒 View only - Job already completed';

    // Insert at beginning of container
    this.container.insertBefore(label, this.container.firstChild);
  }

  // Task 6.3: Hide "View only" label
  _hideViewOnlyLabel() {
    const label = this.container.querySelector('.view-only-label');
    if (label) {
      label.remove();
    }
  }

  // Task 6.3.4: Check if job can be regenerated
  // Requirement 7.5: "The Web Application shall NOT regenerate or reprocess completed jobs"
  canRegenerate(status) {
    return !this._isReadOnlyStatus(status);
  }

  // Task 6.3: Get current job status
  getJobStatus() {
    return this.currentJobStatus;
  }

  // Task 6.3: Check if currently in read-only mode
  isReadOnly() {
    return this._isReadOnlyStatus(this.currentJobStatus);
  }
}

// Export for Node.js/module testing
if (typeof module !== 'undefined' && module.exports) {
  module.exports = ReadOnlyEnforcer;
}
