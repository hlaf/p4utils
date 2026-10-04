
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
    desc "The user's password. When given, the password is ENFORCED: each
      run the provider verifies that the server still accepts it for this
      user (a display-only 'login -p' probe on a connection of its own) and,
      when it does not, re-sets it through the superuser session. Declared
      as a parameter, not a property, so the plaintext never becomes a
      desired value in events, reports or the catalog diff -- the derived
      'password_state' property carries the outcome instead. The password
      only ever travels over the Perforce API's prompt channel; it is never
      placed on a command line."
    validate do |value|
      unless value.is_a?(String) && !value.empty?
        raise ArgumentError, "password must be a non-empty string"
      end
      if value.include?("\n") then
        raise ArgumentError, "password must not contain a newline"
      end
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

  newproperty(:password_state) do
    desc "Derived from 'password' -- do not set it. Present (desired
      'accepted') exactly when a password is declared; absent otherwise, so
      users managed without a password are never probed. The current value
      is 'accepted' when the server accepts the declared password for the
      user and 'rejected' when it does not (wrong password, or no password
      set at all); a 'rejected' -> 'accepted' event is the provider
      re-setting the password."
    newvalues(:accepted)
    # A nil default makes Puppet drop the property from the resource
    # (Type#set_default), which is exactly what a password-less user wants.
    defaultto { resource[:password].nil? ? nil : :accepted }
  end

  newparam(:p4ruby_lib_path) do
    desc "Path to the p4ruby gem's (binary) lib directory."
    validate do |value|
      ENV['RUBYLIB'] = value
    end
  end

  validate do
    if self[:password] && self[:authmethod] == :ldap then
      self.fail "a password cannot be enforced for an LDAP-authenticated user (authmethod => ldap)"
    end
    if self[:password_state] && self[:password].nil? then
      self.fail "password_state is derived from password; declare password instead"
    end
  end

end
