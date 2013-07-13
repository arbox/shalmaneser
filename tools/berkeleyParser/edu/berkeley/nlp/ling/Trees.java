package edu.berkeley.nlp.ling;

import edu.berkeley.nlp.util.Filter;

import java.io.IOException;
import java.io.PushbackReader;
import java.io.Reader;
import java.io.StringReader;
import java.util.*;

/**
 * Tools for displaying, reading, and modifying trees.
 *
 * @author Dan Klein
 */
public class Trees {

  public static interface TreeTransformer<E> {
    Tree<E> transformTree(Tree<E> tree);
  }

  public static class FunctionNodeStripper implements TreeTransformer<String> {
    public Tree<String> transformTree(Tree<String> tree) {
      String transformedLabel = transformLabel(tree);
      if (tree.isLeaf()) {
        return new Tree<String>(transformedLabel);
      }
      List<Tree<String>> transformedChildren = new ArrayList<Tree<String>>();
      for (Tree<String> child : tree.getChildren()) {
        transformedChildren.add(transformTree(child));
      }
      return new Tree<String>(transformedLabel, transformedChildren);
    }

		/**
		 * @param tree
		 * @return
		 */
		public static String transformLabel(Tree<String> tree) {
			String transformedLabel = tree.getLabel();
			int cutIndex = transformedLabel.indexOf('-');
			int cutIndex2 = transformedLabel.indexOf('=');
			int cutIndex3 = transformedLabel.indexOf('^');
			if (cutIndex3 > 0 && (cutIndex3 < cutIndex2 || cutIndex2 == -1))
				cutIndex2 = cutIndex3;
			if (cutIndex2 > 0 && (cutIndex2 < cutIndex || cutIndex == -1))
				cutIndex = cutIndex2;
			if (cutIndex > 0 && !tree.isLeaf()) {
				transformedLabel = new String(transformedLabel.substring(0, cutIndex));
			}
			return transformedLabel;
		}
  }

  public static class EmptyNodeStripper implements TreeTransformer<String> {
    public Tree<String> transformTree(Tree<String> tree) {
      String label = tree.getLabel();
      if (label.equals("-NONE-") || label.equals("-none-")) {
        return null;
      }
      if (tree.isLeaf()) {
        return new Tree<String>(label);
      }
      List<Tree<String>> children = tree.getChildren();
      List<Tree<String>> transformedChildren = new ArrayList<Tree<String>>();
      for (Tree<String> child : children) {
        Tree<String> transformedChild = transformTree(child);
        if (transformedChild != null)
          transformedChildren.add(transformedChild);
      }
      if (transformedChildren.size() == 0)
        return null;
      return new Tree<String>(label, transformedChildren);
    }
  }

  public static class XOverXRemover<E> implements TreeTransformer<E> {
    public Tree<E> transformTree(Tree<E> tree) {
      E label = tree.getLabel();
      List<Tree<E>> children = tree.getChildren();
      while (children.size() == 1 && ! children.get(0).isLeaf() && label.equals(children.get(0).getLabel())) {
        children = children.get(0).getChildren();
      }
      List<Tree<E>> transformedChildren = new ArrayList<Tree<E>>();
      for (Tree<E> child : children) {
        transformedChildren.add(transformTree(child));
      }
      return new Tree<E>(label, transformedChildren);
    }
  }

  public static class StandardTreeNormalizer implements TreeTransformer<String> {
    EmptyNodeStripper emptyNodeStripper = new EmptyNodeStripper();
    XOverXRemover<String> xOverXRemover = new XOverXRemover<String>();
    FunctionNodeStripper functionNodeStripper = new FunctionNodeStripper();

    public Tree<String> transformTree(Tree<String> tree) {
      tree = functionNodeStripper.transformTree(tree);
      tree = emptyNodeStripper.transformTree(tree);
      tree = xOverXRemover.transformTree(tree);
      return tree;
    }
  }


  public static class PennTreeReader implements Iterator<Tree<String>> {
    public static String ROOT_LABEL = "ROOT";

    PushbackReader in;
    Tree<String> nextTree;

