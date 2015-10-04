# Define: ixastorage::ha_resource
# Parameters:
# arguments
#
define ixastorage::ha_resource ($iscsi_vip, $iscsi_vip_nm, $iscsi_iqn, $master_node) {
  include ixastorage::params
  include corosync::reprobe
  $drbd_resource          = $name
  $drbd_primitive         = "drbd_${drbd_resource}"
  $drbd_path              = $ixastorage::params::storage_group_hash['drbd'][$drbd_resource]['device']
  $ip_primitive           = "ip_${drbd_resource}"
  $ms_resource            = "ms_${drbd_primitive}"
  $iscsi_target_primitive = "iscsi_target_${drbd_resource}"
  $iscsi_lun_primitive    = "iscsi_lun_${drbd_resource}"
  $iscsi_conf_primitive   = "iscsi_conf_${drbd_resource}"
  $iscsi_conf_bin         = "/usr/sbin/iscsi_${iscsi_conf_primitive}.sh"
  $allowed_initiators     = join($ixastorage::params::storage_group_hash['allowed_initiators'],' ')

#######################################
### Resource definitons             ###
#######################################

  ## DRBD

  cs_primitive { "$drbd_primitive":
    primitive_class => 'ocf',
    provided_by     => 'linbit',
    primitive_type  => 'drbd',
    parameters      =>  { 'drbd_resource' => "$drbd_resource" },
    ms_metadata     =>  {
      'clone-max'           => '2',
      'clone-node-max'      => '1',
      'master-max'          => '1',
      'master-node-max'     => '1',
      'notify'              => 'true',
      'globally-unique'     => 'false',
      #'migration-threshold' => '5',
      'failure-timeout'     => '30s',
    },
    operations      =>  { 'monitor'      => { 'interval' => '12s', 'role'  => 'Slave',  'timeout' => '20','on-fail' => "restart"}, #reducing interval from 21  #http://lists.linux-ha.org/pipermail/linux-ha/2013-February/046536.html
                          'monitor'      => { 'interval' => '6s',  'role'  => 'Master', 'timeout' => '20','on-fail' => "restart"}, #reducing interval from 10s
                          'start'        => { 'interval' => '0', 'timeout' => '60s',    'on-fail' => "restart"},
                          'stop'         => { 'interval' => '0', 'timeout' => '20s',    'on-fail' => "restart"},
                          'promote'      => { 'interval' => '0', 'timeout' => '60s',    'on-fail' => "restart"},
                          'demote'       => { 'interval' => '0', 'timeout' => '30s',    'on-fail' => "restart"},
                          'notify'       => { 'interval' => '0', 'timeout' => '60s',    'on-fail' => "restart"},
                          },
    promotable      => true,
    require         => [Cs_property['stonith-enabled'],Package['drbd84-utils-8.9.2'],Service['pacemaker']],
  }


  ## VIRTUAL IP

  cs_primitive { "$ip_primitive":
    primitive_class => 'ocf',
    primitive_type  => 'IPaddr2',
    provided_by     => 'heartbeat',
    parameters      => {  'ip'           => "$iscsi_vip",
                          'cidr_netmask' => "$iscsi_vip_nm",
                          'flush_routes' => 'true',
                          'iflabel'      => "iscsi${drbd_resource}"},
    operations      =>  { 'monitor'      => { 'interval' => '6s',  'timeout' => '20s','on-fail' => "restart"}, #reducing interval from 21s
                          'start'        => { 'interval' => '0',   'timeout' => '20s','on-fail' => "restart"},
                          'stop'         => { 'interval' => '0',   'timeout' => '20s','on-fail' => "restart"},
                        },
    require         => [Cs_primitive["$drbd_primitive"],Service['pacemaker']],
  }

  cs_location { "require_ping_gateway_${drbd_resource}":
    primitive => "$ms_resource",
    rules     => [{'boolean' => 'or',
                   'score'   => '-INFINITY',
                   'expressions' => [ {'attribute' => 'pingd', 'operation' => 'not_defined'},
                                      {'attribute' => 'pingd', 'operation' => 'lte', 'value' => 0} ]
                  }],
    score     => false,
    require   => [Cs_primitive["$drbd_primitive"],Cs_primitive["ping_gateway"],Service['pacemaker']],
  }


  ## ISCSI

  cs_primitive { "$iscsi_target_primitive":
    primitive_class => 'ocf',
    primitive_type  => 'iSCSITarget',
    provided_by     => 'heartbeat',
    parameters      => {  'iqn'                   => "$iscsi_iqn",
                          'portals'               => "${iscsi_vip}:3260", # got error saying it created default portal and then failed to make another
                          'implementation'        => 'lio-t',
                          'additional_parameters' => 'MaxConnections=100 AuthMethod=None InitialR2T=No MaxOutstandingR2T=64',
                        },
    operations      =>  {  'monitor'              => { 'timeout' => '20s', 'interval' => '30s','on-fail' => "restart"},
                           'start'                => { 'timeout' => '20s', 'interval' => '0','on-fail'   => "restart"},
                           'stop'                =>  { 'timeout' => '20s', 'interval' => '0','on-fail'   => "restart"},
                        },
    require         => [Cs_primitive["$ip_primitive"],Package['targetcli'],Service['pacemaker']],
  }

# http://serverfault.com/a/622110
# emulate_3pc=1,emultate_tpu=1,emulate_caw=1

# https://github.com/ClusterLabs/resource-agents/issues/610

  cs_primitive { "$iscsi_lun_primitive":
    primitive_class => 'ocf',
    primitive_type  => 'iSCSILogicalUnit',
    provided_by     => 'heartbeat',
    parameters      => {  'target_iqn'         => "$iscsi_iqn",
                          'lun'                => "1",
                          'path'               => $drbd_path,
                          'allowed_initiators' => $allowed_initiators,
                          'implementation'     => 'lio-t'},
    operations      =>  {  'monitor'              => { 'timeout' => '10s', 'interval' => '30s','on-fail' => "restart" }, #reducing interval from 20s
                           'start'                => { 'timeout' => '20s', 'interval' => '0'  ,'on-fail' => "restart" },
                           'stop'                =>  { 'timeout' => '20s', 'interval' => '0'  ,'on-fail' => "restart" },
                        },
    require         => [Cs_primitive["$iscsi_target_primitive"],Service['pacemaker']],
  }

## Additional iSCSI settings
# See https://github.com/ClusterLabs/resource-agents/issues/610

  file { "$iscsi_conf_bin":
    ensure    => present,
    content   => template('ixastorage/iscsi_settings.sh.erb'),
    owner     => 'root',
    group     => 'root',
    mode      => '0755',
  }

  cs_primitive { "$iscsi_conf_primitive":
    primitive_class => 'ocf',
    primitive_type  => 'anything',
    provided_by     => 'heartbeat',
    parameters      => {  'binfile'            => $iscsi_conf_bin,
                          'stop_timeout'       => "3"},
    require         => [Cs_primitive["$iscsi_target_primitive"],File["$iscsi_conf_bin"],Service['pacemaker'],File['/usr/lib/ocf/resource.d/heartbeat/anything']],
  }

#######################################
### Resource Ordering and Locations ###
#######################################

# DRBD Master -> IP -> Target -> Lun -> Conf

  cs_order { "ip_after_drbd_${drbd_resource}":
    first   => "${ms_resource}:promote",
    second  => "${ip_primitive}:start",
    require => [Cs_primitive["$ip_primitive"],Cs_primitive["$drbd_primitive"],Service['pacemaker']],
  }

  cs_order { "target_after_ip_${drbd_resource}":
    first   => "${ip_primitive}:start",
    second  => "${iscsi_target_primitive}:start",
    require => [Cs_primitive["$ip_primitive"],Cs_primitive["$iscsi_lun_primitive"],Service['pacemaker']],
  }

  cs_order { "lun_after_target_${drbd_resource}":
    first   => "${iscsi_target_primitive}:start",
    second  => "${iscsi_lun_primitive}:start",
    require => [Cs_primitive["$iscsi_lun_primitive"],Cs_primitive["$iscsi_target_primitive"],Service['pacemaker']],
  }

  cs_order { "conf_after_lun_${drbd_resource}":
    first   => "${iscsi_lun_primitive}:start",
    second  => "${iscsi_conf_primitive}:start",
    require => [Cs_primitive["$iscsi_lun_primitive"], Cs_primitive["$iscsi_conf_primitive"],Service['pacemaker']],
  }

# Make sure all required resources are together

  cs_colocation { "ip_with_drbd_${drbd_resource}":
    primitives => ["${ms_resource}:Master","$ip_primitive"],
    require    => [Cs_order["conf_after_lun_${drbd_resource}"]],
  }

  cs_colocation { "target_with_ip_${drbd_resource}":
    primitives => ["$ip_primitive","$iscsi_target_primitive"],
    require    => [Cs_order["conf_after_lun_${drbd_resource}"]],
  }

  cs_colocation { "lun_with_target_${drbd_resource}":
    primitives => ["$iscsi_target_primitive","$iscsi_lun_primitive"],
    require    => [Cs_order["conf_after_lun_${drbd_resource}"]],
  }

  cs_colocation { "conf_with_lun_${drbd_resource}":
    primitives => ["$iscsi_lun_primitive","$iscsi_conf_primitive"],
    require    => [Cs_order["conf_after_lun_${drbd_resource}"]],
  }

# Run the colocated resources on the designated master

  cs_location { "prefer_${drbd_resource}_${master_node}":
    primitive => "${ms_resource}",
    node_name => "$master_node",
    score     => '2',
    require   => [Cs_primitive["$drbd_primitive"],Service['pacemaker']],
  }

}