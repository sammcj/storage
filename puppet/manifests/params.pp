# Class: ixastorage::params

class ixastorage::params {

## Read data from Hiera
  $storage_group_hash=hiera_hash("storage_$storage_group")
  $network_settings=hiera_hash('network_storage')
  $storage_hostnames=keys($ixastorage::params::storage_group_hash['storage_hosts'])

## Merge host data to get a list of unicast ip addresses
  $storage_unicast_addresses=extracthashvals($storage_group_hash['storage_hosts'],'corosync_ip')
  $unicast_addresses=$storage_unicast_addresses

}