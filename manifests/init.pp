# Class: p4utils
# ===========================
#
# The `p4utils` class is a simple wrapper class for
# `p4utils::config` resources.
#
# Parameters
# ----------
# * `configs`
# A hash of the config files to be created on the node.
#
# Authors
# -------
# Alan Petersen <alanpetersen@mac.com>
#
# Copyright
# ---------
# Copyright 2016 Alan Petersen, unless otherwise noted.
#
class p4utils(
  $config = {}
) {
  if is_hash($config) and (size($config) > 0) {
    create_resources(p4utils::config, $config)
  }
}
