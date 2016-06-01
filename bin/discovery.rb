#!/opt/puppet/bin/ruby
require 'json'
require 'rbvmomi'
require 'trollop'
require 'pathname'
require 'nokogiri'
require 'open3'


puppet_dir = File.join(Pathname.new(__FILE__).parent.parent,'lib','puppet_x', 'puppetlabs')
require "#{puppet_dir}/transport/emc_vnx"

opts = Trollop::options do
  opt :server, 'EMC VNX Array', :type => :string, :required => true
  opt :username, 'EMC VNX username', :type => :string, :required => true
  opt :password, 'EMC VNX password', :type => :string, :default => ENV['PASSWORD']
  opt :timeout, 'command timeout', :default => 240
  opt :community_string, 'EMC VNX community string', :default => 'public'
  opt :output, 'output facts to a file', :type => :string, :required => true
end

facts = {}

def collect_emc_vnx_facts(opts)
  facts = {}
  xml_doc = collect_inventory(opts)
  facts.merge!(sub_system_info(xml_doc))
  facts.merge!(sub_controller_info(xml_doc))
  facts.merge!(disk_info(xml_doc))
  facts.merge!(raid_groups(xml_doc))
  facts.merge!(disk_pools(xml_doc))
  facts.merge!(pools(xml_doc))
  facts.merge!(additional_calculations(opts))
  facts.each do |f,v|
  facts[f]=(v.is_a?String)? v.to_s : v.to_json.to_s
  end

  facts.to_json
end

def sub_system_info(xml_doc)
  facts = {}
  sub_system = xml_doc.xpath('//SAN:Subsystems/CLAR:CLARiiON')
  props = sub_system.at_xpath('//CLAR:*').children
  props.each do |node|
    next if node.node_name == "text"
    next if ["Softwares", "Physicals", "FaultInfos", "Logicals", "DNS", "FileMetaData"].include?(node.node_name)
    facts[node.node_name] = node.content
  end

  softwares = []
  props = sub_system.at_xpath('//CLAR:Softwares').children
  props.each do |node|
    software_facts = {}
    next if node.node_name == "text"
    software_info = node.children
    software_info.each do |si|
      next if si.node_name == "text"
      software_facts[si.node_name] = si.content
    end
    softwares <<  software_facts
  end
  facts["softwares_data"]={"Softwares"=> softwares}
  facts
end

def disk_info(xml_doc)
  facts = {}
  facts['disk_info'] ||= []
  disks = xml_doc.xpath('//CLAR:Physicals/CLAR:Disks/CLAR:Disk')
  disks.each do |disk|
    disk_info_hash = {}
    disk.children.each do |disk_attr|
      next if disk_attr.node_name == "text"
      disk_info_hash[disk_attr.node_name] = disk_attr.content
    end
    facts['disk_info'] << disk_info_hash
  end
  facts={"disk_info_data"=>facts}
  facts
end

def sub_lun_info(xml_doc)
  facts = {}
  sub_system = xml_doc.xpath('//CLAR:Logicals/CLAR:')
end

def raid_groups(xml_doc)
  facts = { 'raid_groups' => [] }
  raid_groups = xml_doc.xpath('//CLAR:Logicals/CLAR:RAIDGroups/CLAR:RAIDGroup')
  raid_groups.each do |raid_group|
    raid_info = {}
    raid_group.children.each do |r_attr|
      next if r_attr.node_name == "text"
      if r_attr.node_name == "Disks"
        raid_info['disks'] = raid_disks(r_attr)
      else
        raid_info[r_attr.node_name] = r_attr.content
      end
    end
    facts['raid_groups'] <<  raid_info
  end
  facts={"raid_groups_data"=>facts}
  facts
end

def raid_disks(r_disks)
  raid_disk_info = []
  r_disks.children.each do |disk|
    next if disk.node_name == "text" || disk.node_name != "Disk"
    r_disk_info = {}
    disk.children.each do |d_attr|
      next if d_attr.node_name == "text"
      r_disk_info[d_attr.node_name] = d_attr.content
    end
    raid_disk_info << r_disk_info
  end
  raid_disk_info
