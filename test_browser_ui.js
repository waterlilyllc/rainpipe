// Browser UI Test using Playwright
// Verifies that ProgressPanel, LogPanel, and CompletionPanel display correctly

const { chromium } = require('playwright');
const assert = require('assert');

const BASE_URL = 'http://localhost:4567';

async function runTest() {
  const browser = await chromium.launch({ headless: true }); // headless mode (no X server available)
  const page = await browser.newPage();

  // Capture console messages
  page.on('console', msg => console.log('🔹 CONSOLE:', msg.type(), msg.text()));
  page.on('error', err => console.error('🔴 PAGE ERROR:', err));

  try {
    console.log('📱 Opening /filtered_pdf page...');
    await page.goto(`${BASE_URL}/filtered_pdf`);

    // Wait for page to load
    await page.waitForLoadState('networkidle');
    console.log('✅ Page loaded');

    // Check if form exists
    const form = await page.$('form');
    assert(form !== null, 'Form not found');
    console.log('✅ Form found');

    // Check if FormIntegration is initialized
    const formIntegrationExists = await page.evaluate(() => {
      return typeof window.formIntegration !== 'undefined';
    });
    assert(formIntegrationExists, 'FormIntegration not initialized');
    console.log('✅ FormIntegration initialized');

    // Fill form with test data
    console.log('\n📝 Filling form...');
    await page.fill('[name="keywords"]', 'test keyword');

    // Get progress panel initial state
    const progressPanelInitial = await page.evaluate(() => {
      const panel = document.querySelector('#progress-panel');
      return {
        display: window.getComputedStyle(panel).display,
        html: panel ? panel.innerHTML.substring(0, 100) : 'NOT_FOUND'
      };
    });
    console.log('Progress panel initial state:', progressPanelInitial);

    // Submit form
    console.log('\n🚀 Submitting form...');

    // Listen for network response
    const formSubmitPromise = page.evaluate(() => {
      return new Promise((resolve) => {
        // Wait a bit for the form submission to trigger
        setTimeout(() => {
          resolve({
            progressPanelDisplay: window.getComputedStyle(document.querySelector('#progress-panel')).display,
            logPanelDisplay: window.getComputedStyle(document.querySelector('#log-panel')).display,
            completionPanelDisplay: window.getComputedStyle(document.querySelector('#completion-panel')).display,
            formIntegrationJobId: window.formIntegration?.currentJobId
          });
        }, 500);
      });
    });

    // Click submit button
    await page.click('button[type="submit"]');

    // Wait for response
    const uiState = await formSubmitPromise;
    console.log('\n📊 UI State after form submission:');
    console.log('  Progress panel display:', uiState.progressPanelDisplay);
    console.log('  Log panel display:', uiState.logPanelDisplay);
    console.log('  Completion panel display:', uiState.completionPanelDisplay);
    console.log('  FormIntegration job ID:', uiState.formIntegrationJobId);

    // Check if progress panel became visible
    if (uiState.progressPanelDisplay === 'none') {
      console.warn('❌ Progress panel is still hidden!');

      // Check for JavaScript errors
      const jsErrors = await page.evaluate(() => {
        return window.__jsErrors || [];
      });
      if (jsErrors.length > 0) {
        console.error('JavaScript errors detected:', jsErrors);
      }

      // Check form submission details
      const formDetails = await page.evaluate(() => {
        return {
          formSelector: !!document.querySelector('form'),
          progressPanelSelector: !!document.querySelector('#progress-panel'),
          formHandler: typeof window.formIntegration?._attachFormHandler
        };
      });
      console.log('Form details:', formDetails);
    } else {
      console.log('✅ Progress panel is visible!');
    }

    // Wait for a few progress updates
    console.log('\n⏳ Waiting for progress updates (15 seconds)...');
    let lastProgress = null;
    for (let i = 0; i < 15; i++) {
      const progress = await page.evaluate(() => {
        const panel = document.querySelector('#progress-panel');
        const logPanel = document.querySelector('#log-panel');
        return {
          progressDisplay: panel ? window.getComputedStyle(panel).display : 'NOT_FOUND',
          logDisplay: logPanel ? window.getComputedStyle(logPanel).display : 'NOT_FOUND',
          progressContent: panel ? panel.innerText.substring(0, 100) : '',
          logContent: logPanel ? logPanel.innerText.substring(0, 100) : '',
          jobId: window.formIntegration?.currentJobId,
          pollingActive: window.formIntegration?.pollingManager !== null
        };
      });

      if (progress.progressDisplay !== 'none') {
        console.log(`  [${i}s] Progress panel visible, content preview: ${progress.progressContent.substring(0, 50)}...`);
      }

      if (progress.logDisplay !== 'none' && progress.logContent) {
        console.log(`  [${i}s] Log panel visible, logs: ${progress.logContent.substring(0, 50)}...`);
      }

      lastProgress = progress;
      await page.waitForTimeout(1000);
    }

    console.log('\n📋 Final Status:');
    console.log('Progress panel:', lastProgress.progressDisplay);
    console.log('Log panel:', lastProgress.logDisplay);
    console.log('Job ID:', lastProgress.jobId);
    console.log('Polling active:', lastProgress.pollingActive);

    // Take screenshots for verification
    console.log('\n📸 Taking screenshots...');
    await page.screenshot({ path: '/tmp/filtered_pdf_initial.png' });
    console.log('Screenshot saved: /tmp/filtered_pdf_initial.png');

    // Scroll to see progress panel
    await page.evaluate(() => {
      document.querySelector('#progress-panel')?.scrollIntoView({ behavior: 'smooth' });
    });
    await page.waitForTimeout(1000);

    await page.screenshot({ path: '/tmp/filtered_pdf_progress.png' });
    console.log('Screenshot saved: /tmp/filtered_pdf_progress.png');

  } catch (error) {
    console.error('❌ Test error:', error);
  } finally {
    console.log('\n✨ Closing browser...');
    await browser.close();
  }
}

// Catch unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
});

runTest().catch(console.error);
