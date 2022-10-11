terraform {
  required_providers {
    equinix = {
      source = "equinix/equinix"
    }
  }
}
provider "equinix" {
  auth_token = var.auth_token
}

resource "equinix_metal_reserved_ip_block" "mgw_subnet" {
  project_id = var.project_id
  metro = var.metro
  type = "public_ipv4"
  quantity = var.mgw_subnet_size
  description = "TF VCF Metal Gateway Subnet"
  tags = [ "TF_VCF_MGW" ]
}

resource "equinix_metal_vlan" "mgw_vlan" {
  project_id  = var.project_id
  metro       = var.metro
  vxlan       = var.mgw_vlanid
  description = "TF_VCF_MGW - Metal Gateway VLAN"
}

resource "equinix_metal_vlan" "private_vlan" {
  project_id  = var.project_id
  metro       = var.metro
  vxlan       = var.private_vlanid
  description = "TF_VCF_MGW - First Private VLAN"
}

resource "equinix_metal_gateway" "vcf_mgw" {
  project_id = var.project_id
  vlan_id = equinix_metal_vlan.mgw_vlan.id
  ip_reservation_id = equinix_metal_reserved_ip_block.mgw_subnet.id
}

resource "equinix_metal_device" "esx" {
  count             = var.host_count
  hostname          = join("-",[var.hostname_prefix,count.index+1])
  project_id        = var.project_id
  metro             = var.metro
  plan              = var.plan
  operating_system  = var.operating_system
  billing_cycle     = var.billing_cycle
  tags = [ "TF_VCF_MGW" ]
  custom_data = jsonencode({
    sshd = {
      enabled = true
      pwauth = true
    }
    rootpwcrypt = var.password
    esxishell = {
       enabled = true
    }
    kickstart = {
      firstboot_shell = "/bin/sh -C"
      firstboot_shell_cmd = <<EOT
sed -i '/^exit*/i /vmfs/volumes/datastore1/configpost.sh' /etc/rc.local.d/local.sh;
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config;
touch /vmfs/volumes/datastore1/configpost.sh;
chmod 755 /vmfs/volumes/datastore1/configpost.sh;
echo 'esxcli network vswitch standard portgroup remove --portgroup-name="VM Network" --vswitch-name="vSwitch0"' >> /vmfs/volumes/datastore1/configpost.sh;
echo 'esxcli network vswitch standard portgroup add --portgroup-name="${join("",["vlan_",equinix_metal_vlan.mgw_vlan.vxlan])}" --vswitch-name="vSwitch0"' >> /vmfs/volumes/datastore1/configpost.sh;
echo 'esxcfg-vswitch -v ${equinix_metal_vlan.mgw_vlan.vxlan} -p ${join("",["vlan_",equinix_metal_vlan.mgw_vlan.vxlan])} vSwitch0' >> /vmfs/volumes/datastore1/configpost.sh;
echo 'esxcli network ip dns server add --server=${var.dns}' >> /vmfs/volumes/datastore1/configpost.sh;
echo 'esxcli network ip dns search add --domain=${var.domain}' >> /vmfs/volumes/datastore1/configpost.sh;
echo 'esxcfg-advcfg -s ${join("-",[var.hostname_prefix,count.index])}.${var.domain} /Misc/hostname' >> /vmfs/volumes/datastore1/configpost.sh;
echo 'esxcli system hostname set -H=${join("-",[var.hostname_prefix,count.index+1])}' >> /vmfs/volumes/datastore1/configpost.sh;
echo 'esxcli system hostname set -f=${join("-",[var.hostname_prefix,count.index+1,".",var.domain])}' >> /vmfs/volumes/datastore1/configpost.sh;
echo 'echo "server ${var.ntp}" >> /etc/ntp.conf' >> /vmfs/volumes/datastore1/configpost.sh;
echo 'chkconfig ntpd on' >> /vmfs/volumes/datastore1/configpost.sh;
echo 'esxcfg-vswitch -p "Management Network" -v ${equinix_metal_vlan.mgw_vlan.vxlan} vSwitch0' >> /vmfs/volumes/datastore1/configpost.sh;
echo 'esxcfg-vmknic -d "Private Network"' >> /vmfs/volumes/datastore1/configpost.sh;
echo 'esxcfg-vswitch -D "Private Network" vSwitch0' >> /vmfs/volumes/datastore1/configpost.sh;
echo 'esxcli network ip interface ipv4 set -i vmk0 -I ${cidrhost(equinix_metal_reserved_ip_block.mgw_subnet.cidr_notation,var.mgw_subnet_size - 1 - var.host_count + count.index)} -N ${cidrnetmask(equinix_metal_reserved_ip_block.mgw_subnet.cidr_notation)} -g ${cidrhost(equinix_metal_reserved_ip_block.mgw_subnet.cidr_notation,1)} -t static' >> /vmfs/volumes/datastore1/configpost.sh;
echo 'esxcfg-route ${cidrhost(equinix_metal_reserved_ip_block.mgw_subnet.cidr_notation,1)}' >> /vmfs/volumes/datastore1/configpost.sh;
echo 'esxcli network vswitch standard uplink add --uplink-name=vmnic1 --vswitch-name=vSwitch0' >> /vmfs/volumes/datastore1/configpost.sh;
echo 'sed -i '/configpost.sh/d' /etc/rc.local.d/local.sh' >> /vmfs/volumes/datastore1/configpost.sh;
echo 'cd /etc/vmware/ssl' >> /vmfs/volumes/datastore1/configpost.sh;
echo '/sbin/generate-certificates' >> /vmfs/volumes/datastore1/configpost.sh;
echo '/etc/init.d/hostd restart && /etc/init.d/vpxa restart' >> /vmfs/volumes/datastore1/configpost.sh;
EOT
      postinstall_shell = "/bin/sh -C"
      postinstall_shell_cmd = ""
    }
  })
}

resource "equinix_metal_port" "eth0" {
  count = var.host_count
  port_id = [for p in equinix_metal_device.esx[count.index].ports : p.id if p.name == "eth0"][0]
  vlan_ids = [equinix_metal_vlan.mgw_vlan.id, equinix_metal_vlan.private_vlan.id]
  bonded = false
}

resource "equinix_metal_port" "eth1" {
  count = var.host_count
  port_id = [for p in equinix_metal_device.esx[count.index].ports : p.id if p.name == "eth1"][0]
  vlan_ids = [equinix_metal_vlan.mgw_vlan.id, equinix_metal_vlan.private_vlan.id]
  bonded = false
}