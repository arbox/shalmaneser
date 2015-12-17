require 'logging'

module Shalmaneser
  module Frappe
    class HeadzHelpers
      # Conjunction
      def get_conjuncts(node)
        get_dtrs(node, 'CJ')
      end

      # flatten
      def descend(current, flat)
        return flat if current.nil?

        if current.key?("conj")
          tmp = current.delete("conj")
          flat.push current
          tmp.each { |item| descend(item, flat) }
        else
          flat.push current
        end
      end

      # Zugriff
      def get_dtr(node, label)
        if (dtrs = node.children_by_edgelabels([label]))
          dtrs.first
        else
          LOGGER.debug "SelectHeadDtr: no #{label} dtr for #{node}."

          nil
        end
      end

      def get_dtrs(node, label)
        if !(dtrs = node.children_by_edgelabels([label]))
          LOGGER.debug " SelectHeadDtr: no #{label} dtr for #{node}."
        else
          dtrs
        end
      end

      def get_rightmost_dtr(node, label)
        children = node.children_by_edgelabels([label])
        if (re = children.last)
          re
        else
          LOGGER.debug "SelectHeadDtr: no #{label} dtrs for #{node}."
          nil
        end
      end
    end # Class HeadzHelpers
  end
end
