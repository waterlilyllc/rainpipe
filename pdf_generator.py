#!/usr/bin/env python3
"""
PDF Generator using ReportLab with Japanese font support
Generates larger, more readable PDFs compared to Prawn
"""

import json
import sys
import os
from datetime import datetime
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm, inch
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, Table, TableStyle
from reportlab.lib import colors
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
import textwrap

# Japanese font setup
FONT_PATHS = [
    '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    '/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
]

def find_font():
    """Find available Japanese font"""
    for path in FONT_PATHS:
        if os.path.exists(path):
            return path
    return None

def strip_markdown(text):
    """Remove Markdown formatting"""
    if not isinstance(text, str):
        return str(text)

    import re
    text = re.sub(r'\*\*(.+?)\*\*', r'\1', text)  # **bold** → bold
    text = re.sub(r'\*(.+?)\*', r'\1', text)       # *italic* → italic
    text = re.sub(r'__(.+?)__', r'\1', text)       # __bold__ → bold
    text = re.sub(r'_(.+?)_', r'\1', text)         # _italic_ → italic
    text = re.sub(r'\[(.+?)\]\(.+?\)', r'\1', text)  # [link](url) → link
    text = re.sub(r'^#+\s+(.+)$', r'\1', text, flags=re.MULTILINE)  # # header → header
    text = re.sub(r'^- ', '• ', text, flags=re.MULTILINE)  # - list → • list
    return text

