require 'caracal/core/models/page_flip_model'
require 'caracal/errors'


module Caracal
  module Core

    # This module encapsulates all the functionality related to flipping
    # specific page contents
    #
    module PageFlips
      def self.included(base)
        base.class_eval do

          #-------------------------------------------------------------
          # Public Methods
          #-------------------------------------------------------------

          def page_flip(*args, &block)
            options = Caracal::Utilities.extract_options!(args)

            # Pass through the page dimensions from the parent document,
            # using the page height as the page width, due to it using
            # the inverse dimensions.
            options.merge!({
              width: page_height,
              margin_left: page_margin_left,
              margin_right: page_margin_right
            })

            model = Caracal::Core::Models::PageFlipModel.new(options, &block)
            
            if model.valid?
              contents << model
            end

            model
          end
        end
      end
    end
  end
end
