
Puppet::Type.newtype(:p4_ldap) do
  desc <<-'ENDOFDESC'
  Manages Perforce LDAP configurations ('p4 ldap' specs).

  Example usage:

  p4_ldap { 'corp-ldap':
    host           => 'ldap.example.com',
    port           => '389',
    encryption     => 'tls',
    bind_method    => 'search',
    search_base_dn => 'ou=users,dc=example,dc=com',
    search_filter  => '(&(objectClass=posixAccount)(uid=%user%))',
    search_scope   => 'subtree',
    search_bind_dn => 'cn=proxy,ou=users,dc=example,dc=com',
    search_passwd  => 'supersecret',
    probe_user     => 'someuser',
    probe_password => 'thatuserspassword',
  }

  Only the attributes you declare are managed; the other fields of an
  existing spec are preserved on every save.

  ENDOFDESC

  ensurable

  newparam(:name, :namevar => true) do
    desc "The LDAP configuration name - must be unique"
  end

  newparam(:search_passwd) do
    desc "The password the server binds with as 'search_bind_dn' (the
      SearchPasswd field). When given, it is ENFORCED: each run the
      provider has the server test the configuration ('p4 ldap -t', as
      'probe_user' with 'probe_password') and, when the directory refuses
      the server's bind, re-saves the spec with this password. Declared as
      a parameter, not a property, so the plaintext never becomes a
      desired value in events, reports or the catalog diff -- the derived
      'search_passwd_state' property carries the outcome instead. The
      password only ever travels inside the spec form over the Perforce
      API; it is never placed on a command line. Requires 'probe_user' and
      'probe_password'."
    validate do |value|
      unless value.is_a?(String) && !value.empty?
        raise ArgumentError, "search_passwd must be a non-empty string"
      end
      if value.include?("\n") then
        raise ArgumentError, "search_passwd must not contain a newline"
      end
    end
  end

  newparam(:probe_user) do
    desc "A directory user the server authenticates through this
      configuration when probing 'search_passwd' ('p4 ldap -t'). Any LDAP
      user known to the directory will do; it needs no Perforce access."
  end

  newparam(:probe_password) do
    desc "The directory password of 'probe_user'. Travels over the Perforce
      API's prompt channel only; never logged, never on a command line."
    validate do |value|
      unless value.is_a?(String) && !value.empty?
        raise ArgumentError, "probe_password must be a non-empty string"
      end
      if value.include?("\n") then
        raise ArgumentError, "probe_password must not contain a newline"
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

  newproperty(:host) do
    desc "The LDAP server's hostname (Host)"
  end

  newproperty(:port) do
    desc "The LDAP server's port (Port)"
    munge { |value| value.to_s }
  end

  newproperty(:encryption) do
    desc "Transport encryption (Encryption): none, ssl or tls"
    newvalues(:none, :ssl, :tls)
  end

  newproperty(:bind_method) do
    desc "How the server binds a user (BindMethod): simple, search or sasl"
    newvalues(:simple, :search, :sasl)
  end

  newproperty(:options) do
    desc "The Options line, e.g. 'nodowncase nogetattrs norealminusername'"
  end

  newproperty(:simple_pattern) do
    desc "The DN pattern for bind method 'simple' (SimplePattern)"
  end

  newproperty(:search_base_dn) do
    desc "Where a 'search' bind looks for the user (SearchBaseDN)"
  end

  newproperty(:search_filter) do
    desc "The LDAP filter a 'search' bind uses, with %user% (SearchFilter)"
  end

  newproperty(:search_scope) do
    desc "Search scope (SearchScope): baseonly, children or subtree"
    newvalues(:baseonly, :children, :subtree)
  end

  newproperty(:search_bind_dn) do
    desc "The DN the server binds as to run the search (SearchBindDN).
      Its password is 'search_passwd', which must be declared with it."
  end

  newproperty(:sasl_realm) do
    desc "The realm for bind method 'sasl' (SaslRealm)"
  end

  newproperty(:group_base_dn) do
    desc "Where group membership is checked (GroupBaseDN)"
  end

  newproperty(:group_search_filter) do
    desc "The group membership filter (GroupSearchFilter)"
  end

  newproperty(:group_search_scope) do
    desc "Group search scope (GroupSearchScope): baseonly, children or subtree"
    newvalues(:baseonly, :children, :subtree)
  end

  newproperty(:attribute_uid) do
    desc "The directory attribute holding the Perforce user name (AttributeUid)"
  end

  newproperty(:attribute_name) do
    desc "The directory attribute(s) holding the full name (AttributeName)"
  end

  newproperty(:attribute_email) do
    desc "The directory attribute holding the email address (AttributeEmail)"
  end

  # Defined last on purpose: Puppet syncs properties in definition order,
  # so by the time this one is synced every other drifting property has
  # been queued and the single spec save that fixes the password carries
  # them too.
  newproperty(:search_passwd_state) do
    desc "Derived from 'search_passwd' -- do not set it. Present (desired
      'accepted') exactly when a search_passwd is declared; absent
      otherwise, so configurations managed without one are never probed.
      The current value is 'accepted' when the directory accepts the
      server's bind for this configuration and 'rejected' when it does not
      (a stale SearchPasswd); a 'rejected' -> 'accepted' event is the
      provider re-saving the spec with the declared password."
    newvalues(:accepted)
    # A nil default makes Puppet drop the property from the resource
    # (Type#set_default), which is exactly what a password-less spec wants.
    defaultto { resource[:search_passwd].nil? ? nil : :accepted }
  end

  newparam(:p4ruby_lib_path) do
    desc "Path to the p4ruby gem's (binary) lib directory."
    validate do |value|
      ENV['RUBYLIB'] = value
    end
  end

  validate do
    if self[:search_passwd] then
      if self[:probe_user].nil? || self[:probe_password].nil? then
        self.fail "search_passwd is enforced through a 'p4 ldap -t' probe; declare probe_user and probe_password with it"
      end
    else
      if self[:probe_user] || self[:probe_password] then
        self.fail "probe_user and probe_password only serve search_passwd enforcement; declare search_passwd or drop them"
      end
      if self[:search_bind_dn] then
        self.fail "the server binds as search_bind_dn with search_passwd; declare search_passwd with it"
      end
    end
    if self[:search_passwd_state] && self[:search_passwd].nil? then
      self.fail "search_passwd_state is derived from search_passwd; declare search_passwd instead"
    end
  end

end
