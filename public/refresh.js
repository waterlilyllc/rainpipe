// 新着ブックマーク再取得機能
class BookmarkRefresher {
  constructor() {
    this.refreshBtn = document.getElementById('refresh-btn');
    this.refreshIcon = document.getElementById('refresh-icon');
    this.refreshText = document.getElementById('refresh-text');
    this.isRefreshing = false;
    
    if (this.refreshBtn) {
      this.refreshBtn.addEventListener('click', () => this.refresh());
    }
  }

  async refresh() {
    if (this.isRefreshing) return;
    
    this.setRefreshing(true);
    
    try {
      const response = await fetch('/refresh', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        }
      });
      
      const result = await response.json();
      
      if (result.success) {
        this.showMessage(result.message, 'success');
        
        if (result.new_count > 0) {
          // 新着があった場合は3秒後にリロード
          setTimeout(() => {
            window.location.reload();
          }, 3000);
        }
      } else {
        this.showMessage(result.message, 'error');
      }
      
    } catch (error) {
      this.showMessage('通信エラーが発生しました', 'error');
      console.error('Refresh error:', error);
    } finally {
      setTimeout(() => {
        this.setRefreshing(false);
      }, 2000);
    }
  }

  setRefreshing(isRefreshing) {
    this.isRefreshing = isRefreshing;
    
    if (isRefreshing) {
      this.refreshBtn.disabled = true;
      this.refreshBtn.classList.add('refreshing');
      this.refreshIcon.style.animation = 'spin 1s linear infinite';
      this.refreshText.textContent = '取得中...';
    } else {
      this.refreshBtn.disabled = false;
      this.refreshBtn.classList.remove('refreshing');
      this.refreshIcon.style.animation = '';
      this.refreshText.textContent = '新着取得';
    }
  }

  showMessage(message, type) {
    // 既存のメッセージを削除
    const existing = document.querySelector('.refresh-message');
    if (existing) existing.remove();
    
    // 新しいメッセージを表示
    const messageDiv = document.createElement('div');
    messageDiv.className = `refresh-message ${type}`;
    messageDiv.textContent = message;
    
    // ボタンの後に挿入
    this.refreshBtn.parentNode.insertBefore(messageDiv, this.refreshBtn.nextSibling);
    
    // 5秒後に自動削除
    setTimeout(() => {
      messageDiv.remove();
    }, 5000);
  }
}

// ページ読み込み時に初期化
document.addEventListener('DOMContentLoaded', () => {
  new BookmarkRefresher();
});

// CSS アニメーションを動的に追加
const style = document.createElement('style');
style.textContent = `
@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}

.refresh-message {
  margin: 0.5rem 0;
  padding: 0.5rem 1rem;
  border-radius: 4px;
  font-size: 0.9rem;
  animation: fadeIn 0.3s ease-in;
}

.refresh-message.success {
  background-color: #d4edda;
  color: #155724;
  border: 1px solid #c3e6cb;
}

.refresh-message.error {
  background-color: #f8d7da;
  color: #721c24;
  border: 1px solid #f5c6cb;
}

@keyframes fadeIn {
  from { opacity: 0; transform: translateY(-10px); }
  to { opacity: 1; transform: translateY(0); }
}

.refresh-btn {
  transition: all 0.2s ease;
}

.refresh-btn.refreshing {
  opacity: 0.7;
}
`;
document.head.appendChild(style);