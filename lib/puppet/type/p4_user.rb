
Puppet::Type.newtype(:p4_user) do
  desc <<-'ENDOFDESC'
  Manages Perforce users accounts.

  Example usage:

  p4_user { 'joeuser':
    fullname     => 'Joe User',
    email        => 'joe@host.com',
    password     => 'supersecret',
    groups       => 'user,admin',
    instance_dir => '/opt/www/dokuwiki',
  }

  ENDOFDESC

  ensurable

  newparam(:name, :namevar => true) do
   desc "P4 login name - must be unique"
  end

  newparam(:password) do
    desc "the user's password"
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

  newproperty(:fullname) do
    desc "The user's real name"
  end

  newproperty(:email) do
    desc "The user's email address"
  end

  newproperty(:type) do
    desc "The Perforce user type. This cannot be changed once set."
    defaultto :standard
    newvalues(:standard, :service, :operator)
  end

  newproperty(:authmethod) do
    desc "The authetication method (perforce or ldap) for the user"
    defaultto :perforce
    newvalues(:perforce, :ldap)
  end

end
