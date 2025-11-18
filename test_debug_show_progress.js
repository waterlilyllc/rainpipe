// Debug test to check if _showProgress() is being called
// Patches FormIntegration to log method calls

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
    console.log('🐛 _showProgress() 追跡テスト');
    console.log('========================================\n');

    console.log('📱 /filtered_pdf ページを開く...');
    await page.goto(`${BASE_URL}/filtered_pdf`);
    await page.waitForLoadState('networkidle');
    console.log('✅ ページ読み込み完了\n');

    // Inject logging code after page loads
    console.log('🔧 FormIntegration をパッチして logging を追加...');
    await page.evaluate(() => {
      // Save original methods
      const originalShowProgress = FormIntegration.prototype._showProgress;
      const originalHideForm = FormIntegration.prototype._hideForm;

      // Wrap with logging
      FormIntegration.prototype._showProgress = function() {
        console.log('📋 _showProgress() が呼び出されました');
        console.log(`   progressPanel 存在: ${!!this.progressPanel}`);
        console.log(`   progressPanel.style.display 変更前: ${this.progressPanel.style.display}`);

        // Call original method
        originalShowProgress.call(this);

        console.log(`   progressPanel.style.display 変更後: ${this.progressPanel.style.display}`);
        console.log(`   computed display: ${window.getComputedStyle(this.progressPanel).display}`);
      };

      FormIntegration.prototype._hideForm = function() {
        console.log('📋 _hideForm() が呼び出されました');
        originalHideForm.call(this);
      };
    });

    console.log('✅ パッチ完了\n');

    // Fill keywords
    console.log('📝 フォームに「Obsidian」を入力...');
    await page.fill('[name="keywords"]', 'Obsidian');
    console.log('✅ 入力完了\n');

    // Submit form and wait for completion
    console.log('🚀 フォームを送信...');
    await Promise.all([
      page.waitForNavigation({ waitUntil: 'networkidle', timeout: 5000 }).catch(() => {}),
      page.click('button[type="submit"]')
    ]);

    console.log('✅ フォーム送信完了\n');

    // Wait for async operations
    await page.waitForTimeout(1000);

    // Check final state
    const finalState = await page.evaluate(() => {
      const progressPanel = document.querySelector('#progress-panel');
      return {
        progressPanelDisplay: window.getComputedStyle(progressPanel).display,
        inlineStyle: progressPanel.getAttribute('style'),
        jobId: window.formIntegration?.currentJobId
      };
    });

    console.log('🔍 最終状態:');
    console.log(`  - ProgressPanel computed display: ${finalState.progressPanelDisplay}`);
    console.log(`  - ProgressPanel inline style: ${finalState.inlineStyle}`);
    console.log(`  - Job ID: ${finalState.jobId}\n`);

    console.log('✅ テスト完了');

  } catch (error) {
    console.error('\n❌ テストエラー:', error.message);
  } finally {
    await browser.close();
  }
}

runTest().catch(console.error);
