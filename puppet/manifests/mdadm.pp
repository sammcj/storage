class ixastorage::mdadm($arrays) {
  class { '::mdadm' : }

  create_resources('mdadm',$arrays)

  ## Speed up resync
  augeas::sysctl::conf {
    'dev.raid.speed_limit_max':  value => '999999999';
  }

}