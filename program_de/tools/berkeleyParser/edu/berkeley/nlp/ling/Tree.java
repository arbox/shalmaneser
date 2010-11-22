package edu.berkeley.nlp.ling;

import java.io.Serializable;
import java.util.*;

/**
 * Represent linguistic trees, with each node consisting of a label and a list of children.
 * @author Dan Klein
 */
public class Tree<L> implements Serializable {
  /**
	 * 
	 */
	private static final long serialVersionUID = 1L;

	L label;
  List<Tree<L>> children;
  public void setChildren(List<Tree<L>> c) {
    this.children= c;
  }
  public List<Tree<L>> getChildren() {
    return children;
  }
  public L getLabel() {
    return label;
  }
  public boolean isLeaf() {
    return getChildren().isEmpty();
  }
  public boolean isPreTerminal() {
    return getChildren().size() == 1 && getChildren().get(0).isLeaf();
  }

  public List<L> getYield() {
    List<L> yield = new ArrayList<L>();
    appendYield(this, yield);
    return yield;
  }
  
  public List<Tree<L>> getTerminals() {
  	List<Tree<L>> yield = new ArrayList<Tree<L>>();
  	appendTerminals(this, yield);
  	return yield;
  }
  
  private static <L> void appendTerminals(Tree<L> tree, List<Tree<L>> yield) {
  	if (tree.isLeaf()) {
  		yield.add(tree);
  		return;
  	}
    for (Tree<L> child : tree.getChildren()) {
      appendTerminals(child, yield);
    }
  }
  
  /** Clone the structure of the tree.  Unfortunately, the new labels are copied by
   * reference from the current tree.
   * 
   * @return
   */
  public Tree<L> shallowClone() {
  	ArrayList<Tree<L>> newChildren = new ArrayList<Tree<L>>(children.size());
  	for (Tree<L> child : children) {
  		newChildren.add(child.shallowClone());
  	}
  	return new Tree<L>(label, newChildren);
  }

  private static <L> void appendYield(Tree<L> tree, List<L> yield) {
    if (tree.isLeaf()) {
      yield.add(tree.getLabel());
      return;
    }
    for (Tree<L> child : tree.getChildren()) {
      appendYield(child, yield);
    }
  }

  public List<L> getPreTerminalYield() {
    List<L> yield = new ArrayList<L>();
    appendPreTerminalYield(this, yield);
    return yield;
  }

  private static <L> void appendPreTerminalYield(Tree<L> tree, List<L> yield) {
    if (tree.isPreTerminal()) {
      yield.add(tree.getLabel());
      return;
    }
    for (Tree<L> child : tree.getChildren()) {
      appendPreTerminalYield(child, yield);
    }
  }
  
  public int getDepth() {
  	int maxDepth = 0;
  	for (Tree<L> child : children) {
  		int depth = child.getDepth();
  		if (depth>maxDepth)
  			maxDepth = depth;
  	}
  	return maxDepth + 1;
  }

  public List<Tree<L>> getAtDepth(int depth) {
    List<Tree<L>> yield = new ArrayList<Tree<L>>();
    appendAtDepth(depth, this, yield);
    return yield;
  }

  private static <L> void appendAtDepth(int depth, Tree<L> tree, List<Tree<L>> yield) {
  	if (depth<0)
  		return;
    if (depth==0) {
      yield.add(tree);
      return;
    }
    for (Tree<L> child : tree.getChildren()) {
      appendAtDepth(depth-1, child, yield);
    }
  }
  
  public void setLabel(L label) {
  	this.label = label;
  }


  public String toString() {
    StringBuilder sb = new StringBuilder();
    toStringBuilder(sb);
    return sb.toString();
  }

  public void toStringBuilder(StringBuilder sb) {
    if (! isLeaf()) sb.append('(');
    if (getLabel() != null) {
      sb.append(getLabel());
    }
    if (! isLeaf()) {
      for (Tree<L> child : getChildren()) {
        sb.append(' ');
        child.toStringBuilder(sb);
      }
      sb.append(')');
    }
  }

  public Tree(L label, List<Tree<L>> children) {
    this.label = label;
    this.children = children;
  }

  public Tree(L label) {
    this.label = label;
    this.children = Collections.emptyList();
  }
  
  /**
   * Get the set of all subtrees inside the tree by returning a tree
   * rooted at each node.  These are <i>not</i> copies, but all share
   * structure.  The tree is regarded as a subtree of itself.
   *
   * @return the <code>Set</code> of all subtrees in the tree.
   */
  public Set<Tree<L>> subTrees() {
    return (Set<Tree<L>>) subTrees(new HashSet<Tree<L>>());
  }

  /**
   * Get the list of all subtrees inside the tree by returning a tree
   * rooted at each node.  These are <i>not</i> copies, but all share
   * structure.  The tree is regarded as a subtree of itself.
   *
   * @return the <code>List</code> of all subtrees in the tree.
   */
  public List<Tree<L>> subTreeList() {
    return (List<Tree<L>>) subTrees(new ArrayList<Tree<L>>());
  }


  /**
   * Add the set of all subtrees inside a tree (including the tree itself)
   * to the given <code>Collection</code>.
   *
   * @param n A collection of nodes to which the subtrees will be added
   * @return The collection parameter with the subtrees added
   */
  public Collection<Tree<L>> subTrees(Collection<Tree<L>> n) {
    n.add(this);
    List<Tree<L>> kids = getChildren();
    for (Tree kid : kids) {
      kid.subTrees(n);
    }
    return n;
  }

  /**
   * Returns an iterator over the nodes of the tree.  This method
   * implements the <code>iterator()</code> method required by the
   * <code>Collections</code> interface.  It does a preorder
   * (children after node) traversal of the tree.  (A possible
   * extension to the class at some point would be to allow different
   * traversal orderings via variant iterators.)
   *
   * @return An interator over the nodes of the tree
   */
  public Iterator iterator() {
    return new TreeIterator();
  }
  private class TreeIterator implements Iterator {

	    private List<Tree<L>> treeStack;

	    private TreeIterator() {
	      treeStack = new ArrayList<Tree<L>>();
	      treeStack.add(Tree.this);
	    }

	    public boolean hasNext() {
	      return (!treeStack.isEmpty());
	    }

	    public Object next() {
	      int lastIndex = treeStack.size() - 1;
	      Tree<L> tr = treeStack.remove(lastIndex);
	      List<Tree<L>> kids = tr.getChildren();
	      // so that we can efficiently use one List, we reverse them
	      for (int i = kids.size() - 1; i >= 0; i--) {
	        treeStack.add(kids.get(i));
	      }
	      return tr;
	    }

	    /**
	     * Not supported
	     */
	    public void remove() {
	      throw new UnsupportedOperationException();
	    }

	  }

  public boolean hasUnaryChain(){
  	return hasUnaryChainHelper(this, false);
  }
  	
  private boolean hasUnaryChainHelper(Tree<L> tree, boolean unaryAbove){
  	boolean result = false;
		if (tree.getChildren().size()==1){
			if (unaryAbove) return true;
			else if (tree.getChildren().get(0).isPreTerminal()) return false;
			else return hasUnaryChainHelper(tree.getChildren().get(0), true);
  	}
  	else {
  		for (Tree<L> child : tree.getChildren()){
  			if (!child.isPreTerminal()) 
  				result = result || hasUnaryChainHelper(child,false);
  		}
  	}
  	return result;
  }
  
}
