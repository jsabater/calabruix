---
title: "Provisioning VMs on Proxmox using Cloud-Init and Ansible"
date: 2025-08-03
lastmod: 2025-08-09
description: "Create a Debian-based VM template using Cloud-Init and cloud images on your Proxmox cluster, then provision it using Ansible"
summary: "Provisioning Debian VMs on Proxmox using cloud-init, cloud images and Ansible"
categories: ["virtualisation"]
tags: ["proxmox", "pve", "cloud-init", "vm", "ansible"]
---

This article explains how to create a Cloud-Init based template to be cloned when creating new VMs in our Proxmox cluster. Proxmox offers native mechanisms to create templates from existing VMs, to be later reused, but making them Cloud-Init enabled goes a long way towards automation. Moreover, Ansible will help us wrap it up nicely.

## Cloud images

Cloud images are lightweight snapshots of a configured OS created for use with cloud infrastructure (e.g., [*](VPS), [*](VM)). They provide a way to repeatably create identical copies of a machine across platforms.

Debian provides [official cloud images](https://cloud.debian.org/images/cloud/) of its operating system, packaged into a format suitable for cloud platforms (e.g., `qcow2`, `raw`), which include tools like Cloud-Init to facilitate automated configuration and customization upon startup.

> Cloud images are not meant for direct installation on physical hardware.

## Cloud-Init

[Cloud-Init](https://cloud-init.io/) is the industry standard method for cloud instance initialization. During boot, it identifies the cloud it is running on and initializes the system accordingly. Configuration instructions can be reused and always get consistent, reliable results.

Cloud-Init can handle a range of tasks that normally happen when a new instance is created. It is responsible for activities like setting the hostname and the default locale, configuring network interfaces, creating user accounts, generating SSH skeys, and even running scripts. This streamlines the deployment process, as cloud instances will all be automatically configured in the same way, which reduces the chance to introduce human error.

The operation takes place in two separate phases. The first phase is during the early (local) boot stage, before networking has been enabled. The second is during the late boot stages, after Cloud-Init has applied the networking configuration.

During early boot, Cloud-Init discovers the datasource, obtains all the configuration data from it, and configures networking.

During late boot, Cloud-Init runs through the tasks that were not critical for provisioning. This is where it configures the running instance according to your needs. This process can be done by interacting with Ansible.

## ISO download

We will be using the `genericcloud` version of the image in `qcow2` (QEMU Copy On Write) format.

Because the `Download from URL` button in the `ISO Images` menu option of our node only allows us to download images in ISO format, we will use the terminal to perform this operation. 

We will be using the Debian 13 Trixie [cloud image](https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2) and [SHA 512 sum](https://cloud.debian.org/images/cloud/trixie/latest/SHA512SUMS).

On your first node, e.g., `proxmox1`, download the image:

```bash
mkdir --parents /var/lib/vz/template/cloud
wget https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2 \
     --output-document=/var/lib/vz/template/cloud/debian-13-genericcloud-amd64.qcow2
```

For security, calculate its SHA 512 checksum and compare it with the one from the SHA512SUMS file:

```bash
sha512sum /var/lib/vz/template/cloud/debian-13-genericcloud-amd64.qcow2
wget --quiet https://cloud.debian.org/images/cloud/trixie/latest/SHA512SUMS -O- \
  | grep debian-13-genericcloud-amd64.qcow2
```

Optionally, copy the `qcow2` image to the rest of nodes (adapt to your cluster):

```bash
NUM_NODES=$(pvecm nodes | grep -cE '^\s+[0-9]+\s+[0-9]+\s+proxmox[0-9]+')
SRC_FILE="/var/lib/vz/template/cloud/debian-13-genericcloud-amd64.qcow2"
for i in `seq 2 ${NUM_NODES}`
do
  echo "Copying `basename ${SRC_FILE}` to proxmox${i}"
  rsync --rsh=ssh ${SRC_FILE} proxmox${i}:/var/lib/vz/template/cloud/
done
```

For Debian 12 and 11, the process is similar, but you will have to download different images:

* Debian 12 Bookworm [cloud image](https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2) and [SHA 512 sum](https://cloud.debian.org/images/cloud/bookworm/latest/SHA512SUMS).
* Debian 11 Bullseye [cloud image](https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-genericcloud-amd64.qcow2) and [SHA 512 sum](https://cloud.debian.org/images/cloud/bullseye/latest/SHA512SUMS).

## Templating

We need to create a virtual machine, then turn it into a template. The Proxmox assistant will not let us create a VM without an image, and it only accepts ISO images. Therefore, we will resort to the terminal.

As an example, we will create a VM with id 9000 for Debian 12. You may want to use successive ids for other versions of Debian, and adapt the commands accordingly.

Just in case it has not been done before, create the resource pool of your liking:

```bash
pvesh create /pools --poolid templates --comment "Templates for VMs"
```

First of all, create an empty virtual machine:

```bash
qm create 9000 --name "debian-12-tmpl" --cores 2 --cpu host \
   --balloon 1024 --memory 2048 --onboot 0 \
   --net0 virtio,bridge=vmbr4002,firewall=1,mtu=1400 \
   --scsihw virtio-scsi-single \
   --ostype l26 --bios seabios \
   --agent enabled=1,fstrim_cloned_disks=1,type=virtio \
   --pool templates --description "Debian 12 Bookworm cloud template"
```

Using processor type `host` exposes modern CPU features such as [*](AVX), [*](AVX2), [*](SSE4.2), [*](BMI1)/[*](BMI2), and [*](FMA). We trade better performance and compatibility with modern software for less portability, i.e., VM live migration between nodes may fail when using very different CPU architectures.

Optionally, add tags to the VM to help identify it later:

```bash
qm set 9000 --tags debian12,local
```

> Choosing a very big VM ID is not mandatory, but rather a quick way to identify VM templates in our cluster.

Next, import the cloud image as a disk:

```bash
qm disk import 9000 --format qcow2 \
   /var/lib/vz/template/cloud/debian-12-genericcloud-amd64.qcow2 local
```

In Proxmox, `raw` and `qcow2` are common disk image formats, each with distinct advantages and disadvantages. The former offers potentially better performance due to its simplicity, while the latter provides features like snapshots, compression, and dynamic resizing, albeit with a slight performance overhead. The choice depends on specific needs and the underlying storage type[^2].

[^2]: The [Proxmox storage documentation](https://pve.proxmox.com/wiki/Storage) explains how `/var/lib/vz` maps to the `local` storage type.

Next, attach the disk to the VM:

```bash
qm set 9000 --scsi0 local:9000/vm-9000-disk-0.qcow2,format=qcow2,iothread=1,discard=on,serial=os
```

The next step is to configure a CD-ROM drive, which will be used to pass the Cloud-Init data to the VM:

```bash
qm set 9000 --ide2 local:cloudinit
```

> `--cdrom` is an alias for `--ide2`. Using `--ide2` sets `media=cdrom`.

To be able to boot directly from the Cloud-Init image, we need to set the boot parameter to `order=scsi0` to restrict the [*](BIOS) to boot from this disk only. This will speed up booting, because it skips the testing for a bootable CD-ROM.

```bash
qm set 9000 --boot order=scsi0
```

For many Cloud-Init images, it is required to configure a serial console and use it as a display. However, if the configuration does not work for a given image, switch back to the default display instead.

```bash
qm set 9000 --serial0 socket --vga serial0
```

Now is the time to visit the `Cloud-Init` menu option of our newly-created, not-yet-started VM with ID 9000, and configure the following options with some default values (adapt to your needs):

* User: `ansible`
* Password: `<password>`
* DNS domain: `localdomain.com`
* DNS servers: `192.168.0.2 192.168.0.3`
* SSH public key: `ssh-ed25519 AAAAC3N [..] Ansible`
* IP Config (net0): `DHCP`

Use a randomnly generated password for your `ansible` user, then save it in a vault, such as Proton Pass or Bitwarden/Vaultwarden. Also add it to the Ansible vault, so it can be used later to provision the VM.

Once you are finished, do not forget to use the `Regenerate image` button to update the CD-ROM containing the Cloud-Init configuration. Or you can use the following command from the terminal:

```bash
qm cloudinit update 9000
```

In order to keep our template small and simple, we will use just once disk. Later on we will add a second disk to it, to be used as swap. Thus, this is a summary of the disk our template will have:

| Option            | OS disk    | Notes                                      |
|-------------------|:----------:|--------------------------------------------|
| `Bus/Device`      | `SCSI 0`   | VirtIO SCSI driver works well with discard |
| `Storage`         | `local`    |                                            |
| `Disk size (GiB)` | 3          |                                            |
| `Format`          | `qcow2`    | QCOW 2 supports snapshots                  |
| `Cache`           | No cache   |                                            |
| `IO thread`       | Yes        | Enable parallel access                     |
| `Backup`          | Yes        | Include disk in backup jobs                |
| `Async IO`        | `io_uring` | Most compatible and reliable               |
| `Discard`         | Yes        | Enable TRIM/UNMAP                          |

We are now ready to convert the VM into a template. From this template we will be able to quickly create clones. Either right-click on the VM and choose the `Convert to template` option, or use the terminal:

```bash
qm template 9000
```

> Templating a VM is a one-way ticket. The VM is converted, not duplicated into a template.

By not starting the VM before converting it into a template, we are preventing the Debian bootstrap process from executing. For your reference, bootstrapping means setting up:

* **Machine id**, stored in `/etc/machine-id`, which is used by D-Bus and systemd for various purposes, including identifying the system.
* **Disk [*](UUID)**, used in `/etc/fstab`, which allows for reliable mounting even if device names change.
* **SSH host keys**, stored in `/etc/ssh/ssh_host_*`, which are used for secure remote access to the system.

## Ansible

In the previous section, we neither configured the VM's Cloud-Init options, nor did we install basic shell tools and utilities.

This choice is intentional, as we want to keep our template as clean as possible so that we do not have to undo or correct anything in the future, and because we will be using Ansible to provision and configure it.

To provision VMs from our template, including setting up Cloud-Init configurations, we will use the [Ansible Proxmox KVM](https://docs.ansible.com/ansible/devel/collections/community/proxmox/proxmox_kvm_module.html) module, which you will have to install manually:

```bash
ansible-galaxy collection install community.proxmox
```

### Provisioning

The process of provisioning a virtual machine from a template follows these steps:

1. Clone the virtual machine from the template.
2. Configure Cloud-Init options.
3. Start the virtual machine.
4. Optionally, customise the virtual machine.

When provisioning a virtual machine from the Debian 11 template, we will add the `cicustom` attribute to the task that updates the Cloud-Init configuration so that the `proxmox_kvm` module executes a custom network configuration snippet, which is necessary to avoid a known issue where the default network configuration causes long boot delays, or even hangs, due to IPv6 misconfiguration.

Specifically, Debian 11 cloud images may fail to bring up the `ens18` interface cleanly due to Cloud-Init generating incomplete or incorrect `ifupdown` configurations, especially when IPv6 is left blank. By injecting a valid, minimal network configuration through a `cicustom` snippet, the playbook ensures a smooth and predictable network setup during first boot, preventing timeout errors and enabling faster provisioning.

Debian 12 and 13 cloud images do not require such snippet.

To keep it simple, a lot of variables are hardcoded in the following example, but you can easily adapt it to your needs. For context, the following code would exist in the following Ansible structure:

1. Inventory file at `inventory/myapp.yml`.
2. Variables for all groups at `inventory/group_vars/all/vars.yml`.
3. Playbook templates at `plays/templates/provision/`.
4. Playbook tasks at `plays/tasks/provision/`.
5. Playbook at `plays/provision.yml`.

```yaml
# inventory/myapp.yml
myapp:
  hosts:
    myapp1.localdomain.com:
      ansible_host: 192.168.0.21
      proxmox_vmid: 121
```

```yaml
# inventory/group_vars/all/vars.yml
proxmox_api_user: "{{ vault_proxmox_api_user | default('root@pam') }}"
proxmox_api_token_id: "{{ vault_proxmox_api_token_id }}"
proxmox_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
proxmox_ci_password: "{{ vault_proxmox_ci_password }}"
```

```yaml
# plays/templates/provision/disable-ipv6-network.yaml.j2
version: 2
ethernets:
  ens18:
    dhcp4: true
    dhcp6: false
    accept-ra: false
```

```yaml
# plays/tasks/provision/clone.yml
- name: Check if the virtual machine already exists
  register: vm_status
  failed_when: false # Do not fail when the VM does not exist
  delegate_to: localhost
  community.general.proxmox_kvm:

    # API
    api_host: "proxmox1.localdomain.com"
    api_user: "{{ proxmox_api_user }}"
    api_token_id: "{{ proxmox_api_token_id }}"
    api_token_secret: "{{ proxmox_api_token_secret }}"
    
    # VM. Use `vmid` to checking status.
    vmid: "{{ proxmox_vmid }}"
    node: "proxmox1"
    state: current

- name: Clone the virtual machine from the template
  when: vm_status.status is not defined or vm_status.status == "absent"
  delegate_to: localhost
  community.general.proxmox_kvm:
    state: present

    # API
    api_host: "proxmox1.localdomain.com"
    api_user: "{{ proxmox_api_user }}"
    api_token_id: "{{ proxmox_api_token_id }}"
    api_token_secret: "{{ proxmox_api_token_secret }}"

    # VM. Use `newid` when cloning.
    newid: "{{ proxmox_vmid }}"
    node: "proxmox1"
    name: "{{ inventory_hostname_short }}"

    # Cloning
    storage: "local"
    format: "qcow2"
    clone: "debian12-tmpl"
    full: true
    description: "Cloned from Debian 12 template"

- name: Debian 11 specific configuration
  when:
    - ansible_distribution == "Debian"
    - ansible_distribution_major_version == "11"
  block:

    - name: Upload Cloud-Init snippet to disable IPv6 network configuration
      delegate_to: proxmox1.localdomain.com
      ansible.builtin.template:
        src: templates/provision/debian-11-disable-ipv6-network.yaml.j2
        dest: /var/lib/vz/snippets/debian-11-disable-ipv6-network.yaml
        owner: root
        group: root
        mode: "0644"

    - name: Set Cloud-Init custom script for Debian 11
      set_fact:
        proxmox_cicustom:
          network: "local:snippets/debian-11-disable-ipv6-network.yaml"

- name: Update the virtual machine Cloud-Init configuration
  delegate_to: localhost
  community.general.proxmox_kvm:
    update: true

    # API
    api_host: "{{ proxmox_api_host }}"
    api_user: "{{ proxmox_api_user }}"
    api_token_id: "{{ proxmox_api_token_id }}"
    api_token_secret: "{{ proxmox_api_token_secret }}"

    # VM. Use `vmid` when updating.
    vmid: "{{ proxmox_vmid }}"
    node: "{{ proxmox_node }}"
    cores: "4"
    memory: "8192"
    balloon: "4096"

    # Cloud-Init credentials
    ciuser: "ansible"
    cipassword: "{{ proxmox_ci_password }}"
    sshkeys: "{{ lookup('ansible.builtin.file', '~/.ssh/ansible.pub') }}"

    # Cloud-Init network
    ipconfig:
      ipconfig0: "ip={{ ansible_host }}/16"
    nameservers:
      - "192.168.0.4"
      - "192.168.0.5"
    searchdomains: "localdomain.com"

    # Cloud-Init custom script
    cicustom: "{{ proxmox_cicustom | default(omit) }}"
```

```yaml
# plays/tasks/provision/start.yml
- name: Start virtual machine
  delegate_to: localhost
  community.general.proxmox_kvm:
    state: started
    timeout: 10

    # API
    api_host: "proxmox1.localdomain.com"
    api_user: "{{ proxmox_api_user }}"
    api_token_id: "{{ proxmox_api_token_id }}"
    api_token_secret: "{{ proxmox_api_token_secret }}"

    node: "proxmox1"
    vmid: "{{ proxmox_vmid }}"

- name: Wait for the virtual machine to be accessible
  ansible.builtin.wait_for:
    host: "{{ ansible_host }}"
    port: 22
    timeout: 300
```

### Swap disk

When marked as such, via the `proxmox_swap` attribute in our inventory, we can provision a second disk to the VM, to be used as swap. Again, many variables are hardcoded in the following example, but you can easily adapt it to your needs.

```yaml
# inventory/myapp.yml
myapp:
  hosts:
    myapp1.localdomain.com:
      ansible_host: 192.168.0.21
      proxmox_vmid: 121
      proxmox_swap: 1 # GB
```

```yaml
# plays/tasks/provision/swap.yml
- name: Create and attach swap disk to VM
  when: proxmox_swap | default(0)
  delegate_to: localhost
  community.proxmox.proxmox_kvm:
    update: true
    update_unsafe: true # Allow updating `scsi`

    # API
    api_host: "{{ proxmox_api_host }}"
    api_user: "{{ proxmox_api_user }}"
    api_token_id: "{{ proxmox_api_token_id }}"
    api_token_secret: "{{ proxmox_api_token_secret }}"

    # VM
    vmid: "{{ proxmox_vmid }}"
    node: "{{ proxmox_node }}"
    scsi:
      scsi1: "local:{{ proxmox_swap }},format=raw,discard=on,backup=0,serial=swap"
```

This is a summary of the disk we are adding to our VM:

| Option            | Swap disk  | Notes                                      |
|-------------------|:----------:|--------------------------------------------|
| `Bus/Device`      | `SCSI 1`   | VirtIO SCSI driver works well with discard |
| `Storage`         | `local`    |                                            |
| `Disk size (GiB)` | 1          |                                            |
| `Format`          | `raw`      | Prefer speed to snapshot support           |
| `Cache`           | No cache   |                                            |
| `IO thread`       | No         | Enable parallel access                     |
| `Backup`          | No         | No need to back up this disk               |
| `Async IO`        | `io_uring` | Most compatible and reliable               |
| `Discard`         | Yes        | Enable TRIM/UNMAP                          |

Once the disk has been attached, we need to format it as swap and enable it. To keep things as simple as possible, we will make use of the `serial` parametrer of the disk, which is set to `swap`, to identify it in the `/dev/disk/by-id` directory. Because this path will always point to the correct device, we can use it in our playbook without worrying about the actual device name or its UUID.

```yaml
# plays/tasks/provision/swap.yml
- name: Wait for swap disk to appear
  register: wait_for_swap_disk
  ansible.builtin.wait_for:
    path: "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_swap"
    state: present
    timeout: 30

- name: Configure swap disk in VM
  when:
    - not wait_for_swap_disk.failed
    - wait_for_swap_disk.state == 'link'
  block:

    - name: Create swap filesystem on disk
      community.general.filesystem:
        fstype: swap
        dev: "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_swap"

    - name: Add swap entry to '/etc/fstab'
      ansible.posix.mount:
        src: "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_swap"
        path: none
        fstype: swap
        opts: sw
        state: present

    - name: Activate swap partition
      ansible.builtin.command:
        cmd: "swapon --all --verbose"
      register: swapon_result
      failed_when: false
      changed_when:
        - swapon_result.rc != 0
        - "'already active' not in swapon_result.stdout"
```
