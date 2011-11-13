require "fred/FredFeatures"

def determine_training_senses(lemma, exp, lemmas_and_senses_obj, split_id)
  if split_id
    # oh no, we're splitting the dataset into random training and test portions.
    # this means that we actually have to look into the training part of the data to 
    # determine the number of training senses
    senses_hash= Hash.new()

    reader = AnswerKeyAccess.new(exp, "train", lemma, "r", split_id, "train")
    reader.each  { |lemma, pos, ids, sids, gold_senses, transformed_gold_senses|
      gold_senses.each { |s| senses_hash[s] = true }
    }
    return senses_hash.keys()

  else
    # we're using separate test data.
    # so we can just look up the number of training senses 
    # in the lemmas_and_senses object
    senses = lemmas_and_senses_obj.get_senses(lemma)
    if senses
      return senses
    else
      return []
    end
  end
end
