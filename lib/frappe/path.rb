#############################
# class describing a path between two nodes
#
# provides access and output facilities for different aspects of the path
#
# this is the return value of SynInterpreter.path_between
module Shalmaneser
  module Frappe
    class Path
      attr_reader :startnode

      ###
      # initialize to empty path
      def initialize(startnode)
        @path = []
        @cutoff_last_pt = false
        set_startnode(startnode)
      end

      ###
      # deep_clone:
      # return clone of this path object,
      #  with clone of this path rather than the same path
      def deep_clone
        new_path = self.clone
        new_path.set_path(@path.clone)

        return new_path
      end

      ###
      def set_startnode(startnode)
        @startnode = startnode

        return self
      end

      ###
      # iterate through the current path
      #
      # yield tuples
      # [direction, edgelabel, nodelabel, endnode]
      #  direction: string, U/D
      #  edgelabel: string
      #  nodelabel: string
      #  endnode:   SynNode
      def each_step
        @path.each { |step|
          yield step
        }
      end

      ###
      # empty?
      # any steps in here?
      def empty?
        return @path.empty?
      end

      ###
      # add one step to the beginning of the current path
      def add_first_step(start_node,#SynNode
                         direction, # string: U, D
                         gf,        # string: edge label
                         pt)
        @path.unshift([direction, gf, pt, @startnode])
        set_startnode(start_node)

        return self
      end


      ###
      # add one step to the end of the current path
      def add_last_step(direction, # string: U, D
                        gf,        # string: edge label
                        pt,        # string: node label (of end_node)
                        end_node)  # SynNode
        @path << [direction, gf, pt, end_node]

        return self
      end

      ###
      # path length
      def length
        return @path.length
      end

      ###
      #
      def print(print_direction, # boolean. true: print direction
                print_gf,        # boolean. true: print edgelabel
                print_pt)        # boolean. true: print nodelabel

        return print_aux(@path, print_direction, print_gf, print_pt)
      end

      ###
      # print path from roof node to end
      def print_downpart(print_direction,
                         print_gf,
                         print_pt)

        roof, roof_index = compute_roof
        if roof.nil? or @path.empty?
          # no roof set
          return ""

        else
          # roof node is in the middle
          return print_aux(@path[roof_index..-1],
                           print_direction, print_gf, print_pt)
        end
      end

      ###
      def lca
        return compute_roof.first
      end

      ###
      # cut off last node label in print and print_downpart?
      def set_cutoff_last_pt_on_printing(bool) # Boolean
        @cutoff_last_pt = bool
      end

      ########
      protected

      def set_path(new_path)
        @path = new_path
      end


      ########
      private

      ###
      # step through the path as long as direction is up.
      # when direction starts to go "D", take current node as roof node
      #
      # returns: pair [roof node, roof node index] (SynNode, integer)
      def compute_roof
        node = @startnode
        index = 0

        each_step { |direction, edgelabel, nodelabel, endnode|
          if direction =~ /D/
            # down! the previous node was roof
            return [node, index]
          else
            node = endnode
            index += 1
          end
        }

        # last node is roof
        return [node, index]

      end

      ###
      def print_aux(path,
                    print_direction,
                    print_gf,
                    print_pt)
        retv = ''
        path.each { |step|
          direction, gf, pt, _node = step.map { |entry|
            if entry.nil?
              "-"
            else
              entry
            end
          }

          if print_direction
            retv << direction + " "
          end

          if print_gf
            retv << gf + " "
          end

          if print_pt
            retv << pt + " "
          end
        }

        if @cutoff_last_pt && print_pt && (retv =~ /^(.+ )\w+ $/)
          return $1
        else
          return retv
        end
      end
    end
  end
end
