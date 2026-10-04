require 'puppetlabs_spec_helper/module_spec_helper'

# The types read Puppet[:confdir] while they LOAD (the p4config default), and
# a unit spec names its type at describe time -- before the per-example
# settings bootstrap has run. Seed the same throwaway defaults up front.
unless Puppet[:confdir]
  Puppet.settings.preferred_run_mode = 'user'
  Puppet.settings.initialize_app_defaults(
    :logdir       => '/dev/null',
    :confdir      => '/dev/null',
    :vardir       => '/dev/null',
    :rundir       => '/dev/null',
    :hiera_config => '/dev/null'
  )
end
