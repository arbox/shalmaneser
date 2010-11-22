###
# Enduser mode:
# no training, use only precompiled classifiers,
# and remove DB table with test data after applying classifiers
#
# The global variable for this, $ENDUSER_MODE, is expected to 
# be set in the main program, e.g. due to some setting in the 
# experiment file.

##
# if in enduser mode, the given condition must be true,
# otherwise end execution
def in_enduser_mode_ensure(condition)
  if $ENDUSER_MODE and not(condition)
    $stderr.puts "Sorry, this service is unavailable in enduser mode."
    exit 0
  end
end

##
# If in enduser mode, end execution
def in_enduser_mode_unavailable()
  in_enduser_mode_ensure(false)
end

