import edu.umass.cs.mallet.base.types.*;
import edu.umass.cs.mallet.base.classify.*;
import edu.umass.cs.mallet.base.classify.evaluate.*;

import edu.umass.cs.mallet.base.util.*;
import edu.umass.cs.mallet.base.util.CommandOption;

import java.io.*;
import java.util.*;
import java.util.Random;
import java.lang.reflect.*;
/**

 * Classify a file of instances using a pre-trained classifier 
   and print out classifications

   Interface for the Shalmaneser shallow semantic parser to MALLET.

   Sebastian Pado (pado@coli.uni-saarland.de) 2004-6

   This class is based heavily on Vectors2Classify.java, a part of the 
   Mallet machine learning toolkit.
   Copyright: Andrew McCallum <a href="mailto:mccallum@cs.umass.edu">mccallum@cs.umass.edu</a>

   Mallet is provided under the terms of the Common Public License,
   version 1.0, as published by http://www.opensource.org.  

   Shalmaneser is provided under the terms of the GPL.

 */


public abstract class Classify
{
	public static void main (String[] args) throws bsh.EvalError, java.io.IOException
	{
	    
	    Classifier classifier;
 
	    if (args.length != 2) {
		throw new IllegalArgumentException("Usage: classify [classifier] [test data]");
	    }
	    	    
	    try {
		ObjectInputStream ois = new ObjectInputStream (new FileInputStream (args[0]));
		classifier = (Classifier) ois.readObject();
		ois.close();
	    } catch (Exception e) {
		e.printStackTrace();
		throw new IllegalArgumentException ("Couldn't read classifier "+args[0]);
	    }
	    
	    InstanceList ilist= InstanceList.load (new File(args[1]));	    
	    
	    Trial testTrial = new Trial (classifier, ilist);
	    
	    System.err.println("Accuracy: "+testTrial.accuracy());
	    // deactivate to avoid null pointer error for test instances with null label
	    // System.err.println(new ConfusionMatrix (testTrial).toString());

	    printTrialClassification(testTrial);
	    
	}
    
    private static void printTrialClassification(Trial trial)
    {
	ArrayList classifications = trial.toArrayList();
	
	for (int i = 0; i < classifications.size(); i++) {
	    Instance instance = trial.getClassification(i).getInstance();
	    //	    System.out.print(instance.getName() + " " + instance.getTarget() + " ");
	    
	    Labeling labeling = trial.getClassification(i).getLabeling();
	    
	    for (int j = 0; j < labeling.numLocations(); j++){
		System.out.print(labeling.getLabelAtRank(j).toString() + "\t" + labeling.getValueAtRank(j) + "\t");
	    }
	    
	    System.out.println();
	}
    }    
}
