require 'spec_helper'

describe Caracal::Core::Fields do
  subject { Caracal::Document.new }
  
  
  #-------------------------------------------------------------
  # Public Methods
  #-------------------------------------------------------------

  describe 'public method tests' do
    
    # .table
    describe '.field' do
      let!(:size) { subject.contents.size }
      
      before { subject.field :table_of_contents }
      
      it { expect(subject.contents.size).to eq size + 1 }
      it { expect(subject.contents.last).to be_a(Caracal::Core::Models::FieldModel) }
    end
    
  end
  
end
