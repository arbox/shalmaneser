package edu.berkeley.nlp.PCFGLA;

import edu.berkeley.nlp.parser.EnglishPennTreebankParseEvaluator;
import edu.berkeley.nlp.PCFGLA.GrammarTrainer.Options;
import edu.berkeley.nlp.PCFGLA.smoothing.SmoothAcrossParentSubstate;
import edu.berkeley.nlp.PCFGLA.smoothing.Smoother;
import edu.berkeley.nlp.ling.StateSet;
import edu.berkeley.nlp.ling.Tree;
import edu.berkeley.nlp.ling.Trees;
import edu.berkeley.nlp.util.CommandLineUtils;
import edu.berkeley.nlp.util.Numberer;
import edu.berkeley.nlp.util.Option;
import edu.berkeley.nlp.util.OptionParser;

import java.io.BufferedOutputStream;
import java.io.BufferedWriter;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.ObjectInputStream;
import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.io.PrintWriter;
import java.nio.charset.Charset;
import java.util.*;
import java.util.zip.GZIPInputStream;

/**
 * Reads in the Penn Treebank and generates N_GRAMMARS different grammars.
 *
 * @author Slav Petrov
 */
public class GrammarTester  {

	public static class Options {

		@Option(name = "-in", required = true, usage = "Input File for Grammar (Required)\n")
		public String inFileName;

		@Option(name = "-path", usage = "Path to Corpus (Default: null)\n")
		public String path = null;

		@Option(name = "-lang", usage = "Language:  1-ENG, 2-CHN, 3-GER, 4-ARB (Default: 1-ENG)")
		public int lang = 1;

		@Option(name = "-maxL", usage = "Maximum sentence length (Default <=40)")
		public int maxSentenceLength = 40;

		@Option(name = "-section", usage = "On which part of the WSJ to test: train/dev/test (Default: dev)")
		public String section = "dev";

		@Option(name = "-viterbi", usage = "Compute viterbi derivation instead of max-rule parse (Default: max-rule)")
		public boolean viterbiParse = false;

		@Option(name = "-unaryPenalty", usage = "Unary penalty (Default: 1.0)")
		public double unaryPenalty = 1.0;

		@Option(name = "-finalLevel", usage = "Parse with projected grammar from this level (Default: -1 = input grammar)")
		public int finalLevel = -1;
		
		@Option(name = "-verbose", usage = "Verbose/Quiet (Default: Quiet)\n")
		public boolean verbose = false;
		
		@Option(name = "-accurate", usage = "Set thresholds for accuracy. (Default: set thresholds for efficiency)")
		public boolean accurate = false;

		@Option(name = "-useGoldPOS", usage = "Use gold part of speech tags (Default: false)")
		public boolean useGoldPOS = false;


		/*
 * These options should eventually be added back in.
 */
//  "								-N	   Produce N-Best list (Default: 1)"+
//  "								-out   Write parses to textfile (Default: false)"+

	}
	
