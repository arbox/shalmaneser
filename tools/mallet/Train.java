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

 * Train a classifier based on labelled training examples

   Interface for the Shalmaneser shallow semantic parser to MALLET.

   Sebastian Pado (pado@coli.uni-saarland.de) 2004-6

   This class is based heavily on Vectors2Classify.java, a part of the 
   Mallet machine learning toolkit.
   Copyright: Andrew McCallum <a href="mailto:mccallum@cs.umass.edu">mccallum@cs.umass.edu</a>

   Mallet is provided under the terms of the Common Public License,
   version 1.0, as published by http://www.opensource.org.  

   Shalmaneser is provided under the terms of the GPL.

 */

public abstract class Train
{
    private static ArrayList classifierTrainers = new ArrayList();

	static CommandOption.Object trainerConstructor = new CommandOption.Object
	(Train.class, "trainer", "ClassifierTrainer constructor",	true, new NaiveBayesTrainer(),
	 "Java code for the constructor used to create a ClassifierTrainer.  "+
	 "If no '(' appears, then \"new \" will be prepended and \"Trainer()\" will be appended."+
	 "You may use this option mutiple times to compare multiple classifiers.", null)
		{
			public void parseArg (java.lang.String arg) {
				// parse something like Maxent,gaussianPriorVariance=10,numIterations=20
				//System.out.println("Arg = " + arg);

                // first, split the argument at commas.
				java.lang.String fields[] = arg.split(",");

				//Massage constructor name, so that MaxEnt, MaxEntTrainer, new MaxEntTrainer()
				// all call new MaxEntTrainer()
				java.lang.String constructorName = fields[0];
				if (constructorName.indexOf('(') != -1)     // if contains (), pass it though
					super.parseArg(arg);
				else {
					if (constructorName.endsWith("Trainer")){
						super.parseArg("new " + constructorName + "()"); // add parens if they forgot
					}else{
						super.parseArg("new "+constructorName+"Trainer()"); // make trainer name from classifier name
					}
				}

				// find methods associated with the class we just built
				Method methods[] =  this.value.getClass().getMethods();

				// find setters corresponding to parameter names.
				for (int i=1; i<fields.length; i++){
					java.lang.String nameValuePair[] = fields[i].split("=");
					java.lang.String parameterName  = nameValuePair[0];
					java.lang.String parameterValue = nameValuePair[1];  //todo: check for val present!
					java.lang.Object parameterValueObject;
					try {
						parameterValueObject = getInterpreter().eval(parameterValue);
					} catch (bsh.EvalError e) {
						throw new IllegalArgumentException ("Java interpreter eval error on parameter "+
						                                    parameterName + "\n"+e);
					}

					boolean foundSetter = false;
					for (int j=0; j<methods.length; j++){
						if ( ("set" + Character.toUpperCase(parameterName.charAt(0)) + parameterName.substring(1)).equals(methods[j].getName()) &&
							methods[j].getParameterTypes().length == 1){

							try {
								java.lang.Object[] parameterList = new java.lang.Object[]{parameterValueObject};
								methods[j].invoke(this.value, parameterList);
							} catch ( IllegalAccessException e) {
								System.out.println("IllegalAccessException " + e);
								throw new IllegalArgumentException ("Java access error calling setter\n"+e);
							}  catch ( InvocationTargetException e) {
								System.out.println("IllegalTargetException " + e);
								throw new IllegalArgumentException ("Java target error calling setter\n"+e);
							}
							foundSetter = true;
							break;
						}
					}
					if (!foundSetter){
		                System.out.println("Parameter " + parameterName + " not found on trainer " + constructorName);
						System.out.println("Available parameters for " + constructorName);
						for (int j=0; j<methods.length; j++){
							if ( methods[j].getName().startsWith("set") && methods[j].getParameterTypes().length == 1){
								System.out.println(Character.toLowerCase(methods[j].getName().charAt(3)) +
								                   methods[j].getName().substring(4));
							}
						}

						throw new IllegalArgumentException ("no setter found for parameter " + parameterName);
					}
				}

			}
			public void postParsing (CommandOption.List list) {
				classifierTrainers.add (this.value);
			}
		};

    
	static CommandOption.String trainingData = new CommandOption.String
	(Train.class, "train", "FILENAME", true, "input",
	 "Training data file.", null);

	static CommandOption.String outputFile = new CommandOption.String
	(Train.class, "out", "FILENAME", true, "output",
	 "The filename in which to write the classifier after it has been trained.", null);


	public static void main (String[] args) throws bsh.EvalError, java.io.IOException
	{

	    // Process the command-line options
	    CommandOption.setSummary (Train.class,
				      "A tool for training, saving and printing diagnostics from a classifier on vectors.");
	    CommandOption.process (Train.class, args);
	    
	    InstanceList trainingFileIlist=null;
	    
	    // handle default trainer here for now; default argument processing doesn't  work
	    if (!trainerConstructor.wasInvoked()){
		classifierTrainers.add (new NaiveBayesTrainer());
	    }

	    InstanceList ilist = InstanceList.load (new File(trainingData.value));
	    
	    ClassifierTrainer trainer = (ClassifierTrainer) classifierTrainers.get(0);
	    
	    System.err.println (" Training " + trainer.toString() + " with "+ilist.size()+" instances");

	    Classifier classifier = trainer.train (ilist);
	    
	    String filename = outputFile.value;
	    try {
		ObjectOutputStream oos = new ObjectOutputStream
		    (new FileOutputStream (filename));
		oos.writeObject (classifier);
		oos.close();
	    } catch (Exception e) {
		e.printStackTrace();
		throw new IllegalArgumentException ("Couldn't write classifier to filename "+
						    filename);
	    }
	}
}
