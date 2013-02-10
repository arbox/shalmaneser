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
package opennlp.maxent.io;

import opennlp.maxent.*;
import java.io.*;
import java.util.zip.*;

/**
 * Model writer that saves models in plain text format.
 *
 * @author      Jason Baldridge
 * @version     $Revision: 1.1.1.1 $, $Date: 2001/10/23 14:06:53 $
 */
public class PlainTextGISModelWriter extends GISModelWriter {
    BufferedWriter output;
    
   /**
     * Constructor which takes a GISModel and a File and prepares itself to
     * write the model to that file. Detects whether the file is gzipped or not
     * based on whether the suffix contains ".gz".
     *
     * @param model The GISModel which is to be persisted.
     * @param f The File in which the model is to be persisted.
     */
     public PlainTextGISModelWriter (GISModel model, File f)
	throws IOException, FileNotFoundException {

	super(model);
	if (f.getName().endsWith(".gz")) {
	    output = new BufferedWriter(new OutputStreamWriter(
  	                 new GZIPOutputStream(new FileOutputStream(f))));
	}
	else {
	    output = new BufferedWriter(new FileWriter(f));
	}
    }

   /**
     * Constructor which takes a GISModel and a BufferedWriter and prepares
     * itself to write the model to that writer.
     *
     * @param model The GISModel which is to be persisted.
     * @param bw The BufferedWriter which will be used to persist the model.
     */
    public PlainTextGISModelWriter (GISModel model, BufferedWriter bw) {
	super(model);
	output = bw;
    }

    protected void writeUTF (String s) throws java.io.IOException {
	output.write(s);
	output.newLine();
    }

    protected void writeInt (int i) throws java.io.IOException {
	output.write(Integer.toString(i));
	output.newLine();
    }
    
    protected void writeDouble (double d) throws java.io.IOException {
	output.write(Double.toString(d));
	output.newLine();
    }

    protected void close () throws java.io.IOException {
	output.flush();
	output.close();
    }
    
}
