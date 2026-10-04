require 'spec_helper'

# The provider talks to the server only through P4Utils::Helper, which is
# stubbed here (its 'require "P4"' lives inside Helper#initialize, so no
# P4Ruby is needed). Everything the server would answer is scripted.
describe Puppet::Type.type(:p4_ldap).provider(:p4ruby) do

  let(:helper) { stub('helper') }
  let(:p4config) { '/tmp/p4config.txt' }
  let(:bind_dn) { 'cn=proxy,ou=users,dc=example,dc=com' }
  let(:base_params) { { :name => 'corp', :host => 'ldap.example.com', :encryption => 'tls', :p4config => p4config } }
  let(:enforced_params) do
    base_params.merge(:bind_method => 'search', :search_bind_dn => bind_dn, :search_passwd => 's3cret',
                      :probe_user => 'bob', :probe_password => 'bobs-pw')
  end
  let(:params) { base_params }
  let(:resource) { Puppet::Type.type(:p4_ldap).new(params) }
  # What the server stores today: more fields than the resource manages.
  let(:stored) do
    { 'Name' => 'corp', 'Host' => 'ldap.example.com', 'Port' => '389', 'Encryption' => 'tls',
      'BindMethod' => 'search', 'Options' => 'nodowncase nogetattrs norealminusername',
      'SearchBaseDN' => 'ou=users,dc=example,dc=com', 'SearchFilter' => '(uid=%user%)',
      'SearchScope' => 'subtree', 'SearchBindDN' => bind_dn, 'SearchPasswd' => '******',
      'GroupSearchScope' => 'subtree' }
  end
  let(:current) do
    { :ensure => :present, :name => 'corp', :host => 'ldap.example.com', :port => '389', :encryption => 'tls',
      :bind_method => 'search', :search_bind_dn => bind_dn }
  end
  let(:provider) { described_class.new(current) }

  before(:each) do
    P4Utils::Helper.stubs(:new).returns(helper)
    resource.provider = provider
  end

  describe '.instances' do
    it 'maps every configured spec onto the managed properties' do
      helper.expects(:getLdapNames).returns(['corp'])
      helper.expects(:getLdap).with('corp').returns(stored)
      instances = described_class.instances
      expect(instances.map { |i| i.name }).to eq(['corp'])
      expect(instances.first.host).to eq('ldap.example.com')
      expect(instances.first.port).to eq('389')
      expect(instances.first.search_bind_dn).to eq(bind_dn)
      expect(instances.first.simple_pattern).to be_nil
    end
  end

  describe '#search_passwd_state' do
    context 'without a declared search_passwd' do
      it 'is absent and never opens a connection' do
        P4Utils::Helper.expects(:new).never
        expect(provider.search_passwd_state).to eq(:absent)
      end
    end

    context 'with a declared search_passwd' do
      let(:params) { enforced_params }

      it 'has the server test the configuration, through a helper bound to the resource p4config' do
        P4Utils::Helper.expects(:new).with(p4config).returns(helper)
        helper.expects(:ldap_bind_accepted?).with('corp', bind_dn, 'bob', 'bobs-pw').returns(true)
        expect(provider.search_passwd_state).to eq(:accepted)
      end

      it 'is rejected when the directory refuses the server bind' do
        helper.expects(:ldap_bind_accepted?).returns(false)
        expect(provider.search_passwd_state).to eq(:rejected)
      end

      it 'classifies against the LIVE bind DN, not the declared one, when they differ' do
        provider = described_class.new(current.merge(:search_bind_dn => 'cn=proxy,ou=Users,dc=example,dc=com'))
        resource.provider = provider
        helper.expects(:ldap_bind_accepted?).with('corp', 'cn=proxy,ou=Users,dc=example,dc=com', 'bob', 'bobs-pw').returns(false)
        expect(provider.search_passwd_state).to eq(:rejected)
      end

      it 'lets a broken probe fail the resource rather than guess' do
        helper.expects(:ldap_bind_accepted?).raises(RuntimeError, 'Failed to initialize LDAP connection')
        expect { provider.search_passwd_state }.to raise_error(RuntimeError, /initialize LDAP connection/)
      end
    end
  end

  describe '#search_passwd_state=' do
    let(:params) { enforced_params }

    it 're-saves the stored form with the declared fields and password, then proves the bind took' do
      helper.expects(:getLdap).with('corp').returns(stored.dup)
      saved = nil
      helper.expects(:saveLdap).with { |form| saved = form; true }
      helper.expects(:ldap_bind_accepted?).with('corp', bind_dn, 'bob', 'bobs-pw').returns(true)
      provider.search_passwd_state = :accepted
      expect(saved['SearchPasswd']).to eq('s3cret')
      expect(saved['Host']).to eq('ldap.example.com')
      expect(saved['Encryption']).to eq('tls')
      # Fields the resource does not manage survive untouched.
      expect(saved['Options']).to eq('nodowncase nogetattrs norealminusername')
      expect(saved['GroupSearchScope']).to eq('subtree')
      expect(saved['SearchFilter']).to eq('(uid=%user%)')
    end

    it 'fails loudly when the directory still refuses the bind afterwards' do
      helper.stubs(:getLdap).returns(stored.dup)
      helper.expects(:saveLdap)
      helper.expects(:ldap_bind_accepted?).returns(false)
      expect { provider.search_passwd_state = :accepted }.to raise_error(Puppet::Error, /still refuses the server's bind for LDAP configuration 'corp'/)
    end

    it 'carries the other queued changes in the same save, which flush then skips' do
      helper.stubs(:getLdap).returns(stored.merge('Host' => 'old.example.com'))
      saved = nil
      helper.expects(:saveLdap).once.with { |form| saved = form; true }
      helper.stubs(:ldap_bind_accepted?).returns(true)
      provider.host = 'ldap.example.com'
      provider.search_passwd_state = :accepted
      provider.flush
      expect(saved['Host']).to eq('ldap.example.com')
    end

    it 'never puts the password anywhere but the form (no property carries it into events or reports)' do
      helper.stubs(:getLdap).returns(stored.dup)
      helper.expects(:saveLdap).with { |form| form['SearchPasswd'] == 's3cret' }
      helper.stubs(:ldap_bind_accepted?).returns(true)
      provider.search_passwd_state = :accepted
      desired = resource.properties.map { |p| p.should.to_s }
      expect(desired).not_to include('s3cret')
      expect(desired).not_to include('bobs-pw')
      expect(desired).to include('accepted')
    end
  end

  describe '#create' do
    let(:provider) { described_class.new }

    context 'with a search_passwd declared' do
      let(:params) { enforced_params }

      it 'saves the declared fields over the server template, then proves the bind' do
        helper.expects(:getLdap).with('corp').returns({ 'Name' => 'corp', 'Port' => '389', 'Encryption' => 'none', 'BindMethod' => 'simple' })
        saved = nil
        helper.expects(:saveLdap).with { |form| saved = form; true }
        helper.expects(:ldap_bind_accepted?).with('corp', bind_dn, 'bob', 'bobs-pw').returns(true)
        provider.create
        expect(saved).to eq('Name' => 'corp', 'Port' => '389', 'Encryption' => 'tls', 'BindMethod' => 'search',
                            'Host' => 'ldap.example.com', 'SearchBindDN' => bind_dn, 'SearchPasswd' => 's3cret')
      end

      it 'fails when the bind still does not take after creation' do
        helper.stubs(:getLdap).returns({})
        helper.expects(:saveLdap)
        helper.expects(:ldap_bind_accepted?).returns(false)
        expect { provider.create }.to raise_error(Puppet::Error, /still refuses/)
      end
    end

    context 'without a search_passwd' do
      it 'saves without probing' do
        helper.expects(:getLdap).returns({})
        helper.expects(:saveLdap).with('Name' => 'corp', 'Host' => 'ldap.example.com', 'Encryption' => 'tls')
        helper.expects(:ldap_bind_accepted?).never
        provider.create
      end
    end
  end

  describe '#destroy' do
    it 'deletes the configuration' do
      helper.expects(:deleteLdap).with('corp')
      provider.destroy
    end
  end

  describe '#flush' do
    it 'saves the declared fields over the stored form once something is queued' do
      helper.expects(:getLdap).with('corp').returns(stored.dup)
      saved = nil
      helper.expects(:saveLdap).with { |form| saved = form; true }
      provider.host = 'ldap.example.com'
      provider.flush
      expect(saved['Host']).to eq('ldap.example.com')
      expect(saved['SearchPasswd']).to eq('******')  # not declared: passed through as the server gave it
      expect(saved['Options']).to eq('nodowncase nogetattrs norealminusername')
    end

    it 'opens no connection at all when nothing is queued' do
      P4Utils::Helper.expects(:new).never
      provider.flush
    end
  end

end
