package edu.berkeley.nlp.io;

import edu.berkeley.nlp.ling.Tree;
import edu.berkeley.nlp.ling.Trees;
import edu.berkeley.nlp.util.ConcatenationIterator;

import java.util.*;
import java.io.*;
import java.nio.charset.Charset;
import java.nio.charset.UnsupportedCharsetException;

/**
 * @author Dan Klein
 */
public class PennTreebankReader {

  static class TreeCollection extends AbstractCollection<Tree<String>> {

    List<File> files;
    Charset charset;

    static class TreeIteratorIterator implements Iterator<Iterator<Tree<String>>> {
      Iterator<File> fileIterator;
      Iterator<Tree<String>> nextTreeIterator;
      Charset charset;

      public boolean hasNext() {
        return nextTreeIterator != null;
      }

      public Iterator<Tree<String>> next() {
        Iterator<Tree<String>> currentTreeIterator = nextTreeIterator;
        advance();
        return currentTreeIterator;
      }

      public void remove() {
        throw new UnsupportedOperationException();
      }

      private void advance() {
        nextTreeIterator = null;
        while (nextTreeIterator == null && fileIterator.hasNext()) {
        	File file = fileIterator.next();
        	//System.out.println(file);
          try {
            nextTreeIterator = new Trees.PennTreeReader(new BufferedReader(
								new InputStreamReader(new FileInputStream(file), this.charset)));
          } catch (FileNotFoundException e) {
          } catch (UnsupportedCharsetException e) {
          	throw new Error("Unsupported charset in file "+file.getPath());
          }
        }
      }

      TreeIteratorIterator(List<File> files, Charset charset) {
        this.fileIterator = files.iterator();
        this.charset = charset;
        advance();
      }
    }

    public Iterator<Tree<String>> iterator() {
      return new ConcatenationIterator<Tree<String>>(new TreeIteratorIterator(files, this.charset));
    }

    public int size() {
      int size = 0;
      Iterator i = iterator();
      while (i.hasNext()) {
        size++;
        i.next();
      }
      return size;
    }

    private List<File> getFilesUnder(String path, FileFilter fileFilter) {
      File root = new File(path);
      List<File> files = new ArrayList<File>();
      addFilesUnder(root, files, fileFilter);
      return files;
    }

    private void addFilesUnder(File root, List<File> files, FileFilter fileFilter) {
      if (! fileFilter.accept(root)) return;
      if (root.isFile()) {
        files.add(root);
        return;
      }
      if (root.isDirectory()) {
        File[] children = root.listFiles();
        for (int i = 0; i < children.length; i++) {
          File child = children[i];
          addFilesUnder(child, files, fileFilter);
        }
      }
    }

    public TreeCollection(String path, int lowFileNum, int highFileNum, Charset charset) {
      FileFilter fileFilter = new NumberRangeFileFilter(".mrg", lowFileNum, highFileNum, true);
      this.files = getFilesUnder(path, fileFilter);
      this.charset = charset;
    }
    public TreeCollection(String path, int lowFileNum, int highFileNum, String charsetName) {
    	this(path,lowFileNum,highFileNum,Charset.forName(charsetName));
    }
    public TreeCollection(String path, int lowFileNum, int highFileNum) {
    	this(path,lowFileNum,highFileNum,Charset.defaultCharset());
    }
  }

  public static Collection<Tree<String>> readTrees(String path, Charset charset) {
    return readTrees(path, -1, Integer.MAX_VALUE, charset);
  }

  public static Collection<Tree<String>> readTrees(String path, int lowFileNum, int highFileNumber, Charset charset) {
    return new TreeCollection(path, lowFileNum, highFileNumber, charset);
  }

  public static void main(String[] args) {
    Collection<Tree<String>> trees = readTrees(args[0], Charset.defaultCharset());
    for (Tree<String> tree : trees) {
      tree = (new Trees.StandardTreeNormalizer()).transformTree(tree);
      System.out.println(Trees.PennTreeRenderer.render(tree));
    }
  }

}
