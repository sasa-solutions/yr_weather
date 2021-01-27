require 'json'
require 'time'
require 'uri'
require 'net/http'
require 'tmpdir'

class YrWeather

  class << self
    attr_accessor :configuration
  end

  def self.config
    self.configuration ||= YrWeather::Configuration.new
    yield(configuration)
  end

  class YrWeather::Configuration
    attr_accessor :sitename
    attr_accessor :redis
    attr_accessor :utc_offset
    def initialize
      @sitename   = nil
      @redis      = nil
      @utc_offset = nil
    end
  end

  class YrWeather::RedisCache

    def initialize(params)
      @latitude  = params[:latitude]
      @longitude = params[:longitude]
      @redis     = params[:redis]
    end

    def to_cache(data)
      seconds_to_cache = (data[:expires] - Time.now).ceil
      seconds_to_cache = 60  if seconds_to_cache < 60
      @redis.set(redis_key, data.to_json, ex: seconds_to_cache)
    end

    def from_cache
      @redis.get(redis_key)
    end

    private

      def redis_key
        "yr_weather.#{@latitude}.#{@longitude}"
      end

  end

  class YrWeather::FileCache

    def initialize(params)
      @latitude  = params[:latitude]
      @longitude = params[:longitude]
    end

    def to_cache(data)
      file_name = cache_file_name
      File.write(file_name, data.to_json)
    end

    def from_cache
      file_name = cache_file_name
      if File.file?(cache_file_name)
        File.read(file_name)
      end
    end

    private

      def cache_file_name
        file_name = "yr_weather.#{@latitude}.#{@longitude}.tmp"
        File.join(Dir.tmpdir,file_name)
      end

  end


  YR_NO            = 'https://api.met.no/weatherapi/locationforecast/2.0/complete'
  COMPASS_BEARINGS = %w(N NE E SE S SW W NW)
  ARC              = 360.0/COMPASS_BEARINGS.length.to_f

  @latitude     = nil
  @longitude    = nil
  @utc_offset   = nil

  @data         = nil
  @now          = Time.now
  @start_of_day = nil

  # @latitude     = -33.9531096408383
  # @longitude    = 18.4806353422955

  # YrWeather.get(latitude: -33.9531096408383, longitude: 18.4806353422955)
  # def self.get(sitename:, latitude:, longitude:, utc_offset: '+00:00', limit_to: nil)
  #   YrWeather.new(latitude: latitude, longitude: longitude, utc_offset: utc_offset).process(limit_to)
  # end

  def initialize(latitude:, longitude:, utc_offset: nil)
    @latitude     = latitude.round(4)   # yr developer page requests four decimals.
    @longitude    = longitude.round(4)
    @utc_offset   = utc_offset || YrWeather.configuration.utc_offset || '+00:00'
    @now          = Time.now.localtime(@utc_offset)
    @start_of_day = Time.local(@now.year, @now.month, @now.day)
    @start_of_day = @start_of_day + 24*60*60  if @now.hour >= 20
    raise 'yr.no reqiure a sitename and email. See readme for details'  unless YrWeather.configuration.sitename=~/@/
    params        = { latitude: @latitude,  longitude: @longitude, redis: YrWeather.configuration.redis }
    @cacher       = (YrWeather.configuration.redis ? YrWeather::RedisCache.new(params) : YrWeather::FileCache.new(params))
    @data         = load_forecast
  end

  def initialised?
    !@data.nil?
  end

  def raw
    @data
  end

  def metadata
    {
      forecast_updated_at: @data.dig(:properties, :meta, :updated_at),
      downloaded_at:       @data[:downloaded_at],
      expires_at:          @data[:expires],
      start_of_day:        @start_of_day,
      latitude:            @data.dig(:geometry, :coordinates)[1],
      longitude:           @data.dig(:geometry, :coordinates)[0],
      msl:                 @data.dig(:geometry, :coordinates)[2],
      units:               @data.dig(:properties, :meta, :units),
    }
  end

  def current
    time = @data.dig(:properties, :timeseries).map { |e| e[:time] }.reject { |e| e>@now }.sort.last
    node = @data.dig(:properties, :timeseries).select { |e| e[:time]==time }.first
    node.dig(:data, :instant, :details).merge({
      at:                   time,
      symbol_code:          node.dig(:data, :next_1_hours, :summary, :symbol_code),
      precipitation_amount: node.dig(:data, :next_1_hours, :details, :precipitation_amount),
      wind_direction:       degrees_to_bearing(node.dig(:data, :instant, :details, :wind_from_direction)),
      wind_description:     wind_description(node.dig(:data, :instant, :details, :wind_speed)),
      wind_speed_knots:     to_knots(node.dig(:data, :instant, :details, :wind_speed)),
    })
  end

  def next_12_hours
    range = @now..(@now + 12*60*60)
    forecast(range).merge(symbol: symbol_code_hourly(range))
  end

  def three_days
    range = @now..(@now + 3*24*60*60)
    forecast(range).tap { |hs| hs.delete(:wind_description) }
  end

  def week
    range = @now..(@now + 7*24*60*60)
    forecast(range).tap { |hs| hs.delete(:wind_description) }
  end

  def six_hourly
    t = @start_of_day
    loop do
      if (t + 6*60*60) > Time.now
        break
      else
        t = t + 6*60*60
      end
    end
    nodes = @data.dig(:properties, :timeseries).select { |e| e.dig(:data, :next_6_hours) }.map { |e| [e[:time], e] }.to_h
    nodes = 20.times.map do |i|
      nodes[t + i*6*60*60]
    end.compact.map do |node|
      {
        at:                   node.dig(:time),
        temperature_maximum:  node.dig(:data, :next_6_hours, :details, :air_temperature_max),
        temperature_minimum:  node.dig(:data, :next_6_hours, :details, :air_temperature_min),
        wind_speed_max:       node.dig(:data, :instant, :details, :wind_speed),
        wind_speed_max_knots: to_knots(node.dig(:data, :instant, :details, :wind_speed)),
        wind_direction:       degrees_to_bearing(node.dig(:data, :instant, :details, :wind_from_direction)),
        wind_description:     node.dig(:data, :instant, :details, :wind_speed),
        precipitation:        node.dig(:data, :next_6_hours, :details, :precipitation_amount),
        symbol_code:          node.dig(:data, :next_6_hours, :summary, :symbol_code),
      }
    end
  end

  def daily
    8.times.map do |day|
      start = @start_of_day + day*24*60*60
      range = start..(start + 24*60*60)
      forecast(range).merge(at: start)
    end
  end

  def arrays
    nodes  = @data.dig(:properties, :timeseries)
    points = nodes.map do |node|
      {
        at:            node[:time],
        temperature:   node.dig(:data, :instant, :details, :air_temperature),
        wind_speed:    node.dig(:data, :instant, :details, :wind_speed),
        precipitation: node.dig(:data, :next_1_hours, :details, :precipitation_amount) || node.dig(:data, :next_6_hours, :details, :precipitation_amount),
        hours:         ( node.dig(:data, :next_1_hours, :details, :precipitation_amount) ? 1 : 6),
      }
    end
    results = {
      at:               [],
      temperature:      [],
      wind_speed:       [],
      wind_speed_knots: [],
      precipitation:    [],
      hours:            [],
    }
    points.each do |point|
      point[:hours].times do |i|
        results[:at]               << point[:at] + i*60*60
        results[:temperature]      << point[:temperature]
        results[:wind_speed]       << point[:wind_speed]
        results[:wind_speed_knots] << to_knots(point[:wind_speed])
        results[:precipitation]    << ((point[:precipitation].to_f) / (point[:hours].to_f)).round(1)
      end
    end
    results
  end


  private

    def forecast(range)
      nodes  = nodes_for_range(range)
      detail = nodes.map { |e| e.dig(:data, :instant, :details) }
      wind_directions = detail.map { |e| degrees_to_bearing(e[:wind_from_direction]) }
      {
        temperature_maximum:  detail.map { |e| e[:air_temperature] }.max,
        temperature_minimum:  detail.map { |e| e[:air_temperature] }.min,
        wind_speed_max:       detail.map { |e| e[:wind_speed] }.max,
        wind_speed_max_knots: to_knots(detail.map { |e| e[:wind_speed] }.max),
        wind_description:     wind_description(detail.map { |e| e[:wind_speed] }.max),
        wind_direction:       wind_directions.max_by { |e| wind_directions.count(e) },
        precipitation:        precipitation(range, nodes)
      }
    end

    def precipitation(range, nodes)
      next_time = range.first
      end_time  = range.last
      nodes.map do |node|
        mm = nil
        if node[:time] >= next_time
          [1,6,12].each do |i|
            mm = node.dig(:data, "next_#{i}_hours".to_sym, :details, :precipitation_amount)
            if mm
              next_time = next_time + i*60*60
              break
            end
          end
        end
        mm
      end.sum
    end

    def symbol_code_hourly(range)
      symbols = nodes_for_range(@now..(@now + 12*60*60)).map { |e| e.dig(:data, :next_1_hours, :summary, :symbol_code) }
      symbols.max_by { |e| symbols.count(e) }
    end

    def nodes_for_range(range)
      @data.dig(:properties, :timeseries).select { |e| range.include?(e[:time]) }
    end

    def degrees_to_bearing(degrees)
      COMPASS_BEARINGS[(degrees.to_f/ARC).round % COMPASS_BEARINGS.length]
    end

    def to_knots(ms)
      ( ms ? (ms*1.943844).round(1) : nil )
    end

    def wind_description(speed)
      ms = speed.round(1)
      case ms
      when (0..(0.5))       then 'calm'
      when ((0.5)..(1.5))   then 'light air'
      when ((1.6)..(3.3))   then 'light breeze'
      when ((4)..(5.5))     then 'gentle breeze'
      when ((5.5)..(7.9))   then 'moderate breeze'
      when ((8)..(10.7))    then 'fresh breeze'
      when ((10.8)..(13.8)) then 'strong breeze'
      when ((13.9)..(17.1)) then 'high wind,'
      when ((17.2)..(20.7)) then 'gale'
      when ((20.8)..(24.4)) then 'strong gale'
      when ((24.5)..(28.4)) then 'storm'
      when ((28.5)..(32.6)) then 'violent storm'
      else 'hurricane force'
      end
    end


    def load_forecast
      data  = @cacher.from_cache
      data = parse_json(data)  if !data.nil?
      if data.nil?
        data  = forecast_from_yr
        @cacher.to_cache(data)
      end
      data
    end

    def parse_json(json)
      parse_times(JSON.parse(json, symbolize_names: true))
    end


    def parse_times(hash)
      if (hash.is_a?(Hash))
        hash.transform_values do |v|
          if v.is_a?(Hash)
            parse_times(v)
          elsif v.is_a?(Array)
            v.map { |e| parse_times(e) }
          elsif v.is_a?(String) && v=~/\d{4}-\d\d-\d\d[\sT]\d\d:\d\d:\d\d/
            Time.parse(v)
            # r = Time.parse(v) rescue nil
            # (r || v)
          else
            v
          end 
        end
      else
        hash
      end
    end



    # def parse
    #   %w(hourly today tomorrow three_days week daily daily_objects hourly_objects).map(&:to_sym).map { |e| [e, self.send(e)] }
    # end

    def forecast_from_yr
      url                     = URI("#{YR_NO}?lat=#{@latitude}&lon=#{@longitude}")
      https                   = Net::HTTP.new(url.host, url.port)
      https.use_ssl           = true
      request                 = Net::HTTP::Get.new(url)
      request["Content-Type"] = "application/json"
      request["User-Agent"]   = YrWeather.configuration.sitename
      response                = https.request(request)
      {
        expires:       Time.parse(response['expires']),
        last_modified: Time.parse(response['last-modified']),
        downloaded_at: Time.now,
      }.merge(parse_json(response.body))
    end


end