    public boolean hasNext() {
      return (nextTree != null);
    }

    public Tree<String> next() {
      if (!hasNext()) throw new NoSuchElementException();
      Tree<String> tree = nextTree;
      nextTree = readRootTree();
//      System.out.println(nextTree);
      return tree;
    }

    private Tree<String> readRootTree() {
      try {
        readWhiteSpace();
        if (!isLeftParen(peek())) return null;
        return readTree(true);
      } catch (IOException e) {
        throw new RuntimeException("Error reading tree.");
      }
    }

    private Tree<String> readTree(boolean isRoot) throws IOException {
      readLeftParen();
      String label = readLabel();
      if (label.length() == 0 && isRoot) label = ROOT_LABEL;
      List<Tree<String>> children = readChildren();
      readRightParen();
      return new Tree<String>(label, children);
    }

    private String readLabel() throws IOException {
      readWhiteSpace();
      return readText();
    }

    private String readText() throws IOException {
      StringBuilder sb = new StringBuilder();
      int ch = in.read();
      while (!isWhiteSpace(ch) && !isLeftParen(ch) && !isRightParen(ch)) {
        sb.append((char) ch);
        ch = in.read();
      }
      in.unread(ch);
      //System.out.println("Read text: ["+sb+"]");
      return sb.toString().intern();
    }

    private List<Tree<String>> readChildren() throws IOException {
      readWhiteSpace();
      if (!isLeftParen(peek()))
        return Collections.singletonList(readLeaf());
      return readChildList();
    }

    private int peek() throws IOException {
      int ch = in.read();
      in.unread(ch);
      return ch;
    }

    private Tree<String> readLeaf() throws IOException {
      String label = readText();
      return new Tree<String>(label);
    }

    private List<Tree<String>> readChildList() throws IOException {
      List<Tree<String>> children = new ArrayList<Tree<String>>();
      readWhiteSpace();
      while (!isRightParen(peek())) {
        children.add(readTree(false));
        readWhiteSpace();
      }
      return children;
    }

    private void readLeftParen() throws IOException {
//      System.out.println("Read left.");
      readWhiteSpace();
      int ch = in.read();
      if (!isLeftParen(ch)) throw new RuntimeException("Format error reading tree. (leftParen)");
    }

    private void readRightParen() throws IOException {
//      System.out.println("Read right.");
      readWhiteSpace();
      int ch = in.read();
      
      if (!isRightParen(ch)) {
      	System.out.println((char)ch);
      	throw new RuntimeException("Format error reading tree. (rightParen)");
      }
    }

    private void readWhiteSpace() throws IOException {
      int ch = in.read();
      while (isWhiteSpace(ch)) {
        ch = in.read();
      }
      in.unread(ch);
    }

    private boolean isWhiteSpace(int ch) {
      return (ch == ' ' || ch == '\t' || ch == '\f' || ch == '\r' || ch == '\n');
    }

    private boolean isLeftParen(int ch) {
      return ch == '(';
    }

    private boolean isRightParen(int ch) {
      return ch == ')';
    }

    public void remove() {
      throw new UnsupportedOperationException();
    }

    public PennTreeReader(Reader in) {
      this.in = new PushbackReader(in);
      nextTree = readRootTree();
      //System.out.println(nextTree);
    }
  }

  /**
   * Renderer for pretty-printing trees according to the Penn Treebank indenting
   * guidelines (mutliline).  Adapted from code originally written by Dan Klein
   * and modified by Chris Manning.
   */
  public static class PennTreeRenderer {

    /**
     * Print the tree as done in Penn Treebank merged files. The formatting
     * should be exactly the same, but we don't print the trailing whitespace
     * found in Penn Treebank trees. The basic deviation from a bracketed
     * indented tree is to in general collapse the printing of adjacent
     * preterminals onto one line of tags and words.  Additional complexities
     * are that conjunctions (tag CC) are not collapsed in this way, and that
     * the unlabeled outer brackets are collapsed onto the same line as the next
     * bracket down.
     */
    public static <L> String render(Tree<L> tree) {
      StringBuilder sb = new StringBuilder();
      renderTree(tree, 0, false, false, false, true, sb);
      sb.append('\n');
      return sb.toString();
    }

