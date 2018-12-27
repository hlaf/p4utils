
Puppet::Type.newtype(:p4_group) do
  desc <<-'ENDOFDESC'
  Manages Perforce groups.

  Example usage:

  p4_group { 'admins':
    ensure      => present,
    users       => ['p4admin','joe'],
    owners      => ['p4admin'],
    subgroups   => ['grp1'],
    maxlocktime => 'unset',
    maxscanrows => 'unset',
    maxresults  => 'unset',
    timeout     => 'unlimited',
    passtimeout => 'unset',
  }

  ENDOFDESC

  ensurable

  newparam(:name, :namevar => true) do
   desc "P4 group name - must be unique"
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

  newproperty(:users, :array_matching => :all) do
    desc "An array of group members"
    def flatten_and_sort(array)
      array = [array] unless array.is_a? Array
      array.collect { |a| a.split(' ') }.flatten.sort
    end

    def insync?(is)
      return @should == [:absent] if is == :absent
      flatten_and_sort(is) == flatten_and_sort(@should)
    end
  end

  newproperty(:owners, :array_matching => :all) do
    desc "An array of group owners"
    def flatten_and_sort(array)
      array = [array] unless array.is_a? Array
      array.collect { |a| a.split(' ') }.flatten.sort
    end

    def insync?(is)
      return @should == [:absent] if is == :absent
      flatten_and_sort(is) == flatten_and_sort(@should)
    end
  end

  newproperty(:subgroups, :array_matching => :all) do
    desc "An array of subgroups"
    def flatten_and_sort(array)
      array = [array] unless array.is_a? Array
      array.collect { |a| a.split(' ') }.flatten.sort
    end

    def insync?(is)
      return @should == [:absent] if is == :absent
      flatten_and_sort(is) == flatten_and_sort(@should)
    end
  end

  newproperty(:maxlocktime) do
    desc "The maximum time that locks will be placed in the Perforce database"
  end

  newproperty(:maxscanrows) do
    desc "The maximum number of rows that will be scanned in the Perforce database"
  end

  newproperty(:maxresults) do
    desc "The maximum number of results returned by a command execution"
  end

  newproperty(:timeout) do
    desc "A timeout value for login tickets"
  end

  newproperty(:passtimeout) do
    desc "The expiration time for user passwords"
  end

end
