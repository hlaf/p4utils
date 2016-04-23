
Puppet::Type.newtype(:p4_setting) do
  desc <<-'ENDOFDESC'
  Manages Perforce configuration settings.

  Example usage:

  p4_setting { 'security':
    value => '3',
  }

  ENDOFDESC

  ensurable

  newproperty(:state) do
    desc <<-EOT
      *READ ONLY*
      The state of the configurable.
      Possible values are `default`, `environment`, `configure` and `tunable`.
      * `default` - indicates that this value is currenly unconfigured, and is set to the default value.
      * `environment` - indicates that this value is configured via environment variables.
      * `configure` - indicates that the value is a switch that sets functionality on the server, and is configured.
      * `tunable` - indicates that the value is a variable that affects server tuning, and is configured.
    EOT
    validate do |val|
      fail "state is read-only"
    end
  end

  newparam(:name, :namevar => true) do
   desc "P4 configuration setting name - must be unique"
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

  newproperty(:value) do
    desc "Value associated with the setting"
  end


end
