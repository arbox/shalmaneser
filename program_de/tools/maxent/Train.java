///////////////////////////////////////////////////////////////////////////////
// Copyright (C) 2001 Chieu Hai Leong and Jason Baldridge
//
// modified and extended 2007 by sebastian pado
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

public class Train {

    public static boolean USE_SMOOTHING = false;
    public static double SMOOTHING_OBSERVATION = 0.1;
    
    /**
     * Main method. Call as follows:
     * <p>
     * java Train dataFile classifierFile
     */
    public static void main (String[] args) {
      String dataFileName = new String(args[0]);
      String classifierFileName = new String();
      if (args.length > 1) {
	  classifierFileName = new String(args[1]); }
      else {
	  System.err.println("Error: Need to specify classifier path.");
	  System.exit(1); }

      try {
        FileReader datafr = new FileReader(new File(dataFileName));
        EventStream es = new BasicEventStream(new PlainTextByLineDataStream(datafr));
        GIS.SMOOTHING_OBSERVATION = SMOOTHING_OBSERVATION;
        GISModel model = GIS.trainModel(es,USE_SMOOTHING);        
        File modelFile = new File(classifierFileName);

        GISModelWriter writer =
          new SuffixSensitiveGISModelWriter(model, modelFile);
        writer.persist();
      } catch (Exception e) {
        System.out.print("Unable to create model due to exception: ");
        System.out.println(e);
      }
    }

}
