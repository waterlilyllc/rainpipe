require 'mail'

class KindleEmailSender
  def initialize
    @gmail_address = ENV['GMAIL_ADDRESS']
    @gmail_app_password = ENV['GMAIL_APP_PASSWORD']
    @kindle_email = ENV['KINDLE_EMAIL']

    validate_credentials!
    configure_mail
  end

  # PDFをKindleに送信
  # @param pdf_path [String] PDFファイルのパス
  # @param subject [String] メールの件名（オプション）
  # @return [Boolean] 送信成功/失敗
  def send_pdf(pdf_path, subject: nil)
    unless File.exist?(pdf_path)
      puts "❌ PDFファイルが見つかりません: #{pdf_path}"
      return false
    end

    file_size = File.size(pdf_path) / 1024 / 1024.0 # MB
    if file_size > 25
      puts "❌ ファイルサイズが大きすぎます: #{file_size.round(2)}MB (最大25MB)"
      return false
    end

    # デフォルトの件名
    subject ||= "Weekly Bookmarks - #{Date.today.strftime('%Y/%m/%d')}"

    puts "📧 Kindleにメール送信中..."
    puts "   件名: #{subject}"
    puts "   ファイル: #{File.basename(pdf_path)} (#{file_size.round(2)}MB)"
    puts "   送信先: #{@kindle_email}"

    begin
      mail = Mail.new do
        from     ENV['GMAIL_ADDRESS']
        to       ENV['KINDLE_EMAIL']
        subject  subject
        body     "週間ブックマークサマリーをお送りします。\n\nRainpipe より自動送信"

        add_file pdf_path
      end

      mail.delivery_method :smtp, smtp_settings

      puts "🔧 SMTP設定確認:"
      puts "   From: #{ENV['GMAIL_ADDRESS']}"
      puts "   To: #{ENV['KINDLE_EMAIL']}"
      puts "   Subject: #{subject}"

      mail.deliver!

      puts "✅ メール送信成功！"
      true
    rescue Timeout::Error => e
      puts "❌ メール送信失敗（タイムアウト）: #{e.message}"
      puts "   SMTP接続がタイムアウトしました。ネットワークを確認してください。"
      false
    rescue Net::SMTPAuthenticationError => e
      puts "❌ メール送信失敗（認証エラー）: #{e.message}"
      puts "   Gmailの認証情報が正しくありません。"
      puts "   GMAIL_ADDRESS: #{ENV['GMAIL_ADDRESS']}"
      puts "   アプリパスワード設定を確認してください。"
      false
    rescue Net::SMTPServerBusy => e
      puts "❌ メール送信失敗（SMTPサーバビジー）: #{e.message}"
      false
    rescue => e
      puts "❌ メール送信失敗: #{e.class.name}: #{e.message}"
      puts "詳細:"
      puts e.backtrace.first(5).join("\n")
      false
    end
  end

  private

  def validate_credentials!
    missing = []
    missing << 'GMAIL_ADDRESS' unless @gmail_address
    missing << 'GMAIL_APP_PASSWORD' unless @gmail_app_password
    missing << 'KINDLE_EMAIL' unless @kindle_email

    if missing.any?
      raise "環境変数が設定されていません: #{missing.join(', ')}"
    end
  end

  def configure_mail
    settings = smtp_settings
    Mail.defaults do
      delivery_method :smtp, settings
    end
  end

  def smtp_settings
    {
      address:              'smtp.gmail.com',
      port:                 587,
      domain:               'gmail.com',
      user_name:            @gmail_address,
      password:             @gmail_app_password,
      authentication:       'plain',
      enable_starttls_auto: true
    }
  end
end
