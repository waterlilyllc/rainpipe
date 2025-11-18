// Debug test for ProgressPanel display issue
// Tests FormIntegration initialization and ProgressPanel visibility

const { chromium } = require('playwright');

const BASE_URL = 'http://localhost:4567';

async function runTest() {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();

  // Capture all console messages
  page.on('console', msg => {
    console.log(`[PAGE ${msg.type().toUpperCase()}] ${msg.text()}`);
  });

  try {
    console.log('\n========================================');
    console.log('🐛 FormIntegration デバッグテスト開始');
    console.log('========================================\n');

    console.log('📱 /filtered_pdf ページを開く...');
    await page.goto(`${BASE_URL}/filtered_pdf`);
    await page.waitForLoadState('networkidle');
    console.log('✅ ページ読み込み完了\n');

    // Check DOM elements before form submission
    console.log('🔍 初期状態の DOM 確認:');
    const domState = await page.evaluate(() => {
      const form = document.querySelector('form');
      const progressPanel = document.querySelector('#progress-panel');
      const formIntegration = window.formIntegration;

      return {
        formExists: !!form,
        progressPanelExists: !!progressPanel,
        progressPanelDisplay: progressPanel ? window.getComputedStyle(progressPanel).display : 'N/A',
        formIntegrationLoaded: !!formIntegration,
        formIntegrationFormNull: formIntegration ? formIntegration.form === null : 'N/A',
        formIntegrationProgressPanelNull: formIntegration ? formIntegration.progressPanel === null : 'N/A',
        formIntegrationFormSelector: formIntegration?.formSelector,
        formIntegrationProgressPanelSelector: formIntegration?.progressPanelSelector
      };
    });

    console.log(`  - Form DOM 存在: ${domState.formExists}`);
    console.log(`  - ProgressPanel DOM 存在: ${domState.progressPanelExists}`);
    console.log(`  - ProgressPanel display: ${domState.progressPanelDisplay}`);
    console.log(`  - FormIntegration ロード済み: ${domState.formIntegrationLoaded}`);
    console.log(`  - FormIntegration.form === null: ${domState.formIntegrationFormNull}`);
    console.log(`  - FormIntegration.progressPanel === null: ${domState.formIntegrationProgressPanelNull}`);
    console.log(`  - FormIntegration.formSelector: ${domState.formIntegrationFormSelector}`);
    console.log(`  - FormIntegration.progressPanelSelector: ${domState.formIntegrationProgressPanelSelector}\n`);

    // Fill keywords
    console.log('📝 フォームに「Obsidian」を入力...');
    await page.fill('[name="keywords"]', 'Obsidian');
    console.log('✅ 入力完了\n');

    // Monitor display before and after submission
    console.log('🚀 フォーム送信前の状態:');
    let stateBeforeSubmit = await page.evaluate(() => {
      const form = document.querySelector('form');
      const progressPanel = document.querySelector('#progress-panel');
      return {
        formDisplay: window.getComputedStyle(form).display,
        progressPanelDisplay: window.getComputedStyle(progressPanel).display
      };
    });
    console.log(`  - Form: ${stateBeforeSubmit.formDisplay}`);
    console.log(`  - ProgressPanel: ${stateBeforeSubmit.progressPanelDisplay}\n`);

    // Submit form
    console.log('📤 フォームを送信...');
    await Promise.all([
      page.waitForNavigation({ waitUntil: 'networkidle', timeout: 5000 }).catch(() => {}),
      page.click('button[type="submit"]')
    ]);

    // Wait a bit for state changes
    await page.waitForTimeout(500);

    // Check state immediately after submission
    console.log('✅ フォーム送信完了\n');
    console.log('🔍 フォーム送信直後の状態:');

    let stateAfterSubmit = await page.evaluate(() => {
      const form = document.querySelector('form');
      const progressPanel = document.querySelector('#progress-panel');
      const formIntegration = window.formIntegration;

      return {
        formDisplay: window.getComputedStyle(form).display,
        progressPanelDisplay: window.getComputedStyle(progressPanel).display,
        currentJobId: formIntegration?.currentJobId || null,
        pollingActive: formIntegration?.pollingManager !== null,
        progressPanelElement: !!progressPanel,
        progressPanelHTML: progressPanel?.innerHTML?.substring(0, 100) || 'N/A'
      };
    });

    console.log(`  - Form display: ${stateAfterSubmit.formDisplay}`);
    console.log(`  - ProgressPanel display: ${stateAfterSubmit.progressPanelDisplay}`);
    console.log(`  - CurrentJobId: ${stateAfterSubmit.currentJobId}`);
    console.log(`  - Polling Active: ${stateAfterSubmit.pollingActive}`);
    console.log(`  - ProgressPanel Element exists: ${stateAfterSubmit.progressPanelElement}`);
    console.log(`  - ProgressPanel HTML: ${stateAfterSubmit.progressPanelHTML}\n`);

    // If ProgressPanel still shows 'none', investigate CSS
    if (stateAfterSubmit.progressPanelDisplay === 'none') {
      console.log('⚠️  ProgressPanel は display:none のままです');
      console.log('🔍 CSS スタイル確認:');

      const cssInfo = await page.evaluate(() => {
        const progressPanel = document.querySelector('#progress-panel');
        const computedStyle = window.getComputedStyle(progressPanel);

        return {
          display: computedStyle.display,
          visibility: computedStyle.visibility,
          opacity: computedStyle.opacity,
          inlineStyle: progressPanel.getAttribute('style'),
          classList: progressPanel.className
        };
      });

      console.log(`  - Computed display: ${cssInfo.display}`);
      console.log(`  - Computed visibility: ${cssInfo.visibility}`);
      console.log(`  - Computed opacity: ${cssInfo.opacity}`);
      console.log(`  - Inline style: ${cssInfo.inlineStyle}`);
      console.log(`  - Class list: ${cssInfo.classList}\n`);
    }

    console.log('⏳ 3秒間の状態監視...');
    for (let i = 0; i < 3; i++) {
      const state = await page.evaluate(() => {
        const progressPanel = document.querySelector('#progress-panel');
        const formIntegration = window.formIntegration;

        return {
          progressDisplay: window.getComputedStyle(progressPanel).display,
          pollingActive: formIntegration?.pollingManager !== null,
          jobId: formIntegration?.currentJobId
        };
      });

      console.log(`[${i}s] ProgressPanel: ${state.progressDisplay}, Polling: ${state.pollingActive}, JobId: ${state.jobId}`);
      await page.waitForTimeout(1000);
    }

    console.log('\n✅ テスト完了');

  } catch (error) {
    console.error('\n❌ テストエラー:', error.message);
    await page.screenshot({ path: '/tmp/debug_error.png' });
  } finally {
    await browser.close();
  }
}

runTest().catch(console.error);
