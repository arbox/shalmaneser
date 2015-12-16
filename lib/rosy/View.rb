# class DBView
# KE, SP 27.1.05
#
# builds on class DBTable, which offers access to a database table
# extract views of the table (select columns, select rows)
# and offers access methods for these views.
# Rows of the table can be returned either as hashes or as arrays.
#
# There is a special column of the table (the name of which we get in the new() method),
# the gold column.
# It can be returned directly, or modified by some "dynamic feature object",
# and its value (modified or unmodified) will always be last in the array representation of a row.

require 'db/sql_query'
require "ruby_class_extensions"
# require "RosyConventions"
require 'db/select_table_and_columns'

class DBView

  ################
  # new
  #
  # prepare a view.
  # given a list of DB tables to access, each with its
  #   set of features to be returned in the view,
  # a set of value restrictions,
  # the name of the gold feature,
  # and a list of objects that manipulate the gold feature into alternate
  # gold features.
  #
  # value_restrictions restricts the view to those rows for which the value restrictions hold,
  # e.g. only those rows where frame = Bla, or only those rows where partofspeech = Blupp
  #
  # The view remembers the indices of the _first_ table in the list of tables
  # it is given.
  #
  # A standard dynamic ID can be given: DynGold objects all have an id() method,
  # which returns a string, by which the use of the object can be requested
  # of the view. If no dynamic ID is given below in methods each_array,
  # each_hash, each_sentence, the system falls back to the standard dynamic ID.
  # if none is given here, the standard DynGold object is the one that doesn't
  # change the gold column. If one is given here, it will be used by default
  # when no ID is given in each_hash, each_array, each_sentence
  #
  # The last parameter is a hash with the following optional entries:
  #  "gold":
  #     string: name of the gold feature
  #     If you want the gold feature to be mapped using a DynGold object,
  #     you need to specify this parameter -- and you need to include
  #     the gold feature in some feature_list.
  #     Warning: if a feature of this name appears in several of the
  #     feature lists, only the first one is mapped
  #  "dynamic_feature_list":
  #     array:DynGold objects, list of objects that map the gold feature
  #     to a different feature value (e.g. to "FE", "NONE")
  #     DynGold objects have one method make: string -> string
  #     that maps one gold feature,
  #     and one method id: -> string that gives an ID unique to this DynGold class
  #     and by which this DynGold class can be chosen.
  # "standard_dyngold_id":
  #     string: standard DynGold object ID (see above)
  # "sentence_id_feature":
  #      string: feature name for the sentence ID column, needed for each_sentence()
  #
  # further parameters that are passed on to SQLQuery.select: see there

  def initialize(table_col_pairs, # array:SelectTableAndColumns objects
                 value_restrictions, # array:ValueRestriction objects
                 db_obj, # MySql object (from mysql.rb) that already has access to the correct database
                 parameters = {}) # hash with further parameters: see above

    @db_obj = db_obj
    @table_col_pairs = table_col_pairs
    @parameters = parameters

    # view empty?
    if @table_col_pairs.empty? or
        @table_col_pairs.big_and { |tc| tc.columns.class.to_s == "Array" and tc.columns.empty? }
      @view_empty = true
      return
    else
      @view_empty = false
    end

    # okay, we can make the view, it contains at least one table and
    # at least one column:
    # do one view for all columns requested, and one for the indices of each table
    #
    # @main_table is a DBResult object
    @main_table = execute_command(SQLQuery.select(@table_col_pairs,
                                                  value_restrictions, parameters))

    # index_tables: Hash: table name =>  DBResult object
    @index_tables = Hash.new
    table_col_pairs.each_with_index { |tc, index|
      # read index column of this table, add all the other tables
      # with empty column lists
      index_table_col_pairs = @table_col_pairs.map_with_index { |other_tc, other_index|
        if other_index == index
        # the current table
          SelectTableAndColumns.new(tc.table_obj,
                                    [tc.table_obj.index_name])
        else
          # other table: keep just the table, not the columns
          SelectTableAndColumns.new(other_tc.table_obj, nil)
        end
      }
      @index_tables[tc.table_obj.table_name] = execute_command(SQLQuery.select(index_table_col_pairs,
                                                                               value_restrictions, parameters))
    }

    # map gold to something else?
    # yes, if parameters[gold] has been set
    if @parameters["gold"]
      @map_gold = true
      # remember which column in the DB table is the gold column
      @gold_index = column_names().index(@parameters["gold"])
    else
      @map_gold = false
    end
  end

  ################
  # close
  #
  # to be called when the view is no longer needed:
  # frees the DBResult objects underlying this view
  def close()
    unless @view_empty
      @main_table.free()
      @index_tables.each_value { |t| t.free() }
    end
  end

  ################
  # write_to_file
  #
  # writes instances to a file
  # each instance given as a comma-separated list of features
  # The features are the ones given in my_feature_list
  # (parameter to the new() method) above, in that order,
  # plus (dynamic) gold, which is last.
  #
  # guarantees that comma is used only to separate features -- but no other
  # changes in the feature values
  def write_to_file(file, # stream to write to
                    dyn_gold_id=nil) #string: ID of a DynGold object from the dynamic_feature_list.
                                     # if nil, main gold is used

    each_instance_s(dyn_gold_id) { |instance_string|
      file.puts instance_string
    }
  end


  ################
  # each_instance_s
  #
  # yields each instance as a string:
  # a comma-separated list of features
  # The features are the ones given in my_feature_list
  # (parameter to the new() method) above, in that order,
  # plus (dynamic) gold, which is last.
  #
  # guarantees that comma is used only to separate features -- but no other
  # changes in the feature values
  def each_instance_s(dyn_gold_id=nil) #string: ID of a DynGold object from the dynamic_feature_list.
                                     # if nil, main gold is used
    each_array(dyn_gold_id) {|array|
      yield array.map { |entry| entry.to_s.gsub(/,/, "COMMA") }.join(",")
    }
  end

  ################
  # each_hash
  #
  # iterates over hashes representing rows
  #          in each row, there is a gold key/value pair
  #          specified by the optional argument dyn_gold_id.
  #          which is the string ID of a  DynGold object
  #          from the dynamic_feature_list.
  #          If arg is not present, main gold is used
  #
  #          The key for the gold is the dyn_gold_id
  #          If that is nil, the key is 'gold'
  #
  # yields: hashes column_name -> column_value
  def each_hash(dyn_gold_id=nil) #string: ID of a DynGold object from the dynamic_feature_list, or nil
    if @view_empty
      return
    end
    if @map_gold
      dyn_gold_obj = fetch_dyn_gold_obj(dyn_gold_id)
    end
    @main_table.reset()

    @main_table.each_hash { |row_hash|
      if @map_gold
        row_hash[@parameters["gold"]] = dyn_gold_obj.make(row_hash[@parameters["gold"]])
      end

      yield row_hash
    }
  end

  ################
  # each_array
  #
  # iterates over arrays representing rows
  #          the last item of each row is the gold column
  #          selected by the optional argument dyn_gold_id.
  #          which is the string ID of a  DynGold object
  #          from the dynamic_feature_list.
  #          If arg is not present, main gold is used
  #
  # yields: arrays of column values,
  #         values are in the order of my_feature_list given
  #         to the new() method, (dynamic) gold is last
  def each_array(dyn_gold_id=nil) #string: ID of a DynGold object from the dynamic_feature_list, or nil

    if @view_empty
      return
    end
    if @map_gold
      dyn_gold_obj = fetch_dyn_gold_obj(dyn_gold_id)
    end
    @main_table.reset()

    @main_table.each {|row|
      if @gold_index
        gold = row.delete_at(@gold_index)
        if @map_gold
          row.push dyn_gold_obj.make(gold)
        else
          row.push gold
        end
      end

      yield row
    }
  end

  ################
  # update_column
  #
  # update a column for all rows of this view
  #
  # Given a column name to be updated, and a list of value tuples,
  # update each row of the view, or rather the appropriate column of each row of the view,
  # with values for that row.
  #
  # the list has the same length as the view, as there must be a value tuple
  # for each row of the view.
  #
  # returns: nothing
  def update_column(name, # string: column name
                    values) # array of Objects

    if @view_empty
      raise "Cannot update empty view"
    end

    # find the first table in @table_col_pairs that has
    # a column with this name
    # and update that column
    @table_col_pairs.each { |tc|
      if (tc.columns.class.to_s == "Array" and tc.columns.include? name) or
          (tc.columns == "*" and tc.table_obj.list_column_names().include? name)

        table_name = tc.table_obj.table_name

        # sanity check: number of update entries must match
        # number of entries in this view
        unless values.length() == @index_tables[table_name].num_rows()
          $stderr.puts "Error: length of value array (#{values.length}) is not equal to length of view (#{@index_tables[table_name].num_rows})!"
          exit 1
        end

        @index_tables[tc.table_obj.table_name].reset()

        values.each { |value|
          index = @index_tables[table_name].fetch_row().first
          tc.table_obj.update_row(index, [[name, value]])
        }

        return
      end
    }

    # no match found
    $stderr.puts "View.rb Error: cannot update a column that is not in this view: #{name}"
    exit 1
  end


  ################
  # each_sentence
  #
  # like each_hash, but it groups the row hashes sentence-wise
  # sentence boundaries in the view are detected by the change in a
  # special column describing sentence IDs
  #
  # also needs a dyngold object id
  #
  # returns: an array of hashes column_name -> column_value
  def each_sentence(dyn_gold_id = nil)  # string: ID of a DynGold object from the dynamic_feature_list, or nil

    # sanity check 1: need to know what the sentence ID is
    unless @parameters["sentence_id_feature"]
      raise "I need the name of the sentence ID feature for each_sentence()"
    end
    # sanity check 2: the view needs to include the sentence ID
    unless column_names().include? @parameters["sentence_id_feature"]
      raise "View.each_sentence: Cannot do this without sentence ID in the view"
    end

    last_sent_id = nil
    sentence = Array.new
    each_hash(dyn_gold_id) {|row_hash|
      if last_sent_id != row_hash[@parameters["sentence_id_feature"]] and
          (!(last_sent_id.nil?))
        yield sentence
        sentence = Array.new
      end
      last_sent_id = row_hash[@parameters["sentence_id_feature"]]
      sentence << row_hash
    }
    unless sentence.empty?
      yield sentence
    end
  end

  ######################
  # length
  #
  # returns the length of the view: the number of its rows
  def length()
    return @index_tables[@table_col_pairs.first.table_obj.table_name].num_rows
  end

  ###
  private

  ################
  # column_names
  #
  # returns: array:string
  #   the list of column names for this view
  #   in the right order
  def column_names()
    if @view_empty
      return []
    else
      return @main_table.list_column_names()
    end
  end

  ######
  # fetch_dyn_gold_obj
  #
  # given an ID of a gold object, look for the DynGold object
  # with this ID in the dynamic_feature_list and return it
  # If the ID is nil, use the standard dynamic gold ID that
  # has been set in the new() method.
  # If that is nil too, take the non-modified gold as a
  # default: return a dummy object with a make() method
  # that just returns its parameter.
  #
  # returns: object offering a make() method

  def fetch_dyn_gold_obj(dyn_gold_id) # string or nil
    # find a DynGold object that will transform the gold column
    if dyn_gold_id.nil?
      dyn_gold_id = @parameters["standard_dyngold_id"]
    end

    dyn_gold_obj = "we need an object that can do 'make'"
    if dyn_gold_id
      unless @parameters["dynamic_feature_list"]
        raise "No dynamic features given"
      end

      dyn_gold_obj = @parameters["dynamic_feature_list"].detect { |obj|
        obj.id() == dyn_gold_id
      }
      if dyn_gold_obj.nil?
        $stderr.puts "View.rb: Unknown DynGold ID " + dyn_gold_id
        $stderr.puts "Using unchanged gold"
        dyn_gold_id = nil
      end
    end

    unless dyn_gold_id
      # no dynamic gold ID: use unchanged gold by default
      class << dyn_gold_obj
        def make(x)
          x
        end
        def id()
          return "gold"
        end
      end
    end
    return dyn_gold_obj
  end

  def execute_command(command)
    begin
      return @db_obj.query(command)
    rescue MysqlError => e
      $stderr.puts "Error executing SQL query. Command was:\n" + command
      $stderr.puts "Error code: #{e.errno}"
      $stderr.puts "Error message: #{e.error}"
      raise e
    end
  end

end
