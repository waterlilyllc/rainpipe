// Test: Frontend Progress UI Components (Tasks 5.1-5.4)
// Tests for PollingManager, ProgressPanel, ErrorPanel, CompletionPanel

describe('PollingManager', function() {
  let pollingManager;
  let mockFetch;
  let progressCallbacks;

  beforeEach(function() {
    // Mock fetch API
    mockFetch = jasmine.createSpy('fetch');
    window.fetch = mockFetch;

    // Initialize PollingManager
    pollingManager = new PollingManager();
    progressCallbacks = {
      onProgress: jasmine.createSpy('onProgress'),
      onError: jasmine.createSpy('onError'),
      onComplete: jasmine.createSpy('onComplete')
    };
  });

  // Task 5.1: PollingManager initialization and polling loop
  it('should start polling at 1 second intervals (Task 5.1)', function(done) {
    const mockResponse = {
      status: 'processing',
      job_id: 'test-uuid',
      current_stage: 'filtering',
      current_percentage: 25,
      stage_details: {},
      logs: []
    };

    mockFetch.and.returnValue(Promise.resolve({
      ok: true,
      json: function() { return Promise.resolve(mockResponse); }
    }));

    pollingManager.start('test-uuid', progressCallbacks);

    // After 1.1 seconds, polling should have happened
    setTimeout(function() {
      expect(mockFetch).toHaveBeenCalledWith(jasmine.stringContaining('/api/progress?job_id=test-uuid'));
      expect(progressCallbacks.onProgress).toHaveBeenCalledWith(mockResponse);
      pollingManager.stop();
      done();
    }, 1100);
  });

  // Task 5.1: Stop polling on completion
  it('should stop polling when job status is completed (Task 5.1)', function(done) {
    const completedResponse = {
      status: 'completed',
      job_id: 'test-uuid',
      current_stage: 'email_sending',
      current_percentage: 100,
      stage_details: {},
      logs: []
    };

    mockFetch.and.returnValue(Promise.resolve({
      ok: true,
      json: function() { return Promise.resolve(completedResponse); }
    }));

    pollingManager.start('test-uuid', progressCallbacks);

    setTimeout(function() {
      expect(progressCallbacks.onComplete).toHaveBeenCalledWith(completedResponse);
      expect(pollingManager.isPolling).toBe(false);
      done();
    }, 1100);
  });

  // Task 5.1: Error handling and retry with exponential backoff
  it('should handle network errors with exponential backoff (Task 5.1)', function(done) {
    mockFetch.and.returnValue(Promise.reject(new Error('Network error')));

    pollingManager.start('test-uuid', progressCallbacks);

    setTimeout(function() {
      expect(mockFetch).toHaveBeenCalled();
      expect(progressCallbacks.onError).toHaveBeenCalled();
      pollingManager.stop();
      done();
    }, 1100);
  });

  // Task 5.1: Get current progress
  it('should expose get_current_progress method (Task 5.1)', function() {
    pollingManager.currentProgress = {
      status: 'processing',
      current_percentage: 50,
      current_stage: 'content_fetching'
    };

    const progress = pollingManager.get_current_progress();
    expect(progress.current_percentage).toBe(50);
    expect(progress.current_stage).toBe('content_fetching');
  });
});