    /**
     * Display a node, implementing Penn Treebank style layout
     */
    private static <L> void renderTree(Tree<L> tree, int indent, boolean parentLabelNull,
                                       boolean firstSibling,
                                       boolean leftSiblingPreTerminal,
                                       boolean topLevel,
                                       StringBuilder sb) {
      // the condition for staying on the same line in Penn Treebank
      boolean suppressIndent = (parentLabelNull ||
              (firstSibling && tree.isPreTerminal()) ||
              (leftSiblingPreTerminal && tree.isPreTerminal() &&
              (tree.getLabel() == null ||
              !tree.getLabel().toString().startsWith("CC"))));
      if (suppressIndent) {
        sb.append(' ');
      } else {
        if (!topLevel) {
          sb.append('\n');
        }
        for (int i = 0; i < indent; i++) {
          sb.append("  ");
        }
      }
      if (tree.isLeaf() || tree.isPreTerminal()) {
        renderFlat(tree, sb);
        return;
      }
      sb.append('(');
      sb.append(tree.getLabel());
      renderChildren(tree.getChildren(), indent + 1,
              tree.getLabel() == null || tree.getLabel().toString() == null, sb);
      sb.append(')');
    }

    private static <L> void renderFlat(Tree<L> tree, StringBuilder sb) {
      if (tree.isLeaf()) {
        sb.append(tree.getLabel().toString());
        return;
      }
      sb.append('(');
      if (tree.getLabel()==null)
      	sb.append("<null>");
      else
      	sb.append(tree.getLabel().toString());
      sb.append(' ');
      sb.append(tree.getChildren().get(0).getLabel().toString());
      sb.append(')');
    }


    private static <L> void renderChildren(List<Tree<L>> children, int indent, boolean parentLabelNull, StringBuilder sb) {
      boolean firstSibling = true;
      boolean leftSibIsPreTerm = true;  // counts as true at beginning
      for (Tree<L> child : children) {
        renderTree(child, indent, parentLabelNull, firstSibling, leftSibIsPreTerm, false, sb);
        leftSibIsPreTerm = child.isPreTerminal();
        // CC is a special case
        if (child.getLabel() != null && child.getLabel().toString().startsWith("CC")) {
          leftSibIsPreTerm = false;
        }
        firstSibling = false;
      }
    }
  }

  public static void main(String[] args) {
    PennTreeReader reader = new PennTreeReader(new StringReader("((S (NP (DT the) (JJ quick) (JJ brown) (NN fox)) (VP (VBD jumped) (PP (IN over) (NP (DT the) (JJ lazy) (NN dog)))) (. .)))"));
    Tree<String> tree = reader.next();
    System.out.println(PennTreeRenderer.render(tree));
    System.out.println(tree);
  }

  /**
   * Splices out all nodes which match the provided filter.
   *
   * @param tree
   * @param filter
   * @return
   */
  public static <L> Tree<L> spliceNodes(Tree<L> tree, Filter<L> filter) {
    List<Tree<L>> rootList = spliceNodesHelper(tree, filter);
    if (rootList.size() > 1) throw new IllegalArgumentException("spliceNodes: no unique root after splicing");
    if (rootList.size() < 1) return null;
    return rootList.get(0);
  }

  private static <L> List<Tree<L>> spliceNodesHelper(Tree<L> tree, Filter<L> filter) {
  	if (tree.isLeaf()) return Collections.singletonList(new Tree<L>(tree.getLabel())); // dont splie out leaves
    List<Tree<L>> splicedChildren = new ArrayList<Tree<L>>();
    for (Tree<L> child : tree.getChildren()) {
      List<Tree<L>> splicedChildList = spliceNodesHelper(child, filter);
      splicedChildren.addAll(splicedChildList);
    }
    if (filter.accept(tree.getLabel()))
      return splicedChildren;
    return Collections.singletonList(new Tree<L>(tree.getLabel(), splicedChildren));
  }

}
