// PollingManager - Task 5.1: Real-time progress polling
// Polls /api/progress endpoint at 1 second intervals
// Handles network errors with exponential backoff

class PollingManager {
  constructor() {
    this.pollingInterval = 1000; // 1 second per Task 5.1
    this.isPolling = false;
    this.timerId = null;
    this.currentProgress = null;
    this.retryCount = 0;
    this.maxRetries = 10;
    this.retryDelays = [1000, 2000, 4000, 8000]; // Exponential backoff: 1s, 2s, 4s, 8s
    this.callbacks = null;
    this.jobId = null;
  }

  // Task 5.1: Start polling with job_id and callbacks
  // @param job_id [String] UUID of the job to poll
  // @param callbacks [Object] { onProgress, onError, onComplete }
  start(job_id, callbacks) {
    if (this.isPolling) {
      console.warn('Polling already in progress');
      return;
    }

    this.jobId = job_id;
    this.callbacks = callbacks || {};
    this.isPolling = true;
    this.retryCount = 0;

    // Start polling immediately
    this._poll();
  }

  // Stop polling
  stop() {
    if (this.timerId) {
      clearTimeout(this.timerId);
      this.timerId = null;
    }
    this.isPolling = false;
  }

  // Get current progress
  // @return [Object] Current progress object
  get_current_progress() {
    return this.currentProgress;
  }

  // Private: Polling loop
  _poll() {
    if (!this.isPolling) {
      return;
    }

    const url = `/api/progress?job_id=${encodeURIComponent(this.jobId)}`;

    // Task 5.1: Fetch progress from API
    fetch(url)
      .then(response => {
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}`);
        }
        return response.json();
      })
      .then(data => {
        // Task 5.1: Parse ProgressResponse JSON and validate schema
        this._validateProgressSchema(data);
        this.currentProgress = data;
        this.retryCount = 0; // Reset retry count on success

        // Task 5.1: Callback for new progress
        if (this.callbacks.onProgress) {
          this.callbacks.onProgress(data);
        }

        // Task 5.1: Stop polling when job completes
        if (data.status === 'completed' || data.status === 'failed' || data.status === 'cancelled') {
          this.isPolling = false;
          if (this.callbacks.onComplete) {
            this.callbacks.onComplete(data);
          }
          return;
        }

        // Task 5.1: Schedule next poll at 1 second interval
        this.timerId = setTimeout(() => this._poll(), this.pollingInterval);
      })
      .catch(error => {
        // Task 5.1: Handle network errors with exponential backoff
        this.retryCount++;

        if (this.callbacks.onError) {
          this.callbacks.onError(error);
        }

        if (this.retryCount >= this.maxRetries) {
          console.error(`Max retries (${this.maxRetries}) reached. Stopping polling.`);
          this.isPolling = false;
          return;
        }

        // Exponential backoff delay
        const delayIndex = Math.min(this.retryCount - 1, this.retryDelays.length - 1);
        const delay = this.retryDelays[delayIndex];

        console.log(`Retry ${this.retryCount}/${this.maxRetries} after ${delay}ms`, error.message);
        this.timerId = setTimeout(() => this._poll(), delay);
      });
  }

  // Task 5.1: Validate ProgressResponse JSON schema
  _validateProgressSchema(data) {
    const requiredFields = ['status', 'job_id', 'current_stage', 'current_percentage', 'stage_details', 'logs'];
    for (const field of requiredFields) {
      if (!(field in data)) {
        throw new Error(`Missing required field: ${field}`);
      }
    }
  }
}

// Export for Node.js/module testing
if (typeof module !== 'undefined' && module.exports) {
  module.exports = PollingManager;
}
