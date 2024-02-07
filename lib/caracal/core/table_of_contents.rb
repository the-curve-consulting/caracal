require 'caracal/core/models/table_of_contents_model'
require 'caracal/errors'


module Caracal
  module Core

    # This module encapsulates all the functionality related to table of
    # contents
    #
    module TableOfContents
      def self.included(base)
        base.class_eval do

          #-------------------------------------------------------------
          # Public Methods
          #-------------------------------------------------------------

          def table_of_contents(*args, &block)
            options = Caracal::Utilities.extract_options!(args)

            model = Caracal::Core::Models::TableOfContentsModel.new(options, &block)
            
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
