document.addEventListener('DOMContentLoaded', function() {
    // エクスポートボタンのクリックハンドラー
    document.addEventListener('click', function(e) {
        if (e.target.closest('.export-btn')) {
            const button = e.target.closest('.export-btn');
            const bookmarkId = button.dataset.bookmarkId;
            const isNotion = button.classList.contains('notion-export');
            const destination = isNotion ? 'notion' : 'obsidian';
            
            exportBookmark(bookmarkId, destination, button);
        }
    });
    
    async function exportBookmark(bookmarkId, destination, button) {
        // ボタンを無効化して処理中を表示
        const originalContent = button.innerHTML;
        button.disabled = true;
        button.innerHTML = '<span style="font-size: 12px;">処理中...</span>';
        
        try {
            const response = await fetch(`/export/${bookmarkId}`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ destination: destination })
            });
            
            const result = await response.json();
            
            if (result.success) {
                // 成功時のフィードバック
                button.innerHTML = '✅';
                button.style.backgroundColor = '#d4edda';
                button.style.borderColor = '#c3e6cb';
                
                // 成功メッセージを表示
                showNotification(`${destination === 'notion' ? 'Notion' : 'Obsidian'}に送信しました！`, 'success');
                
                // 3秒後に元に戻す
                setTimeout(() => {
                    button.innerHTML = originalContent;
                    button.style.backgroundColor = '';
                    button.style.borderColor = '';
                    button.disabled = false;
                }, 3000);
            } else {
                // エラー時のフィードバック
                button.innerHTML = '❌';
                button.style.backgroundColor = '#f8d7da';
                button.style.borderColor = '#f5c6cb';
                
                // エラーメッセージを表示
                showNotification(`エラー: ${result.error || '送信に失敗しました'}`, 'error');
                
                // 3秒後に元に戻す
                setTimeout(() => {
                    button.innerHTML = originalContent;
                    button.style.backgroundColor = '';
                    button.style.borderColor = '';
                    button.disabled = false;
                }, 3000);
            }
        } catch (error) {
            console.error('Export error:', error);
            button.innerHTML = originalContent;
            button.disabled = false;
            showNotification('ネットワークエラーが発生しました', 'error');
        }
    }
    
    function showNotification(message, type) {
        // 既存の通知を削除
        const existingNotification = document.querySelector('.export-notification');
        if (existingNotification) {
            existingNotification.remove();
        }
        
        // 通知要素を作成
        const notification = document.createElement('div');
        notification.className = 'export-notification';
        notification.classList.add(type);
        notification.textContent = message;
        
        // スタイルを設定
        notification.style.cssText = `
            position: fixed;
            bottom: 20px;
            right: 20px;
            padding: 15px 20px;
            border-radius: 8px;
            font-size: 14px;
            z-index: 1000;
            animation: slideIn 0.3s ease-out;
        `;
        
        if (type === 'success') {
            notification.style.backgroundColor = '#d4edda';
            notification.style.color = '#155724';
            notification.style.border = '1px solid #c3e6cb';
        } else {
            notification.style.backgroundColor = '#f8d7da';
            notification.style.color = '#721c24';
            notification.style.border = '1px solid #f5c6cb';
        }
        
        document.body.appendChild(notification);
        
        // 3秒後に自動的に削除
        setTimeout(() => {
            notification.style.animation = 'slideOut 0.3s ease-out';
            setTimeout(() => notification.remove(), 300);
        }, 3000);
    }
    
    // アニメーション用のスタイルを追加
    if (!document.querySelector('#export-animations')) {
        const style = document.createElement('style');
        style.id = 'export-animations';
        style.textContent = `
            @keyframes slideIn {
                from {
                    transform: translateX(100%);
                    opacity: 0;
                }
                to {
                    transform: translateX(0);
                    opacity: 1;
                }
            }
            
            @keyframes slideOut {
                from {
                    transform: translateX(0);
                    opacity: 1;
                }
                to {
                    transform: translateX(100%);
                    opacity: 0;
                }
            }
        `;
        document.head.appendChild(style);
    }
});