# define: ixastorage::drbd
#
#
define ixastorage::drbd(
    $host1          ,
    $host2          ,
    $host1_ip       ,
    $host2_ip       ,
    $device         ,
    $port           ,
    $logical_volume ,
    $resource       = $name,
    $verify_alg     = 'crc32c',
    $manage         = true,
    $initial_setup  = true,
    $rate           = '4194304K',
    $net_parameters = {
      'max-epoch-size'   => '16000',
      'no-tcp-cork'      => '',
      'max-buffers'      => '16000',
      'unplug-watermark' => '32',
      'sndbuf-size'      => '0',
      'after-sb-0pri'    => 'discard-zero-changes',
      'after-sb-1pri'    => 'discard-secondary',
      'after-sb-2pri'    => 'disconnect',
      'csums-alg'        => 'crc32c',
    },
    $syncer_parameters = {
      'al-extents'       => '3389',
    },
    $disk_parameters = {
      'disk-flushes'    => 'no',
      'md-flushes'      => 'no',
      'disk-barrier'    => 'no',
      'no-disk-flushes' => '',
      'no-md-flushes'   => '',
      'no-disk-barrier' => '',
      'c-plan-ahead'    => '2',
      'c-max-rate'      => '1024M',
      'c-min-rate'      => '150M',
      'c-fill-target'   => '500k',
      'fencing'         => 'resource-only',
      'on-io-error'     => 'detach',
    },
    $handler_parameters = {
      'fence-peer'          => '/usr/lib/drbd/crm-fence-peer.sh',
      'after-resync-target' => '/usr/lib/drbd/crm-unfence-peer.sh',
      #'split-brain'         => '/usr/lib/drbd/notify-split-brain.sh',
    },
  ) {

  ::drbd::resource { "$resource":
    host1               => $host1,
    host2               => $host2,
    ip1                 => $host1_ip,
    ip2                 => $host2_ip,
    disk                => $logical_volume,
    port                => $port,
    device              => $device,
    manage              => $manage,
    verify_alg          => $verify_alg,
    initial_setup       => $initial_setup,
    net_parameters      => $net_parameters,
    syncer_parameters   => $syncer_parameters,
    disk_parameters     => $disk_parameters,
    handler_parameters  => $handler_parameters,
    notify              => Exec['drbd_reload_conf'] #TODO And what happens if this fails?
  }




}