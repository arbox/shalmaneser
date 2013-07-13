package edu.berkeley.nlp.util;

import java.util.AbstractList;
import java.util.List;

/**
 * List which returns special boundary symbols hwen get() is called outside the
 * range of the list.
 *
 * @author Dan Klein
 */
public class BoundedList <E> extends AbstractList<E> {
  private E leftBoundary;
  private E rightBoundary;
  private List<E> list;

  /**
   * Returns the object at the given index, provided the index is between 0
   * (inclusive) and size() (exclusive).  If the index is < 0, then a left
   * boundary object is returned.  If the index is >= size(), a right boundary
   * object is returned.  The default boundary objects are both null, unless
   * other objects are specified on construction.
   */
  public E get(int index) {
    if (index < 0) return leftBoundary;
    if (index >= list.size()) return rightBoundary;
    return list.get(index);
  }

  public int size() {
    return list.size();
  }

  public BoundedList(List<E> list, E leftBoundary, E rightBoundary) {
    this.list = list;
    this.leftBoundary = leftBoundary;
    this.rightBoundary = rightBoundary;
  }

  public BoundedList(List<E> list, E boundary) {
    this(list, boundary, boundary);
  }

  public BoundedList(List<E> list) {
    this(list, null);
  }
}
