# Defined Type: p4utils::config
# ===========================
#
# The `p4utils::config` defined resource is designed to lay down a configuration
# file that can then be used by the custom types and providers in this module.
#
# Parameters
# ----------
# * `p4port`
# The P4PORT to be used to connect to the server.
#
# * `p4user`
# The superuser account that will be used for server connections.
#
# * `p4password`
# The password for the superuser account. This is optional. If not
# provided, you must already have a valid ticket on the node. If This
# is provided, then the node must already have a valid ticket.
#
# * `p4client`
# The name of the p4 client specification to use for any file operations.
#
# * `p4tickets`
# Location of the tickets file on the node.
#
# * `p4trust`
# Location of the trust file (needed for SSL).
#
# Examples
# --------
# @example
#    p4utils::config {'/tmp/p4config.txt':
#      p4port     => 'ssl::1666',
#      p4user     => 'p4admin',
#      p4password => 'SuperSecret',
#      p4client   => 'myclient',
#      p4tickets  => '/tmp/p4tickets.txt',
#      p4trust    => '/tmp/p4trust.txt',
#    }
#
# Authors
# -------
# Alan Petersen <alanpetersen@mac.com>
#
# Copyright
# ---------
# Copyright 2016 Alan Petersen, unless otherwise noted.
#
define p4utils::config (
  $configfile = $title,
  $p4port     = '1666',
  $p4user     = 'p4admin',
  $p4password = undef,
  $p4client   = "tmpclient_${::fqdn}",
  $p4tickets  = undef,
  $p4trust    = undef,
  $fileowner  = 'root',
  $filegroup  = 'root',
  $filemode   = '0600',
  $ruby_path  = '/opt/puppetlabs/puppet/bin/ruby',
) {

  $configparent = getparent($configfile)

  if $p4tickets == undef {
    $p4tickets_real = "${configparent}/p4tickets.txt"
  } else {
    $p4tickets_real = $p4tickets
  }

  if $p4trust == undef {
    $p4trust_real = "${configparent}/p4trust.txt"
  } else {
    $p4trust_real = $p4trust
  }

  File {
    ensure => file,
    owner  => $fileowner,
    group  => $filegroup,
    mode   => $filemode,
  }

  # lay down the configuration file using the template
  file { $configfile:
    content => template('p4utils/p4config.erb'),
  }

  # ensure that the p4trust is present, if the port uses SSL
  # this does not perform a login, simply does a p4 trust -y
  # on the server.
  if $p4port =~ /^ssl:/ {
    $trust_script = "/tmp/${p4port}_trust.rb"
    if !defined(File[$trust_script]) {
      file { $trust_script:
        source => 'puppet:///modules/p4utils/p4trust.rb',
      }
    }
    $checktrust_script = "/tmp/${p4port}_checktrust.rb"
    if !defined(File[$checktrust_script]) {
      file { $checktrust_script:
        source => 'puppet:///modules/p4utils/p4checktrust.rb',
      }
    }
    exec { "p4trust_${title}":
      command     => "${ruby_path} ${trust_script}",
      environment => "P4CONFIG=${configfile}",
      unless      => "${ruby_path} ${checktrust_script}",
      require     => File[$trust_script, $checktrust_script, $configfile],
    }
  }

  if $p4password {
    $id = sha1($title)
    $login_script = "/tmp/${p4port}_login_${id}.rb"
    if !defined(File[$login_script]) {
      file { $login_script:
        source => 'puppet:///modules/p4utils/p4login.rb',
      }
    }
    $checklogin_script = "/tmp/${p4port}_checklogin_${id}.rb"
    if !defined(File[$checklogin_script]) {
      file { $checklogin_script:
        source => 'puppet:///modules/p4utils/p4checklogin.rb',
      }
    }
    exec { "p4login_${title}":
      command     => "${ruby_path} ${login_script} ${p4password}",
      environment => "P4CONFIG=${configfile}",
      unless      => "${ruby_path} ${checklogin_script}",
      require     => File[$login_script, $checklogin_script, $configfile],
    }
  }

}
