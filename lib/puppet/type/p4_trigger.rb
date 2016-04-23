
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

  newparam(:name, :namevar => true) do
   desc "Trigger name - must be unique"
   newvalues(/\w*/)
  end

  newparam(:p4config) do
    desc "location of the p4config file"
    configfile = nil
    # validate the p4config parameter, if passed to the resource
    validate do |value|
      if !File.exists?(value) then
        raise ArgumentError, "file #{value} does not exist"
      else
        configfile = value
      end
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
