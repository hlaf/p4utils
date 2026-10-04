require File.expand_path(File.join(File.dirname(__FILE__),'..','..','..','puppet_x','p4utils','helper.rb'))

Puppet::Type.type(:p4_ldap).provide(:p4ruby) do

  # Managed property -> spec form field. A method rather than a constant:
  # a constant assigned inside this block lands on Object, shared with (and
  # clobbered by) every other provider that names one the same way.
  def self.fields
    @fields ||= {
    :host                => 'Host',
    :port                => 'Port',
    :encryption          => 'Encryption',
    :bind_method         => 'BindMethod',
    :options             => 'Options',
    :simple_pattern      => 'SimplePattern',
    :search_base_dn      => 'SearchBaseDN',
    :search_filter       => 'SearchFilter',
    :search_scope        => 'SearchScope',
    :search_bind_dn      => 'SearchBindDN',
    :sasl_realm          => 'SaslRealm',
    :group_base_dn       => 'GroupBaseDN',
    :group_search_filter => 'GroupSearchFilter',
    :group_search_scope  => 'GroupSearchScope',
    :attribute_uid       => 'AttributeUid',
    :attribute_name      => 'AttributeName',
    :attribute_email     => 'AttributeEmail',
    }
  end

  def initialize(value={})
    super(value)
    @property_flush = {}
    @spec_saved = false
  end

  def self.instances
    helper = P4Utils::Helper.new
    helper.getLdapNames.map do |name|
      form = helper.getLdap(name)
      current = { :ensure => :present, :name => name }
      fields.each do |attr, field|
        current[attr] = form[field] unless form[field].nil?
      end
      new(current)
    end
  end

  def self.prefetch(resources)
    catalog = resources[resources.keys.first].catalog
    p4_ldap_config = catalog.resources.find{|s| s.type == :p4_ldap}
    ENV['P4CONFIG'] = p4_ldap_config['p4config']
    specs = instances
    resources.keys.each do | name |
      if provider = specs.find{ | spec | spec.name == name }
        resources[name].provider = provider
      end
    end
  end

  fields.keys.each do |attr|
    define_method(attr) do
      @property_hash[attr]
    end
    define_method("#{attr}=") do |value|
      @property_flush[attr] = value
    end
  end

  def create
    Puppet.debug("creating new p4_ldap resource")
    helper = P4Utils::Helper.new(resource[:p4config])
    save_spec(helper)
    # Syncing 'ensure' short-circuits the other properties for this run, so
    # the bind has to be proven here rather than left to
    # search_passwd_state=.
    if(resource[:search_passwd]) then
      verify_bind(helper)
    end
  end

  def destroy
    P4Utils::Helper.new(resource[:p4config]).deleteLdap(resource[:name])
  end

  # Current state of the declared SearchPasswd: :accepted when the
  # directory takes the server's bind for this configuration, :rejected
  # otherwise. Probed lazily per managed resource (never in
  # self.instances, which has no probe credentials).
  def search_passwd_state
    return :absent if resource.nil? || resource[:search_passwd].nil?
    helper = P4Utils::Helper.new(resource[:p4config])
    if bind_accepted?(helper, live_bind_dn) then
      :accepted
    else
      :rejected
    end
  end

  # Re-save the spec with the declared password (and whatever other
  # properties are queued), then prove the bind took.
  def search_passwd_state=(value)
    helper = P4Utils::Helper.new(resource[:p4config])
    save_spec(helper)
    verify_bind(helper)
    @spec_saved = true
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def flush
    if(@property_flush.length > 0 && !@spec_saved) then
      save_spec(P4Utils::Helper.new(resource[:p4config]))
    end
    @property_hash = resource.to_hash
  end

  private

  # Fetch the live form (a template for a new name), overlay only the
  # declared attributes plus the declared SearchPasswd, and save it, so
  # fields this resource does not manage come back exactly as they were.
  def save_spec(helper)
    form = helper.getLdap(resource[:name])
    form = {} if form.nil?
    form['Name'] = resource[:name]
    self.class.fields.each do |attr, field|
      value = resource[attr]
      form[field] = value.to_s unless value.nil?
    end
    if(resource[:search_passwd]) then
      form['SearchPasswd'] = resource[:search_passwd]
    end
    helper.saveLdap(form)
    @property_flush = {}
  end

  def bind_accepted?(helper, bind_dn)
    helper.ldap_bind_accepted?(resource[:name], bind_dn, resource[:probe_user], resource[:probe_password])
  end

  # Prove the bind took after a save (when the live bind DN is the
  # declared one, or the unchanged one for a resource that leaves it
  # alone): a silent no-op here would report 'changed' while leaving the
  # configuration exactly as broken as before.
  def verify_bind(helper)
    unless bind_accepted?(helper, resource[:search_bind_dn] || @property_hash[:search_bind_dn])
      self.fail "the directory still refuses the server's bind for LDAP configuration '#{resource[:name]}' after saving the declared search_passwd (check search_bind_dn, the probe credentials and the directory)"
    end
    @property_hash[:search_passwd_state] = :accepted
  end

  # The SearchBindDN the server currently uses: the one it reported, or
  # the declared one for a spec that does not exist yet.
  def live_bind_dn
    @property_hash[:search_bind_dn] || resource[:search_bind_dn]
  end

end
