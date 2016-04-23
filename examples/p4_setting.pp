$p4config = '/tmp/p4config.txt'

p4utils::config { $p4config:
  p4port     => 'ssl::1666',
  p4user     => 'p4admin',
  p4password => 'SuperSecret',
  fileowner  => 'alan',
  filegroup  => 'staff',
}

P4_setting {
  ensure   => present,
  p4config => $p4config,
  require  => P4utils::Config[$p4config],
}

p4_setting { 'security':
  value => '3',
}

p4_setting { 'monitor':
  value => '1',
}

p4_setting { 'minClient':
  value => '77',
}

p4_setting { 'minClientMessage':
  value => 'Sorry, you need to update your client to at least version 2014.2',
}

p4_setting { 'server.allowfetch':
  value => '3',
}

p4_setting { 'server.allowpush':
  value => '3',
}
