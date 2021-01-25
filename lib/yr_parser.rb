require 'json'
require 'time'
require 'uri'
require "net/http"

class YrParser

  YR_NO    = 'https://api.met.no/weatherapi/locationforecast/1.9/.json'

  ELEMENTS = %w(temperature windDirection windSpeed precipitation symbol minTemperature maxTemperature).map(&:to_sym)

  @latitude     = nil
  @longitude    = nil
  @msl          = nil
  @utc_offset   = nil

  @data         = nil
  @now          = Time.now
  @start_of_day = nil

  # YrParser.get(latitude: -33.9531096408383, longitude: 18.4806353422955)
  def self.get(latitude:, longitude:, msl: 0, utc_offset: '+00:00')
    YrParser.new(latitude: latitude, longitude: longitude, msl: msl, utc_offset: utc_offset).process
  end

  def initialize(latitude:, longitude:, msl:, utc_offset:)
    @latitude     = latitude
    @longitude    = longitude
    @msl          = msl        || 0
    @utc_offset   = utc_offset || nil
    @now          = Time.now.localtime(@utc_offset)  if @utc_offset
    @start_of_day = Time.local(@now.year, @now.month, @now.day)
  end

  def process
    @data = get_forecast_from_yr
    parse.merge(meta_data)

    #     next_run_date = data[:yr_forecast][:meta][:model][:nextrun]                 rescue nil
    #     next_run_date = Time.parse(next_run_date)                                   if next_run_date    
    # data[:last_processed_at] = @now
    # forecast
  end

  private

    def get_forecast_from_yr
      url  = "#{YR_NO}?lat=#{@latitude}&lon=#{@longitude}&msl=#{@msl}"
      uri  = URI(url)
      body = Net::HTTP.get(uri)
      JSON.parse(body, symbolize_names: true)
    end

    def meta_data
      next_run_at  = @data.dig(:meta, :model, :nextrun)
      next_run_at  = Time.parse(next_run_at)   if next_run_at
      generated_at = @data.dig(:meta, :model, :runended)
      generated_at = Time.parse(generated_at)  if generated_at
      {
        requested_at:       @now,
        next_run_at:        next_run_at,
        model_generated_at: generated_at,
      }
    end

    def parse

      result    = { hourly: {}, today: {}, three_days: {}, week: {}, daily: {} }

      key_count = nil
      data = @data.dig(:product, :time).map do |f|

        r = {
          from: f[:from],
          to:   f[:to],
          type: :point,
        }

        ELEMENTS.each do |e|
          node = f[:location][e]
          if node
            r[e] = case e
                      when :precipitation  then node[:value].to_f
                      when :temperature    then node[:value].to_f
                      when :windSpeed      then node[:mps].to_f
                      when :windDirection  then node[:name]
                      when :symbol         then node[:id]
                      when :minTemperature then node[:value].to_f
                      when :maxTemperature then node[:value].to_f
                      else node
                      end
          end
        end

        r[:from] = Time.parse(r[:from])  if r[:from].is_a?(String)
        r[:to]   = Time.parse(r[:to])    if r[:to].is_a?(String)

        r[:type] = :hourly  if (r[:from] +   60*60)==r[:to]
        r[:type] = :six     if (r[:from] + 6*60*60)==r[:to]

        if r[:type]==:point
          key_count = key_count || f[:location].keys.count
          r[:to]    = r[:to] + ( f[:location].keys.count==key_count ? 60*60 : 6*60*60 )
        end

        r[:id]   = "#{r[:from].to_i}:#{r[:to].to_i}"

        r

      end.select { |f| f[:from]>@now }

      point_forecasts      = data.select { |f| f[:type]==:point }
      hourly_forecasts     = data.select { |f| f[:type]==:hourly }
      six_hourly_forecasts = data.select { |f| f[:type]==:six }

      # add precipitation data to hourly forecasts (note that after a while the hourly forecasts become six hourly)
      rain_hourly          = hourly_forecasts.map     { |f| [f[:id], f[:precipitation]] }.to_h
      rain_six             = six_hourly_forecasts.map { |f| [f[:id], f] }.to_h
      point_forecasts      = point_forecasts.each do |f|
        f[:precipitation]  = rain_hourly[f[:id]] || (rain_six[f[:id]] || {})[:precipitation] || 0
        sky                = (rain_six[f[:id]] || {})[:symbol]
        f[:sky]            = sky  if sky
      end

      # hourly
      hourly                           = point_forecasts.first(48)
      result[:hourly][:from_time]      = hourly.map { |f| f[:from] }
      result[:hourly][:temperatures]   = hourly.map { |f| f[:temperature] }
      result[:hourly][:wind_speed]     = hourly.map { |f| f[:windSpeed] }
      result[:hourly][:wind_direction] = hourly.map { |f| f[:windDirection] }
      result[:hourly][:precipitation]  = hourly.map { |f| f[:precipitation] }

      # daily
      result[:daily][:from_time]       = []
      result[:daily][:precipitation]   = []
      result[:daily][:min_temperature] = []
      result[:daily][:max_temperature] = []
      result[:daily][:max_wind_speed]  = []
      result[:daily][:wind_direction]  = []
      7.times do |i|
        start_time = @start_of_day + i * 24*60*60
        hourly = point_forecasts.select { |h| h[:to] > start_time && h[:to]<(start_time+24*60*60) }
        result[:daily][:from_time]       << start_time
        result[:daily][:precipitation]   << hourly.map { |f| f[:precipitation] }.compact.sum
        result[:daily][:min_temperature] << hourly.map { |f| f[:temperature]   }.compact.min
        result[:daily][:max_temperature] << hourly.map { |f| f[:temperature]   }.compact.max
        result[:daily][:max_wind_speed]  << hourly.map { |f| f[:windSpeed]     }.compact.max
        wind_direction                   = hourly.map { |f| f[:windDirection] }
        result[:daily][:wind_direction]  << wind_direction.compact.max_by { |d| wind_direction.count(i) }
      end

      # day_view
      hourly = point_forecasts.select { |h| h[:to]<=(@start_of_day+24*60*60) }
      result[:today][:precipitation]   = result[:daily][:precipitation][0]
      result[:today][:min_temperature] = result[:daily][:min_temperature][0]
      result[:today][:max_temperature] = result[:daily][:max_temperature][0]
      result[:today][:max_wind_speed]  = result[:daily][:max_wind_speed][0]
      result[:today][:wind_direction]  = result[:daily][:wind_direction][0]

      # we need to get the hourly data for the period through to when our six hourly data starts
      hourly = point_forecasts.select { |h| h[:to]<= six_hourly_forecasts.map { |f| f[:from] }.min } 
      precipitation     = hourly.map { |f| f[:precipitation] }.compact.sum
      min_temperature   = hourly.map { |f| f[:temperature]   }.compact.min
      max_temperature   = hourly.map { |f| f[:temperature]   }.compact.max
      wind_speed        = hourly.map { |f| f[:windSpeed]     }.compact.max

      # three day view
      forecasts = point_forecasts.select { |h| h[:from] < (@start_of_day+3*24*60*60) }
      result[:three_days][:precipitation]   = forecasts.map  { |f| f[:precipitation] }.compact.sum + precipitation
      result[:three_days][:min_temperature] = [forecasts.map { |f| f[:temperature]   }.compact.min, min_temperature].compact.min
      result[:three_days][:max_temperature] = [forecasts.map { |f| f[:temperature]   }.compact.max, max_temperature].compact.max
      result[:three_days][:max_wind_speed]  = [forecasts.map { |f| f[:windSpeed]     }.compact.max, wind_speed].compact.max
      
      # week view
      forecasts = point_forecasts.select { |h| h[:from] < (@start_of_day+7*24*60*60) }
      result[:week][:precipitation]   = forecasts.map  { |f| f[:precipitation] }.compact.sum + precipitation
      result[:week][:min_temperature] = [forecasts.map { |f| f[:temperature]   }.compact.min, min_temperature].compact.min
      result[:week][:max_temperature] = [forecasts.map { |f| f[:temperature]   }.compact.max, max_temperature].compact.max
      result[:week][:max_wind_speed]  = [forecasts.map { |f| f[:windSpeed]     }.compact.max, wind_speed].compact.max

      result

    end

end
