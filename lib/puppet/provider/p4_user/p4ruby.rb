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
    helper = P4Utils::Helper.new
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
    if(resource[:password]) then
      helper.setPassword(userid, resource[:password])
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

  def exists?
    @property_hash[:ensure] == :present
  end

  def flush
    helper = P4Utils::Helper.new
    if(@property_flush.length > 0) then
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
    if(resource[:password]) then
      helper.setPassword(resource[:name], resource[:password])
    end
  end

end