def generate_pdf(data_json, output_path):
    """Generate PDF from JSON data"""

    # Load JSON data
    with open(data_json, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # Find font
    font_path = find_font()
    if font_path:
        try:
            pdfmetrics.registerFont(TTFont('JapaneseFont', font_path))
            font_name = 'JapaneseFont'
            print(f"✅ 日本語フォント使用: {font_path}")
        except Exception as e:
            print(f"⚠️  フォント登録失敗: {e}")
            font_name = 'Helvetica'
    else:
        print("⚠️  日本語フォントが見つかりません")
        font_name = 'Helvetica'

    # Create PDF
    doc = SimpleDocTemplate(
        output_path,
        pagesize=A4,
        rightMargin=1.5*cm,
        leftMargin=1.5*cm,
        topMargin=1.5*cm,
        bottomMargin=1.5*cm
    )

    # Styles
    styles = getSampleStyleSheet()

    # Custom styles with larger fonts
    title_style = ParagraphStyle(
        'CustomTitle',
        parent=styles['Heading1'],
        fontSize=20,
        textColor=colors.HexColor('#1a1a1a'),
        spaceAfter=12,
        fontName=font_name,
        alignment=0  # LEFT
    )

    heading_style = ParagraphStyle(
        'CustomHeading',
        parent=styles['Heading2'],
        fontSize=16,
        textColor=colors.HexColor('#333333'),
        spaceAfter=10,
        fontName=font_name,
        alignment=0
    )

    subheading_style = ParagraphStyle(
        'CustomSubheading',
        parent=styles['Heading3'],
        fontSize=14,
        textColor=colors.HexColor('#555555'),
        spaceAfter=8,
        fontName=font_name,
        alignment=0
    )

    body_style = ParagraphStyle(
        'CustomBody',
        parent=styles['BodyText'],
        fontSize=12,  # Increased from 10
        textColor=colors.HexColor('#333333'),
        spaceAfter=8,
        leading=18,  # Line spacing
        fontName=font_name,
        alignment=0
    )

    list_style = ParagraphStyle(
        'CustomList',
        parent=styles['BodyText'],
        fontSize=12,  # Increased from 10
        textColor=colors.HexColor('#444444'),
        spaceAfter=6,
        leftIndent=20,
        fontName=font_name,
        leading=16
    )

    # Build story
    story = []

    # Header section
    keywords = data.get('keywords', 'N/A')
    date_range = data.get('date_range', {})
    start_date = date_range.get('start', 'N/A')
    end_date = date_range.get('end', 'N/A')

    story.append(Paragraph(f"🔍 {keywords} キーワード検索 PDF", title_style))
    story.append(Paragraph(f"期間: {start_date} ～ {end_date}", body_style))
    story.append(Spacer(1, 0.3*cm))

    # Overall summary
    story.append(PageBreak())
    story.append(Paragraph("📋 全体サマリー", heading_style))
    summary_text = strip_markdown(data.get('overall_summary', data.get('summary', '')))
    for line in summary_text.split('\n'):
        if line.strip():
            if line.strip().startswith('•') or line.strip().startswith('-'):
                story.append(Paragraph(line, list_style))
            else:
                story.append(Paragraph(line, body_style))
    story.append(Spacer(1, 0.3*cm))

    # Related keywords
    story.append(PageBreak())
    story.append(Paragraph("🏷️  関連ワード", heading_style))
    related_clusters = data.get('related_clusters', [])
    for cluster in related_clusters:
        main_topic = cluster.get('main_topic', 'Unknown')
        related_words = cluster.get('related_words', [])
        story.append(Paragraph(f"<b>{main_topic}</b>", subheading_style))
        for word in related_words:
            story.append(Paragraph(f"• {word}", list_style))
        story.append(Spacer(1, 0.2*cm))

    # Analysis
    story.append(PageBreak())
    story.append(Paragraph("💡 考察", heading_style))
    analysis_text = strip_markdown(data.get('analysis', ''))
    for line in analysis_text.split('\n'):
        if line.strip():
            if line.strip().startswith('•') or line.strip().startswith('-'):
                story.append(Paragraph(line, list_style))
            else:
                story.append(Paragraph(line, body_style))
    story.append(Spacer(1, 0.3*cm))

    # Table of contents
    story.append(PageBreak())
    story.append(Paragraph("📑 目次", heading_style))
    bookmarks = data.get('bookmarks', [])
    for i, bookmark in enumerate(bookmarks, 1):
        title = bookmark.get('title', 'Untitled')
        story.append(Paragraph(f"{i}. {title}", list_style))
    story.append(Spacer(1, 0.3*cm))

    # Bookmarks detail
    story.append(PageBreak())
    story.append(Paragraph("📚 ブックマーク詳細", heading_style))

    for i, bookmark in enumerate(bookmarks, 1):
        title = bookmark.get('title', 'Untitled')
        url = bookmark.get('url', '')
        summary = strip_markdown(bookmark.get('summary', ''))

        story.append(Paragraph(f"<b>{i}. {title}</b>", subheading_style))

        if url:
            story.append(Paragraph(f"<font size=10>URL: {url}</font>", body_style))

        story.append(Paragraph("<b>サマリー:</b>", body_style))

        # Add summary with proper line breaks
        for line in summary.split('\n'):
            if line.strip():
                if line.strip().startswith('•') or line.strip().startswith('-'):
                    story.append(Paragraph(line, list_style))
                else:
                    story.append(Paragraph(f"• {line}", list_style))

        story.append(Spacer(1, 0.3*cm))

    # Build PDF
    try:
        doc.build(story)
        file_size = os.path.getsize(output_path)
        file_size_mb = file_size / (1024 * 1024)
        print(f"✅ PDF 生成完了")
        print(f"📄 ファイルパス: {output_path}")
        print(f"💾 ファイルサイズ: {file_size_mb:.2f} MB")
        return True
    except Exception as e:
        print(f"❌ PDF 生成エラー: {e}")
        return False

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("使用法: python3 pdf_generator.py <input_json> <output_pdf>")
        sys.exit(1)

    input_json = sys.argv[1]
    output_pdf = sys.argv[2]

    if not os.path.exists(input_json):
        print(f"❌ ファイルが見つかりません: {input_json}")
        sys.exit(1)

    success = generate_pdf(input_json, output_pdf)
    sys.exit(0 if success else 1)
