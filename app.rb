require 'sinatra'
require 'dotenv/load'
require_relative 'raindrop_client'
require_relative 'helpers'

get '/' do
  @week_start = Date.today.beginning_of_week
  @week_end = @week_start + 6
  @bookmarks = RaindropClient.new.get_weekly_bookmarks(@week_start, @week_end)
  erb :week
end

get '/week/:date' do
  @week_start = Date.parse(params[:date])
  @week_end = @week_start + 6
  @bookmarks = RaindropClient.new.get_weekly_bookmarks(@week_start, @week_end)
  erb :week
end

get '/tag/:tag' do
  @tag = params[:tag]
  @bookmarks = RaindropClient.new.get_bookmarks_by_tag(@tag)
  erb :week
end