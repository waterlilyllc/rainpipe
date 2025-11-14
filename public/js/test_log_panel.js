// Test suite for LogPanel - Task 6.1: Log Display
// Uses Jasmine for testing

describe('LogPanel - Task 6.1: Execution Log Display', () => {
  let container;
  let panel;

  beforeEach(() => {
    container = document.createElement('div');
    container.id = 'log-panel-container';
    document.body.appendChild(container);
    panel = new LogPanel(container);
  });

  afterEach(() => {
    document.body.removeChild(container);
  });

  // Task 6.1.1: HTML structure initialization
  describe('HTML Structure', () => {
    it('should create scrollable log container with proper classes', () => {
      const logContainer = container.querySelector('.log-container');
      expect(logContainer).toBeTruthy();
      expect(logContainer.classList.contains('log-container')).toBe(true);
    });

    it('should have log entries tbody for dynamic entry insertion', () => {
      const tbody = container.querySelector('.log-entries');
      expect(tbody).toBeTruthy();
    });

    it('should have monospace font styling for clarity', () => {
      const logContainer = container.querySelector('.log-container');
      const styles = window.getComputedStyle(logContainer);
      expect(logContainer.classList.contains('monospace')).toBe(true);
    });
  });

  // Task 6.1.2: Render log entries in reverse chronological order
  describe('Log Entry Rendering', () => {
    it('should render log entries in reverse chronological order (newest first)', () => {
      const logs = [
        { timestamp: '2025-01-01T10:00:00Z', stage: 'filtering', message: 'Started' },
        { timestamp: '2025-01-01T10:01:00Z', stage: 'content_fetching', message: 'Fetching' },
        { timestamp: '2025-01-01T10:02:00Z', stage: 'pdf_generation', message: 'Generating' }
      ];

      panel.update(logs);

      const entries = container.querySelectorAll('.log-entry');
      expect(entries.length).toBe(3);
      // Newest should be first
      expect(entries[0].textContent).toContain('2025-01-01T10:02:00Z');
      expect(entries[1].textContent).toContain('2025-01-01T10:01:00Z');
      expect(entries[2].textContent).toContain('2025-01-01T10:00:00Z');
    });

    it('should display timestamp in ISO 8601 format', () => {
      const logs = [
        { timestamp: '2025-01-01T10:00:00Z', stage: 'filtering', message: 'Test' }
      ];

      panel.update(logs);

      const entry = container.querySelector('.log-entry');
      const timestampEl = entry.querySelector('.log-timestamp');
      expect(timestampEl.textContent).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/);
    });

    it('should display stage and message for each entry', () => {
      const logs = [
        { timestamp: '2025-01-01T10:00:00Z', stage: 'filtering', message: 'Filtering bookmarks' }
      ];

      panel.update(logs);

      const entry = container.querySelector('.log-entry');
      expect(entry.textContent).toContain('filtering');
      expect(entry.textContent).toContain('Filtering bookmarks');
    });
  });

  // Task 6.1.3: Auto-scroll to bottom with smooth scroll
  describe('Auto-scroll Behavior', () => {
    it('should auto-scroll to bottom when new logs arrive', (done) => {
      const logs = [
        { timestamp: '2025-01-01T10:00:00Z', stage: 'filtering', message: 'Log 1' }
      ];

      panel.update(logs);
      const logContainer = container.querySelector('.log-container');

      // Simulate scrolled position
      logContainer.scrollTop = 0;

      // Add new logs
      logs.push({ timestamp: '2025-01-01T10:01:00Z', stage: 'content_fetching', message: 'Log 2' });
      panel.update(logs);

      // Check that auto-scroll happened (scrollTop should be at bottom)
      setTimeout(() => {
        expect(logContainer.scrollTop).toBeGreaterThan(0);
        done();
      }, 100);
    });

    it('should implement sticky bottom behavior with rapid arrivals', () => {
      const logContainer = container.querySelector('.log-container');
      expect(logContainer.classList.contains('sticky-bottom')).toBe(true);
    });
  });

  // Task 6.1.4: Performance with large log sets
  describe('Performance', () => {
    it('should handle 1000+ log entries efficiently', () => {
      const logs = [];
      for (let i = 0; i < 1000; i++) {
        logs.push({
          timestamp: new Date(Date.now() - i * 1000).toISOString(),
          stage: 'filtering',
          message: `Log entry ${i}`
        });
      }

      const startTime = performance.now();
      panel.update(logs);
      const endTime = performance.now();

      const entries = container.querySelectorAll('.log-entry');
      expect(entries.length).toBe(1000);
      // Should complete in reasonable time (< 500ms)
      expect(endTime - startTime).toBeLessThan(500);
    });
  });
});

