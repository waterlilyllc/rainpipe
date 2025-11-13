# content_checker.rb
#
# ContentChecker - ブックマークのサマリー有無を検出
#
# 責務:
#   - 各ブックマークの summary フィールド確認
#   - summary が nil または空の場合をカウント
#   - 未取得ブックマークのリストを返却

class ContentChecker
  # ブックマーク配列からサマリー未取得のものを抽出
  # @param bookmarks [Array<Hash>] ブックマーク配列
  # @return [Array<Hash>] サマリーが nil または empty のブックマーク
  def find_missing_summaries(bookmarks)
    bookmarks.reject { |bookmark| summary_present?(bookmark) }
  end

  # ブックマークのサマリーが存在するかチェック
  # @param bookmark [Hash] ブックマーク
  # @return [Boolean] summary フィールドが存在し、空でない場合は true
  def summary_present?(bookmark)
    summary = bookmark['summary'] || bookmark['content']
    !summary.nil? && summary.to_s.strip.length > 0
  end

  # サマリー有無の統計情報を返す
  # @param bookmarks [Array<Hash>] ブックマーク配列
  # @return [Hash] { total: Integer, with_summary: Integer, without_summary: Integer }
  def summary_statistics(bookmarks)
    without = find_missing_summaries(bookmarks)
    with = bookmarks.length - without.length

    {
      total: bookmarks.length,
      with_summary: with,
      without_summary: without.length
    }
  end
end
