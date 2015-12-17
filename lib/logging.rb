require 'logger'
require 'pastel'

# A general logger for all instances.
module Shalmaneser
  LOGGER = Logger.new($stderr)

  LOGGER.level = Logger.const_get(ENV.fetch('LOG_LEVEL', 'INFO'))
  pastel = Pastel.new
  colors = {
    "FATAL" => pastel.red.bold.detach,
    "ERROR" => pastel.red.detach,
    "WARN"  => pastel.yellow.detach,
    "INFO"  => pastel.green.detach,
    "DEBUG" => pastel.white.detach
  }

  LOGGER.formatter = lambda do |severity, datetime, progname, message|
    colorizer = $stderr.tty? ? colors[severity] : ->(s) { s }
    "#{colorizer.call(severity)}: #{message}\n"
  end
end
