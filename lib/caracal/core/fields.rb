require 'caracal/core/models/field_model'
require 'caracal/errors'


module Caracal
  module Core

    # This module encapsulates all the functionality related to fields
    #
    module Fields
      def self.included(base)
        base.class_eval do

          #-------------------------------------------------------------
          # Public Methods
          #-------------------------------------------------------------

          def field(*args, &block)
            options = Caracal::Utilities.extract_options!(args)
            options.merge!({ type: args.first }) if args.first

            model = Caracal::Core::Models::FieldModel.new(options, &block)
            
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
