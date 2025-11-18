// Debug test to check what /api/progress returns

const { chromium } = require('playwright');

const BASE_URL = 'http://localhost:4567';

async function runTest() {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();

  // Capture all console messages
  page.on('console', msg => {
    console.log(`[PAGE ${msg.type().toUpperCase()}] ${msg.text()}`);
  });

  // Capture network requests
  let progressApiCalls = [];
  page.on('response', async (response) => {
    if (response.url().includes('/api/progress')) {
      const status = response.status();
      let body = '';
      try {
        body = await response.text();
      } catch (e) {
        body = '(body could not be read)';
      }
      progressApiCalls.push({
        status,
        url: response.url(),
        body: body.substring(0, 200)
      });
    }
  });

  try {
    console.log('\n========================================');
    console.log('🐛 /api/progress 応答テスト');
    console.log('========================================\n');

    console.log('📱 /filtered_pdf ページを開く...');
    await page.goto(`${BASE_URL}/filtered_pdf`);
    await page.waitForLoadState('networkidle');
    console.log('✅ ページ読み込み完了\n');

    // Fill keywords
    console.log('📝 フォームに「Obsidian」を入力...');
    await page.fill('[name="keywords"]', 'Obsidian');
    console.log('✅ 入力完了\n');

    // Submit form
    console.log('🚀 フォームを送信...');
    progressApiCalls = []; // Reset before submission
    await Promise.all([
      page.waitForNavigation({ waitUntil: 'networkidle', timeout: 5000 }).catch(() => {}),
      page.click('button[type="submit"]')
    ]);
    console.log('✅ フォーム送信完了\n');

    // Wait for polling to happen
    console.log('⏳ ポーリングを待機中（3秒）...');
    await page.waitForTimeout(3000);

    // Display captured API calls
    console.log('🔍 キャプチャされた /api/progress 呼び出し:');
    if (progressApiCalls.length === 0) {
      console.log('  (API 呼び出し なし)');
    } else {
      progressApiCalls.forEach((call, index) => {
        console.log(`\n  [${index}] HTTP ${call.status}`);
        console.log(`      URL: ${call.url}`);
        console.log(`      Body: ${call.body}`);
      });
    }

    // Check direct API call
    console.log('\n\n🔧 直接 API 呼び出しテスト:');
    const jobId = await page.evaluate(() => window.formIntegration?.currentJobId);
    console.log(`Job ID: ${jobId}\n`);

    if (jobId) {
      const apiResponse = await fetch(`${BASE_URL}/api/progress?job_id=${jobId}`);
      const apiData = await apiResponse.json();
      console.log(`API Response Status: ${apiResponse.status}`);
      console.log(`API Response Body:`);
      console.log(JSON.stringify(apiData, null, 2));
    }

    console.log('\n✅ テスト完了');

  } catch (error) {
    console.error('\n❌ テストエラー:', error.message);
  } finally {
    await browser.close();
  }
}

runTest().catch(console.error);
