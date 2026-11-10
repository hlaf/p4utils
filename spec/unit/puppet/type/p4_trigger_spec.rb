require 'spec_helper'

describe Puppet::Type.type(:p4_trigger) do

  def trigger(params = {})
    described_class.new({ :name => 'p4_trigger_example.post_commit' }.merge(params))
  end

  before(:each) { described_class.p4config_hint = nil }
  after(:each)  { described_class.p4config_hint = nil }

  describe 'the purge_namespace parameter' do
    it 'is accepted' do
      expect(described_class.validparameter?(:purge_namespace)).to be_truthy
    end

    it 'is unset by default, so a purge of this type removes nothing' do
      expect(trigger[:purge_namespace]).to be_nil
    end

    it 'keeps the pattern verbatim' do
      expect(trigger(:purge_namespace => '^p4_trigger_')[:purge_namespace]).to eq('^p4_trigger_')
    end
  end

  describe 'the p4config hint' do
    # self.instances is reached from Resources#generate while the transaction
    # graph is built, which is before any prefetch has set an ambient P4CONFIG.
    # Recording the value at validate time is what lets the enumeration connect.
    it 'is recorded when a resource declares p4config' do
      trigger(:p4config => '/tmp/p4config.txt')
      expect(described_class.p4config_hint).to eq('/tmp/p4config.txt')
    end

    it 'stays unset when no resource declares one' do
      trigger
      expect(described_class.p4config_hint).to be_nil
    end
  end
end
