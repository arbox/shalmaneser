/**
 * 
 */
package edu.berkeley.nlp.PCFGLA;


import java.io.InputStreamReader;
import java.util.List;

import edu.berkeley.nlp.ling.StateSet;
import edu.berkeley.nlp.ling.Tree;
import edu.berkeley.nlp.ling.Trees.PennTreeReader;
import edu.berkeley.nlp.util.Numberer;
import edu.berkeley.nlp.util.Option;
import edu.berkeley.nlp.util.OptionParser;

/**
 * @author petrov
 *
 */
public class TreeLabeler {

	public static class Options {

		@Option(name = "-gr", required = true, usage = "Input File for Grammar (Required)\n")
		public String inFileName;

		@Option(name = "-labelLevel", usage = "Parse with projected grammar from this level (yielding 2^level substates) (Default: -1 = input grammar)")
		public int labelLevel = -1;

		@Option(name = "-scores", usage = "Output inside scores. (Default: false)")
		public boolean scores;

	}
	
	
	/**
	 * @param grammar
	 * @param lexicon
	 * @param labelLevel
	 */
	Grammar grammar;
	Lexicon lexicon;
	ArrayParser labeler;
	CoarseToFineMaxRuleParser parser;
	Numberer tagNumberer;
	Binarization binarization;
	
	public TreeLabeler(Grammar grammar, Lexicon lexicon, int labelLevel, Binarization bin) {
		if (labelLevel==-1){
			this.grammar = grammar.copyGrammar();
			this.lexicon = lexicon.copyLexicon();
		} else { // need to project
			int[][] fromMapping = grammar.computeMapping(1);
	    int[][] toSubstateMapping = grammar.computeSubstateMapping(labelLevel);
	    int[][] toMapping = grammar.computeToMapping(labelLevel,toSubstateMapping);
    	double[] condProbs = grammar.computeConditionalProbabilities(fromMapping,toMapping);
    	
    	this.grammar = grammar.projectGrammar(condProbs,fromMapping,toSubstateMapping);
    	this.lexicon = lexicon.projectLexicon(condProbs,fromMapping,toSubstateMapping);
    	this.grammar.splitRules();
    	double filter = 1.0e-10;
  		this.grammar.removeUnlikelyRules(filter,1.0);
  		this.lexicon.removeUnlikelyTags(filter);
		}
		this.grammar.logarithmMode();
		this.lexicon.logarithmMode();
		this.labeler = new ArrayParser(this.grammar, this.lexicon);
		this.parser = new CoarseToFineMaxRuleParser(grammar, lexicon, 
    		1,-1,true,false, false, false, false, false);      
    this.tagNumberer = Numberer.getGlobalNumberer("tags");
    this.binarization = bin;
	}


	public static void main(String[] args) {
		OptionParser optParser = new OptionParser(Options.class);
		Options opts = (Options) optParser.parse(args, true);
		// provide feedback on command-line arguments
		System.err.println("Calling with " + optParser.getPassedInOptions());

    
    String inFileName = opts.inFileName;
    if (inFileName==null) {
    	throw new Error("Did not provide a grammar.");
    }
    System.err.println("Loading grammar from "+inFileName+".");

    ParserData pData = ParserData.Load(inFileName);
    if (pData==null) {
      System.out.println("Failed to load grammar from file"+inFileName+".");
      System.exit(1);
    }
    Grammar grammar = pData.getGrammar();
    grammar.splitRules();
    Lexicon lexicon = pData.getLexicon();
    
    Numberer.setNumberers(pData.getNumbs());
    Numberer tagNumberer =  Numberer.getGlobalNumberer("tags");
    
    int labelLevel = opts.labelLevel;
    if (labelLevel!=-1) System.err.println("Labeling with projected grammar from level "+labelLevel+".");
    
    TreeLabeler treeLabeler = new TreeLabeler(grammar, lexicon, labelLevel, pData.bin);

    short[] numSubstates = treeLabeler.grammar.numSubStates;
    try{
    	PennTreeReader treeReader = new PennTreeReader(new InputStreamReader(System.in));

    	Tree<String> tree = null;
    	while(treeReader.hasNext()){
    		tree = treeReader.next(); 
    		if (tree.getYield().get(0).equals("")){ // empty tree -> parse failure
    			System.out.println("()");
    			continue;
    		}
    		tree = TreeAnnotations.processTree(tree,pData.v_markov, pData.h_markov,pData.bin,false);
    		List<String> sentence = tree.getYield();
    		Tree<StateSet> stateSetTree = StateSetTreeList.stringTreeToStatesetTree(tree, numSubstates, false, tagNumberer);
    		allocate(stateSetTree);
    		Tree<String> labeledTree = treeLabeler.label(stateSetTree, sentence, opts.scores);
    		if (labeledTree!=null && labeledTree.getChildren().size()>0) System.out.println(labeledTree.getChildren().get(0));
    		else System.out.println("()");
    	 }
    }catch (Exception ex) {
      ex.printStackTrace();
    }
    System.exit(0);
	}


	/**
	 * @param stateSetTree
	 * @return
	 */
	private Tree<String> label(Tree<StateSet> stateSetTree, List<String> sentence, boolean outputScores) {
		Tree<String> tree = labeler.getBestViterbiDerivation(stateSetTree,outputScores);
		if (tree==null){ // max-rule tree had no viterbi derivation
			tree = parser.getBestConstrainedParse(sentence, null);
			tree = TreeAnnotations.processTree(tree,1, 0, binarization,false);
//			System.out.println(tree);
			stateSetTree = StateSetTreeList.stringTreeToStatesetTree(tree, this.grammar.numSubStates, false, tagNumberer);
			allocate(stateSetTree);
			tree = labeler.getBestViterbiDerivation(stateSetTree,outputScores);
		}
		return tree;
	}

	/*
   * Allocate the inside and outside score arrays for the whole tree
   */
  static void allocate(Tree<StateSet> tree) {
    tree.getLabel().allocate();
    for (Tree<StateSet> child : tree.getChildren()) {
      allocate(child);
    }
  }
	
}
