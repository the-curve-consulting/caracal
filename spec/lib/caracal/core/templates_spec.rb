require 'spec_helper'
require 'zip'
require 'stringio'

describe Caracal::Core::Templates do

  # Build a minimal in-memory .docx zip for use as a template fixture.
  # Options:
  #   :styles  - array of style attribute hashes to embed in word/styles.xml
  #   :header  - raw XML string for word/header1.xml (omitted when nil)
  #   :footer  - raw XML string for word/footer1.xml (omitted when nil)
  #   :images  - hash of { rId => { target, data } } for relationships + media
  #
  def build_template_docx(styles: [], header: nil, footer: nil, images: {}, footer_images: {})
    buffer = Zip::OutputStream.write_buffer do |zip|
      # _rels for header1 (when header images provided)
      if header && !images.empty?
        rels_xml = <<~XML
          <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
          <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            #{images.map { |rid, info|
              %(<Relationship Id="#{rid}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="#{info[:target]}"/>)
            }.join("\n")}
          </Relationships>
        XML
        zip.put_next_entry('word/_rels/header1.xml.rels')
        zip.write(rels_xml)
      end

      # _rels for footer1 (when footer images provided)
      if footer && !footer_images.empty?
        rels_xml = <<~XML
          <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
          <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            #{footer_images.map { |rid, info|
              %(<Relationship Id="#{rid}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="#{info[:target]}"/>)
            }.join("\n")}
          </Relationships>
        XML
        zip.put_next_entry('word/_rels/footer1.xml.rels')
        zip.write(rels_xml)
      end

      # styles.xml
      style_nodes = styles.map do |s|
        attrs = [
          s[:id]      && %( w:styleId="#{s[:id]}"),
          s[:type]    && %( w:type="#{s[:type]}"),
          s[:default] && %( w:default="1")
        ].compact.join
        name_node    = s[:name]    ? %(<w:name w:val="#{s[:name]}"/>)       : ''
        based_on     = s[:base]    ? %(<w:basedOn w:val="#{s[:base]}"/>)    : ''
        next_style   = s[:next_s]  ? %(<w:next w:val="#{s[:next_s]}"/>)     : ''
        font_node    = s[:font]    ? %(<w:rFonts w:ascii="#{s[:font]}"/>)   : ''
        color_node   = s[:color]   ? %(<w:color w:val="#{s[:color]}"/>)     : ''
        size_node    = s[:size]    ? %(<w:sz w:val="#{s[:size]}"/>)         : ''
        bold_node    = s[:bold]    ? '<w:b/>'                               : ''
        italic_node  = s[:italic]  ? '<w:i/>'                               : ''
        align_node   = s[:align]   ? %(<w:jc w:val="#{s[:align]}"/>)       : ''
        outline_node = s[:outline] ? %(<w:outlineLvl w:val="#{s[:outline]}"/>) : ''

        rpr = (font_node + color_node + size_node + bold_node + italic_node)
        ppr = (align_node + outline_node)

        <<~STYLE
          <w:style#{attrs}>
            #{name_node}#{based_on}#{next_style}
            #{rpr.empty? ? '' : "<w:rPr>#{rpr}</w:rPr>"}
            #{ppr.empty? ? '' : "<w:pPr>#{ppr}</w:pPr>"}
          </w:style>
        STYLE
      end.join

      styles_xml = <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          #{style_nodes}
        </w:styles>
      XML
      zip.put_next_entry('word/styles.xml')
      zip.write(styles_xml)

      # header1.xml
      if header
        zip.put_next_entry('word/header1.xml')
        zip.write(header)
      end

      # footer1.xml
      if footer
        zip.put_next_entry('word/footer1.xml')
        zip.write(footer)
      end

      # media files for images
      images.each do |_rid, info|
        media_path = "word/#{info[:target]}"
        zip.put_next_entry(media_path)
        zip.write(info[:data])
      end

      footer_images.each do |_rid, info|
        media_path = "word/#{info[:target]}"
        zip.put_next_entry(media_path)
        zip.write(info[:data])
      end
    end

    buffer.string
  end


  subject { Caracal::Document.new }

  let(:fixture_path) { File.join(Caracal.root, 'spec', 'support', '_fixtures', 'snippet.docx') }


  #-------------------------------------------------------------
  # Backward Compatibility
  #-------------------------------------------------------------

  describe 'backward compatibility' do
    it 'Document.new without template: still works' do
      expect { Caracal::Document.new }.not_to raise_error
    end

    it 'Document.new with template: nil still works' do
      expect { Caracal::Document.new(template: nil) }.not_to raise_error
    end

    it 'does not set @raw_header_xml without a template' do
      expect(subject.instance_variable_defined?(:@raw_header_xml)).to be false
    end

    it 'does not set @raw_footer_xml without a template' do
      expect(subject.instance_variable_defined?(:@raw_footer_xml)).to be false
    end
  end


  #-------------------------------------------------------------
  # Class Method API
  #-------------------------------------------------------------

  describe '.save / .render accept template: keyword' do
    let(:tmpfile) { Tempfile.new(['caracal_tmpl_test', '.docx']) }
    let(:docx_data) { build_template_docx }

    after { tmpfile.unlink }

    it 'Document.save accepts template: without raising' do
      Tempfile.create(['tmpl', '.docx']) do |tf|
        tf.write(docx_data)
        tf.flush
        expect {
          Caracal::Document.save(tmpfile.path, template: tf.path) { |d| d.p 'hi' }
        }.not_to raise_error
      end
    end

    it 'Document.render accepts template: without raising' do
      Tempfile.create(['tmpl', '.docx']) do |tf|
        tf.write(docx_data)
        tf.flush
        expect {
          Caracal::Document.render('output', template: tf.path) { |d| d.p 'hi' }
        }.not_to raise_error
      end
    end
  end


  #-------------------------------------------------------------
  # Style Loading
  #-------------------------------------------------------------

  describe 'style loading' do
    let(:default_count) { Caracal::Document.default_styles.size }

    describe 'non-default styles are registered' do
      before do
        data = build_template_docx(styles: [
          { id: 'CustomHeading', name: 'custom heading', type: 'paragraph', font: 'Times New Roman', size: 48, bold: true, color: 'FF0000', outline: 0 }
        ])
        Tempfile.create(['tmpl', '.docx']) { |tf| tf.write(data); tf.flush; subject.load_template(tf.path) }
      end

      it 'adds the style to the document' do
        expect(subject.find_style('CustomHeading')).not_to be_nil
      end

      it 'stores the correct font' do
        expect(subject.find_style('CustomHeading').style_font).to eq 'Times New Roman'
      end

      it 'stores the correct size' do
        expect(subject.find_style('CustomHeading').style_size).to eq 48
      end

      it 'stores the correct color' do
        expect(subject.find_style('CustomHeading').style_color).to eq 'FF0000'
      end

      it 'stores bold: true' do
        expect(subject.find_style('CustomHeading').style_bold).to be true
      end
    end

    describe 'template style overrides matching default style' do
      before do
        data = build_template_docx(styles: [
          { id: 'Heading1', name: 'heading 1', type: 'paragraph', font: 'Georgia', size: 40 }
        ])
        Tempfile.create(['tmpl', '.docx']) { |tf| tf.write(data); tf.flush; subject.load_template(tf.path) }
      end

      it 'does not add a duplicate entry' do
        expect(subject.styles.count { |s| s.style_id == 'Heading1' }).to eq 1
      end

      it 'replaces the default font with the template font' do
        expect(subject.find_style('Heading1').style_font).to eq 'Georgia'
      end
    end

    describe 'styles with w:default="1" are skipped' do
      before do
        data = build_template_docx(styles: [
          { id: 'Normal', name: 'normal', type: 'paragraph', default: true, font: 'Courier' }
        ])
        Tempfile.create(['tmpl', '.docx']) { |tf| tf.write(data); tf.flush; subject.load_template(tf.path) }
      end

      it 'leaves the existing Normal style unchanged' do
        expect(subject.find_style('Normal').style_font).to eq 'Arial'
      end
    end

    describe 'referenced fonts are registered' do
      let(:font_name) { 'Papyrus' }

      before do
        data = build_template_docx(styles: [
          { id: 'FancyStyle', name: 'fancy style', type: 'paragraph', font: font_name }
        ])
        Tempfile.create(['tmpl', '.docx']) { |tf| tf.write(data); tf.flush; subject.load_template(tf.path) }
      end

      it 'registers the font' do
        expect(subject.fonts.map(&:font_name)).to include(font_name)
      end
    end
  end


  #-------------------------------------------------------------
  # Header / Footer Passthrough
  #-------------------------------------------------------------

  describe 'header passthrough' do
    let(:header_xml) do
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:p><w:r><w:t>Company Header</w:t></w:r></w:p>
        </w:hdr>
      XML
    end

    before do
      data = build_template_docx(header: header_xml)
      Tempfile.create(['tmpl', '.docx']) { |tf| tf.write(data); tf.flush; subject.load_template(tf.path) }
    end

    it 'sets @raw_header_xml' do
      expect(subject.instance_variable_get(:@raw_header_xml)).not_to be_nil
    end

    it 'raw_header_xml contains the template header content' do
      expect(subject.instance_variable_get(:@raw_header_xml)).to include('Company Header')
    end
  end

  describe 'footer passthrough' do
    let(:footer_xml) do
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:p><w:r><w:t>Acme Corp Footer</w:t></w:r></w:p>
        </w:ftr>
      XML
    end

    before do
      data = build_template_docx(footer: footer_xml)
      Tempfile.create(['tmpl', '.docx']) { |tf| tf.write(data); tf.flush; subject.load_template(tf.path) }
    end

    it 'sets @raw_footer_xml' do
      expect(subject.instance_variable_get(:@raw_footer_xml)).not_to be_nil
    end

    it 'raw_footer_xml contains the template footer content' do
      expect(subject.instance_variable_get(:@raw_footer_xml)).to include('Acme Corp Footer')
    end
  end

  describe 'template with neither header nor footer' do
    before do
      data = build_template_docx
      Tempfile.create(['tmpl', '.docx']) { |tf| tf.write(data); tf.flush; subject.load_template(tf.path) }
    end

    it 'does not set @raw_header_xml' do
      expect(subject.instance_variable_get(:@raw_header_xml)).to be_nil
    end

    it 'does not set @raw_footer_xml' do
      expect(subject.instance_variable_get(:@raw_footer_xml)).to be_nil
    end
  end


  #-------------------------------------------------------------
  # Render Passthrough
  #-------------------------------------------------------------

  describe 'render_header passthrough' do
    it 'uses @raw_header_xml when set' do
      raw = '<w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"/>'
      subject.instance_variable_set(:@raw_header_xml, raw)

      buffer = subject.render
      buffer.rewind

      Zip::InputStream.open(StringIO.new(buffer.sysread)) do |zip|
        while (entry = zip.get_next_entry)
          if entry.name == 'word/header1.xml'
            expect(zip.read).to eq raw
          end
        end
      end
    end

    it 'falls back to HeaderRenderer when @raw_header_xml is not set' do
      expect(Caracal::Renderers::HeaderRenderer).to receive(:render).and_call_original
      subject.render
    end
  end

  describe 'render_footer passthrough' do
    it 'uses @raw_footer_xml when set' do
      raw = '<w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"/>'
      subject.instance_variable_set(:@raw_footer_xml, raw)

      buffer = subject.render
      buffer.rewind

      Zip::InputStream.open(StringIO.new(buffer.sysread)) do |zip|
        while (entry = zip.get_next_entry)
          if entry.name == 'word/footer1.xml'
            expect(zip.read).to eq raw
          end
        end
      end
    end

    it 'falls back to FooterRenderer when @raw_footer_xml is not set' do
      expect(Caracal::Renderers::FooterRenderer).to receive(:render).and_call_original
      subject.render
    end
  end


  #-------------------------------------------------------------
  # Image Remapping
  #-------------------------------------------------------------

  describe 'image remapping from header' do
    let(:png_data)  { "\x89PNG\r\n\x1a\n" + ('x' * 100) }
    let(:header_xml) do
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
               xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <w:p>
            <w:r>
              <w:drawing>
                <wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">
                  <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
                    <a:graphicData>
                      <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
                        <pic:blipFill>
                          <a:blip r:embed="rId1"/>
                        </pic:blipFill>
                      </pic:pic>
                    </a:graphicData>
                  </a:graphic>
                </wp:inline>
              </w:drawing>
            </w:r>
          </w:p>
        </w:hdr>
      XML
    end

    before do
      data = build_template_docx(
        header: header_xml,
        images: { 'rId1' => { target: 'media/logo.png', data: png_data } }
      )
      Tempfile.create(['tmpl', '.docx']) { |tf| tf.write(data); tf.flush; subject.load_template(tf.path) }
    end

    it 'registers the image relationship' do
      rels = subject.instance_variable_get(:@relationships) || subject.relationships
      image_rels = rels.select { |r| r.relationship_type == :image }
      expect(image_rels).not_to be_empty
    end

    it 'rewrites r:embed in the header XML' do
      raw_xml = subject.instance_variable_get(:@raw_header_xml)
      expect(raw_xml).not_to include('r:embed="rId1"')
    end

    it 'includes the image media file in the rendered docx' do
      buffer = subject.render
      buffer.rewind

      entries = []
      Zip::InputStream.open(StringIO.new(buffer.sysread)) do |zip|
        while (entry = zip.get_next_entry)
          entries << entry.name
        end
      end
      expect(entries.any? { |e| e.start_with?('word/media/') && e.end_with?('.png') }).to be true
    end

    it 'includes word/_rels/header1.xml.rels in the rendered docx' do
      buffer = subject.render
      buffer.rewind

      entries = []
      Zip::InputStream.open(StringIO.new(buffer.sysread)) do |zip|
        while (entry = zip.get_next_entry)
          entries << entry.name
        end
      end
      expect(entries).to include('word/_rels/header1.xml.rels')
    end
  end

  describe 'two different images in the same header are both registered' do
    let(:png1) { "\x89PNG\r\n\x1a\n" + ('a' * 100) }
    let(:png2) { "\x89PNG\r\n\x1a\n" + ('b' * 100) }
    let(:header_xml) do
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
               xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <w:p>
            <w:r><w:drawing><wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">
              <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
                <a:graphicData>
                  <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
                    <pic:blipFill><a:blip r:embed="rId1"/></pic:blipFill>
                  </pic:pic>
                </a:graphicData>
              </a:graphic>
            </wp:inline></w:drawing></w:r>
            <w:r><w:drawing><wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">
              <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
                <a:graphicData>
                  <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
                    <pic:blipFill><a:blip r:embed="rId2"/></pic:blipFill>
                  </pic:pic>
                </a:graphicData>
              </a:graphic>
            </wp:inline></w:drawing></w:r>
          </w:p>
        </w:hdr>
      XML
    end

    before do
      data = build_template_docx(
        header: header_xml,
        images: {
          'rId1' => { target: 'media/logo1.png', data: png1 },
          'rId2' => { target: 'media/logo2.png', data: png2 }
        }
      )
      Tempfile.create(['tmpl', '.docx']) { |tf| tf.write(data); tf.flush; subject.load_template(tf.path) }
    end

    it 'registers two distinct image relationships' do
      rels = subject.instance_variable_get(:@relationships) || subject.relationships
      image_rels = rels.select { |r| r.relationship_type == :image }
      expect(image_rels.size).to be >= 2
    end

    it 'writes two distinct media files in the rendered docx' do
      buffer = subject.render
      buffer.rewind

      media_entries = []
      Zip::InputStream.open(StringIO.new(buffer.sysread)) do |zip|
        while (entry = zip.get_next_entry)
          media_entries << entry.name if entry.name.start_with?('word/media/') && entry.name.end_with?('.png')
        end
      end
      expect(media_entries.uniq.size).to be >= 2
    end
  end

end
