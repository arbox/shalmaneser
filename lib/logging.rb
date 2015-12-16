require 'logger'

# A general logger for all instances.
module Shalmaneser
  LOGGER = Logger.new($stderr)
  LOGGER.level = Logger.const_get(ENV.fetch('LOG_LEVEL', 'INFO'))
end
