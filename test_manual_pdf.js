// Manual PDF Generation Test with detailed debugging

const { chromium } = require('playwright');

const BASE_URL = 'http://localhost:4567';

async function runTest() {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();

  page.on('console', msg => {
    const text = msg.text();
    if (text.includes('ERROR') || text.includes('error') || text.includes('Polling') || text.includes('Job')) {
      console.log(`  [PAGE] ${msg.type().toUpperCase()}: ${text.substring(0, 100)}`);
    }
  });

  try {
    console.log('\n🌐 Filtered PDF ページを開く...');
    await page.goto(`${BASE_URL}/filtered_pdf`);
    await page.waitForLoadState('networkidle');
    console.log('✅ ページ読み込み完了\n');

    // Check if FormIntegration is loaded
    const formIntLoaded = await page.evaluate(() => {
      return typeof window.FormIntegration !== 'undefined';
    });
    console.log(`FormIntegration クラス: ${formIntLoaded ? '✅ ロード済み' : '❌ 未ロード'}`);

    // Fill keywords
    console.log('\n📝 フォームに「Obsidian」を入力...');
    await page.fill('[name="keywords"]', 'Obsidian');
    console.log('✅ 入力完了');

    // Click submit button directly
    console.log('\n🚀 送信ボタンをクリック...');
    await Promise.all([
      page.waitForNavigation({ waitUntil: 'networkidle', timeout: 5000 }).catch(() => {}),
      page.click('button[type="submit"]')
    ]);

    console.log('⏳ 0.5 秒待機...');
    await page.waitForTimeout(500);

    // Check state
    const state = await page.evaluate(() => {
      const form = document.querySelector('form');
      const progressPanel = document.querySelector('#progress-panel');
      const integration = window.formIntegration;

      return {
        formExists: !!form,
        formDisplay: form ? window.getComputedStyle(form).display : 'N/A',
        progressDisplay: progressPanel ? window.getComputedStyle(progressPanel).display : 'N/A',
        jobId: integration?.currentJobId || null,
        pollingActive: integration?.pollingManager !== null
      };
    });

    console.log('\n📊 現在の状態:');
    console.log(`  - フォーム: ${state.formDisplay}`);
    console.log(`  - ProgressPanel: ${state.progressDisplay}`);
    console.log(`  - Job ID: ${state.jobId || 'なし'}`);
    console.log(`  - ポーリング: ${state.pollingActive ? '実行中' : '停止'}`);

    if (state.jobId) {
      console.log(`\n✅ Job ID を取得しました: ${state.jobId}`);
      console.log('\n⏳ 30 秒間、進捗を監視中...');

      for (let i = 0; i < 30; i++) {
        const progress = await page.evaluate(() => {
          const panel = document.querySelector('#progress-panel');
          return {
            display: panel ? window.getComputedStyle(panel).display : 'N/A',
            content: panel?.innerText?.substring(0, 80) || 'N/A',
            pollingActive: window.formIntegration?.pollingManager !== null
          };
        });

        if (i % 5 === 0) {
          console.log(`  [${i}s] Display: ${progress.display}, Polling: ${progress.pollingActive}`);
        }
        await page.waitForTimeout(1000);
      }
    } else {
      console.error('❌ Job ID を取得できませんでした');
      console.error('このためフォーム送信に失敗した可能性があります');

      // Try to see what the API returned
      const networkLogs = await page.evaluate(() => {
        return window.__networkLogs || [];
      });
      console.log('ネットワークログ:', networkLogs);
    }

    console.log('\n✅ テスト完了');

  } catch (error) {
    console.error('\n❌ エラー:', error.message);
  } finally {
    await browser.close();
  }
}

runTest();
