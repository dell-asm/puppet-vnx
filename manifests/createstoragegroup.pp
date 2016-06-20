define vnx::createstoragegroup(
  $sgname,
  $host_name,
  $luns={},
){

vnx_storagegroup{"$name":
sg_name=>"$sgname",
luns=>$luns,
host_name=>$host_name,
addonly=>"true",
ensure=>"present",
transport=>"$transport",
}
}
