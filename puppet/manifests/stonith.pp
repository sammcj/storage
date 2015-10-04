# Define: ixastorage::stonith

define ixastorage::stonith ($ipmi_ip, $ipmi_userid, $ipmi_passwd, $corosync_ip) {
  include corosync::reprobe
  $ipmi_host = $name
  $stonith_primitive = "stonith_${ipmi_host}"

#######################################
### STONITH definitions             ###
#######################################

  cs_primitive { "$stonith_primitive":
    primitive_class => 'stonith',
    primitive_type  => 'rcd_serial',
    parameters      => {  'ttydev'          => "/dev/ttyS0",
                          'dtr_rts'         => "dtr",
                          'msduration'      => "1000",
                          'hostlist'        => "$ipmi_host",
                          'stonith-timeout' => '5s'
                           },
    require         => File['/usr/sbin/fence_legacy'],
  }


  cs_location { "dont-run-${stonith_primitive}-on-${ipmi_host}":
    primitive => $stonith_primitive,
    node_name => $ipmi_host,
    score     => '-INFINITY',
    require   => Cs_primitive[$stonith_primitive],
  }


  # Disabled IPMI STONITH as we're using serial
  #
  # cs_primitive { "$stonith_primitive":
  #   primitive_class => 'stonith',
  #   primitive_type  => 'external/ipmi',
  #   parameters      => {  'hostname'     => "$ipmi_host",
  #                         'ipaddr'       => "$ipmi_ip",
  #                         'userid'       => "$ipmi_userid",
  #                         'passwd'       => "$ipmi_passwd",
  #                          },
  #   operations      => {  'monitor'      => { 'interval' => '30m'}},
  #   require         => Package['ipmitool'],
  # }

}