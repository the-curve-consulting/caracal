require 'spec_helper'

describe Caracal::Core::PageFlips do
  subject { Caracal::Document.new }
  
  
  #-------------------------------------------------------------
  # Public Methods
  #-------------------------------------------------------------

  describe 'public method tests' do
    
    # .page
    describe '.page_flip' do
      let!(:size) { subject.contents.size }
      
      before do
        subject.page_flip do |x|
          x.p
        end
      end
      
      it { expect(subject.contents.size).to eq size + 1 }
      it { expect(subject.contents.last).to be_a(Caracal::Core::Models::PageFlipModel) }
    end
  end
end
