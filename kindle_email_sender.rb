require 'mail'
require_relative 'progress_reporter'
require_relative 'progress_callback'

class KindleEmailSender
  def initialize(progress_callback = nil)
    @gmail_address = ENV['GMAIL_ADDRESS']
    @gmail_app_password = ENV['GMAIL_APP_PASSWORD']
    @kindle_emails = [ENV['KINDLE_EMAIL'], ENV['KINDLE_EMAIL_2']].compact.reject(&:empty?)
    @progress_callback = progress_callback || ProgressCallback.null_callback

    validate_credentials!
    configure_mail
  end

  # PDFをKindleに送信
  # @param pdf_path [String] PDFファイルのパス
  # @param subject [String] メールの件名（オプション）
  # @return [Boolean] 送信成功/失敗
  def send_pdf(pdf_path, subject: nil)
    unless File.exist?(pdf_path)
      ProgressReporter.error("PDFファイルが見つかりません", pdf_path)
      @progress_callback.report_event('error', "PDFファイルが見つかりません: #{pdf_path}")
      return false
    end

    file_size = File.size(pdf_path) / 1024 / 1024.0 # MB
    if file_size > 25
      ProgressReporter.error("ファイルサイズ超過", "#{file_size.round(2)}MB（最大25MB）")
      @progress_callback.report_event('error', "ファイルサイズ超過: #{file_size.round(2)}MB")
      return false
    end

    # デフォルトの件名
    subject ||= "Weekly Bookmarks - #{Date.today.strftime('%Y/%m/%d')}"

    ProgressReporter.progress(nil, "Kindle メール送信中", :email)
    ProgressReporter.indented("件名: #{subject}")
    ProgressReporter.indented("ファイル: #{File.basename(pdf_path)} (#{file_size.round(2)}MB)")
    ProgressReporter.indented("送信先: #{@kindle_emails.join(', ')}")

    # Task 3.5: Progress callback に email_sending ステージを報告
    @progress_callback.report_stage('email_sending', 95, {
      recipient: @kindle_emails.join(', '),
      file_size_mb: file_size,
      subject: subject
    })

    success_count = 0
    @kindle_emails.each do |kindle_email|
      begin
        mail = Mail.new do |m|
          m.from     ENV['GMAIL_ADDRESS']
          m.to       kindle_email
          m.subject  subject
          m.body     "週間ブックマークサマリーをお送りします。\n\nRainpipe より自動送信"

          m.add_file pdf_path
        end

        mail.delivery_method :smtp, smtp_settings

        mail.deliver!

        ProgressReporter.success("送信成功: #{kindle_email}")
        success_count += 1
      rescue => e
        ProgressReporter.error("送信失敗: #{kindle_email}", e.message)
      end
    end

    if success_count == @kindle_emails.length
      ProgressReporter.success("全#{success_count}件 送信完了！")
    elsif success_count > 0
      ProgressReporter.progress(nil, "#{success_count}/#{@kindle_emails.length}件 送信成功")
    end

    # Task 3.5: Progress callback にメール送信完了イベントを報告
    @progress_callback.report_stage('email_sending', 100, {
      recipient: @kindle_emails.join(', '),
      status: success_count > 0 ? 'success' : 'failed'
    })

    success_count > 0
  end

  private

  def validate_credentials!
    missing = []
    missing << 'GMAIL_ADDRESS' unless @gmail_address
    missing << 'GMAIL_APP_PASSWORD' unless @gmail_app_password
    missing << 'KINDLE_EMAIL' if @kindle_emails.empty?

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