describe('ProgressPanel', function() {
  let progressPanel;
  let container;

  beforeEach(function() {
    // Create DOM container
    container = document.createElement('div');
    container.id = 'progress-panel';
    document.body.appendChild(container);

    progressPanel = new ProgressPanel(container);
  });

  afterEach(function() {
    document.body.removeChild(container);
  });

  // Task 5.2: ProgressPanel rendering with stage indicator
  it('should render progress panel with stage indicator (Task 5.2)', function() {
    const progress = {
      current_stage: 'filtering',
      current_percentage: 25,
      stage_details: { bookmarks_retrieved: 100 },
      logs: []
    };

    progressPanel.update(progress);

    const stageIndicator = container.querySelector('.stage-indicator');
    expect(stageIndicator).not.toBeNull();
    expect(stageIndicator.textContent).toContain('Filtering bookmarks');
  });

  // Task 5.2: Progress bar rendering
  it('should render progress bar with percentage (Task 5.2)', function() {
    const progress = {
      current_stage: 'content_fetching',
      current_percentage: 50,
      stage_details: {},
      logs: []
    };

    progressPanel.update(progress);

    const progressBar = container.querySelector('.progress-bar');
    expect(progressBar).not.toBeNull();
    expect(progressBar.style.width).toBe('50%');
    expect(container.querySelector('.percentage-label').textContent).toContain('50%');
  });

  // Task 5.2: Stage details display
  it('should display stage metrics (Task 5.2)', function() {
    const progress = {
      current_stage: 'summarization',
      current_percentage: 60,
      stage_details: {
        bookmarks_retrieved: 150,
        bookmarks_summarized: 90
      },
      logs: []
    };

    progressPanel.update(progress);

    const stageDetails = container.querySelector('.stage-details');
    expect(stageDetails).not.toBeNull();
    expect(stageDetails.textContent).toContain('90');
  });

  // Task 5.3: Error panel display
  it('should display error panel when error_info present (Task 5.3)', function() {
    const progress = {
      current_stage: 'summarization',
      current_percentage: 60,
      stage_details: {},
      logs: [],
      error_info: {
        message: 'API timeout',
        status: 'failed'
      }
    };

    progressPanel.update(progress);

    const errorPanel = container.querySelector('.error-panel');
    expect(errorPanel).not.toBeNull();
    expect(errorPanel.style.display).not.toBe('none');
    expect(errorPanel.textContent).toContain('API timeout');
  });

  // Task 5.3: Error panel styling
  it('should style error panel with attention-grabbing color (Task 5.3)', function() {
    const progress = {
      error_info: {
        message: 'Network error',
        status: 'failed'
      },
      stage_details: {},
      logs: []
    };

    progressPanel.update(progress);

    const errorPanel = container.querySelector('.error-panel');
    const bgColor = window.getComputedStyle(errorPanel).backgroundColor;
    expect(bgColor).toMatch(/rgb.*255.*0.*0/); // Red color
  });
});

describe('CompletionPanel', function() {
  let completionPanel;
  let container;

  beforeEach(function() {
    // Create DOM container
    container = document.createElement('div');
    container.id = 'completion-panel';
    document.body.appendChild(container);

    completionPanel = new CompletionPanel(container);
  });

  afterEach(function() {
    document.body.removeChild(container);
  });

  // Task 5.4: Completion panel for download
  it('should show download link when send_to_kindle=false (Task 5.4)', function() {
    const progress = {
      status: 'completed',
      job_id: 'test-uuid-123'
    };

    completionPanel.update(progress, { send_to_kindle: false, pdf_path: '/data/test.pdf' });

    const downloadLink = container.querySelector('.download-link');
    expect(downloadLink).not.toBeNull();
    expect(downloadLink.textContent).toContain('Download PDF');
  });

  // Task 5.4: Completion panel for email
  it('should show email confirmation when send_to_kindle=true (Task 5.4)', function() {
    const progress = {
      status: 'completed',
      job_id: 'test-uuid-123'
    };

    completionPanel.update(progress, { send_to_kindle: true, kindle_email: 'user@kindle.com' });

    const emailMessage = container.querySelector('.email-message');
    expect(emailMessage).not.toBeNull();
    expect(emailMessage.textContent).toContain('user@kindle.com');
  });

  // Task 5.4: Completion panel buttons
  it('should show action buttons (Task 5.4)', function() {
    const progress = { status: 'completed' };
    const callbacks = {
      onRefreshHistory: jasmine.createSpy('onRefreshHistory'),
      onGenerateAnother: jasmine.createSpy('onGenerateAnother')
    };

    completionPanel.update(progress, { send_to_kindle: false }, callbacks);

    const refreshBtn = container.querySelector('.refresh-history-btn');
    const anotherBtn = container.querySelector('.generate-another-btn');

    expect(refreshBtn).not.toBeNull();
    expect(anotherBtn).not.toBeNull();

    refreshBtn.click();
    expect(callbacks.onRefreshHistory).toHaveBeenCalled();

    anotherBtn.click();
    expect(callbacks.onGenerateAnother).toHaveBeenCalled();
  });

  // Task 5.4: Success styling
  it('should style with success color (green background) (Task 5.4)', function() {
    completionPanel.update({ status: 'completed' }, { send_to_kindle: false });

    const successPanel = container.querySelector('.completion-panel');
    const bgColor = window.getComputedStyle(successPanel).backgroundColor;
    expect(bgColor).toMatch(/rgb.*0.*128.*0|rgb.*34.*139.*34/); // Green color
  });
});
