package edu.berkeley.nlp.ling;

import edu.berkeley.nlp.math.ArrayMath;
import edu.berkeley.nlp.math.SloppyMath;
import edu.berkeley.nlp.PCFGLA.GrammarTrainer;

import java.util.Arrays;
import java.text.NumberFormat;

/**
 * Represent parsetrees, with each node consisting of a label and a list of children.
 * The score tables are not allocated by the constructor and allocate() and deallocate()
 * must be called manually. This is to allow more control over memory usage.
 * @author Slav Petrov
 * @author Romain Thibaux
 */
public class StateSet {
  double[] iScores;     // the log-probabilities for each sublabels
  double[] oScores;
  int iScale;
  int oScale;
  String word; /** the word of this node, if it is a terminal node; else null*/

  short numSubStates;
  short state;
  public short from, to;
  
  // Run allocate() before any other operation
  public void allocate() {
    iScores = new double[numSubStates];
    oScores = new double[numSubStates];
  }
  
  // run deallocate() if the scores are no longer needed and
  // this object will not be used for a long time
  public void deallocate() {
    iScores = null;
    oScores = null;
  }
  
  public String toString(){
    if (!word.equals("")) return word+" "+from+"-"+to;// + " " + substates.length;
    String s = state+" ";//"[";
//    for (int i = 0; i < numSubStates; i++){
//      NumberFormat f = NumberFormat.getInstance();
//      f.setMaximumFractionDigits(2);
//      String iS = f.format(Math.log(iScores[i])+100*iScale);
//      String oS = f.format(Math.log(oScores[i])+100*oScale);
//      String iS = Double.toString(Math.log(iScores[i])+100*iScale);
//      String oS = Double.toString(Math.log(oScores[i])+100*oScale);
//      s=s.concat(" ("+state+"-"+i+": iS="+iS+" oS="+oS+")");
//    }
//    s=s.concat(" ]");
    return s;
  }
  
  public final short getState(){
    return state;
  }
  
  public final double getIScore(int i){
    return iScores[i];
  }
  
  public final double[] getIScores() {
  	return iScores;
  }

  public final double getOScore(int i){
    return oScores[i];
  }

  public final double[] getOScores() {
  	return oScores;
  }

  public final void setIScores(double[] s) {
    iScores = s;
  }

  public final void setIScore(int i, double s) {
  	if (iScores == null) iScores = new double[numSubStates];
  	iScores[i] = s;
  }
  
  public final void setOScores(double[] s) {
    oScores = s;
  }

  public final void setOScore(int i, double s) {
    if (oScores == null) oScores = new double[numSubStates];
  	oScores[i] = s;
  }

/*  public void logAddIScore(short i, double s) {
    iScores[i] = SloppyMath.logAdd(iScores[i], s);
  }

  public void logAddOScore(short i,double s) {
    oScores[i] = SloppyMath.logAdd(oScores[i], s);
  }
*/
  
  public final int numSubStates() {
    return numSubStates;
  }
  /*
  public StateSet(int nSubStates) {
    this.numSubStates = nSubStates;
    this.iScores = new double[nSubStates];
    this.oScores = new double[nSubStates];
    for ( int i = 0; i < nSubStates; i++ ) {
      iScores[i] = Double.NEGATIVE_INFINITY;
      oScores[i] = Double.NEGATIVE_INFINITY;
    }
  }*/

  public StateSet(short state, short nSubStates) {
    this.numSubStates = nSubStates;
    this.state = state;
  }
    
  public StateSet(short s, short nSubStates, String word, short from, short to) {
    this.numSubStates = nSubStates;
    this.state = s;
    this.word = word;
    this.from = from;
    this.to = to;
    
  }
  
  public StateSet(StateSet oldS, short nSubStates) {
    this.numSubStates = nSubStates;
    this.state = oldS.state;
    this.word = oldS.word;
    this.from = oldS.from;
    this.to = oldS.to;
    
  }
  
  public String getWord() {
    return word;
  }

  
  public void setWord(String word) {
    this.word = word;
  }

  public void scaleIScores(int previousScale){
	  int logScale = 0;
	  double scale = 1.0;
	  double max = ArrayMath.max(iScores);
	  //if (max==0) 	System.out.println("All iScores are 0!");
	  while (max > GrammarTrainer.SCALE) {
	    max /= GrammarTrainer.SCALE;
	    scale *= GrammarTrainer.SCALE;
	    logScale += 1;
	  }
	  while (max > 0.0 && max < 1.0 / GrammarTrainer.SCALE) {
	    max *= GrammarTrainer.SCALE;
	    scale /= GrammarTrainer.SCALE;
	    logScale -= 1;
	  }
	  if (logScale != 0) {
	    for (int i = 0; i < numSubStates; i++) {
	      iScores[i] /= scale;
	    }
	  }
	  if ((max!=0) && ArrayMath.max(iScores)==0){
	  	System.out.println("Undeflow when scaling iScores!");
	  }
	  iScale = previousScale + logScale;
  }

  public void scaleOScores(int previousScale){
	  int logScale = 0;
	  double scale = 1.0;
	  double max = ArrayMath.max(oScores);
	  //if (max==0) 	System.out.println("All oScores are 0!");
	  while (max > GrammarTrainer.SCALE) {
	    max /= GrammarTrainer.SCALE;
	    scale *= GrammarTrainer.SCALE;
	    logScale += 1;
	  }
	  while (max > 0.0 && max < 1.0 / GrammarTrainer.SCALE) {
	    max *= GrammarTrainer.SCALE;
	    scale /= GrammarTrainer.SCALE;
	    logScale -= 1;
	  }
	  if (logScale != 0) {
	    for (int i = 0; i < numSubStates; i++) {
	      oScores[i] /= scale;
	    }
	  }
	  if ((max!=0) && ArrayMath.max(oScores)==0){
	  	System.out.println("Undeflow when scaling oScores!");
	  }
	  oScale = previousScale + logScale;
  }

  public int getIScale() {
		return iScale;
	}

	public void setIScale(int scale) {
		iScale = scale;
	}

	public int getOScale() {
		return oScale;
	}

	public void setOScale(int scale) {
		oScale = scale;
	}
                                                                                                                                                         
  
  
  
}
