require 'spec_helper'
require File.expand_path(
  File.join(File.dirname(__FILE__), '..', '..', '..', '..',
            'lib', 'puppet', 'util', 'p4_trigger_purge_filter.rb'))

# Puppet::Type::Resources#check consults p4_trigger_check for every purge
# candidate. These examples drive that method directly, because the alternative
# -- exercising a real purge -- needs a live Perforce server.
describe Puppet::Type.type(:resources) do

  OURS   = 'p4_trigger_puppet.config.production.post_commit'.freeze
  THEIRS = 'GF-change-commit'.freeze

  def trigger(name, params = {})
    Puppet::Type.type(:p4_trigger).new({ :name => name }.merge(params))
  end

  # A purger whose catalog declares the given triggers.
  def purger(declared = [])
    catalog = Puppet::Resource::Catalog.new
    declared.each { |res| catalog.add_resource(res) }
    resources = described_class.new(:name => 'p4_trigger', :purge => true)
    catalog.add_resource(resources)
    resources
  end

  context 'with a namespace declared' do
    let(:subject) { purger([trigger(OURS, :purge_namespace => '^p4_trigger_')]) }

    it 'treats an in-namespace trigger as a purge candidate' do
      expect(subject.p4_trigger_check(trigger('p4_trigger_retired.post_commit'))).to be_truthy
    end

    it 'spares a trigger outside the namespace' do
      expect(subject.p4_trigger_check(trigger('some_other_tool_trigger'))).to be_falsey
    end

    it "spares Git Fusion's triggers, which every submit depends on" do
      expect(subject.p4_trigger_check(trigger(THEIRS))).to be_falsey
    end

    it 'anchors the namespace rather than matching it anywhere in the name' do
      expect(subject.p4_trigger_check(trigger('zzz_p4_trigger_suffix'))).to be_falsey
    end
  end

  context 'with a namespace that would match Git Fusion' do
    let(:subject) { purger([trigger(OURS, :purge_namespace => '^')]) }

    # The namespace is the primary mechanism; this is the independent backstop.
    it 'still spares Git Fusion, because the backstop does not consult the pattern' do
      expect(subject.p4_trigger_check(trigger(THEIRS))).to be_falsey
    end

    it 'purges our own entry under the same over-broad pattern' do
      expect(subject.p4_trigger_check(trigger('p4_trigger_retired.post_commit'))).to be_truthy
    end
  end

  context 'with no namespace declared' do
    let(:subject) { purger([trigger(OURS)]) }

    # Unconfigured must mean inert, never "purge everything".
    it 'purges nothing' do
      expect(subject.p4_trigger_check(trigger('p4_trigger_retired.post_commit'))).to be_falsey
      expect(subject.p4_trigger_check(trigger(THEIRS))).to be_falsey
    end
  end

  context 'with no p4_trigger declared at all' do
    let(:subject) { purger([]) }

    it 'purges nothing' do
      expect(subject.p4_trigger_check(trigger('p4_trigger_retired.post_commit'))).to be_falsey
    end
  end
end
