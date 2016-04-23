require 'spec_helper'
describe 'p4utils' do

  context 'with defaults for all parameters' do
    it { should contain_class('p4utils') }
  end
end
