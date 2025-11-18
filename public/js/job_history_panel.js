// JobHistoryPanel - PDF生成ジョブの履歴を表示

class JobHistoryPanel {
  constructor(containerElement) {
    this.container = containerElement;
    this.listElement = containerElement.querySelector('#job-history-list');
  }

  // 履歴を取得して表示
  async loadHistory() {
    try {
      const response = await fetch('/api/jobs/history?limit=10');

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }

      const data = await response.json();

      if (data.jobs && data.jobs.length > 0) {
        this.renderJobs(data.jobs);
      } else {
        this.listElement.innerHTML = '<p style="color: #6c757d; text-align: center;">履歴がありません</p>';
      }
    } catch (error) {
      console.error('履歴の読み込みに失敗しました:', error);
      this.listElement.innerHTML = '<p style="color: #721c24; text-align: center;">❌ エラー: 履歴の読み込みに失敗しました</p>';
    }
  }

  // ジョブリストを表示
  renderJobs(jobs) {
    const jobsHTML = jobs.map(job => this.renderJobItem(job)).join('');

    this.listElement.innerHTML = `
      <table style="width: 100%; border-collapse: collapse;">
        <thead>
          <tr style="background-color: #f8f9fa; border-bottom: 2px solid #dee2e6;">
            <th style="padding: 0.75rem; text-align: left; font-weight: 600;">キーワード</th>
            <th style="padding: 0.75rem; text-align: center; font-weight: 600;">ステータス</th>
            <th style="padding: 0.75rem; text-align: center; font-weight: 600;">ブックマーク数</th>
            <th style="padding: 0.75rem; text-align: left; font-weight: 600;">作成日時</th>
            <th style="padding: 0.75rem; text-align: center; font-weight: 600;">操作</th>
          </tr>
        </thead>
        <tbody>
          ${jobsHTML}
        </tbody>
      </table>
    `;

    // ログ表示ボタンにイベントリスナーを追加
    this.attachEventListeners();
  }

  // 各ジョブの行を生成
  renderJobItem(job) {
    const statusBadge = this.getStatusBadge(job.status);
    const createdAt = this.formatDate(job.created_at);
    const bookmarkCount = job.bookmark_count || '-';

    return `
      <tr style="border-bottom: 1px solid #dee2e6;" data-job-id="${job.job_id}">
        <td style="padding: 0.75rem;">
          <strong>${this.escapeHtml(job.keywords)}</strong>
        </td>
        <td style="padding: 0.75rem; text-align: center;">
          ${statusBadge}
        </td>
        <td style="padding: 0.75rem; text-align: center;">
          ${bookmarkCount}
        </td>
        <td style="padding: 0.75rem; color: #6c757d; font-size: 0.9rem;">
          ${createdAt}
        </td>
        <td style="padding: 0.75rem; text-align: center;">
          <button class="view-logs-btn" data-job-id="${job.job_id}" style="padding: 0.4rem 0.8rem; background-color: #495057; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 0.85rem;">
            📋 ログ表示
          </button>
          ${job.pdf_path ? `<a href="/${job.pdf_path}" download style="margin-left: 0.5rem; padding: 0.4rem 0.8rem; background-color: #28a745; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 0.85rem; text-decoration: none; display: inline-block;">📥 PDF</a>` : ''}
        </td>
      </tr>
    `;
  }

  // ステータスバッジを生成
  getStatusBadge(status) {
    const badges = {
      'completed': '<span style="background-color: #d4edda; color: #155724; padding: 0.25rem 0.75rem; border-radius: 12px; font-size: 0.85rem; font-weight: 600;">✅ 完了</span>',
      'pending': '<span style="background-color: #fff3cd; color: #856404; padding: 0.25rem 0.75rem; border-radius: 12px; font-size: 0.85rem; font-weight: 600;">⏳ 処理待ち</span>',
      'processing': '<span style="background-color: #cce5ff; color: #004085; padding: 0.25rem 0.75rem; border-radius: 12px; font-size: 0.85rem; font-weight: 600;">🔄 処理中</span>',
      'failed': '<span style="background-color: #f8d7da; color: #721c24; padding: 0.25rem 0.75rem; border-radius: 12px; font-size: 0.85rem; font-weight: 600;">❌ 失敗</span>'
    };

    return badges[status] || status;
  }

  // 日付をフォーマット
  formatDate(dateString) {
    if (!dateString) return '-';

    try {
      const date = new Date(dateString);
      const year = date.getFullYear();
      const month = String(date.getMonth() + 1).padStart(2, '0');
      const day = String(date.getDate()).padStart(2, '0');
      const hours = String(date.getHours()).padStart(2, '0');
      const minutes = String(date.getMinutes()).padStart(2, '0');

      return `${year}-${month}-${day} ${hours}:${minutes}`;
    } catch (error) {
      return dateString;
    }
  }

  // HTMLエスケープ
  escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  // イベントリスナーを追加
  attachEventListeners() {
    const logButtons = this.listElement.querySelectorAll('.view-logs-btn');

    logButtons.forEach(button => {
      button.addEventListener('click', (e) => {
        e.preventDefault();
        const jobId = button.dataset.jobId;
        this.showJobLogs(jobId);
      });
    });
  }

  // ジョブのログを表示
  async showJobLogs(jobId) {
    try {
      const response = await fetch(`/api/logs/history?job_id=${encodeURIComponent(jobId)}`);

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }

      const data = await response.json();

      // LogPanelコンポーネントを使ってログを表示
      const logPanelElement = document.querySelector('#log-panel');
      if (logPanelElement && data.logs) {
        logPanelElement.style.display = 'block';

        // LogPanelインスタンスを作成または取得
        if (!window.jobHistoryLogPanel) {
          window.jobHistoryLogPanel = new LogPanel(logPanelElement);
        }

        window.jobHistoryLogPanel.update(data.logs);

        // ログパネルまでスクロール
        logPanelElement.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
      }
    } catch (error) {
      console.error('ログの読み込みに失敗しました:', error);
      alert('ログの読み込みに失敗しました');
    }
  }
}

// Export for Node.js/module testing
if (typeof module !== 'undefined' && module.exports) {
  module.exports = JobHistoryPanel;
}
