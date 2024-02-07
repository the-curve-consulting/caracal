require 'spec_helper'

describe Caracal::Core::Tables do
  subject { Caracal::Document.new }
  
  
  #-------------------------------------------------------------
  # Public Methods
  #-------------------------------------------------------------

  describe 'public method tests' do
    
    # .table
    describe '.table' do
      let!(:size) { subject.contents.size }
      
      before { subject.table [['Sample Text']] }
      
      it { expect(subject.contents.size).to eq size + 1 }
      it { expect(subject.contents.last).to be_a(Caracal::Core::Models::TableModel) }
      it { expect(subject.contents.last.table_width).to be(9360) }
    end

    describe '.table within a page-flip' do
      let!(:size) { subject.contents.size }
      
      before do
        subject.page_flip do |x|
          x.table [['Sample Text']]
        end
      end
      
      it { expect(subject.contents.size).to eq size + 1 }
      it { expect(subject.contents.last.contents.first).to be_a(Caracal::Core::Models::TableModel) }
      it { expect(subject.contents.last.contents.first.table_width).to be(12960) }
    end
  end
end
