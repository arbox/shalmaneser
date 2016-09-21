##########################################################################
# classifier combination class
class ClassifierCombination

  # new(): just remember experiment file object
  def initialize(exp)
    @exp = exp
  end

  # combine:
  #
  # given a list of classifier results --
  # where a classifier result is a list of strings,
  # one string (= assigned class) for each instance,
  # and where each list of classifier results has the same length --
  # for each instance, combine individual classifier results
  # into a single judgement
  #
  # returns: an array of strings: one combined classifier result,
  # one string (=assigned class) for each instance
  def combine(classifier_results) #array:array:string, list of classifier results

    if classifier_results.length == 1
      return classifier_results.first
    elsif classifier_results.length == 0
      raise "Can't do classification with zero classifiers."
    else
      raise "True classifier combination not implemented yet"
    end
  end
end
