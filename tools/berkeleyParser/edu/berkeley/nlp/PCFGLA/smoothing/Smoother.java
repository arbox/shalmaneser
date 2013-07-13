/**
 * 
 */
package edu.berkeley.nlp.PCFGLA.smoothing;

import java.io.Serializable;

import edu.berkeley.nlp.util.BinaryCounterTable;
import edu.berkeley.nlp.util.UnaryCounterTable;

/**
 * @author leon
 *
 */
public interface Smoother {
	public void smooth(UnaryCounterTable unaryCounter, BinaryCounterTable binaryCounter);
	public void smooth(short tag, double[] ruleScores);
	public void updateWeights(int[][] toSubstateMapping);
	public Smoother copy();
}
