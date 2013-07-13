package edu.berkeley.nlp.PCFGLA;

import edu.berkeley.nlp.PCFGLA.GrammarTrainer.Options;
import edu.berkeley.nlp.PCFGLA.smoothing.SmoothAcrossParentBits;
import edu.berkeley.nlp.PCFGLA.smoothing.SmoothAcrossParentSubstate;
import edu.berkeley.nlp.PCFGLA.smoothing.Smoother;
import edu.berkeley.nlp.io.PTBLineLexer;
import edu.berkeley.nlp.io.PTBTokenizer;
import edu.berkeley.nlp.io.PTBLexer;
import edu.berkeley.nlp.ling.StateSet;
import edu.berkeley.nlp.ling.Tree;
import edu.berkeley.nlp.ling.Trees;
import edu.berkeley.nlp.ui.TreeJPanel;
import edu.berkeley.nlp.util.CommandLineUtils;
import edu.berkeley.nlp.util.Numberer;
import edu.berkeley.nlp.util.Option;
import edu.berkeley.nlp.util.OptionParser;

import java.awt.AlphaComposite;
import java.awt.BorderLayout;
import java.awt.Graphics2D;
import java.awt.HeadlessException;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;
import java.awt.geom.Rectangle2D;
import java.awt.image.BufferedImage;
import java.io.BufferedOutputStream;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.ObjectInputStream;
import java.io.OutputStream;
import java.io.PrintWriter;
import java.io.StringReader;
import java.util.*;
import java.util.zip.GZIPInputStream;

import javax.imageio.ImageIO;
import javax.swing.JFrame;

/**
 * Reads in the Penn Treebank and generates N_GRAMMARS different grammars.
 *
 * @author Slav Petrov
 */
public class BerkeleyParser  {
	static TreeJPanel tjp;
	static JFrame frame;
	
	public static class Options {

		@Option(name = "-gr", required = true, usage = "Grammarfile (Required)\n")
		public String grFileName;

		@Option(name = "-tokenize", usage = "Tokenize input first. (Default: false=text is already tokenized)")
		public boolean tokenize;
		
		@Option(name = "-viterbi", usage = "Compute viterbi derivation instead of max-rule tree (Default: max-rule)")
		public boolean viterbi;

		@Option(name = "-binarize", usage = "Output binarized trees. (Default: false)")
		public boolean binarize;

		@Option(name = "-scores", usage = "Output inside scores (only for binarized trees). (Default: false)")
		public boolean scores;

		@Option(name = "-substates", usage = "Output subcategories (only for binarized viterbi trees). (Default: false)")
		public boolean substates;

		@Option(name = "-accurate", usage = "Set thresholds for accuracy. (Default: set thresholds for efficiency)")
		public boolean accurate;

		@Option(name = "-confidence", usage = "Output confidence measure, i.e. tree likelihood (Default: false)")
		public boolean confidence;

		@Option(name = "-render", usage = "Write rendered tree to image file. (Default: false)")
		public boolean render;
		
		@Option(name = "-chinese", usage = "Enable some Chinese specific features in the lexicon.")
		public boolean chinese;
	}
	
  @SuppressWarnings("unchecked")
	public static void main(String[] args) {
//    System.out.println(
//        "usage: java -jar berkeleyParser.jar \n" +
//        " reads sentences (one per line) from STDIN and writes parse trees to STDOUT.");
		OptionParser optParser = new OptionParser(Options.class);
		Options opts = (Options) optParser.parse(args, true);
		// provide feedback on command-line arguments
//		System.out.println("Calling with " + optParser.getPassedInOptions());

    double threshold = 1.0;
    
    String inFileName = opts.grFileName;
    ParserData pData = ParserData.Load(inFileName);
    if (pData==null) {
      System.out.println("Failed to load grammar from file"+inFileName+".");
      System.exit(1);
    }
    Grammar grammar = pData.getGrammar();
    Lexicon lexicon = pData.getLexicon();
    Numberer.setNumberers(pData.getNumbs());
    
    
    
//    Smoother lexSmoother = new SmoothAcrossParentSubstate(0.1);
//    lexicon.smoother = lexSmoother;
    
    if (opts.chinese) Corpus.myLanguage = Corpus.CHINESE;
    
    CoarseToFineMaxRuleParser parser = new CoarseToFineMaxRuleParser(grammar, lexicon, 
    		threshold,-1,opts.viterbi,opts.substates,opts.scores, opts.accurate, false, false);      
    parser.binarization = pData.getBinarization();
    
    if (opts.render) tjp = new TreeJPanel();

    try{
    	BufferedReader inputData = new BufferedReader(new InputStreamReader(System.in));//FileReader(inData));
    	PTBLineLexer tokenizer = null;
    	if (opts.tokenize) tokenizer = new PTBLineLexer();

    	List<String> sentence = null;
    	String line = "";
    	while((line=inputData.readLine()) != null){
    		if (!opts.tokenize) sentence = Arrays.asList(line.split(" "));
    		else sentence = tokenizer.tokenizeLine(line);
    		
    		if (sentence.size()==0) break;
    		
    		Tree<String> parsedTree = parser.getBestConstrainedParse(sentence,null);
    		if (opts.confidence) System.out.print(parser.getLogLikelihood()+"\t");
    		if (!opts.binarize) parsedTree = TreeAnnotations.unAnnotateTree(parsedTree);
    		
    		
    		if (!parsedTree.getChildren().isEmpty()) { 
	         			System.out.println("( "+parsedTree.getChildren().get(0)+")");
	      } else System.out.println("(())");
    		
    		if (opts.render)		writeTreeToImage(parsedTree,line.replaceAll("[^a-zA-Z]", "")+".png");
    	}
    } catch (Exception ex) {
      ex.printStackTrace();
    }
    System.exit(0);
  }

  
  
  public static void writeTreeToImage(Tree<String> tree, String fileName) throws IOException{
  	tjp.setTree(tree);

    
    BufferedImage bi =new BufferedImage(tjp.width(),tjp.height(),BufferedImage.TYPE_INT_ARGB);
    int t=tjp.height();
    Graphics2D g2 = bi.createGraphics();
    
    
    g2.setComposite(AlphaComposite.getInstance(AlphaComposite.CLEAR, 1.0f));
    Rectangle2D.Double rect = new Rectangle2D.Double(0,0,tjp.width(),tjp.height()); 
    g2.fill(rect);
    
    g2.setComposite(AlphaComposite.getInstance(AlphaComposite.SRC_OVER, 1.0f));
    
    tjp.paintComponent(g2); //paint the graphic to the offscreen image
    g2.dispose();
    
    ImageIO.write(bi,"png",new File(fileName)); //save as png format DONE!
  }

}

