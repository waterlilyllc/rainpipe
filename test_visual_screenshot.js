// Visual test - take screenshot of filtered_pdf page with real submission
const { chromium } = require('playwright');

const BASE_URL = 'http://localhost:4567';

async function runTest() {
  const browser = await chromium.launch({ headless: false });
  const page = await browser.newPage();
  page.setViewportSize({ width: 1400, height: 900 });

  // Capture console messages
  page.on('console', msg => {
    console.log(`[PAGE ${msg.type().toUpperCase()}] ${msg.text()}`);
  });

  try {
    console.log('\n========================================');
    console.log('📸 ビジュアルテスト - スクリーンショット取得');
    console.log('========================================\n');

    console.log('📱 /filtered_pdf ページを開く...');
    await page.goto(`${BASE_URL}/filtered_pdf`);
    await page.waitForLoadState('networkidle');
    console.log('✅ ページ読み込み完了\n');

    // Take initial screenshot
    await page.screenshot({ path: '/tmp/01_initial_page.png', fullPage: true });
    console.log('📸 スクリーンショット 1: 初期状態 → /tmp/01_initial_page.png\n');

    // Fill keywords
    console.log('📝 フォームに「Obsidian」を入力...');
    await page.fill('[name="keywords"]', 'Obsidian');
    console.log('✅ 入力完了\n');

    // Submit form
    console.log('🚀 フォームを送信...');
    await Promise.all([
      page.waitForNavigation({ waitUntil: 'networkidle', timeout: 5000 }).catch(() => {}),
      page.click('button[type="submit"]')
    ]);
    console.log('✅ フォーム送信完了\n');

    // Take screenshot after form submission
    await page.waitForTimeout(1000);
    await page.screenshot({ path: '/tmp/02_after_submit.png', fullPage: true });
    console.log('📸 スクリーンショット 2: 送信直後 → /tmp/02_after_submit.png\n');

    // Wait for progress and take more screenshots
    console.log('⏳ 進捗を監視してスクリーンショットを取得中...\n');
    for (let i = 0; i < 10; i++) {
      await page.waitForTimeout(1000);

      const state = await page.evaluate(() => {
        const progressPanel = document.querySelector('#progress-panel');
        const form = document.querySelector('form');
        return {
          progressDisplay: window.getComputedStyle(progressPanel).display,
          formDisplay: window.getComputedStyle(form).display,
          jobId: window.formIntegration?.currentJobId,
          pollingActive: window.formIntegration?.pollingManager !== null
        };
      });

      console.log(`[${i+1}s] ProgressPanel: ${state.progressDisplay}, Polling: ${state.pollingActive}`);

      await page.screenshot({
        path: `/tmp/03_progress_${String(i+1).padStart(2, '0')}.png`,
        fullPage: true
      });
    }

    console.log('\n✅ スクリーンショット取得完了\n');
    console.log('📁 ファイル一覧:');
    console.log('  - /tmp/01_initial_page.png (初期状態)');
    console.log('  - /tmp/02_after_submit.png (送信直後)');
    console.log('  - /tmp/03_progress_01.png ~ /tmp/03_progress_10.png (進捗監視)');

  } catch (error) {
    console.error('\n❌ エラー:', error.message);
  } finally {
    await browser.close();
  }
}

runTest().catch(console.error);
