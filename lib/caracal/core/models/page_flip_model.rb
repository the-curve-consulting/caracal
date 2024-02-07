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

        # accessors
        attr_reader :page_width
        attr_reader :page_margin_left
        attr_reader :page_margin_right

        # initialization
        def initialize(options={}, &block)
          super options, &block
        end

        #-------------------------------------------------------------
        # Public Methods
        #-------------------------------------------------------------
        
        #========== SETTERS ===============================

        # integers
        [:width, :margin_left, :margin_right].each do |m|
          define_method "#{ m }" do |value|
            instance_variable_set("@page_#{ m }", value.to_i)
          end
        end

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

        #--------------------------------------------------
        # Private Instance Methods
        #--------------------------------------------------
        private

        def option_keys
          [:width, :margin_left, :margin_right]
        end
      end
    end
  end
end
