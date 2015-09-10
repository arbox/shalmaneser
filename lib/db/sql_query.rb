# class SQLQuery
# KE, SP 27.1.05
#
# provides static methods that generate SQL queries as strings
# that can then be passed on to the database

require "common/ruby_class_extensions"

# require "common/RosyConventions"

class SQLQuery


  #####
  # SQLQuery.insert
  #
  # query created: insert a new row into a given database table
  # the new row is given as a list of pairs [column_name, value]
  #
  # returns: string
  def SQLQuery.insert(table_name, # string: table name
                      field_value_pairs) # array: string*object [column_name, cell_value]

    # example:
    # insert into table01 (field01,field02,field03,field04,field05) values
    #  (2, 'second', 'another', '1999-10-23', '10:30:00');

    string = "INSERT INTO " + table_name + "("+
             field_value_pairs.map { |column_name, cell_value|
      column_name
    }.join(",") +
             ") VALUES (" +
             field_value_pairs.map { |column_name, cell_value|
      if cell_value.nil?
        raise "SQL query construction error: Nil value for column " + column_name
      end
      SQLQuery.stringify_value(cell_value)
    }.join(",") + ");"

    return string
  end

  #####
  # SQLQuery.select
  #
  # query created: select from given database tables
  # all column entries that conform to the given description:
  # - names of the columns to be selected (or the string "*")
  # - only those column entries where the row matches the given
  #   row restrictions: [column_name, column_value] => WHERE column_name IS column_value
  # - optionally, at most N lines => LIMIT N
  # - If more than one DB table is named, make a join
  # - Value restrictions: If it doesn't say which DB table to use,
  #   use the first one listed in table_col_pairs
  #
  # Use with only one database table creates queries like e.g.
  #   SELECT column1, column2 FROM table WHERE column3=val3 AND column4!=val4
  #
  # or:
  #   SELECT DISTINCT column1, column2 FROM table WHERE column3=val3 AND column4!=val4 LIMIT 10
  #
  # Use with 2 SelectTableAndColumns entries creates queries like
  #  SELECT table1.column1, table1.column2 FROM table1, table2 WHERE table1.column1=val3 AND table1.id=table2.id
  #
  #
  # returns: string.
  #    raises an error if no columns at all are selected
  def SQLQuery.select(table_col_pairs, # Array: SelectTableAndColumns
                      row_restrictions, # array: ValueRestriction objects
                      var_hash = {})  # further parameters:
    # line_limit: integer: select at most N lines. if nil, all lines are chosen
    # distinct: boolean: return each tuple only once. if nil or false, duplicates are kept

    if table_col_pairs.empty?
      raise "Zero tables to select from"
    end

    ## SELECT
    string = "SELECT "

    if var_hash["distinct"]
      # unique return values?
      string << "DISTINCT "
    end

    ## column names to select: iterate through table/col pairs
    at_least_one_column_selected = false
    string << table_col_pairs.map { |tc|

      if tc.columns == "*"
        # all columns from this table
        at_least_one_column_selected = true
        SQLQuery.prepend_tablename(tc.table_obj.table_name, "*")

      elsif tc.columns.class.to_s == "Array" and not(tc.columns.empty?)
        # at least one column from this table
        at_least_one_column_selected = true

        tc.columns.map { |c|
          if c.nil? or c.empty?
            raise "Got nil/empty value within the column name list"
          end

          SQLQuery.prepend_tablename(tc.table_obj.table_name, c)
        }.join(", " )

      else
        # no columns from this table
        nil
      end
    }.compact.join(", ")


    if not(at_least_one_column_selected)
      raise "Empty select: zero columns selected"
    end

    ## FROM table name(s)
    string += " FROM " + table_col_pairs.map { |tc| tc.table_obj.table_name }.join(", ")

    ## WHERE row_restrictions
    unless row_restrictions.nil? or row_restrictions.empty?
      string += " WHERE "+row_restrictions.map { |restr_obj|
        # get the actual restriction out of its object
        # form: name(string) eqsymb(string: =, !=) value(object)
        name, eqsymb, value = restr_obj.get()
        if value.nil?
          raise "SQL query construction error: Nil value for column " + name
        end
        unless restr_obj.val_is_variable
          # value is a value, not a variable name
          value = SQLQuery.stringify_value(value)
        end
        if restr_obj.table_name_included
          # name already includes table name, if needed
          name + eqsymb + value
        else
          # prepend name of first table in table_col_pairs
          SQLQuery.prepend_tablename(table_col_pairs.first.table_obj.table_name(), name) + eqsymb + value
        end
      }.join(" AND ")
    end


    ## LIMIT at_most_that_many_lines
    if var_hash["line_limit"]
      string += " LIMIT " + var_hash["line_limit"].to_s
    end
    string += ";"

    return string
  end

  #####
  # SQLQuery.update
  #
  # query created: overwrite several cells in possibly multiple rows of a
  # database table with new values
  # rows are selected via row restrictions
  #
  # returns: nothing

  # update table01 set field04=19991022, field05=062218 where field01=1;

  def SQLQuery.update(table_name, # string: table name
                      field_value_pairs, # array: string*Object: column name and value
                      row_restrictions # array: ValueRestriction objects: column name and value restriction
                     )
    string = "UPDATE "+table_name+" SET "+
             field_value_pairs.map {|field,value|
      if value.nil?
        raise "SQL query construction error: Nil value for column " + field
      end
      field+"="+SQLQuery.stringify_value(value)}.join(", ") +
             " WHERE "+row_restrictions.map {|restr_obj|
      # get the actual restriction out of its object
      # form: name(string) eqsymb(string: =, !=) value(object)
      name, eqsymb, value = restr_obj.get()
      if value.nil?
        raise "SQL query construction error: Nil value for column " + name
      end
      name + eqsymb + SQLQuery.stringify_value(value)
    }.join(" AND ")
    string += ";"
    return string
  end


  #####
  # SQLQuery.add_columns
  #
  # query created: extend given table by
  # one or more columns given by their names and formats
  #
  # returns: string
  def SQLQuery.add_columns(table_name,  # string: table name
                           column_formats) # array: array: string*string [column_name,column_format]

    string = "ALTER TABLE " + table_name
    string << column_formats.map { |column_name, column_format|
      " ADD COLUMN " + column_name + " " + column_format
    }.join(", ")

    string << ";"

    return string
  end

  #####
  # SQLQuery.stringify ensures that value is a properly
  # escaped SQL string
  #
  # returns: string
  def SQLQuery.stringify_value(value) # object
    if value.class == String
      return "'" + value.gsub(/"/,"QQUOT0").gsub(/'/, "QQUOT1").gsub(/`/, "QQUOT2") + "'"
    else
      return value.to_s
    end
  end

  #####
  # SQLQuery.unstringify undoes the result of stringify_value
  # please apply only to strings
  def SQLQuery.unstringify_value(value) # string
    value.gsub(/QQUOT0/, '"').gsub(/QQUOT1/, "'").gsub(/QQUOT2/, "`")
  end

  ####
  # SQLQuery.prepend_tablename
  #
  # auxiliary method for select:
  # prepend table name to column name
  # and if the column name does not already include a table name
  def SQLQuery.prepend_tablename(table_name,
                                 column_name)
    if not(column_name.include?("."))
      return table_name + "." + column_name
    else
      return column_name
    end
  end
end