	public static void main(String[] args) throws IOException {
		OptionParser optParser = new OptionParser(Options.class);
		Options opts = (Options) optParser.parse(args, true);
		// provide feedback on command-line arguments
		System.out.println("Calling with " + optParser.getPassedInOptions());

    
    String path = opts.path;
    int lang = opts.lang;
    System.out.println("Loading trees from "+path+" and using language "+lang);
           
    
    int maxSentenceLength = opts.maxSentenceLength;
    System.out.println("Will remove sentences with more than "+maxSentenceLength+" words.");

    
//    int nbest = Integer.parseInt(CommandLineUtils.getValueOrUseDefault(input, "-N","1"));
    
    String testSetString = opts.section;
    boolean devTestSet = testSetString.equals("dev");
    boolean finalTestSet = testSetString.equals("test");
    boolean trainTestSet = testSetString.equals("train");
    if (!(devTestSet || finalTestSet || trainTestSet)) {
    	System.out.println("I didn't understand dev/final test set argument "+testSetString);
    	System.exit(1);
    }
    System.out.println(" using "+testSetString+" test set");
    
    Corpus corpus = new Corpus(path,lang,1.0,!trainTestSet);
    List<Tree<String>> testTrees = null; 
    if (devTestSet)
    	testTrees = corpus.getDevTestingTrees();
    if (finalTestSet)
    	testTrees = corpus.getFinalTestingTrees();
    if (trainTestSet)
    	testTrees = corpus.getTrainTrees();
//    System.out.println("The test set has "+testTrees.size()+" test sentences before removing the long ones.");
    
//    String outFile = CommandLineUtils.getValueOrUseDefault(input, "-out", null);
//    BufferedWriter output = null;
//		try {
//			if (outFile!=null)
//		    output = new BufferedWriter(new OutputStreamWriter(new FileOutputStream(outFile), Charset.forName("UTF-8")));//GB18030")));
//		} catch (Exception ex) {
//			ex.printStackTrace();
//		}
    
    String inFileName = opts.inFileName;
    if (inFileName==null) {
    	throw new Error("Did not provide a grammar.");
    }
    System.out.println("Loading grammar from "+inFileName+".");

    ParserData pData = ParserData.Load(inFileName);
    if (pData==null) {
      System.out.println("Failed to load grammar from file"+inFileName+".");
      System.exit(1);
    }
    Grammar grammar = pData.getGrammar();
    grammar.splitRules();
    Lexicon lexicon = pData.getLexicon();
//    Smoother lexSmoother = new SmoothAcrossParentSubstate(0.1);
//    lexicon.smoother = lexSmoother;

//    boolean useGoldPOS = CommandLineUtils.getValueOrUseDefault(input, "-gold", "").equals("true");
    
    Numberer.setNumberers(pData.getNumbs());
    int finalLevel = opts.finalLevel;
    if (finalLevel!=-1) System.out.println("Parsing with projected grammar from level "+finalLevel+".");
    boolean viterbiParse = opts.viterbiParse;
    if (viterbiParse) System.out.println("Computing viterbi derivation instead of max-rule parse.");
//    CoarseToFineMaxRuleParser  parser = new CoarseToFineTwoChartsParser(grammar, lexicon, opts.unaryPenalty,finalLevel,viterbiParse,false,false,opts.accurate); 
    
    boolean doVariational = false;
    boolean useGoldPOS = opts.useGoldPOS;
    CoarseToFineMaxRuleParser  parser =  new CoarseToFineMaxRuleParser(grammar, lexicon, opts.unaryPenalty,finalLevel,viterbiParse,false,false,opts.accurate, doVariational, useGoldPOS);      
    if (doVariational) 
    	grammar.computeProperClosures();

//    for (int i=1;i<=6;i++){
//    	String tmpName = inFileName +"_"+i+"_smoothing.gr";
//      pData = ParserData.Load(tmpName);
//      if (pData==null) {
//        System.out.println("Failed to load grammar from file"+tmpName+".");
//        System.exit(1);
//      }
//      grammar = pData.getGrammar();
//      grammar.splitRules();
//      grammar.logarithmMode();
//      lexicon = pData.getLexicon();
//      lexicon.logarithmMode();
//      parser.lexiconCascade[i+1] = lexicon;
//      parser.grammarCascade[i+1] = grammar;
//    }

    
    
    EnglishPennTreebankParseEvaluator.LabeledConstituentEval<String> eval = new EnglishPennTreebankParseEvaluator.LabeledConstituentEval<String>(Collections.singleton("ROOT"), new HashSet<String>(Arrays.asList(new String[] {"''", "``", ".", ":", ","})));

    
    System.out.println("The computed F1,LP,LR scores are just a rough guide. They are typically 0.1-0.2 lower than the official EVALB scores.");

    
    for (Tree<String> testTree : testTrees) {
      List<String> testSentence = testTree.getYield();
      int sentenceLength = testSentence.size();  
      if( sentenceLength >  maxSentenceLength) continue;
      
      List<String> posTags = null;
      if (useGoldPOS) posTags = testTree.getPreTerminalYield();
      Tree<String> parsedTree = parser.getBestConstrainedParse(testSentence,posTags);
    	
  		if (opts.verbose) System.out.println("Annotated result:\n"+Trees.PennTreeRenderer.render(parsedTree));
  		parsedTree = TreeAnnotations.unAnnotateTree(parsedTree);

//    		if (outFile!=null) output.write(parsedTree+"\n");
  		if (!parsedTree.getChildren().isEmpty()) { 
         			System.out.println(parsedTree.getChildren().get(0));
  		} else System.out.println("()\nLength: "+sentenceLength);//System.out.println(testTree);//

  		eval.evaluate(parsedTree, testTree);
    }
 	  eval.display(true);
 	 System.out.println("The computed F1,LP,LR scores are just a rough guide. They are typically 0.1-0.2 lower than the official EVALB scores.");
// 	  if (outFile!=null){
// 			output.flush();
// 			output.close();
// 		}
    System.exit(0);
  }

  public static List<Integer>[][][] loadData(String fileName) {
  	List<Integer>[][][] data = null;
    try {
      FileInputStream fis = new FileInputStream(fileName); // Load from file
      GZIPInputStream gzis = new GZIPInputStream(fis); // Compressed
      ObjectInputStream in = new ObjectInputStream(gzis); // Load objects
      data = (List<Integer>[][][])in.readObject(); // Read the mix of grammars
      in.close(); // And close the stream.
    } catch (IOException e) {
      System.out.println("IOException\n"+e);
      return null;
    } catch (ClassNotFoundException e) {
      System.out.println("Class not found!");
      return null;
    }
    return data;
  }

}

