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
 * @version $Revision: 1.2 $, $Date: 2001/11/20 17:07:17 $
 */
public class Predict {
    MaxentModel _model;
    ContextGenerator _cg = new BasicContextGenerator();
    
    public Predict (MaxentModel m) {
	_model = m;
    }
    
    private void eval (String predicates) {
	double[] ocs = _model.eval(_cg.getContext(predicates));
	System.out.println("For context: " + predicates
			   + "\n" + _model.getAllOutcomes(ocs) + "\n");
	
    }

    /**
     * Main method. Call as follows:
     * <p>
     * java Predict dataFile (modelFile)
     */
    public static void main(String[] args) {
	String dataFileName, modelFileName;
	if (args.length > 0) {
	    dataFileName = args[0];
	    if (args.length > 1) 
		modelFileName = args[1];
	    else
		modelFileName =
		    dataFileName.substring(0,dataFileName.lastIndexOf('.'))
		    + "Model.txt";
	}
	else {
	    dataFileName = "";
	    modelFileName = "weatherModel.txt";
	}
	Predict predictor = null;
	try {
	    GISModel m =
		new SuffixSensitiveGISModelReader(
			      new File(modelFileName)).getModel();
	    predictor = new Predict(m);
	} catch (Exception e) {
	    e.printStackTrace();
	    System.exit(0);
	}

	if (dataFileName.equals("")) {
	    predictor.eval("Rainy Happy Humid");
	    predictor.eval("Rainy");
	    predictor.eval("Blarmey");
	}
	else {
	    try {
		DataStream ds =
		    new PlainTextByLineDataStream(
			new FileReader(new File(args[0])));

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
    
}
