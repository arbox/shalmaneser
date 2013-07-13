/**
 * 
 */
package edu.berkeley.nlp.io;

import java.io.IOException;
import java.util.Arrays;
import java.util.LinkedList;
import java.util.List;

/**
 * Similar to PTBLexer. However, instead of reading from a Reader this class is given a line
 * and returns a list of tokenized Strings.
 * @author petrov
 *
 */
public class PTBLineLexer extends PTBLexer {
	
	public PTBLineLexer(){
		super((java.io.Reader)null);
	}
	
	public List<String> tokenizeLine(String line) throws IOException{
		LinkedList<String> tokenized = new LinkedList<String>();
		int nEl = line.length();
		char[] array = line.toCharArray();
		yy_buffer = line.toCharArray();//new char[nEl+1];
		//for(int i=0;i<nEl;i++) yy_buffer[i] = array[i];
		//yy_buffer[nEl] = (char)YYEOF;
		yy_startRead = 0;
		yy_endRead = yy_buffer.length;
    yy_atBOL  = true;
    yy_atEOF  = false;
    yy_currentPos = yy_markedPos = yy_pushbackPos = 0;
    yyline = yychar = yycolumn = 0;
    yy_lexical_state = YYINITIAL;
    while(yy_markedPos<yy_endRead)
    	tokenized.add(next());
    return tokenized;
	}
	
	private boolean yy_refill() throws java.io.IOException {
		return true;
	}


}
