require 'spec_helper'

describe Puppet::Type.type(:p4_protection) do

  def prot(params = {})
    described_class.new({ :name => 'admin user perforce_maintenance * //...' }.merge(params))
  end

  describe 'position' do
    it 'defaults to the -1 sentinel' do
      expect(prot[:position]).to eq(-1)
    end

    it 'munges a string to an integer' do
      expect(prot(:position => '4')[:position]).to eq(4)
    end

    it 'rejects a value that is not an integer' do
      expect { prot(:position => 'top') }.to raise_error(Puppet::Error, /Invalid value|invalid value for Integer/)
    end

    # -1 means "append at the end": in sync only when the entry is already the
    # last row. An operator-style line that sits at the end must stop reporting
    # false drift on every converge.
    context 'the -1 sentinel (append at end)' do
      it 'is in sync when the entry is already the last row' do
        resource = prot
        resource.provider.stubs(:protection_count).returns(7)
        expect(resource.property(:position).insync?(6)).to be true
      end

      it 'is out of sync when the entry is not the last row' do
        resource = prot
        resource.provider.stubs(:protection_count).returns(7)
        expect(resource.property(:position).insync?(3)).to be false
      end
    end

    context 'an explicit, in-range index' do
      it 'is in sync when the slot matches' do
        resource = prot(:position => 2)
        resource.provider.stubs(:protection_count).returns(7)
        expect(resource.property(:position).insync?(2)).to be true
      end

      it 'is out of sync when the slot has drifted' do
        resource = prot(:position => 2)
        resource.provider.stubs(:protection_count).returns(7)
        expect(resource.property(:position).insync?(5)).to be false
      end
    end

    # The provider clamps an index at/past the end to the end, so insync? must
    # agree -- otherwise such an entry would churn like the raw sentinel did.
    context 'an explicit index at or past the end' do
      it 'is treated like the sentinel (in sync only when last)' do
        resource = prot(:position => 99)
        resource.provider.stubs(:protection_count).returns(7)
        expect(resource.property(:position).insync?(6)).to be true
        expect(resource.property(:position).insync?(4)).to be false
      end
    end

    context 'when the table size is unknown (no prefetched data)' do
      it 'falls back to a literal comparison for an explicit index' do
        resource = prot(:position => 2)
        resource.provider.stubs(:protection_count).returns(nil)
        expect(resource.property(:position).insync?(2)).to be true
        expect(resource.property(:position).insync?(5)).to be false
      end

      it 'is out of sync for the sentinel when the size is unknown' do
        resource = prot
        resource.provider.stubs(:protection_count).returns(nil)
        expect(resource.property(:position).insync?(6)).to be false
      end
    end
  end
end
