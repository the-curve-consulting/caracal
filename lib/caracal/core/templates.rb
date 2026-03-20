require 'zip'
require 'nokogiri'

module Caracal
  module Core

    # This module encapsulates functionality for loading styles, headers,
    # and footers from an existing .docx template file.
    #
    module Templates

      W_NS = { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' }.freeze
      R_IMAGE_TYPE = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image'.freeze

      def load_template(path)
        ::Zip::File.open(path) do |zip|
          styles_entry  = zip.glob('word/styles.xml').first
          header_entry  = zip.glob('word/header1.xml').first
          footer_entry  = zip.glob('word/footer1.xml').first

          # Load styles
          if styles_entry
            styles_xml = Nokogiri::XML(styles_entry.get_input_stream.read)
            styles_xml.xpath('//w:style', W_NS).each do |node|
              next if node['w:default'] == '1'

              opts = {}

              opts[:id]   = node['w:styleId']
              opts[:type] = node['w:type']
              opts[:name] = node.at_xpath('w:name', W_NS)&.[]('w:val')
              opts[:base] = node.at_xpath('w:basedOn', W_NS)&.[]('w:val')
              opts[:next] = node.at_xpath('w:next', W_NS)&.[]('w:val')

              # Run properties
              rpr = node.at_xpath('w:rPr', W_NS)
              if rpr
                opts[:font]      = rpr.at_xpath('w:rFonts', W_NS)&.[]('w:ascii')
                opts[:color]     = rpr.at_xpath('w:color', W_NS)&.[]('w:val')
                opts[:size]      = rpr.at_xpath('w:sz', W_NS)&.[]('w:val')&.to_i

                b_val = rpr.at_xpath('w:b', W_NS)&.[]('w:val')
                opts[:bold] = (b_val.nil? || b_val == '1' || b_val == 'true') if rpr.at_xpath('w:b', W_NS)

                i_val = rpr.at_xpath('w:i', W_NS)&.[]('w:val')
                opts[:italic] = (i_val.nil? || i_val == '1' || i_val == 'true') if rpr.at_xpath('w:i', W_NS)

                caps_val = rpr.at_xpath('w:caps', W_NS)&.[]('w:val')
                opts[:caps] = (caps_val.nil? || caps_val == '1' || caps_val == 'true') if rpr.at_xpath('w:caps', W_NS)

                u_val = rpr.at_xpath('w:u', W_NS)&.[]('w:val')
                opts[:underline] = (u_val == 'single') if u_val
              end

              # Paragraph properties
              ppr = node.at_xpath('w:pPr', W_NS)
              if ppr
                align_val = ppr.at_xpath('w:jc', W_NS)&.[]('w:val')
                opts[:align] = align_val.to_sym if align_val

                spacing = ppr.at_xpath('w:spacing', W_NS)
                if spacing
                  opts[:line]   = spacing['w:line']&.to_i
                  opts[:top]    = spacing['w:before']&.to_i
                  opts[:bottom] = spacing['w:after']&.to_i
                end

                outline_val = ppr.at_xpath('w:outlineLvl', W_NS)&.[]('w:val')
                opts[:outline] = outline_val.to_i if outline_val

                indent = ppr.at_xpath('w:ind', W_NS)
                if indent
                  opts[:indent_left]  = indent['w:left']&.to_i
                  opts[:indent_right] = indent['w:right']&.to_i
                  opts[:indent_first] = indent['w:firstLine']&.to_i
                end
              end

              # Remove nil values before registering
              opts.reject! { |_, v| v.nil? }

              next unless opts[:id] && opts[:name]

              # Register font if referenced
              font(name: opts[:font]) if opts[:font]

              style(opts)
            end
          end

          # Process header XML
          if header_entry
            header_rels_entry    = zip.glob('word/_rels/header1.xml.rels').first
            header_image_rel_map = build_image_rel_map(header_rels_entry)
            registered_header_rels = {}
            @raw_header_xml = remap_image_relationships(
              header_entry.get_input_stream.read,
              header_image_rel_map,
              zip,
              registered_header_rels
            )
            @raw_header_rels_xml = build_part_rels_xml(header_rels_entry, registered_header_rels)
          end

          # Process footer XML
          if footer_entry
            footer_rels_entry    = zip.glob('word/_rels/footer1.xml.rels').first
            footer_image_rel_map = build_image_rel_map(footer_rels_entry)
            registered_footer_rels = {}
            @raw_footer_xml = remap_image_relationships(
              footer_entry.get_input_stream.read,
              footer_image_rel_map,
              zip,
              registered_footer_rels
            )
            @raw_footer_rels_xml = build_part_rels_xml(footer_rels_entry, registered_footer_rels)
          end
        end
      end


      private

      def build_image_rel_map(rels_entry)
        return {} unless rels_entry
        result = {}
        rels_xml = Nokogiri::XML(rels_entry.get_input_stream.read)
        rels_xml.root.children.each do |node|
          next unless node.is_a?(Nokogiri::XML::Element)
          if node['Type'].to_s == R_IMAGE_TYPE
            result[node['Id'].to_s] = { type: :image, target: node['Target'].to_s }
          end
        end
        result
      end

      def build_part_rels_xml(rels_entry, registered_rels)
        return nil unless rels_entry
        rels_xml = Nokogiri::XML(rels_entry.get_input_stream.read)
        rels_xml.root.children.each do |node|
          next unless node.is_a?(Nokogiri::XML::Element)
          old_rid = node['Id'].to_s
          if registered_rels.key?(old_rid)
            new_rel = registered_rels[old_rid]
            node['Id']     = new_rel.formatted_id
            node['Target'] = new_rel.formatted_target
          end
        end
        rels_xml.to_xml
      end

      # Reads header/footer XML, remaps any image relationship IDs from the
      # template into new IDs registered on this document, and returns the
      # updated XML string.
      #
      def remap_image_relationships(raw_xml, image_rel_map, zip, registered_rels = {})
        return raw_xml if image_rel_map.empty?

        doc   = Nokogiri::XML(raw_xml)
        id_map = {}
        r_ns  = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'

        # Use XPath to find r:embed and r:id attributes directly — Node#traverse
        # never yields Attr nodes, so attributes must be queried via XPath.
        doc.xpath('//@r:embed | //@r:id', 'r' => r_ns).each do |attr|
          old_rid = attr.value
          next unless image_rel_map.key?(old_rid)

          unless id_map.key?(old_rid)
            rel_info   = image_rel_map[old_rid]
            target     = rel_info[:target]
            media_path = target.start_with?('media/') ? "word/#{target}" : "word/media/#{File.basename(target)}"
            media_entry = zip.glob(media_path).first || zip.glob("word/#{target}").first
            next unless media_entry

            media_data = media_entry.get_input_stream.read
            ext        = File.extname(target).sub('.', '')
            # Use old_rid in target name to keep each image relationship unique
            new_rel = relationship(type: :image, target: "image_template_#{old_rid}.#{ext}", data: media_data)
            registered_rels[old_rid] = new_rel
            id_map[old_rid] = new_rel.formatted_id
          end

          attr.value = id_map[old_rid]
        end

        return raw_xml if id_map.empty?
        doc.to_xml
      end

    end

  end
end
