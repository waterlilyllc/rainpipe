// FormIntegration - Task 7.1, 7.2, 7.3: AJAX form submission and progress tracking
// Integrates form submission with progress polling and panel display

class FormIntegration {
  constructor(options) {
    this.formSelector = options.formSelector || '#filtered-pdf-form';
    this.progressPanelSelector = options.progressPanelSelector || '#progress-panel';
    this.completionPanelSelector = options.completionPanelSelector || '#completion-panel';
    this.errorPanelSelector = options.errorPanelSelector || '#form-error-panel';

    this.form = document.querySelector(this.formSelector);
    this.progressPanel = document.querySelector(this.progressPanelSelector);
    this.completionPanel = document.querySelector(this.completionPanelSelector);
    this.errorPanel = document.querySelector(this.errorPanelSelector);

    this.pollingManager = null;
    this.currentJobId = null;

    this._attachFormHandler();
    this._checkResumeParameter();
  }

  // Task 7.1: Intercept form submit event with AJAX
  _attachFormHandler() {
    if (!this.form) {
      console.error('Form not found:', this.formSelector);
      return;
    }

    this.form.addEventListener('submit', (e) => {
      e.preventDefault();
      this._submitFormAjax();
    });
  }

  // Task 7.1: Submit form via AJAX
  _submitFormAjax() {
    // Task 7.1: Extract form values
    const keywords = this.form.querySelector('[name="keywords"]')?.value || '';
    const date_start = this.form.querySelector('[name="date_start"]')?.value || '';
    const date_end = this.form.querySelector('[name="date_end"]')?.value || '';
    const send_to_kindle = this.form.querySelector('[name="send_to_kindle"]')?.checked || false;
    const kindle_email = this.form.querySelector('[name="kindle_email"]')?.value || '';

    // Basic validation
    if (!keywords.trim()) {
      this._showError('Keywords are required');
      return;
    }

    // Task 7.1: Send AJAX POST to /filtered_pdf/generate
    const formData = new FormData();
    formData.append('keywords', keywords);
    formData.append('date_start', date_start);
    formData.append('date_end', date_end);
    formData.append('send_to_kindle', send_to_kindle);
    formData.append('kindle_email', kindle_email);

    fetch('/filtered_pdf/generate', {
      method: 'POST',
      body: formData
    })
      .then(response => {
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}`);
        }
        return response.json();
      })
      .then(data => {
        // Task 7.1: Parse response
        if (data.error) {
          this._showError(data.error);
          return;
        }

        if (!data.job_id) {
          this._showError('No job_id in response');
          return;
        }

        // Task 7.1: Success - hide form, show progress
        this.currentJobId = data.job_id;
        this._hideForm();
        this._showProgress();

        // Task 7.1: Start polling with job_id
        this._startPolling(data.job_id, {
          send_to_kindle: send_to_kindle,
          kindle_email: kindle_email
        });
      })
      .catch(error => {
        console.error('Form submission error:', error);
        this._showError(`Error: ${error.message}`);
      });
  }

  // Task 7.1: Hide form
  _hideForm() {
    if (this.form) {
      this.form.style.display = 'none';
    }
  }

  // Task 7.1: Show progress panel
  _showProgress() {
    if (this.progressPanel) {
      this.progressPanel.style.display = 'block';
    }
  }

  // Task 7.1: Show error in error panel
  _showError(message) {
    if (this.errorPanel) {
      const errorMessage = this.errorPanel.querySelector('.error-message') || this.errorPanel;
      errorMessage.textContent = message;
      this.errorPanel.style.display = 'block';
    } else {
      alert(`Error: ${message}`);
    }
  }

  // Task 7.1: Start polling
  _startPolling(jobId, jobInfo) {
    this.pollingManager = new PollingManager();
    this.pollingManager.start(jobId, {
      onProgress: (progress) => {
        this._onProgressUpdate(progress);
      },
      onError: (error) => {
        console.error('Polling error:', error);
      },
      onComplete: (progress) => {
        this._onJobComplete(progress, jobInfo);
      }
    });
  }

  // Task 7.1: Handle progress update
  _onProgressUpdate(progress) {
    // Update ProgressPanel
    const progressPanel = new ProgressPanel(
      document.querySelector(this.progressPanelSelector)
    );
    progressPanel.update(progress);
  }

  // Task 7.1: Handle job completion
  _onJobComplete(progress, jobInfo) {
    // Hide progress panel, show completion panel
    if (this.progressPanel) {
      this.progressPanel.style.display = 'none';
    }

    if (this.completionPanel) {
      const completionPanel = new CompletionPanel(this.completionPanel);
      completionPanel.update(progress, jobInfo, {
        onRefreshHistory: () => this._refreshHistory(),
        onGenerateAnother: () => this._generateAnother()
      });
    }
  }

  // Task 7.4: Refresh history table
  _refreshHistory() {
    // Reload the page or refresh the history section
    window.location.hash = '#history';
    location.reload();
  }

  // Task 7.4: Return to form
  _generateAnother() {
    this.currentJobId = null;
    if (this.form) {
      this.form.style.display = 'block';
      this.form.reset();
    }
    if (this.progressPanel) {
      this.progressPanel.style.display = 'none';
    }
    if (this.completionPanel) {
      this.completionPanel.style.display = 'none';
    }
    this._hideError();
  }

  // Task 7.1: Hide error panel
  _hideError() {
    if (this.errorPanel) {
      this.errorPanel.style.display = 'none';
    }
  }

  // Task 7.3: Check for resume parameter in URL
  _checkResumeParameter() {
    const params = new URLSearchParams(window.location.search);
    const resumeJobId = params.get('resume');

    if (resumeJobId) {
      this._resumeMonitoring(resumeJobId);
    }
  }

  // Task 7.3: Resume monitoring for page reload
  _resumeMonitoring(jobId) {
    // Task 7.3: Query /api/progress to restore last known state
    fetch(`/api/progress?job_id=${encodeURIComponent(jobId)}`)
      .then(response => {
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}`);
        }
        return response.json();
      })
      .then(progress => {
        // Task 7.3: Skip form display, show progress
        this.currentJobId = jobId;
        this._hideForm();
        this._showProgress();

        // Task 7.3: Restore progress display
        const progressPanel = new ProgressPanel(
          document.querySelector(this.progressPanelSelector)
        );
        progressPanel.update(progress);

        // Task 7.3: Start polling if still processing
        if (progress.status === 'processing') {
          this._startPolling(jobId, {});
        } else if (progress.status === 'completed') {
          this._onJobComplete(progress, {});
        }
      })
      .catch(error => {
        console.error('Resume monitoring error:', error);
        // If error, just show the form normally
      });
  }
}

// Export for Node.js/module testing
if (typeof module !== 'undefined' && module.exports) {
  module.exports = FormIntegration;
}
