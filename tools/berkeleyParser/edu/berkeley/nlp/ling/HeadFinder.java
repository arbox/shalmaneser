package edu.berkeley.nlp.ling;

import java.io.Serializable;

/**
 * An interface for finding the "head" daughter of a phrase structure tree.
 * This could potentially be any sense of "head", but has mainly been used
 * to find the lexical head for lexicalized PCFG parsing.
 *
 * @author Christopher Manning
 */
public interface HeadFinder extends Serializable {

  /**
   * Determine which daughter of the current parse tree is the head.
   * It assumes that the daughters already have had their heads
   * determined. Another method has to do the tree walking.
   *
   * @param t The parse tree to examine the daughters of
   * @return The parse tree that is the head.  The convention has been
   *         that this returns <code>null</code> if no head is found.
   *         But maybe it should throw an exception?
   */
  public Tree<String> determineHead(Tree<String> t);

}
