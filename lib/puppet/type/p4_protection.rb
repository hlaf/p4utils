
Puppet::Type.newtype(:p4_protection) do
  desc <<-'ENDOFDESC'
  Manages Perforce protection entries.

  Example usage:

  p4_setting { 'write group admins //depot/...':
    position => 4,
  }

  ENDOFDESC

  ensurable

  newparam(:line, :namevar => true) do
   desc "P4 protection entry - must be unique"
   munge do |v|
     v.strip.gsub(/\s+/, ' ')
   end
  end

  newparam(:p4config) do
    desc "location of the p4config file"
    configfile = nil
    # validate the p4config parameter, if passed to the resource
    validate do |value|
      configfile = value
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

  newproperty(:position) do
    desc "Position of the entry in the protections file. Lower numbers are higher. This should be an integer"
    defaultto (-1)
    munge do |v|
      case v
      when Integer
        v
      when String
        Integer(v)
      else
        raise ArgumentError, "Invalid value #{v.inspect}."
      end
    end
  end

end
