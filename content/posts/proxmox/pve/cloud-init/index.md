---
title: "Provisioning VMs on Proxmox using Cloud-Init and Ansible"
date: 2025-07-08
lastmod: 2025-07-08
description: "Create a Debian-based VM template using Cloud-Init and cloud images on your Proxmox cluster, then provision it using Ansible"
summary: "Provisioning Debian VMs on Proxmox using cloud-init, cloud images and Ansible"
categories: ["virtualisation"]
tags: ["proxmox", "pve", "cloud-init"]
draft: true
---

This article explains how to create a Cloud-Init based template to be cloned when creating new VMs in our Proxmox cluster. Proxmox offers native mechanisms to create templates from existing VMs, to be later reused, but making them Cloud-Init enabled goes a long way towards automation. Finally, Ansible will help us wrap it up nicely.

## Cloud-Init

Cloud images are lightweight snapshots of a configured OS created for use with cloud infrastructure. They provide a way to repeatably create identical copies of a machine across platforms. Debian provides cloud images[^1] of its operating system, packaged into a format suitable for cloud platforms (e.g., `qcow2`, `raw`, `tar.xz`), which include tools like Cloud-Init to facilitate automated configuration and customization upon startup.

[^1]: These images are not meant for direct installation on physical hardware.

[Cloud-Init](https://cloud-init.io/) is the industry standard method for cloud instance initialization. During boot, it identifies the cloud it is running on and initializes the system accordingly. Configuration instructions can be reused and always get consistent, reliable results.

Cloud-Init can handle a range of tasks that normally happen when a new instance is created. It is responsible for activities like setting the hostname and the default locale, configuring network interfaces, creating user accounts, generating SSH skeys, and even running scripts. This streamlines the deployment process, as cloud instances will all be automatically configured in the same way, which reduces the chance to introduce human error.

The operation takes place in two separate phases. The first phase is during the early (local) boot stage, before networking has been enabled. The second is during the late boot stages, after Cloud-Init has applied the networking configuration.

During early boot, Cloud-Init discovers the datasource, obtains all the configuration data from it, and configures networking.

During late boot, Cloud-Init runs through the tasks that were not critical for provisioning. This is where it configures the running instance according to your needs. This process can be done by interacting with Ansible.

## ISO download

Debian provides [official cloud images](https://cloud.debian.org/images/cloud/). We will be using the `genericcloud` version of the image in `qcow2` (QEMU Copy On Write) format.

* Debian 11 Bullseye [cloud image](https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-genericcloud-amd64.qcow2) and [SHA 512 sum](https://cloud.debian.org/images/cloud/bullseye/latest/SHA512SUMS).
* Debian 12 Bookworm [cloud image](https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2) and [SHA 512 sum](https://cloud.debian.org/images/cloud/bookworm/latest/SHA512SUMS).

Because the `Download from URL` button in the `ISO Images` menu option of our node only allows us to download images in ISO format, we will use the terminal to perform this operation. On your first node, e.g., `proxmox1`, download the image:

```bash
mkdir /var/lib/vz/template/cloud
wget https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2 \
     --output-document=/var/lib/vz/template/iso/debian-12-genericcloud-amd64.qcow2
```

For security, calculate its SHA 512 checksum and compare it with the one from the SHA512SUMS file:

```bash
sha512sum /var/lib/vz/template/cloud/debian-12-genericcloud-amd64.qcow2
wget https://cloud.debian.org/images/cloud/bookworm/latest/SHA512SUMS -O- | grep debian-12-genericcloud-amd64.qcow2
```

Optionally, copy the `qcow2` image to the rest of nodes:

```bash
NUM_NODES=$(pvecm nodes | grep -cE '^\s+[0-9]+\s+[0-9]+\s+proxmox[0-9]+')
for i in `seq 2 ${NUM_NODES}`
do
  rsync --rsh=ssh /var/lib/vz/template/cloud/debian-12-genericcloud-amd64.qcow2 proxmox${i}:/var/lib/vz/template/cloud/
done
```

## Templating

We need to create a virtual machine, then turn it into a template. The Proxmox assistant will not let us create a VM without an image, and it only accepts ISO images. Therefore, we will resort to the terminal.

First of all, create an empty virtual machine:

```bash
qm create 9000 --name "debian-12-tmpl" --balloon 1024 --memory 2048 --cores 2 --net0 virtio,bridge=vmbr4002,firewall=1,mtu=1400 --scsihw virtio-scsi-single --ostype l26 --agent enabled=1,fstrim_cloned_disks=1,type=virtio --bios seabios --description "Debian 12 Bookworm cloud template"
```

> Choosing a very big VM ID is not mandatory, but rather a quick way to identify VM templates in our cluster.

Next, import the cloud image as a disk:

```bash
qm disk import 9000 /var/lib/vz/template/cloud/debian-12-genericcloud-amd64.qcow2 local  --format qcow2
```

In Proxmox, `raw` and `qcow2` are common disk image formats, each with distinct advantages and disadvantages when using them with `qm disk import`. The former offers potentially better performance due to its simplicity, while the latter provides features like snapshots, compression, and dynamic resizing, albeit with a slight performance overhead. The choice depends on specific needs and the underlying storage type.

Next, attach the new (unused) disk to the VM as a SCSI drive on the SCSI controller:

```bash
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local:9000/vm-9000-disk-0.qcow2,discard=on,iothread=1,size=3G
```

The next step is to configure a CD-ROM drive, which will be used to pass the Cloud-Init data to the VM:

```bash
qm set 9000 --ide2 local:cloudinit
```

> `--cdrom` is an alias for `--ide2`. Using `--ide2` sets `media=cdrom`.

To be able to boot directly from the Cloud-Init image, we need to set the boot parameter to order=scsi0 to restrict BIOS to boot from this disk only. This will speed up booting, because VM BIOS skips the testing for a bootable CD-ROM.

```bash
qm set 9000 --boot order=scsi0
```

For many Cloud-Init images, it is required to configure a serial console and use it as a display. HOwever, if the configuration does not work for a given image, switch back to the default display instead.

```bash
qm set 9000 --serial0 socket --vga serial0
```

If we were not using Ansible, this would be the point in time in which we would visit the `Cloud-Init` menu option of our newly-created, not-yet-started VM with ID 9000, and configure the following options to our liking:

* User: `devops`
* Password: <password>
* DNS domain: `localdomain.com`
* DNS servers: `192.168.0.2 192.168.0.3`
* SSH public key: <cluster-wide-devops-key>
* IP Config (net0): DHCP

In a last step, we will convert the VM into a template. From this template we will be able to quickly create (linked) clones. The deployment from VM templates is much faster than creating a full clone.

Either right-click on the VM and choose the `Convert to template` option, or use the terminal:

```bash
qm template 9000
```

> Templating a VM is a one-way ticket. The VM is converted, not duplicated into a template.

By not starting the VM before converting it into a template, we are preventing the Debian bootstrap process from executing. This process sets up:

* **Machine id**, stored in `/etc/machine-id`, which is used by D-Bus and systemd for various purposes, including identifying the system.
* **Disk [*](UUID)**, used in `/etc/fstab`, which allows for reliable mounting even if device names change.
* **SSH host keys**, stored in `/etc/ssh/ssh_host_*`, which are used for secure remote access to the system.

## Ansible

In the previous section, we neither configured the VM's Cloud-Init options, nor did we install basic packages such as `qemu-guest-agent`, or other basic tools and utilities such as `ccze`, `dnsutils`, `htop`, `nmap`, or `tcpdump`.

This choice is intentional, as we want to keep as clean as possible so that we do not have to undo or correct anything in the future. And because we will be using Ansible to configure it once it has been bootstrapped.

https://claude.ai/chat/ff50568b-980f-40aa-8f85-1cdb2fc06e1f

```yaml
# playbooks/provision-vm.yml
---
- name: Provision VM from Cloud-Init template
  hosts: "{{ target_group | default('all') }}"
  gather_facts: false
  vars:
    proxmox_api_host: "{{ hostvars[inventory_hostname]['proxmox_node'] }}.your-domain.com"
    proxmox_api_user: "root@pam"
    proxmox_api_password: "{{ vault_proxmox_password }}"
    
  tasks:
    - name: Create VM from template
      community.general.proxmox_kvm:
        api_host: "{{ proxmox_api_host }}"
        api_user: "{{ proxmox_api_user }}"
        api_password: "{{ proxmox_api_password }}"
        node: "{{ proxmox_node }}"
        vmid: "{{ proxmox_ctid }}"
        name: "{{ inventory_hostname.split('.')[0] }}"
        clone: "debian-12-cloud-template"
        full: true
        storage: "local-lvm"
        format: "qcow2"
        timeout: 300
        
        # Cloud-Init configuration
        ciuser: "ansible"
        cipassword: "{{ vault_vm_password }}"
        sshkeys: "{{ lookup('file', '~/.ssh/id_rsa.pub') }}"
        
        # Network configuration from inventory
        ipconfig:
          ipconfig0: "ip={{ ansible_host }}/24,gw=192.168.0.1"
        nameservers: "192.168.0.1 8.8.8.8"
        
        # Environment-specific configuration
        cicustom: "user=local:snippets/user-data-{{ group_names[0] }}.yml"
        
        state: present
        
    - name: Start VM
      community.general.proxmox_kvm:
        api_host: "{{ proxmox_api_host }}"
        api_user: "{{ proxmox_api_user }}"
        api_password: "{{ proxmox_api_password }}"
        node: "{{ proxmox_node }}"
        vmid: "{{ proxmox_ctid }}"
        state: started
```

## Cloning

You can easily deploy such a template by cloning:

```bash
qm clone 9000 110 --name appserver1 --full
```

Then configure the SSH public key used for authentication, and configure the IP setup:

```bash
qm set 110 --sshkey ~/.ssh/id_dsa.pub --ipconfig0 ip=192.168.0.110/24,gw=
```

# Python 2.7

We have a legacy application that is based on Python 2.7. Thus, we want to add Python 2.7 to the template, so it is already there when cloned.

Create the file `/etc/apt/sources.list.d/bullseye.sources` use the preferred `deb822` format:

```
Types: deb
URIs: https://deb.debian.org/debian
Suites: bullseye bullseye-updates
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: https://security.debian.org/debian-security
Suites: bullseye-security
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
```

Alternatively, if you prefer the classic format, create the file `/etc/apt/sources.list.d/bullseye.list` with the following content:

```
deb http://deb.debian.org/debian bullseye main
deb http://deb.debian.org/debian bullseye-updates main
deb http://security.debian.org bullseye-security main
```