
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|

  spec.name          = "yr_weather"
  spec.version       = '1.0.3'
  spec.date          = '2021-01-28'
  spec.licenses      = ['MIT']

  spec.authors       = ["renen"]
  spec.email         = ["renen@121.co.za"]

  spec.summary       = 'Easily interpret and use yr.no weather forecast APIs'
  spec.description   = 'Detailed, accurate, forecast data from yr.no. Converts location data into usable forecasts (for different periods), as well as into summaries that are simple to understand, and easy to use.'
  spec.homepage      = 'https://github.com/sasa-solutions/yr_weather'

  spec.files = ['lib/yr_weather.rb']

end
