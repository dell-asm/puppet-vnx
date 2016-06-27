define vnx::createstoragegroup(
  $sgname,
  $host_name,
  $luns={},
){
vnx_storagegroup{$name:
ensure    =>  'present',
sg_name   =>  '$sgname',
luns      =>  $luns,
host_name =>  $host_name,
addonly   =>  true,
transport =>  $transport,
}
}
