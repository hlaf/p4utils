require 'spec_helper'
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'lib', 'puppet_x', 'p4utils', 'helper.rb'))

# P4Ruby is not installed here, so these specs stand in a scripted P4 class:
# it records what the helper sends (which must never be a password on a
# command line) and answers the way the real API does -- a P4Exception
# whose detail sits in #errors, or plain output.
class P4Exception < RuntimeError; end unless defined?(P4Exception)

class FakeP4
  attr_accessor :user, :password, :ticket_file, :prog, :port, :input
  attr_reader :calls, :errors, :warnings

  def initialize(script = {})
    @script = script
    @calls = []
    @errors = []
    @warnings = []
    @port = script.fetch(:port, 'localhost:1666')
    @user = script.fetch(:user, nil)
    @connected = false
  end

  def connect
    @calls << [:connect]
    fail_with(@script[:connect_error]) if @script[:connect_error]
    @connected = true
  end

  def disconnect
    @calls << [:disconnect]
    @connected = false
  end

  def connected?
    @connected
  end

  def run_trust(*args)
    @calls << [:run_trust] + args
    []
  end

  def run(*args)
    @calls << [:run] + args
    []
  end

  def run_login(*args)
    @calls << [:run_login] + args
    fail_with(@script[:login_error]) if @script[:login_error]
    fail_with(@script[:login_warning], @warnings) if @script[:login_warning]
    @script.fetch(:login_output, ['TICKET0123456789ABCDEF'])
  end

  # 'p4 ldaps' lists {name, host, port, type, status} per configuration.
  def run_ldaps(*args)
    @calls << [:run_ldaps] + args
    @script.fetch(:ldaps, [])
  end

  # 'p4 ldap -o <name>' answers the stored form (a template for an unknown
  # name); '-d' deletes; '-t <user> <name>' is the server-side test, which
  # consumes the password from #input and answers with a verdict.
  def run_ldap(*args)
    @calls << [:run_ldap] + args
    case args.first
    when '-o'
      form = @script.fetch(:ldap_forms, {})[args[1]]
      [form ? form.dup : { 'Name' => args[1], 'Port' => '389', 'Encryption' => 'none', 'BindMethod' => 'simple' }]
    when '-d'
      []
    when '-t'
      @calls << [:prompt_answered, @input]
      fail_with(@script[:ldap_test_error]) if @script[:ldap_test_error]
      @script.fetch(:ldap_test_output, ['Authentication successful.'])
    end
  end

  def save_ldap(form)
    @calls << [:save_ldap, form]
    ["LDAP configuration #{form['Name']} saved."]
  end

  private

  def fail_with(message, sink = @errors)
    sink << message
    raise P4Exception, "[P4#run] Errors during command execution\n\n\t[Error]: #{message}\n\n"
  end
end

class P4; end unless defined?(P4)

