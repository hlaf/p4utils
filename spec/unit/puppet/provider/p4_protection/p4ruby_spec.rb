require 'spec_helper'

# The provider talks to the server only through P4Utils::Helper, which is
# stubbed here (its 'require "P4"' lives inside Helper#initialize, so no
# P4Ruby is needed). Everything the server would answer is scripted.
describe Puppet::Type.type(:p4_protection).provider(:p4ruby) do

  let(:helper) { stub('helper') }
  let(:line) { 'admin user perforce_maintenance * //...' }

  before(:each) do
    P4Utils::Helper.stubs(:new).returns(helper)
  end

  describe 'self.instances' do
    it 'reports each entry index and the table size so the sentinel can be resolved' do
      helper.stubs(:getProtections).returns([
        { 'mode' => 'write', 'type' => 'user', 'name' => 'alice', 'host' => '*', 'path' => '//...' },
        { 'mode' => 'admin', 'type' => 'user', 'name' => 'perforce_maintenance', 'host' => '*', 'path' => '//...' },
      ])
      instances = described_class.instances
      expect(instances.map { |p| p.name }).to eq([
        'write user alice * //...',
        'admin user perforce_maintenance * //...',
      ])
      expect(instances.last.position).to eq(1)
      expect(instances.last.protection_count).to eq(2)
    end
  end

  describe '#flush' do
    # Nothing changed for an in-position entry, so the security-critical table
    # must not be re-saved. With position in sync Puppet never calls the
    # setter, so property_flush stays empty and flush is a no-op.
    it 'does not rewrite the table for an in-position entry' do
      resource = Puppet::Type.type(:p4_protection).new(:name => line, :position => -1)
      provider = described_class.new(:ensure => :present, :name => line, :position => 1, :count => 2)
      resource.provider = provider
      helper.expects(:addProtection).never
      provider.flush
    end

    # An entry declared at an explicit index that has drifted is moved back.
    it 'moves an entry whose explicit index has drifted' do
      resource = Puppet::Type.type(:p4_protection).new(:name => line, :position => 2)
      provider = described_class.new(:ensure => :present, :name => line, :position => 5, :count => 7)
      resource.provider = provider
      provider.position = 2
      helper.expects(:addProtection).with('admin', 'user', 'perforce_maintenance', '*', '//...', 2)
      provider.flush
    end
  end
end
