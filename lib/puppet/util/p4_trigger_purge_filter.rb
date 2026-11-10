require 'puppet/type/resources'

# Scoped purge support for p4_trigger.
#
# Puppet::Type::Resources#check dispatches to a method named "<type>_check" for
# every purge candidate, which is how the stock user type spares system accounts
# (see user_check). Defining p4_trigger_check therefore lets
#
#   resources { 'p4_trigger': purge => true }
#
# retire only the triggers a catalog's own declarations own, and leave alone the
# entries other software installs into the same table.
#
# That distinction matters on a Perforce server: self.instances reads the one
# global trigger table, which holds entries this module never created. Git
# Fusion installs its own (GF-change-commit and friends) and the server cannot
# accept a submit without them, so an unscoped purge is an outage rather than a
# tidy-up.
#
# self.instances is deliberately left returning the whole table, so discovery
# via `puppet resource p4_trigger` and the provider's prefetch still see every
# entry; only the purge candidates are filtered.
Puppet::Type.type(:resources).class_eval do

  # The namespace is read from the purge_namespace parameter of any declared
  # p4_trigger resource, so the pattern lives in the catalog that owns the
  # triggers rather than in this module.
  def p4_trigger_purge_namespace
    return nil if catalog.nil?
    catalog.resources.each do |res|
      next unless res.respond_to?(:type) && res.type == :p4_trigger
      value = res[:purge_namespace]
      return value unless value.nil? || value.to_s.empty?
    end
    nil
  end

  def p4_trigger_check(resource)
    name = resource[:name].to_s

    # Safety net independent of the configured pattern: Git Fusion's own
    # triggers are load bearing for every submit, so they are never candidates.
    return false if name =~ /\AGF-/

    pattern = p4_trigger_purge_namespace

    # No namespace configured means nothing is owned, so nothing is purged. An
    # unconfigured or half-deployed site must not start deleting server state.
    return false if pattern.nil?

    name =~ Regexp.new(pattern) ? true : false
  end
end
