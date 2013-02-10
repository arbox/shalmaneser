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
 * Main class which calls the GIS procedure after building the EventStream
 * from the data.
 *
 * @author  Chieu Hai Leong and Jason Baldridge
 * @version $Revision: 1.5 $, $Date: 2005/10/24 12:29:20 $
 */
public class CreateModel {

    // some parameters if you want to play around with the smoothing option
    // for model training.  This can improve model accuracy, though training
    // will potentially take longer and use more memory.  Model size will also
    // be larger.  Initial testing indicates improvements for models built on
    // small data sets and few outcomes, but performance degradation for those
    // with large data sets and lots of outcomes.
    public static boolean USE_SMOOTHING = false;
    public static double SMOOTHING_OBSERVATION = 0.1;
    
    /**
     * Main method. Call as follows:
     * <p>
     * java CreateModel dataFile
     */
    public static void main (String[] args) {
      String dataFileName = new String(args[0]);
      String modelFileName =
        dataFileName.substring(0,dataFileName.lastIndexOf('.'))
        + "Model.txt";
      try {
        FileReader datafr = new FileReader(new File(dataFileName));
        EventStream es = 
          new BasicEventStream(new PlainTextByLineDataStream(datafr));
        GIS.SMOOTHING_OBSERVATION = SMOOTHING_OBSERVATION;
        GISModel model = GIS.trainModel(es,USE_SMOOTHING);
        
        File outputFile = new File(modelFileName);
        GISModelWriter writer =
          new SuffixSensitiveGISModelWriter(model, outputFile);
        writer.persist();
      } catch (Exception e) {
        System.out.print("Unable to create model due to exception: ");
        System.out.println(e);
      }
    }

}
