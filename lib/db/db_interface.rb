# DBInterface
#
# Okay, things are getting somewhat complicated here with all
# the DB classes, but this is how it all fits together:
#
# - DBWrapper: abstract class describing the DB interface
# - DBMySQL, DBSQLite: subclasses of DBWrapper, for MySQL
#     and SQLite, respectively
# - DBInterface: class to be used from outside,
#     decides ( based on the experiment file) whether to use
#     MySQL or SQLite and makes an object of the right kind,
#     'require'-ing either DBMySQL or DBSQLite, but not both,
#     because the right ruby packages might not be installed
#     for both SQL systems
# @note This class will be obsolete if we delete MySQL.
require 'logging'

module Shalmaneser
  module DB
    class DBInterface
      # @param  exp experiment file object with 'dbtype' entry
      # @param  dir [String] Shalmaneser directory (used by SQLite only)
      # @param  identifier [String] identifier of the data (SQLite)
      def self.get_db_interface(exp, dir = nil, identifier = nil)
        case exp.get('dbtype')
        when 'mysql'
          begin
            require_relative 'db_mysql'
          rescue => e
            LOGGER.fatal 'Error loading DB interface.'
            LOGGER.fatal 'Make sure you have the Ruby MySQL package installed.'
            raise e
          end

          return DBMySQL.new(exp)
        when 'sqlite'
          begin
            require_relative 'db_sqlite'
          rescue => e
            LOGGER.fatal 'Error loading DB interface.'
            LOGGER.fatal 'Make sure you have the Ruby SQLite package installed.'
            raise e
          end

          return DBSQLite.new(exp, dir, identifier)
        else
          # @todo AB: [2016-09-09 Fri 16:33]
          #   This is an assertion which should be done in the OptionParser.
          LOGGER.fatal('Error: database type needs to be either "mysql" or "sqlite".')
          LOGGER.fatal('Please set parameter "dbtype" in the experiment file accordingly.')
          raise
        end
      end
    end
  end
end
