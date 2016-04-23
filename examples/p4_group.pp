$p4config = '/tmp/p4config.txt'

p4utils::config { $p4config:
  p4port     => 'ssl::1666',
  p4user     => 'p4admin',
  p4password => 'SuperSecret',
  fileowner  => 'alan',
  filegroup  => 'staff',
}

P4_group {
  ensure   => present,
  p4config => $p4config,
  require  => P4utils::Config[$p4config],
}

p4_group { 'unlimited':
  owners  => 'p4admin',
  users   => ['zack','p4admin','p4service','bob','alan'],
  timeout => 'unlimited',
}
