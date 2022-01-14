//main tf file

// Global TF Settings
terraform {
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "2.0.2"
    }
  }
}

// Provider specific settings
provider "vsphere" {
  user           = "administrator@vsphere.local"
  password       = "VMware1!"
  vsphere_server = "vc-01.foggyclouds.io"

  # If you have a self-signed cert
  allow_unverified_ssl = true
}


// Data block
data "vsphere_datacenter" "dc" {
  name = "Datacenter"
}

data "vsphere_datastore" "datastore" {
  name          = "datastore-lab"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_compute_cluster" "cluster" {
  name          = "cluster-lab"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  name          = "net-lab"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = "templates/packer/ubuntu/linux-ubuntu-20"
  datacenter_id = data.vsphere_datacenter.dc.id
}

// Resource block
resource "vsphere_virtual_machine" "vm" {
  name             = "test-vm-01"
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id

  num_cpus = 2
  memory   = 2048
  guest_id = data.vsphere_virtual_machine.template.guest_id

  scsi_type = data.vsphere_virtual_machine.template.scsi_type

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = data.vsphere_virtual_machine.template.disks.0.size
    eagerly_scrub    = data.vsphere_virtual_machine.template.disks.0.eagerly_scrub
    thin_provisioned = data.vsphere_virtual_machine.template.disks.0.thin_provisioned
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    customize {

      network_interface {
        ipv4_address = "192.168.1.100"
        ipv4_netmask = 24
      }

      ipv4_gateway    = "192.168.1.254"
      dns_server_list = ["4.2.2.2"]
      dns_suffix_list = ["foggyclouds.io"]

      linux_options {
        host_name = "test-vm-01"
        domain    = "foggyclouds.io"
      }
    }
  }
  lifecycle {
    ignore_changes = [
      annotation,
      clone[0].template_uuid,
      clone[0].customize[0].dns_server_list,
      clone[0].customize[0].network_interface[0]
    ]
  }
}

// output block
output "vm_ip_address" {
  value = vsphere_virtual_machine.vm.default_ip_address
}

output "vm_hostname" {
  value = vsphere_virtual_machine.vm.name
}