describe P4Utils::Helper do

  # Build a helper around a scripted superuser session without running
  # Helper#initialize (which would 'require "P4"' and connect).
  def helper_with(session)
    helper = described_class.allocate
    helper.instance_variable_set(:@p4, session)
    helper
  end

  describe '#set_password' do
    let(:session) { FakeP4.new(:user => 'p4admin') }
    let(:helper) { helper_with(session) }

    it 'answers the two passwd prompts over the input channel, never on the command line' do
      helper.set_password('bob', 's3cret')
      expect(session.input).to eq(['s3cret', 's3cret'])
      expect(session.calls).to eq([[:run, 'passwd', 'bob']])
      expect(session.calls.flatten).not_to include('-P')
      expect(session.calls.flatten).not_to include('s3cret')
    end

    it 'refuses to change the session user password (p4d asks for the old one first)' do
      expect { helper.set_password('p4admin', 's3cret') }.to raise_error(RuntimeError, /session user 'p4admin'/)
      expect(session.calls).to be_empty
    end
  end

  describe '#password_accepted?' do
    let(:helper) { helper_with(FakeP4.new(:user => 'p4admin')) }
    let(:probe) { FakeP4.new(script) }
    let(:script) { {} }

    before(:each) do
      P4.stubs(:new).returns(probe)
    end

    def probe!(userid = 'bob', password = 's3cret')
      helper.password_accepted?(userid, password)
    end

    context 'when the server issues a ticket' do
      it 'is true' do
        expect(probe!).to be true
      end

      it 'probes as the user, with the password on the API and a display-only login' do
        probe!
        expect(probe.user).to eq('bob')
        expect(probe.password).to eq('s3cret')
        expect(probe.prog).to eq('puppet-p4_user')
        expect(probe.calls).to eq([[:connect], [:run_login, '-p'], [:disconnect]])
        expect(probe.calls.flatten).not_to include('s3cret')
      end

      it 'keeps the probe away from the superuser ticket file and cleans up its own' do
        probe_tickets = nil
        probe.define_singleton_method(:connect) { probe_tickets = ticket_file; @connected = true; @calls << [:connect] }
        probe!
        expect(probe_tickets).to be_a(String)
        expect(probe_tickets).not_to be_empty
        expect(File.exist?(probe_tickets)).to be false
      end

      it 'does not trust a plaintext port' do
        probe!
        expect(probe.calls.map { |c| c.first }).not_to include(:run_trust)
      end
    end

    context 'over SSL' do
      let(:script) { { :port => 'ssl:localhost:1666' } }

      it 'accepts the server fingerprint before logging in' do
        probe!
        expect(probe.calls).to eq([[:connect], [:run_trust, '-y'], [:run_login, '-p'], [:disconnect]])
      end
    end

    context 'when the server rejects the password' do
      let(:script) { { :login_error => 'Authentication failed.' } }

      it 'is false and still disconnects' do
        expect(probe!).to be false
        expect(probe.calls.last).to eq([:disconnect])
      end
    end

    context 'when the server says the password is invalid' do
      let(:script) { { :login_error => "Perforce password (P4PASSWD) invalid or unset." } }

      it 'is false' do
        expect(probe!).to be false
      end
    end

    context 'when the user has no password set at all' do
      let(:script) { { :login_output => ["'login' not necessary, no password set for this user."] } }

      it 'is false (the declared password is not what the account has)' do
        expect(probe!).to be false
      end
    end

    context 'when the same verdict arrives as a raised warning' do
      let(:script) { { :login_warning => "'login' not necessary, no password set for this user." } }

      it 'is false' do
        expect(probe!).to be false
      end
    end

    context 'when the failure is not about the password' do
      let(:script) { { :login_error => "Access for user 'bob' has not been enabled by 'p4 protect'." } }

      it 're-raises instead of guessing' do
        expect { probe! }.to raise_error(P4Exception, /p4 protect/)
        expect(probe.calls.last).to eq([:disconnect])
      end
    end

    context 'when the server cannot be reached' do
      let(:script) { { :connect_error => 'Connect to server failed; check $P4PORT.' } }

      it 're-raises and does not try to disconnect an unconnected probe' do
        expect { probe! }.to raise_error(P4Exception, /Connect to server failed/)
        expect(probe.calls).to eq([[:connect]])
      end
    end
  end

  describe 'LDAP configurations' do
    let(:bind_dn) { 'cn=proxy,ou=users,dc=example,dc=com' }
    let(:stored) do
      { 'Name' => 'corp', 'Host' => 'ldap.example.com', 'Port' => '389', 'Encryption' => 'tls',
        'BindMethod' => 'search', 'SearchBindDN' => bind_dn, 'SearchPasswd' => '******',
        'GroupSearchScope' => 'subtree' }
    end
    let(:script) { { :ldaps => [{ 'name' => 'corp', 'host' => 'ldap.example.com', 'port' => '389', 'type' => 'tls', 'status' => 'active' }], :ldap_forms => { 'corp' => stored } } }
    let(:session) { FakeP4.new(script.merge(:user => 'p4admin')) }
    let(:helper) { helper_with(session) }

    describe '#getLdapNames' do
      it 'lists the configured names' do
        expect(helper.getLdapNames).to eq(['corp'])
      end

      it 'fails loudly on a listing it does not understand rather than reporting nothing' do
        session = FakeP4.new(:ldaps => [{ 'host' => 'x' }])
        expect { helper_with(session).getLdapNames }.to raise_error(RuntimeError, /unexpected 'p4 ldaps' output/)
      end
    end

    describe '#getLdap' do
      it 'fetches the stored form' do
        expect(helper.getLdap('corp')).to eq(stored)
        expect(session.calls).to eq([[:run_ldap, '-o', 'corp']])
      end
    end

    describe '#saveLdap' do
      it 'hands the whole form, password included, to the API input channel (never a command line)' do
        form = stored.merge('SearchPasswd' => 'new-s3cret')
        helper.saveLdap(form)
        expect(session.calls).to eq([[:save_ldap, form]])
        expect(session.calls.flatten.select { |c| c.is_a?(String) }).not_to include('new-s3cret')
      end
    end

    describe '#deleteLdap' do
      it 'deletes a configured name' do
        helper.deleteLdap('corp')
        expect(session.calls.last).to eq([:run_ldap, '-d', 'corp'])
      end

      it 'is a no-op for an unknown name' do
        helper.deleteLdap('nope')
        expect(session.calls).to eq([[:run_ldaps]])
      end
    end

    describe '#ldap_bind_accepted?' do
      def probe!
        helper.ldap_bind_accepted?('corp', bind_dn, 'bob', 'bobs-pw')
      end

      context 'when the server authenticates the probe user' do
        it 'is true' do
          expect(probe!).to be true
        end

        it 'runs the server-side test as the probe user, answering its password prompt over the input channel' do
          probe!
          expect(session.calls).to eq([[:run_ldap, '-t', 'bob', 'corp'], [:prompt_answered, 'bobs-pw']])
          expect(session.calls.first).not_to include('bobs-pw')
        end
      end

      context 'when the directory refuses the configuration\'s own bind (stale SearchPasswd)' do
        let(:script) { super().merge(:ldap_test_error => "Authentication as #{bind_dn} failed. Reason: Invalid credentials") }

        it 'is false' do
          expect(probe!).to be false
        end

        it 'matches the bind DN case-insensitively (directories do)' do
          expect(helper.ldap_bind_accepted?('corp', bind_dn.upcase, 'bob', 'bobs-pw')).to be false
        end
      end

      context 'when the directory refuses the probe user instead' do
        let(:script) { super().merge(:ldap_test_error => 'Authentication as uid=bob,ou=users,dc=example,dc=com failed. Reason: Invalid credentials') }

        it 're-raises: that is not the server\'s credential' do
          expect { probe! }.to raise_error(P4Exception, /uid=bob/)
        end
      end

      context 'when the server reports a plain failure without naming a DN' do
        let(:script) { super().merge(:ldap_test_error => 'Authentication for bob failed against configuration corp.') }

        it 'counts it as a rejection (the caller re-saves and re-probes)' do
          expect(probe!).to be false
        end
      end

      context 'when no bind DN is live' do
        let(:script) { super().merge(:ldap_test_error => "Authentication as #{bind_dn} failed. Reason: Invalid credentials") }

        it 'cannot attribute a named failure to the server and re-raises' do
          expect { helper.ldap_bind_accepted?('corp', nil, 'bob', 'bobs-pw') }.to raise_error(P4Exception)
        end
      end

      context 'when the failure is not an authentication verdict' do
        let(:script) { super().merge(:ldap_test_error => 'Failed to initialize LDAP connection to: ldap.example.com:389') }

        it 're-raises instead of guessing' do
          expect { probe! }.to raise_error(P4Exception, /initialize LDAP connection/)
        end
      end

      context 'when the server answers without a verdict' do
        let(:script) { super().merge(:ldap_test_output => []) }

        it 'fails rather than reading silence as success' do
          expect { probe! }.to raise_error(RuntimeError, /gave no verdict/)
        end
      end
    end
  end

end
