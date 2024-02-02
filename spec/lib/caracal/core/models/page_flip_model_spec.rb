require 'spec_helper'

describe Caracal::Core::Models::PageFlipModel do
  let(:name) { 'Arial' }
  
  subject { described_class.new }
  
  
  #-------------------------------------------------------------
  # Configuration
  #-------------------------------------------------------------
  
  describe 'configuration tests' do
    
    describe 'inheritance' do
      it { expect(subject).to be_a(Caracal::Core::Models::BaseModel) }
    end
  end

  #=============== VALIDATION ===========================

  describe '.valid?' do
    describe 'when content provided' do
      before { allow(subject).to receive(:contents).and_return(['a']) }
      
      it { expect(subject.valid?).to eq true }
    end
    describe 'when content not provided' do
      before { allow(subject).to receive(:contents).and_return([]) }
      
      it { expect(subject.valid?).to eq false }
    end
  end
end
