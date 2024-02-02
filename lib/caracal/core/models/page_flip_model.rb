require 'caracal/core/models/base_model'

module Caracal
  module Core
    module Models

      # This class handles block options passed to tables via their data
      # collections.
      #
      class PageFlipModel < BaseModel

        #-------------------------------------------------------------
        # Configuration
        #-------------------------------------------------------------

        # initialization
        def initialize(options={}, &block)
          super options, &block
        end

        #-------------------------------------------------------------
        # Public Methods
        #-------------------------------------------------------------

        #=============== DATA ACCESSORS =======================

        # .contents
        def contents
          @contents ||= []
        end

        #=============== VALIDATION ===========================

        # .valid?
        def valid?
          contents.size > 0
        end
      end
    end
  end
end
