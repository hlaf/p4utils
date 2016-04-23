$p4config = '/tmp/p4config.txt'

p4utils::config { $p4config:
  p4port     => 'ssl::1666',
  p4user     => 'p4admin',
  p4password => 'SuperSecret',
  fileowner  => 'alan',
  filegroup  => 'staff',
}

P4_protection {
  ensure   => present,
  p4config => $p4config,
  require  => P4utils::Config[$p4config],
}

p4_protection { 'write user * * //...':
  ensure   => 'absent',
}

p4_protection { 'write group developers * //depot/main/src/...':
  ensure   => 'present',
  position => '99',
}