describe('HistorySelector - Task 6.2: Viewing Past Job Logs', () => {
  let container;
  let selector;

  beforeEach(() => {
    container = document.createElement('div');
    container.id = 'history-container';
    document.body.appendChild(container);
    selector = new HistorySelector(container);
  });

  afterEach(() => {
    document.body.removeChild(container);
  });

  // Task 6.2.1: Dropdown showing recent jobs
  describe('History Dropdown', () => {
    it('should create dropdown element showing recent PDF generation jobs', () => {
      const select = container.querySelector('.history-selector');
      expect(select).toBeTruthy();
      expect(select.tagName).toBe('SELECT');
    });

    it('should display recent jobs in format: keywords | date | status | bookmark_count | duration', () => {
      const jobs = [
        {
          uuid: 'job-1',
          keywords: 'ruby',
          created_at: '2025-01-01T10:00:00Z',
          status: 'completed',
          bookmark_count: 25,
          duration_seconds: 120
        }
      ];

      selector.updateJobs(jobs);

      const option = container.querySelector('option[value="job-1"]');
      expect(option.textContent).toContain('ruby');
      expect(option.textContent).toContain('2025-01-01');
      expect(option.textContent).toContain('completed');
      expect(option.textContent).toContain('25');
      expect(option.textContent).toContain('120');
    });

    it('should display last 10 jobs maximum', () => {
      const jobs = [];
      for (let i = 0; i < 15; i++) {
        jobs.push({
          uuid: `job-${i}`,
          keywords: `keyword${i}`,
          created_at: new Date(Date.now() - i * 3600000).toISOString(),
          status: 'completed',
          bookmark_count: 10 + i,
          duration_seconds: 60 + i
        });
      }

      selector.updateJobs(jobs);

      const options = container.querySelectorAll('option[value^="job-"]');
      expect(options.length).toBe(10);
    });
  });

  // Task 6.2.2: On selection change, fetch and display logs
  describe('Job Log Loading', () => {
    it('should fetch logs when job is selected', (done) => {
      let fetchCalled = false;

      // Mock fetch
      global.fetch = jasmine.createSpy('fetch').and.returnValue(
        Promise.resolve({
          ok: true,
          json: () => Promise.resolve({
            logs: [
              { timestamp: '2025-01-01T10:00:00Z', stage: 'filtering', message: 'Loaded' }
            ]
          })
        })
      );

      selector.onJobSelected = (logs) => {
        expect(logs.length).toBe(1);
        expect(logs[0].message).toContain('Loaded');
        done();
      };

      const select = container.querySelector('.history-selector');
      select.value = 'job-uuid-123';
      select.dispatchEvent(new Event('change'));
    });

    it('should refresh LogPanel with selected job logs', (done) => {
      const logPanel = new LogPanel(document.createElement('div'));
      spyOn(logPanel, 'update');

      selector.setLogPanel(logPanel);

      global.fetch = jasmine.createSpy('fetch').and.returnValue(
        Promise.resolve({
          ok: true,
          json: () => Promise.resolve({
            logs: [
              { timestamp: '2025-01-01T10:00:00Z', stage: 'filtering', message: 'Test' }
            ]
          })
        })
      );

      const select = container.querySelector('.history-selector');
      select.value = 'job-uuid-123';
      select.dispatchEvent(new Event('change'));

      setTimeout(() => {
        expect(logPanel.update).toHaveBeenCalled();
        done();
      }, 100);
    });
  });

  // Task 6.2.3: Mark current job visually
  describe('Current Job Highlighting', () => {
    it('should mark current job with bold and highlight', () => {
      selector.markCurrentJob('job-current');

      const currentOption = container.querySelector('option[value="job-current"]');
      expect(currentOption.classList.contains('current-job')).toBe(true);
    });

    it('should display "In Progress" label for active job', () => {
      selector.markCurrentJob('job-current');

      const currentOption = container.querySelector('option[value="job-current"]');
      expect(currentOption.textContent).toContain('In Progress');
    });

    it('should not mark other jobs as current', () => {
      const otherOption = container.querySelector('option[value="job-other"]');
      expect(otherOption.classList.contains('current-job')).toBeFalsy();
    });
  });
});

