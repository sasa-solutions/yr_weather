require 'redis'
require_relative 'lib/yr_weather'

YrWeather.config do |c|
  c.sitename   = 'sasa.solutions;info@sasa.solutions'
  c.utc_offset = '+02:00'
  c.redis      = Redis.new(:host => 'localhost', :port => 6379)
end

parser = YrWeather.new(latitude: -33.9531096408383, longitude: 18.4806353422955)
# pp parser.initialised?
# pp parser.metadata
# pp parser.current
# pp parser.next_12_hours
# pp parser.daily
# pp parser.six_hourly
# pp parser.three_days
# pp parser.week
# pp parser.arrays