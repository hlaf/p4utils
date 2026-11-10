require File.expand_path(File.join(File.dirname(__FILE__), '..', 'util',
                                   'p4_trigger_purge_filter.rb'))

Puppet::Type.newtype(:p4_trigger) do
  desc <<-'ENDOFDESC'
  Manages Perforce triggers.

  Example usage:

  p4_trigger { 'codemgr':
    type    => 'change-commit',
    path    => '//depot/puppet/control/production/...',
    command => '/p4/triggers/webhook_trigger.sh production',
  }

  ENDOFDESC

  ensurable

  # Remembered from whichever resource declares it, so self.instances can
  # connect when it is reached outside a prefetch. The purge path gets there
  # through Resources#generate, which runs while the transaction graph is being
  # built -- before any provider prefetch, and regardless of how the resources
  # are ordered against each other. A parameter's validate runs earlier still,
  # when the catalog is turned into resources, so this is set in time.
  class << self
    attr_accessor :p4config_hint
  end

  newparam(:name, :namevar => true) do
   desc "Trigger name - must be unique"
   newvalues(/\w*/)
  end

  newparam(:p4config) do
    desc "location of the p4config file"
    configfile = nil
    # validate the p4config parameter, if passed to the resource
    validate do |value|
      configfile = value
      Puppet::Type.type(:p4_trigger).p4config_hint = value
    end
    # if no parameter passed, check for the default configfile
    if !configfile then
      defaultcfg = File.join(Puppet[:confdir], 'p4config.txt')
      if File.exists?(defaultcfg) then
        configfile = defaultcfg
      end
    end
    # set the P4CONFIG environment variable if a configfile exists
    if configfile then
      ENV['P4CONFIG'] = configfile
    end
  end

  newparam(:purge_namespace) do
    desc "Regular expression matching the trigger names this catalog owns.

      Consumed by `resources { 'p4_trigger': purge => true }`, which retires
      only the entries whose name matches. Triggers installed by other software
      -- Git Fusion's, for one -- share this server's single trigger table and
      must survive a purge, so leaving this unset removes nothing at all."
  end

  newproperty(:type) do
    desc "The type of trigger"
  end

  newproperty(:path) do
    desc "The depot path affected by the trigger"
  end

  newproperty(:command) do
    desc "The command line to execute"
  end

end
