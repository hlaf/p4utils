require 'spec_helper'

describe Puppet::Type.type(:p4_ldap) do

  def spec(params = {})
    described_class.new({ :name => 'corp', :host => 'ldap.example.com' }.merge(params))
  end

  def enforced(params = {}, without = [])
    full = { :search_bind_dn => 'cn=proxy,dc=example,dc=com', :search_passwd => 's3cret',
             :probe_user => 'bob', :probe_password => 'bobs-pw' }.merge(params)
    without.each { |key| full.delete(key) }
    spec(full)
  end

  describe 'the spec fields' do
    it 'are properties mapped one to one' do
      [:host, :port, :encryption, :bind_method, :options, :simple_pattern, :search_base_dn, :search_filter,
       :search_scope, :search_bind_dn, :sasl_realm, :group_base_dn, :group_search_filter, :group_search_scope,
       :attribute_uid, :attribute_name, :attribute_email].each do |field|
        expect(described_class.validproperty?(field)).to be_truthy
      end
    end

    it 'keeps the port a string, as the server stores it' do
      expect(spec(:port => 389)[:port]).to eq('389')
    end

    it 'restricts the enumerated fields to the values p4d accepts' do
      expect { spec(:encryption => 'starttls') }.to raise_error(Puppet::Error, /Invalid value/)
      expect { spec(:bind_method => 'anonymous') }.to raise_error(Puppet::Error, /Invalid value/)
      expect { spec(:search_scope => 'one') }.to raise_error(Puppet::Error, /Invalid value/)
      expect { spec(:group_search_scope => 'one') }.to raise_error(Puppet::Error, /Invalid value/)
      expect(spec(:encryption => 'tls', :bind_method => 'search', :search_scope => 'subtree')[:encryption]).to eq(:tls)
    end
  end

  describe 'search_passwd' do
    it 'is a parameter, never a property (keeps the plaintext out of events and reports)' do
      expect(described_class.validparameter?(:search_passwd)).to be true
      expect(described_class.validproperty?(:search_passwd)).to be false
      expect(enforced.properties.map { |p| p.name }).not_to include(:search_passwd)
    end

    it 'rejects an empty password' do
      expect { enforced(:search_passwd => '') }.to raise_error(Puppet::Error, /non-empty/)
    end

    it 'rejects a password containing a newline' do
      expect { enforced(:search_passwd => "top\nsecret") }.to raise_error(Puppet::Error, /newline/)
    end

    it 'needs the probe credentials the server tests it with' do
      expect { enforced({}, [:probe_user]) }.to raise_error(Puppet::Error, /declare probe_user and probe_password/)
      expect { enforced({}, [:probe_password]) }.to raise_error(Puppet::Error, /declare probe_user and probe_password/)
    end

    it 'is required by a declared search_bind_dn (the server binds as that DN with it)' do
      expect { spec(:search_bind_dn => 'cn=proxy,dc=example,dc=com') }.to raise_error(Puppet::Error, /declare search_passwd with it/)
    end

    it 'is what the probe credentials serve; they are refused without it' do
      expect { spec(:probe_user => 'bob', :probe_password => 'bobs-pw') }.to raise_error(Puppet::Error, /only serve search_passwd enforcement/)
    end
  end

  describe 'probe_password' do
    it 'is a parameter and must be a usable password' do
      expect(described_class.validproperty?(:probe_password)).to be false
      expect { enforced(:probe_password => '') }.to raise_error(Puppet::Error, /non-empty/)
      expect { enforced(:probe_password => "a\nb") }.to raise_error(Puppet::Error, /newline/)
    end
  end

  describe 'search_passwd_state' do
    it 'is a property derived from search_passwd, desired accepted' do
      expect(described_class.validproperty?(:search_passwd_state)).to be_truthy
      resource = enforced
      expect(resource.property(:search_passwd_state)).not_to be_nil
      expect(resource[:search_passwd_state]).to eq(:accepted)
    end

    it 'is absent from a resource that declares no search_passwd' do
      resource = spec
      expect(resource.property(:search_passwd_state)).to be_nil
      expect(resource[:search_passwd_state]).to be_nil
    end

    it 'cannot be declared without a search_passwd' do
      expect { spec(:search_passwd_state => 'accepted') }.to raise_error(Puppet::Error, /derived from search_passwd/)
    end

    it 'only accepts "accepted" as a desired value' do
      expect { enforced(:search_passwd_state => 'rejected') }.to raise_error(Puppet::Error, /Invalid value/)
    end

    it 'is the last property, so one save carries every other queued change' do
      expect(enforced.properties.last.name).to eq(:search_passwd_state)
    end

    it 'is out of sync when the directory refuses the bind and in sync when it accepts it' do
      property = enforced.property(:search_passwd_state)
      expect(property.insync?(:rejected)).to be false
      expect(property.insync?(:accepted)).to be true
    end
  end

end
