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