end

def disk_pools(xml_doc)
  facts = {'disk_pools' => []}
  d_pools = xml_doc.xpath("//CLAR:Logicals/CLAR:Diskpools/CLAR:Diskpool")
  d_pools.each do |disk_pool|
    disk_pool_info = {}
    disk_pool.children.each do |d_attr|
      next if d_attr.node_name == "text"
      if d_attr.node_name == "Disks"
        disk_pool_info['Disks'] = raid_disks(d_attr)
      else
        disk_pool_info[d_attr.node_name] = d_attr.content
      end

    end
    facts['disk_pools'] << disk_pool_info
  end
   facts={"disk_pools_data"=>facts}
  facts
end

def pools(xml_doc)
  facts = { 'pools' => []}
  pools = xml_doc.xpath("//CLAR:Logicals/CLAR:PoolProvisioning/CLAR:PoolProvisioningFeature/CLAR:Pools/CLAR:Pool")
  pools.each do |pool|
    pool_info = {}
    pool.children.each do |p_attr|
      next if p_attr.node_name == "text"
      if p_attr.node_name == "MLUs"
        pool_info['MLUs'] = pool_mlus(p_attr)
      else
        pool_info[p_attr.node_name] = p_attr.content
      end
    end
    facts['pools'] <<  pool_info
  end
   facts={'pools_data'=>facts}
  facts
end

def pool_mlus(mlus)
  mlu_array = []
  mlus.children.each do |mlu|
    next if mlu.node_name == "text"
    if mlu.node_name = "MLU"
      mlu_info = {}
      mlu.children.each do |m_attr|
        next if m_attr.node_name == "text"
        mlu_info[m_attr.node_name] = m_attr.content
      end
      mlu_array << mlu_info
    end
  end
  mlu_array
end

def sub_controller_info(xml_doc)
  facts = {}
  facts_hba= {}
  controllers = []
  hba_s={}
  sub_system_servers = xml_doc.xpath('//SAN:SAN/SAN:Servers/SAN:Server')

  sub_system_servers.each do |sub_system|
    next if sub_system.node_name == "text"
    container_info = {}
    server_info = sub_system.children
    server_info.each do |s|
      next if s.node_name == "text"
        if ['HBAInfo'].include?(s.node_name)
           a = hba_info(s)
           facts_hba['HBAInfo'] = a
        end
      container_info[s.node_name] = s.content
    end
    controllers <<  container_info
  end
  facts['controllers'] = controllers
  facts={"controllers_data"=>facts}
  facts.merge!({"hbainfo_data"=>facts_hba})
  facts
end

def hba_info(controller_path)
  hba_facts = {}
  attributes = ['NumberOfHBAPorts',
                'HostLoginStatus',
                'HostManagementStatus',
                'IsAttachedHost']
  attributes.collect {|x| hba_facts[x] = controller_path.at_xpath("//SAN:#{x}").text}
  hba_ports = controller_path.at_xpath('//SAN:HBAPorts/SAN:HBAPort')
  hba_ports_info = []
  hba_ports.children.each do |hba_port|
    next if hba_port.node_name == "text"
    hba_port_attr = hba_port.children
    port_hash = {}
    ['WWN', 'VendorDescription', 'NumberOfSPPorts' ].collect {|x| port_hash[x] = hba_port_attr.at_xpath("//SAN:#{x}").text}
    hba_ports_info << port_hash
  end
  hba_facts['hba_ports_info'] = hba_ports_info
  hba_facts
end

