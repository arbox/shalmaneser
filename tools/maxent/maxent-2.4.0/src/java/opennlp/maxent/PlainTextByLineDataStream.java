///////////////////////////////////////////////////////////////////////////////
// Copyright (C) 2001 Jason Baldridge and Gann Bierner
//
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Lesser General Public
// License as published by the Free Software Foundation; either
// version 2.1 of the License, or (at your option) any later version.
//
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public
// License along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
//////////////////////////////////////////////////////////////////////////////   
package opennlp.maxent;

import java.io.*;

/**
 * This DataStream implementation will take care of reading a plain text file
 * and returning the Strings between each new line character, which is what
 * many Maxent applications need in order to create EventStreams.
 *
 * @author      Jason Baldridge
 * @version     $Revision: 1.1.1.1 $, $Date: 2001/10/23 14:06:53 $
 *
 */
public class PlainTextByLineDataStream implements DataStream {
    BufferedReader dataReader;
    String next;
    
    public PlainTextByLineDataStream (Reader dataSource) {
	dataReader = new BufferedReader(dataSource);
	try {
	    next = dataReader.readLine();
	}
	catch (IOException e) {
	    e.printStackTrace();
	}
    }
    
    public Object nextToken () {
	String current = next;
	try {
	    next = dataReader.readLine();
	}
	catch (Exception e) {
	    e.printStackTrace();
	}
	return current;
    }

    public boolean hasNext () {
	return next != null;
    }
 
}

