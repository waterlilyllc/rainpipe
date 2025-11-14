// HistorySelector - Task 6.2: View past job logs
// Dropdown selector for viewing historical PDF generation jobs and their logs

class HistorySelector {
  constructor(container) {
    this.container = container;
    this.jobs = [];
    this.logPanel = null;
    this.currentJobId = null;
    this._render();
  }

  // Task 6.2: Initialize dropdown element
  _render() {
    this.container.innerHTML = `
      <div class="history-selector-wrapper card mb-3">
        <div class="card-body">
          <label for="job-history-select" class="form-label">
            <i class="bi bi-clock-history"></i> Job History
          </label>

          <!-- Task 6.2: Dropdown showing recent PDF generation jobs -->
          <select class="history-selector form-select" id="job-history-select">
            <option value="">-- Select a job --</option>
          </select>

          <small class="text-muted d-block mt-2">
            Shows last 10 jobs. Format: keywords | date | status | bookmarks | duration
          </small>
        </div>
      </div>
    `;

    this.select = this.container.querySelector('.history-selector');
    this.select.addEventListener('change', (e) => this._onJobSelected(e));
  }

  // Task 6.2: Update dropdown with recent jobs
  // @param jobs [Array] Array of job records from database
  // Each job: { uuid, keywords, created_at, status, bookmark_count, duration_seconds }
  updateJobs(jobs) {
    this.jobs = jobs || [];

    // Task 6.2: Display last 10 jobs maximum
    const recentJobs = this.jobs.slice(0, 10);

    // Clear existing options (except placeholder)
    while (this.select.options.length > 1) {
      this.select.remove(1);
    }

    // Add job options
    recentJobs.forEach(job => {
      const option = document.createElement('option');
      option.value = job.uuid;

      // Task 6.2: Display in format: keywords | date | status | bookmark_count | duration
      const date = new Date(job.created_at).toLocaleDateString();
      const duration = Math.round(job.duration_seconds / 60) + 'm';
      const bookmarks = job.bookmark_count || 0;

      let label = `${this._escapeHtml(job.keywords)} | ${date} | ${job.status} | ${bookmarks} bookmarks | ${duration}`;

      // Task 6.2.3: Mark current job with "In Progress" label
      if (job.uuid === this.currentJobId) {
        label += ' (In Progress)';
        option.classList.add('current-job');
        option.style.fontWeight = 'bold';
        option.style.color = '#0066cc';
      }

      option.textContent = label;
      this.select.appendChild(option);
    });
  }

  // Task 6.2: Mark current job visually
  // @param jobId [String] Current job UUID
  markCurrentJob(jobId) {
    this.currentJobId = jobId;
    this.updateJobs(this.jobs);  // Refresh to apply highlighting
  }

  // Task 6.2: Set LogPanel to update when job is selected
  // @param logPanel [LogPanel] LogPanel instance to update
  setLogPanel(logPanel) {
    this.logPanel = logPanel;
  }

  // Task 6.2: Handle job selection change
  _onJobSelected(event) {
    const jobId = event.target.value;

    if (!jobId) {
      return;  // Placeholder selected
    }

    // Task 6.2: Fetch logs for selected job
    this._fetchJobLogs(jobId);
  }

  // Task 6.2: Fetch logs for selected job from API
  // @param jobId [String] Job UUID
  _fetchJobLogs(jobId) {
    fetch(`/api/logs/history?job_id=${encodeURIComponent(jobId)}`)
      .then(response => {
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}`);
        }
        return response.json();
      })
      .then(data => {
        // Task 6.2: Refresh LogPanel with selected job logs
        if (this.logPanel && data.logs) {
          this.logPanel.update(data.logs);
        }
      })
      .catch(error => {
        console.error('Failed to load job logs:', error);
        alert(`Failed to load logs for job ${jobId}: ${error.message}`);
      });
  }

  // Escape HTML special characters for security
  _escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }
}

// Export for Node.js/module testing
if (typeof module !== 'undefined' && module.exports) {
  module.exports = HistorySelector;
}
