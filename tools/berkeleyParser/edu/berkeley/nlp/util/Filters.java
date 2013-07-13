package edu.berkeley.nlp.util;

import java.io.Serializable;
import java.lang.reflect.Array;
import java.util.*;

/**
 * Filters contains some simple implementations of the Filter interface.
 *
 * @author Christopher Manning
 * @version 1.0
 */
public class Filters {

  /**
   * Nothing to instantiate
   */
  private Filters() {
  }

  /**
   * The acceptFilter accepts everything.
   */
  public static Filter acceptFilter() {
    return new CategoricalFilter(true);
  }

  /**
   * The rejectFilter accepts nothing.
   */
  public static Filter rejectFilter() {
    return new CategoricalFilter(false);
  }

  private static final class CategoricalFilter implements Filter {

    private final boolean judgment;

    private CategoricalFilter(boolean judgment) {
      this.judgment = judgment;
    }

    /**
     * Checks if the given object passes the filter.
     *
     * @param obj an object to test
     */
    public boolean accept(Object obj) {
      return judgment;
    }
  }


  /**
   * The collectionAcceptFilter accepts a certain collection.
   */
  public static Filter collectionAcceptFilter(Object[] objs) {
    return new CollectionAcceptFilter(Arrays.asList(objs), true);
  }

  /**
   * The collectionAcceptFilter accepts a certain collection.
   */
  public static Filter collectionAcceptFilter(Collection objs) {
    return new CollectionAcceptFilter(objs, true);
  }

  /**
   * The collectionRejectFilter rejects a certain collection.
   */
  public static Filter collectionRejectFilter(Object[] objs) {
    return new CollectionAcceptFilter(Arrays.asList(objs), false);
  }

  /**
   * The collectionRejectFilter rejects a certain collection.
   */
  public static Filter collectionRejectFilter(Collection objs) {
    return new CollectionAcceptFilter(objs, false);
  }

  private static final class CollectionAcceptFilter implements Filter, Serializable {

    private final Collection args;
    private final boolean judgment;

    private CollectionAcceptFilter(Collection c, boolean judgment) {
      this.args = new HashSet(c);
      this.judgment = judgment;
    }

    /**
     * Checks if the given object passes the filter.
     *
     * @param obj an object to test
     */
    public boolean accept(Object obj) {
      if (args.contains(obj)) {
        return judgment;
      } else {
        return !judgment;
      }
    }
  }

  /**
   * Filter that accepts only when both filters accept (AND).
   */
  public static Filter andFilter(Filter f1, Filter f2) {
    return (new CombinedFilter(f1, f2, true));
  }

  /**
   * Filter that accepts when either filter accepts (OR).
   */
  public static Filter orFilter(Filter f1, Filter f2) {
    return (new CombinedFilter(f1, f2, false));
  }

  /**
   * Conjunction or disjunction of two filters.
   */
  private static class CombinedFilter implements Filter {
    private Filter f1, f2;
    private boolean conjunction; // and vs. or

    public CombinedFilter(Filter f1, Filter f2, boolean conjunction) {
      this.f1 = f1;
      this.f2 = f2;
      this.conjunction = conjunction;
    }

    public boolean accept(Object o) {
      if (conjunction) {
        return (f1.accept(o) && f2.accept(o));
      }
      return (f1.accept(o) || f2.accept(o));
    }
  }

  /**
   * Filter that does the opposite of given filter (NOT).
   */
  public static Filter notFilter(Filter filter) {
    return (new NegatedFilter(filter));
  }

  /**
   * Filter that's either negated or normal as specified.
   */
  public static Filter switchedFilter(Filter filter, boolean negated) {
    return (new NegatedFilter(filter, negated));
  }

  /**
   * Negation of a filter.
   */
  private static class NegatedFilter implements Filter {
    private Filter filter;
    private boolean negated;

    public NegatedFilter(Filter filter, boolean negated) {
      this.filter = filter;
      this.negated = negated;
    }

    public NegatedFilter(Filter filter) {
      this(filter, true);
    }

    public boolean accept(Object o) {
      return (negated ^ filter.accept(o)); // xor
    }
  }

  /**
   * Applies the given filter to each of the given elems, and returns the
   * list of elems that were accepted. The runtime type of the returned
   * array is the same as the passed in array.
   */
  public static Object[] filter(Object[] elems, Filter filter) {
    List filtered = new ArrayList();
    for (int i = 0; i < elems.length; i++) {
      if (filter.accept(elems[i])) {
        filtered.add(elems[i]);
      }
    }
    return (filtered.toArray((Object[]) Array.newInstance(elems.getClass().getComponentType(), filtered.size())));
  }

  /**
   * Removes all elems in the given Collection that aren't accepted by the given Filter.
   */
  public static void retainAll(Collection elems, Filter filter) {
    for (Iterator iter = elems.iterator(); iter.hasNext();) {
      Object elem = iter.next();
      if (!filter.accept(elem)) {
        iter.remove();
      }
    }
  }
}
