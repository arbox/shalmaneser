/**
 * 
 */
package edu.berkeley.nlp.util;

/**
 * @author adpauls
 * Box holding a reference
 * Useful for accessing variables from within an anonymous class
 *
 */
public class Box<V>
{
	V v;
	public Box(V v)
	{
		this.v = v;
	}
	
	public V getVal()
	{
		return v;
	}
	
	public void setVal(V v)
	{
		this.v = v;
	}
	

}
