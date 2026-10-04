require File.expand_path(File.join(File.dirname(__FILE__),'..','..','..','puppet_x','p4utils','helper.rb'))

Puppet::Type.type(:p4_user).provide(:p4ruby) do

  def initialize(value={})
    super(value)
    @property_flush = {}
  end

  def self.instances
    users = Array.new
    p4users = P4Utils::Helper.new.getUsers
    p4users.each do |u|
      users << new(
        :ensure     => :present,
        :name       => u['User'],
        :fullname   => u['FullName'],
        :email      => u['Email'],
        :type       => u['Type'],
        :authmethod => u['AuthMethod']
      )
    end
    return users
  end

  def self.prefetch(resources)
    catalog = resources[resources.keys.first].catalog
    p4_user_config = catalog.resources.find{|s| s.type == :p4_user}
    ENV['P4CONFIG'] = p4_user_config['p4config']
    users = instances
    resources.keys.each do | name |
      if provider = users.find{ | user | user.name == name }
        resources[name].provider = provider
      end
    end
  end

  def create
    Puppet.debug("creating new p4_user resource")
    self.fail "email is a required attribute" unless resource[:email]
    self.fail "fullname is a required attribute" unless resource[:fullname]
    helper = P4Utils::Helper.new(resource[:p4config])
    userid = resource[:name]
    fullname = resource[:fullname]
    email = resource[:email]
    type = 'standard'
    authmethod = 'perforce'
    if(resource[:type]) then
      type = resource[:type]
    end
    if(resource[:authmethod]) then
      authmethod = resource[:authmethod]
    end
    helper.addUser(userid, fullname, email, type, authmethod)
    # Syncing 'ensure' short-circuits the other properties for this run, so
    # the password has to be set here rather than left to password_state=.
    if(resource[:password]) then
      enforce_password(helper)
    end
  end

  def destroy
    userid = resource[:name]
    P4Utils::Helper.new.removeUser(userid)
  end

  def fullname
    @property_hash[:fullname]
  end

  def fullname=(value)
    @property_flush[:fullname] = value
  end

  def email
    @property_hash[:email]
  end

  def email=(value)
    @property_flush[:email] = value
  end

  def type
    @property_hash[:type]
  end

  def type=(value)
    @property_flush[:type] = value
  end

  def authmethod
    @property_hash[:authmethod]
  end

  def authmethod=(value)
    @property_flush[:authmethod] = value
  end

  # Current state of the declared password: :accepted when the server takes
  # it for this user, :rejected otherwise. Probed lazily per managed
  # resource (never in self.instances, which has no password to test).
  def password_state
    return :absent if resource.nil? || resource[:password].nil?
    helper = P4Utils::Helper.new(resource[:p4config])
    if helper.password_accepted?(resource[:name], resource[:password]) then
      :accepted
    else
      :rejected
    end
  end

  def password_state=(value)
    enforce_password(P4Utils::Helper.new(resource[:p4config]))
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def flush
    if(@property_flush.length > 0) then
      helper = P4Utils::Helper.new(resource[:p4config])
      userid = resource[:name]
      fullname = @property_hash[:fullname]
      email = @property_hash[:email]
      type = @property_hash[:type]
      authmethod = @property_hash[:authmethod]
      if(resource[:fullname]) then
        fullname = resource[:fullname]
      end
      if(resource[:email]) then
        email = resource[:email]
      end
      if(resource[:type]) then
        type = resource[:type]
      end
      if(resource[:authmethod]) then
        authmethod = resource[:authmethod]
      end
      helper.addUser(userid, fullname, email, type, authmethod)
    end
    @property_hash = resource.to_hash
  end

  private

  # Set the declared password through the superuser session, then prove it
  # took by probing again: a silent no-op here would report 'changed' while
  # leaving the account exactly as broken as before.
  def enforce_password(helper)
    userid = resource[:name]
    helper.set_password(userid, resource[:password])
    unless helper.password_accepted?(userid, resource[:password])
      self.fail "p4d still rejects the declared password for user '#{userid}' after 'p4 passwd'"
    end
    @property_hash[:password_state] = :accepted
  end

end