def collect_inventory(opts)
  discovery_dump_file = "/tmp/emc_discovery_#{opts[:server]}.xml"
  File.delete(discovery_dump_file) if File.exists?(discovery_dump_file)
  emc_cli_cmd = "/opt/Navisphere/bin/naviseccli"

  raise("Naviseccli not installed") unless File.exists?(emc_cli_cmd)
  Open3.popen3("#{emc_cli_cmd} -User #{opts[:username]} -Scope 0 -Address #{opts[:server]} -Password #{opts[:password]} arrayconfig -capture  -output #{discovery_dump_file}") do |stdin, stdout, stderr, wait_thr|
  end
  wait_counter = 1
  until File.exist?(discovery_dump_file)
    break if wait_counter >= 120
    sleep 1
    wait_counter += 1
  end
  if !File.exist?(discovery_dump_file)
    puts "Failed to execute discovery for #{opts[:server]}. Discovery dump file not created"
    exit 1
  end
  data_capture = File.read(discovery_dump_file)
  File.delete(discovery_dump_file)
  Nokogiri::XML(data_capture)
end

def additional_calculations(opts)
  facts = {}
  pool_list = {}
  raw_capacity = 0
  user_capacity = 0
  consumed_capacity = 0
  lun_capacity = 0
  hot_spare = 0
  hot_spare_capacity = 0
  pool_name = ""

   Open3.popen3("/opt/Navisphere/bin/naviseccli -User #{opts[:username]} -Scope 0 -Address #{opts[:server]} -Password #{opts[:password]} storagepool -list") do | stdin, stdout, stderr, wait_thr|
     stdout.read.split(/\r?\n/).each do |storagepool|
       pool_name = storagepool.split(":").last.strip if storagepool.include? "Pool Name:"
       if storagepool.include? "Available Capacity (GBs):"
         if !pool_name.empty?
           pool_list[pool_name]= storagepool.split(":").last.to_f
           pool_name = ""
         end
       end
       available += s.split(":").last.to_i if s.include? "Available Capacity (GBs):"
       raw_capacity += s.split(":").last.to_i if s.include? "Raw Capacity (GBs):"
       user_capacity += s.split(":").last.to_i if s.include? "User Capacity (GBs):"
       consumed_capacity += s.split(":").last.to_i  if s.include? "Consumed Capacity (GBs):"
     end
   end

   Open3.popen3("/opt/Navisphere/bin/naviseccli -User #{opts[:username]} -Scope 0 -Address #{opts[:server]} -Password #{opts[:password]} getdisk -all") do | stdin, stdout, stderr, wait_thr|
     isit_hotspare = false
     stdout.read.split(/\r?\n/).each do |s|
      if s.include? "Hot Spare Ready"
        hot_spare += 1
        isit_hotspare = true
       end
      if (s.include? "User Capacity:") && isit_hotspare
        hot_spare_capacity += s.split(":").last.to_f
        isit_hotspare = false
      end
     end
   end

   Open3.popen3("/opt/Navisphere/bin/naviseccli -User #{opts[:username]} -Scope 0 -Address #{opts[:server]} -Password #{opts[:password]} getAll") do | stdin, stdout, stderr, wait_thr|
     lun_capacity_temp =0
     stdout.read.split(/\r?\n/).each do |s|
       lun_capacity_temp = s.split(":").last.to_i if  s.include? "LUN Capacity(Megabytes):"
       if s.include? "\"~filestorage\""
         lun_capacity += lun_capacity_temp
         lun_capacity_temp = 0
       end
     end
   end
   facts["pool_list"]={"pool"=> [pool_list]}
   facts["HotspareDisks"]=hot_spare
   facts["HotspareDiskSpace"]=hot_spare_capacity
   facts["Free Storage Pool Space"]=available
   facts["Consumed Disk Space"]=consumed_capacity
   facts["Free Space for File"]=lun_capacity/1024
   facts["User Capacity"]=user_capacity
   facts["Raw Disk Space"]=raw_capacity
   facts
end

begin

  args=['--trace']

  Timeout.timeout(opts[:timeout]) do
    facts = collect_emc_vnx_facts opts
  end
rescue Timeout::Error
  puts "Timed out trying to gather inventory"
  exit 1
rescue Exception => e
  puts "#{e}\n#{e.backtrace.join("\n")}"
  exit 1
else
  if facts.empty?
    puts 'Could not get updated facts'
    exit 1
  else
    File.write(opts[:output], facts)
  end
end
