#!/bin/bash -x
# version 1.0.5-0
# -------- edit /etc/hosts file

hostname=`hostname`
ip=`ip addr show dev eth0 | sed -nr 's/.*inet ([^ /]+).*/\1/p'`
echo "0.0.0.0   localhost localhost.localdomain localhost4 localhost4.localdomain4 ${hostname}"> /etc/hosts



# internal dns registration
$vci_utility_scripts
vciUtil startAll

# register hostname
sed -i 's/search openstacklocal$/search node.vci/' /etc/resolv.conf
curl -X PUT -d "{\"Node\": \"${hostname}\"}" http://consul.service.$environment.vci:8500/v1/catalog/deregister
curl -X PUT -d "{\"Node\": \"${hostname}\", \"Address\": \"${ip}\"}" http://consul.service.$environment.vci:8500/v1/catalog/register

# register LBs if exist
IFS=', ' read -a lbs <<< "$lbs_details"
for lb_detail in "${lbs[@]}"; do
    IFS=':' read -a lb <<< "$lb_detail"
    curl -X PUT -d "{\"Node\": \"${lb[0]}\", \"Address\": \"${lb[1]}\"}" http://consul.service.$environment.vci:8500/v1/catalog/register
done

$component_installation

result=`echo $?` 

$check_installation
