///////////////////////////////////////////////////////////////////////////////
// Copyright (C) 2001 Chieu Hai Leong and Jason Baldridge
//
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Lesser General Public
// License as published by the Free Software Foundation; either
// version 2.1 of the License, or (at your option) any later version.
//
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public
// License along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
//////////////////////////////////////////////////////////////////////////////   

import opennlp.maxent.*;
import opennlp.maxent.io.*;
import java.io.*;

/**
 * Test the model on some input.
 *
 * @author  Jason Baldridge
 * @version $Revision: 1.4 $, $Date: 2007/07/09 15:27:31 $
 */
public class Classify {
    MaxentModel _model;
    ContextGenerator _cg = new BasicContextGenerator();
    

    // store models in binary, zipped form
    // (make sure this is shared in Train.java)
    public static String MODEL_SUFFIX = "Model.bin.gz";

    public Classify (MaxentModel m) {
	_model = m;
    }
    
    private void eval (String predicates) {
	double[] ocs = _model.eval(_cg.getContext(predicates));
	//	System.out.println("For context: " + predicates
	//			   + "\n" + _model.getAllOutcomes(ocs) + "\n");
		System.out.println(_model.getAllOutcomes(ocs));	
    }

    /**
     * Main method. Call as follows:
     * <p>
     * java Classify dataFile classifierFile
     */
    public static void main(String[] args) {
	String dataFileName, modelFileName;
	String classifierFileName = new String();
	if (args.length > 1) {
	    classifierFileName = new String(args[1]); }
	else {
	    System.err.println("Error: Need to specify classifier path.");
	    System.exit(1); }
	
	dataFileName = args[0];


	File modelFile = new File(classifierFileName);
	
	Classify predictor = null;
	
	try {
	    GISModel m =
		new SuffixSensitiveGISModelReader(modelFile).getModel();
	    predictor = new Classify(m);
	} catch (Exception e) {
	    e.printStackTrace();
	    System.exit(0);
	}

	try {
	    DataStream ds =
		new PlainTextByLineDataStream(new FileReader(new File(dataFileName)));
	    
	    while (ds.hasNext()) {
		String s = (String)ds.nextToken();
		predictor.eval(s.substring(0, s.lastIndexOf(' ')));
	    }
	    return;
	}
	catch (Exception e) {
	    System.out.println("Unable to read from specified file: "
			       + args[0]);
	    System.out.println();
	    
	}
    }
}
