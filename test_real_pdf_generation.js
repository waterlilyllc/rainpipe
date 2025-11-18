// Real PDF Generation Test using Playwright
// Tests actual PDF generation workflow with Obsidian keyword

const { chromium } = require('playwright');

const BASE_URL = 'http://localhost:4567';

async function runTest() {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();

  // Capture console messages
  page.on('console', msg => {
    if (msg.type() === 'error') {
      console.log('🔴 CONSOLE ERROR:', msg.text());
    } else if (msg.type() === 'log') {
      console.log('📝 CONSOLE LOG:', msg.text());
    }
  });

  try {
    console.log('\n========================================');
    console.log('🎬 実際のPDF生成テスト開始');
    console.log('========================================\n');

    console.log('📱 /filtered_pdf ページを開く...');
    await page.goto(`${BASE_URL}/filtered_pdf`);
    await page.waitForLoadState('networkidle');
    console.log('✅ ページ読み込み完了\n');

    // Fill form with Obsidian keyword
    console.log('📝 フォームに入力...');
    console.log('   - キーワード: "Obsidian"');
    await page.fill('[name="keywords"]', 'Obsidian');

    // Get default dates (should be set by page script)
    const dateStart = await page.inputValue('[name="date_start"]');
    const dateEnd = await page.inputValue('[name="date_end"]');
    console.log(`   - 開始日: ${dateStart}`);
    console.log(`   - 終了日: ${dateEnd}\n`);

    // Submit form
    console.log('🚀 フォームを送信...');
    const submitTime = Date.now();

    // Wait for Job ID to appear in FormIntegration
    let jobId = null;
    let progressVisible = false;

    await page.waitForFunction(
      () => {
        const integration = window.formIntegration;
        return integration && integration.currentJobId;
      },
      { timeout: 5000 }
    );

    jobId = await page.evaluate(() => window.formIntegration.currentJobId);
    console.log(`✅ Job ID 取得: ${jobId}\n`);

    // Check progress panel visibility
    const progressPanel = await page.$('#progress-panel');
    const isVisible = await progressPanel.evaluate(el =>
      window.getComputedStyle(el).display !== 'none'
    );

    console.log(`✅ Progress Panel 表示状態: ${isVisible ? '表示中' : '非表示'}\n`);

    if (!isVisible) {
      console.error('❌ Progress Panel が表示されていません！');
      await browser.close();
      return;
    }

    // Monitor progress for 30 seconds
    console.log('⏳ PDF生成の進捗を監視中...\n');

    let lastProgress = null;
    let maxPercentage = 0;
    let stagesObserved = new Set();

    for (let i = 0; i < 30; i++) {
      const progress = await page.evaluate(() => {
        const integration = window.formIntegration;
        const panel = document.querySelector('#progress-panel');

        return {
          jobId: integration?.currentJobId,
          panelDisplay: window.getComputedStyle(panel).display,
          panelHTML: panel?.innerText || '',
          pollingActive: integration?.pollingManager !== null
        };
      });

      // Display status every 5 seconds
      if (i % 5 === 0 || i < 3) {
        console.log(`[${i}s] PolingActive: ${progress.pollingActive}, PanelDisplay: ${progress.panelDisplay}`);
        if (progress.panelHTML) {
          console.log(`     Panel Content: ${progress.panelHTML.substring(0, 60)}...`);
        }
      }

      lastProgress = progress;
      await page.waitForTimeout(1000);
    }

    console.log('\n📋 最終状態:');
    console.log(`   - Job ID: ${lastProgress.jobId}`);
    console.log(`   - Progress Panel: ${lastProgress.panelDisplay}`);
    console.log(`   - Polling Active: ${lastProgress.pollingActive}`);

    // Take screenshot
    console.log('\n📸 スクリーンショット撮影...');
    await page.screenshot({ path: '/tmp/pdf_generation_test.png', fullPage: true });
    console.log('✅ /tmp/pdf_generation_test.png に保存\n');

    // Check if PDF file was created
    console.log('📁 生成済みPDFファイルを確認中...');
    const lsResult = await require('child_process').execSync('ls -lh /var/git/rainpipe/data/*.pdf 2>/dev/null | tail -5', { encoding: 'utf-8' });
    console.log(lsResult);

    console.log('\n========================================');
    console.log('✅ テスト完了！');
    console.log('========================================\n');

  } catch (error) {
    console.error('❌ テストエラー:', error.message);
    await page.screenshot({ path: '/tmp/error_screenshot.png' });
    console.log('エラースクリーンショット: /tmp/error_screenshot.png');
  } finally {
    await browser.close();
  }
}

runTest().catch(console.error);
