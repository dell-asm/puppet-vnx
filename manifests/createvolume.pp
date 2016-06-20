define vnx::createvolume(
  $type     = "NonThin",
  $capacity = "1",
  $sp       = "a",
  $poolName = "Pool 0",
  $scope    = "0",
){
vnx_lun{"$name":
  lun_name=>$name,
  type=>"$type",
  capacity=>"$capacity",
  default_owner=>"$sp",
  pool_name=>"$poolName",
  transport=>"$transport",
}
}
