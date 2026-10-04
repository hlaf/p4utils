require 'spec_helper'

# The provider talks to the server only through P4Utils::Helper, which is
# stubbed here (its 'require "P4"' lives inside Helper#initialize, so no
# P4Ruby is needed). Everything the server would answer is scripted.
describe Puppet::Type.type(:p4_user).provider(:p4ruby) do

  let(:helper) { stub('helper') }
  let(:p4config) { '/tmp/p4config.txt' }
  let(:base_params) { { :name => 'bob', :fullname => 'Bob', :email => 'bob@example.com', :p4config => p4config } }
  let(:params) { base_params }
  let(:resource) { Puppet::Type.type(:p4_user).new(params) }
  let(:current) { { :ensure => :present, :name => 'bob', :fullname => 'Bob', :email => 'bob@example.com', :type => :standard, :authmethod => :perforce } }
  let(:provider) { described_class.new(current) }

  before(:each) do
    P4Utils::Helper.stubs(:new).returns(helper)
    resource.provider = provider
  end

  describe '#password_state' do
    context 'without a declared password' do
      it 'is absent and never opens a connection' do
        P4Utils::Helper.expects(:new).never
        expect(provider.password_state).to eq(:absent)
      end
    end

    context 'with a declared password' do
      let(:params) { base_params.merge(:password => 's3cret') }

      it 'probes through a helper bound to the resource p4config' do
        P4Utils::Helper.expects(:new).with(p4config).returns(helper)
        helper.expects(:password_accepted?).with('bob', 's3cret').returns(true)
        expect(provider.password_state).to eq(:accepted)
      end

      it 'is rejected when the server does not take the password' do
        helper.expects(:password_accepted?).with('bob', 's3cret').returns(false)
        expect(provider.password_state).to eq(:rejected)
      end

      it 'lets a broken probe fail the resource rather than guess' do
        helper.expects(:password_accepted?).raises(RuntimeError, 'Connect to server failed')
        expect { provider.password_state }.to raise_error(RuntimeError, /Connect to server failed/)
      end
    end
  end

  describe '#password_state=' do
    let(:params) { base_params.merge(:password => 's3cret') }

    it 'sets the password over the prompt channel and proves it took' do
      set = sequence('enforce')
      helper.expects(:set_password).with('bob', 's3cret').in_sequence(set)
      helper.expects(:password_accepted?).with('bob', 's3cret').returns(true).in_sequence(set)
      provider.password_state = :accepted
    end

    it 'fails loudly when the server still rejects the password afterwards' do
      helper.expects(:set_password).with('bob', 's3cret')
      helper.expects(:password_accepted?).with('bob', 's3cret').returns(false)
      expect { provider.password_state = :accepted }.to raise_error(Puppet::Error, /still rejects the declared password for user 'bob'/)
    end
  end

  describe '.instances' do
    it 'maps every listed user onto the managed properties' do
      helper.expects(:getUsers).returns([{ 'User' => 'ci', 'FullName' => 'CI', 'Email' => 'ci@example.com',
                                           'Type' => 'standard', 'AuthMethod' => 'ldap' }])
      instances = described_class.instances
      expect(instances.map { |i| i.name }).to eq(['ci'])
      expect(instances.first.authmethod).to eq('ldap')
      expect(instances.first.type).to eq('standard')
    end
  end

  describe '#create' do
    let(:provider) { described_class.new }

    context 'with a password declared' do
      let(:params) { base_params.merge(:password => 's3cret') }

      it 'saves the declared fields, then enforces the password (ensure sync skips the other properties)' do
        helper.expects(:saveUser).with('bob', { 'FullName' => 'Bob', 'Email' => 'bob@example.com' })
        helper.expects(:set_password).with('bob', 's3cret')
        helper.expects(:password_accepted?).with('bob', 's3cret').returns(true)
        provider.create
      end

      it 'fails when the password still does not take after creation' do
        helper.stubs(:saveUser)
        helper.expects(:set_password).with('bob', 's3cret')
        helper.expects(:password_accepted?).returns(false)
        expect { provider.create }.to raise_error(Puppet::Error, /still rejects/)
      end
    end

    context 'without a password' do
      it 'does not touch the password' do
        helper.expects(:saveUser).with('bob', { 'FullName' => 'Bob', 'Email' => 'bob@example.com' })
        helper.expects(:set_password).never
        helper.expects(:password_accepted?).never
        provider.create
      end
    end

    context 'with type and authmethod declared' do
      let(:params) { base_params.merge(:type => 'operator', :authmethod => 'ldap') }

      it 'passes them along as the strings the form takes' do
        helper.expects(:saveUser).with('bob', { 'FullName' => 'Bob', 'Email' => 'bob@example.com',
                                                'Type' => 'operator', 'AuthMethod' => 'ldap' })
        provider.create
      end
    end
  end

  describe '#flush' do
    let(:params) { base_params.merge(:password => 's3cret') }

    it 'no longer re-sets the password as a side effect of an unrelated change' do
      helper.expects(:set_password).never
      helper.expects(:password_accepted?).never
      helper.expects(:saveUser).with('bob', { 'FullName' => 'Bob', 'Email' => 'bob@example.com' })
      provider.email = 'bob@example.com'
      provider.flush
    end

    it 'sends only the declared fields: an undeclared authmethod is not guessed from the live value' do
      provider = described_class.new(current.merge(:authmethod => :ldap))
      resource.provider = provider
      helper.expects(:saveUser).with { |_, fields| !fields.has_key?('AuthMethod') && !fields.has_key?('Type') }
      provider.fullname = 'Bob'
      provider.flush
    end

    it 'opens no connection at all when nothing is queued' do
      P4Utils::Helper.expects(:new).never
      provider.flush
    end
  end

end
