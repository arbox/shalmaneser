package edu.berkeley.nlp.PCFGLA;

import edu.berkeley.nlp.ling.Tree;
import java.util.*;

interface Parser {
  public Tree<String> getBestParse(List<String> sentence);
}

