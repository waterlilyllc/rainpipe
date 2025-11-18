// Screenshot test - headless mode with detailed content inspection
const { chromium } = require('playwright');

const BASE_URL = 'http://localhost:4567';

async function runTest() {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  page.setViewportSize({ width: 1400, height: 1200 });

  try {
    console.log('\n========================================');
    console.log('📸 スクリーンショット取得テスト (headless)');
    console.log('========================================\n');

    console.log('📱 /filtered_pdf ページを開く...');
    await page.goto(`${BASE_URL}/filtered_pdf`);
    await page.waitForLoadState('networkidle');
    console.log('✅ ページ読み込み完了\n');

    // Take initial screenshot
    await page.screenshot({ path: '/tmp/01_initial_page.png', fullPage: true });
    console.log('📸 スクリーンショット 1: 初期状態\n');

    // Fill keywords
    console.log('📝 フォームに「Obsidian」を入力...');
    await page.fill('[name="keywords"]', 'Obsidian');
    await page.waitForTimeout(500);
    console.log('✅ 入力完了\n');

    // Submit form
    console.log('🚀 フォームを送信...');
    await Promise.all([
      page.waitForNavigation({ waitUntil: 'networkidle', timeout: 5000 }).catch(() => {}),
      page.click('button[type="submit"]')
    ]);
    console.log('✅ フォーム送信完了\n');

    // Wait a bit after submission
    await page.waitForTimeout(1500);

    // Take screenshot after form submission
    await page.screenshot({ path: '/tmp/02_after_submit.png', fullPage: true });
    console.log('📸 スクリーンショット 2: 送信直後\n');

    // Inspect page structure
    const pageContent = await page.evaluate(() => {
      const progressPanel = document.querySelector('#progress-panel');
      const logPanel = document.querySelector('#log-panel');
      const form = document.querySelector('form');

      return {
        progressPanelExists: !!progressPanel,
        progressDisplay: progressPanel ? window.getComputedStyle(progressPanel).display : 'N/A',
        progressHTML: progressPanel ? progressPanel.innerText.substring(0, 200) : 'N/A',
        logPanelExists: !!logPanel,
        logDisplay: logPanel ? window.getComputedStyle(logPanel).display : 'N/A',
        logHTML: logPanel ? logPanel.innerText.substring(0, 200) : 'N/A',
        formDisplay: window.getComputedStyle(form).display,
        jobId: window.formIntegration?.currentJobId
      };
    });

    console.log('🔍 ページ内容確認:');
    console.log(`  - ProgressPanel 存在: ${pageContent.progressPanelExists}`);
    console.log(`  - ProgressPanel display: ${pageContent.progressDisplay}`);
    console.log(`  - ProgressPanel HTML (最初の200文字):`);
    console.log(`    ${pageContent.progressHTML}\n`);
    console.log(`  - LogPanel 存在: ${pageContent.logPanelExists}`);
    console.log(`  - LogPanel display: ${pageContent.logDisplay}`);
    console.log(`  - LogPanel HTML (最初の200文字):`);
    console.log(`    ${pageContent.logHTML}\n`);
    console.log(`  - Form display: ${pageContent.formDisplay}`);
    console.log(`  - Job ID: ${pageContent.jobId}\n`);

    // Wait for more progress
    console.log('⏳ 5秒間待機して進捗を確認...\n');
    for (let i = 0; i < 5; i++) {
      await page.waitForTimeout(1000);

      const progressContent = await page.evaluate(() => {
        const logPanel = document.querySelector('#log-panel');
        const progressPanel = document.querySelector('#progress-panel');
        return {
          logDisplay: logPanel ? window.getComputedStyle(logPanel).display : 'N/A',
          logText: logPanel ? logPanel.innerText.substring(0, 150) : 'N/A',
          progressPercentage: progressPanel ? progressPanel.querySelector('.percentage-label')?.innerText : 'N/A'
        };
      });

      console.log(`[${i+1}s] LogPanel display: ${progressContent.logDisplay}, 進捗: ${progressContent.progressPercentage}`);
    }

    // Take final screenshot
    await page.screenshot({ path: '/tmp/03_final_state.png', fullPage: true });
    console.log('\n📸 スクリーンショット 3: 最終状態\n');

    console.log('✅ スクリーンショット取得完了');
    console.log('\n📁 ファイル:');
    console.log('  - /tmp/01_initial_page.png (初期状態)');
    console.log('  - /tmp/02_after_submit.png (送信直後)');
    console.log('  - /tmp/03_final_state.png (最終状態)');

  } catch (error) {
    console.error('\n❌ エラー:', error.message);
  } finally {
    await browser.close();
  }
}

runTest().catch(console.error);
