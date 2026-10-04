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

end
