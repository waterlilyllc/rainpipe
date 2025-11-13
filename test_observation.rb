#!/usr/bin/env ruby

require 'dotenv'
Dotenv.load('/var/git/rainpipe/.env')

require_relative 'daily_interest_observer'

observer = DailyInterestObserver.new
observer.run_daily_observation