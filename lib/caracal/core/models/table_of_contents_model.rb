require 'caracal/core/models/base_model'


module Caracal
  module Core
    module Models

      # This class encapsulates the logic needed to store and manipulate
      # text data.
      #
      class TableOfContentsModel < BaseModel

        #--------------------------------------------------
        # Configuration
        #--------------------------------------------------

        # constants
        const_set(:DEFAULT_OPTS, 'TOC \o "1-1" \h \z \u \t "Heading 5,1"')
        const_set(:DEFAULT_SIZE, 32)
        const_set(:DEFAULT_TITLE, 'Table of Contents')

        # accessors
        attr_reader :toc_opts
        attr_reader :toc_size
        attr_reader :toc_title

        #-------------------------------------------------------------
        # Public Class Methods
        #-------------------------------------------------------------
        
        # initialization
        def initialize(options={}, &block)
          @toc_opts  ||= DEFAULT_OPTS
          @toc_size  ||= DEFAULT_SIZE
          @toc_title ||= DEFAULT_TITLE
          super options, &block
        end

        #-------------------------------------------------------------
        # Public Instance Methods
        #-------------------------------------------------------------

        #=============== GETTERS ==============================

        #========== GETTERS ===============================

        #========== SETTERS ===============================

        # integers
        [:size].each do |m|
          define_method "#{ m }" do |value|
            instance_variable_set("@toc_#{ m }", value.to_i)
          end
        end

        # strings
        [:title, :opts].each do |m|
          define_method "#{ m }" do |value|
            instance_variable_set("@toc_#{ m }", value.to_s)
          end
        end

        #========== VALIDATION ============================

        def valid?
          !!/^TOC/.match(toc_opts)
        end

        #--------------------------------------------------
        # Private Methods
        #--------------------------------------------------
        private

        def option_keys
          [:opts, :size, :title]
        end
      end
    end
  end
end
