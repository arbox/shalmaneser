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

def get_db_interface(exp, # experiment file object with 'dbtype' entry
                     dir = nil, # string: Shalmaneser directory (used by SQLite only)
                     identifier = nil) # string: identifier of the data (SQLite)

  case exp.get("dbtype")
  when "mysql"
    begin
      require 'db/db_mysql'
    rescue
      $stderr.puts "Error loading DB interface."
      $stderr.puts "Make sure you have the Ruby MySQL package installed."
      exit 1
    end
    return DBMySQL.new(exp)
    
  when "sqlite"
    begin
      require 'db/db_sqlite'
    rescue
      $stderr.puts "Error loading DB interface."
      $stderr.puts "Make sure you have the Ruby SQLite package installed."
      exit 1
    end
    return DBSQLite.new(exp, dir, identifier)
    
  else
    $stderr.puts "Error: database type needs to be either 'mysql' or 'sqlite'."
    $stderr.puts "Please set parameter 'dbtype' in the experiment file accordingly."
    exit 1
  end
end