describe('ReadOnlyEnforcement - Task 6.3: Completed Job Protection', () => {
  let container;
  let panel;

  beforeEach(() => {
    container = document.createElement('div');
    document.body.appendChild(container);
  });

  afterEach(() => {
    document.body.removeChild(container);
  });

  // Task 6.3.1: Hide cancel button for completed jobs
  describe('Cancel Button Visibility', () => {
    it('should hide cancel button when viewing completed job', () => {
      const cancelBtn = document.createElement('button');
      cancelBtn.classList.add('cancel-job-btn');
      container.appendChild(cancelBtn);

      const enforcer = new ReadOnlyEnforcer(container);
      enforcer.enforceReadOnly('completed');

      expect(cancelBtn.style.display).toBe('none');
    });

    it('should hide cancel button when viewing failed job', () => {
      const cancelBtn = document.createElement('button');
      cancelBtn.classList.add('cancel-job-btn');
      container.appendChild(cancelBtn);

      const enforcer = new ReadOnlyEnforcer(container);
      enforcer.enforceReadOnly('failed');

      expect(cancelBtn.style.display).toBe('none');
    });

    it('should hide cancel button when viewing cancelled job', () => {
      const cancelBtn = document.createElement('button');
      cancelBtn.classList.add('cancel-job-btn');
      container.appendChild(cancelBtn);

      const enforcer = new ReadOnlyEnforcer(container);
      enforcer.enforceReadOnly('cancelled');

      expect(cancelBtn.style.display).toBe('none');
    });

    it('should show cancel button when job is processing', () => {
      const cancelBtn = document.createElement('button');
      cancelBtn.classList.add('cancel-job-btn');
      cancelBtn.style.display = 'none';
      container.appendChild(cancelBtn);

      const enforcer = new ReadOnlyEnforcer(container);
      enforcer.enforceReadOnly('processing');

      expect(cancelBtn.style.display).not.toBe('none');
    });
  });

  // Task 6.3.2: Hide generate button and progress for non-active jobs
  describe('Generate Button and Progress Hiding', () => {
    it('should hide generate button for completed jobs', () => {
      const generateBtn = document.createElement('button');
      generateBtn.classList.add('generate-another-btn');
      container.appendChild(generateBtn);

      const enforcer = new ReadOnlyEnforcer(container);
      enforcer.enforceReadOnly('completed');

      expect(generateBtn.style.display).toBe('none');
    });

    it('should hide progress panel for historical jobs', () => {
      const progressPanel = document.createElement('div');
      progressPanel.classList.add('progress-panel');
      container.appendChild(progressPanel);

      const enforcer = new ReadOnlyEnforcer(container);
      enforcer.enforceReadOnly('completed');

      expect(progressPanel.style.display).toBe('none');
    });
  });

  // Task 6.3.3: Display "View only" label for historical jobs
  describe('View Only Label', () => {
    it('should display "View only" label for completed jobs', () => {
      const enforcer = new ReadOnlyEnforcer(container);
      enforcer.enforceReadOnly('completed');

      const viewOnlyLabel = container.querySelector('.view-only-label');
      expect(viewOnlyLabel).toBeTruthy();
      expect(viewOnlyLabel.textContent).toContain('View only');
    });

    it('should add visual styling to indicate read-only mode', () => {
      const enforcer = new ReadOnlyEnforcer(container);
      enforcer.enforceReadOnly('completed');

      const viewOnlyLabel = container.querySelector('.view-only-label');
      expect(viewOnlyLabel.classList.contains('badge-secondary')).toBe(true);
    });
  });

  // Task 6.3.4: No re-execution buttons for past jobs
  describe('Re-execution Prevention', () => {
    it('should prevent job regeneration by hiding all action buttons', () => {
      const buttons = [
        { class: 'cancel-job-btn', role: 'cancel' },
        { class: 'generate-another-btn', role: 'generate' },
        { class: 'retry-btn', role: 'retry' }
      ];

      buttons.forEach(btn => {
        const el = document.createElement('button');
        el.classList.add(btn.class);
        container.appendChild(el);
      });

      const enforcer = new ReadOnlyEnforcer(container);
      enforcer.enforceReadOnly('completed');

      buttons.forEach(btn => {
        const el = container.querySelector(`.${btn.class}`);
        expect(el.style.display).toBe('none');
      });
    });

    it('should meet requirement 7.5: no regeneration of completed jobs', () => {
      // This is a high-level test confirming the enforcement exists
      const enforcer = new ReadOnlyEnforcer(container);
      const canRegenerate = enforcer.canRegenerate('completed');
      expect(canRegenerate).toBe(false);
    });
  });
});
