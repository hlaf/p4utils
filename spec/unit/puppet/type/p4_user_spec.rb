require 'spec_helper'

describe Puppet::Type.type(:p4_user) do

  def user(params = {})
    described_class.new({ :name => 'bob', :fullname => 'Bob', :email => 'bob@example.com' }.merge(params))
  end

  describe 'type and authmethod' do
    it 'have no default, so an undeclared field is left as the server has it' do
      resource = user
      expect(resource[:type]).to be_nil
      expect(resource[:authmethod]).to be_nil
      expect(resource.properties.map { |p| p.name }).not_to include(:type, :authmethod)
    end

    it 'take only the values p4d accepts' do
      expect(user(:type => 'operator', :authmethod => 'ldap')[:authmethod]).to eq(:ldap)
      expect { user(:type => 'admin') }.to raise_error(Puppet::Error, /Invalid value/)
      expect { user(:authmethod => 'kerberos') }.to raise_error(Puppet::Error, /Invalid value/)
    end
  end

  describe 'password' do
    it 'is a parameter, never a property (keeps the plaintext out of events and reports)' do
      expect(described_class.validparameter?(:password)).to be true
      expect(described_class.validproperty?(:password)).to be false
      expect(user(:password => 's3cret').properties.map { |p| p.name }).not_to include(:password)
    end

    it 'rejects an empty password' do
      expect { user(:password => '') }.to raise_error(Puppet::Error, /non-empty/)
    end

    it 'rejects a password containing a newline' do
      expect { user(:password => "top\nsecret") }.to raise_error(Puppet::Error, /newline/)
    end

    it 'cannot be combined with authmethod => ldap' do
      expect { user(:password => 's3cret', :authmethod => 'ldap') }.to raise_error(Puppet::Error, /LDAP/)
    end
  end

  describe 'password_state' do
    it 'is a property derived from password, desired accepted' do
      expect(described_class.validproperty?(:password_state)).to be_truthy
      resource = user(:password => 's3cret')
      expect(resource.property(:password_state)).not_to be_nil
      expect(resource[:password_state]).to eq(:accepted)
    end

    it 'is absent from a resource that declares no password' do
      resource = user
      expect(resource.property(:password_state)).to be_nil
      expect(resource[:password_state]).to be_nil
    end

    it 'cannot be declared without a password' do
      expect { user(:password_state => 'accepted') }.to raise_error(Puppet::Error, /derived from password/)
    end

    it 'only accepts "accepted" as a desired value' do
      expect { user(:password => 's3cret', :password_state => 'rejected') }.to raise_error(Puppet::Error, /Invalid value/)
    end

    it 'is out of sync when the server rejects the password and in sync when it accepts it' do
      property = user(:password => 's3cret').property(:password_state)
      expect(property.insync?(:rejected)).to be false
      expect(property.insync?(:accepted)).to be true
    end
  end

end
