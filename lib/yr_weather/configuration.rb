class YrParser::Configuration
  attr_accessor :sitename
  attr_accessor :redis
  attr_accessor :utc_offset
  def initialize
    @sitename   = nil
    @redis      = nil
    @utc_offset = nil
  end
end