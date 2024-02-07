require 'spec_helper'

describe Caracal::Core::Models::TableOfContentsModel do
  subject do
    described_class.new
  end


  #-------------------------------------------------------------
  # Configuration
  #-------------------------------------------------------------

  describe 'configuration tests' do

    # accessors
    describe 'accessors' do
      it { expect(subject.toc_opts).to eq 'TOC \o "1-1" \h \z \u \t "Heading 5,1"' }
      it { expect(subject.toc_size).to eq 32 }
      it { expect(subject.toc_title).to eq 'Table of Contents' }
    end
  end


  #-------------------------------------------------------------
  # Public Methods
  #-------------------------------------------------------------

  describe 'public method tests' do
    #=============== GETTERS ==========================


    #=============== SETTERS ==========================

    # integers
    describe '.size' do
      before { subject.size(24) }

      it { expect(subject.toc_size).to eq 24 }
    end

    # strings
    describe '.opts' do
      before { subject.opts('TOC \o "1-1"') }

      it { expect(subject.toc_opts).to eq 'TOC \o "1-1"' }
    end
    describe '.title' do
      before { subject.title('Hello World') }

      it { expect(subject.toc_title).to eq 'Hello World' }
    end

    #=============== VALIDATION ===========================

    describe '.valid?' do
      describe 'when the opts exist' do
        before do
          allow(subject).to receive(:opts).and_return('TOC \o "1-1"')
        end

        it { expect(subject.valid?).to eq true }
      end
      describe 'when no runs exist' do
        before do
          allow(subject).to receive(:opts).and_return(nil)
        end

        it { expect(subject.valid?).to eq false }
      end
    end

  end


  #-------------------------------------------------------------
  # Private Methods
  #-------------------------------------------------------------

  describe 'private method tests' do

    # .option_keys
    describe '.option_keys' do
      let(:actual)   { subject.send(:option_keys).sort }
      let(:expected) { [:opts, :size, :title].sort }

      it { expect(actual).to eq expected }
    end

  end

end
