#!/bin/bash

#CRR_REPO="https://github.com/NevilleDNZ-downstream/algol68g-release-builder-downstream"
CRR_REPO_URL="https://github.com"
CRR_REPO="$CRR_REPO_URL/NevilleDNZ/algol68-autopkg"
CRR_REPO="$CRR_REPO_URL/NevilleDNZ-downstream/algol68-autopkg-downstream"

CRR_VM=qemu
CRR_VM=kvm
CRR_VM=vmware
CRR_VM=docker
CRR_VM=xen
CRR_VM=vbox

CRR_AR_DIR=AR

TODO="Under construction..."

TRUE="TrU"
FALSE=""
q="'"
qq='"'

WS0="[[:space:]]*"
WS="[[:space:]]\+"

OPT_checksum=$FALSE
OPT_debug=$TRUE

trace_argv="$(echo_Q "$@")"

RAISE(){
    if [ $# != 0 ]; then
        echo_Q EXCEPTION: "$@"
    else
        echo_Q EXCEPTION: "$trace_argv"
    fi
    exit 1
}

NOTE(){
    if [ $# != 0 ]; then
        echo_Q NOTE: "$@"
    else
        echo_Q NOTE: "$trace_argv"
    fi
    true
}

WARN(){
    if [ $# != 0 ]; then
        echo_Q WARNING/$?: "$@"
    else
        echo_Q WARNING/$?: "$trace_argv"
    fi
    true
}

TRACE(){
    trace_argv="$(echo_Q "$@")"
    echo_Q TRACE: "$@" 1>&2
    "$@"
    return "$?"
}

ASSERT(){
    trace_argv="$(echo_Q "$@")"
    echo_Q TRACE: "$@" 1>&2
    "$@" || RAISE
    return "$?"
}

SKIP(){
    echo_Q SKIP: "$@"
    # "$@"
}

CD(){
    trace_argv="$(echo_Q "$@")"
    echo_Q CD: "$@"
    cd "$@"
}

SUDO(){
# Hint: edit /etc/sudoers.d/abcdev to include NOPASSWD...
# Defaults timestamp_timeout=30
## abcdev ALL=(ALL:ALL) ALL
# abcdev ALL=(ALL:ALL) NOPASSWD: ALL
    echo_Q SUDO: "$@"
    TRACE sudo "$@"
}

NEED(){
    SUDO dnf install -y "$@"
}

cows_come_home=999

WAIT_WHILE(){
    for((i=0; i<$cows_come_home; i++)); do
        TRACE "$@" || return "$?"
        sleep 6
    done
    return 0
}

WAIT_UNTIL(){
    for((i=0; i<$cows_come_home; i++)); do
        TRACE "$@" && return $?
        rc="$?"
        sleep 6
    done
    return "$rc"
}

NOT(){
    "$@"
    case "$?" in
        (0)return 1;;
        (*)return 0;;
    esac
}

ip_up_host(){
    ping -c 1 -w 100 $1
}

is_open_host_port(){
    echo > /dev/tcp/$1/$2
}

Is_up_vm_nic(){
    ip=`get_ip_of_vm_nic $1`
    ip_up_host $ip
}

Is_open_vm_port(){
    ip=`get_ip_of_vm_nic $1`
    is_open_host_port $ip $2
}

CRR_ISO_LABEL="OEMDRV" # required only for RHEL? CIDATA for ubuntu/cloud-init

# -Leap-15.5-NET-x86_64-Build491.1-Media
normalise_hostname(){
    sed '
        s?^.*/??;
        s/?.*$//;
        s/[.]iso//;
        s/-\(\(dvd\|DVD\)\(-*[0-9][0-9]*\)*\|disc[0-9]\|live\|boot\|minimal\|legacy\|desktop\|netinst\|live\|server\|NET\|Build[^-]*\|Media\|RELEASE\)//g;
        s/\([a-zA-Z]\)/\L\1/g;
        s/\([a-z]\)-\([0-9]\)/\1\2/g;
        s/[^a-z0-9]/-/g;
    '
}

review_hostnames(){
    for iso in ~/Downloads/*.iso; do
        n=`echo $iso | normalise_hostname`; echo -n $n ................; basename $iso
    done
    exit
}


OPT_v=""

# Function to find the IP address associated with a VM's NIC MAC address # by ChatGPT
get_ip_of_vm_nic() {
    local vm_name="$1"
    local nic_number="$2"
    #ASSERT [ -n "$vm_name" ]
    #ASSERT [ -n "$nic_number" ]
    local subnet_l="192.168.56.174/24" # Define your subnet list here

    # Retrieve the MAC address for the specified NIC of the VM
    mac_address=$(VBoxManage showvminfo "$vm_name" --machinereadable | grep "macaddress$nic_number" | cut -d'"' -f2 | tr '[:upper:]' '[:lower:]')

    if [[ -n "$mac_address" ]]; then
        [ -n "$OPT_v" ] && echo "MAC address for VM $vm_name is: $mac_address"
        # echo $mac_address
    else
        [ -n "$OPT_v" ] && echo "No MAC address found for VM $vm_name." 1>&2
        return 1
    fi

    # Format the MAC address to standard colon-separated format
    mac_address=$(echo "$mac_address" | sed 's/\(..\)/\1:/g;s/:$//')

    [ -n "$OPT_v" ] && echo "Scanning for MAC address $mac_address in subnet $subnet_l..." 1>&2

    # Use ip neigh to find the IP address associated with the MAC address
    ip_address=$(ip neigh | awk "/$mac_address/"'{print $1}')
    if [ "$ip_address" == "" ]; then
    # Scan the subnet with nmap to populate the ARP table
        for subnet in $subnet_l; do
            nmap -sn $subnet > /dev/null 2>&1
        done
        ip_address=$(ip neigh | awk "/$mac_address/"'{print $1}')
    fi

    if [[ -n "$ip_address" ]]; then
        [ -n "$OPT_v" ] && echo "IP address for MAC $mac_address is: $ip_address"
        echo $ip_address
    else
        [ -n "$OPT_v" ] && echo "No IP address found for MAC $mac_address." 1>&2
        return 1
    fi

    return 0
}

# Example usage:
# get_ip_of_vm_nic "VM name" 1

local_downloads="$HOME/Downloads"
local_tmpdir="$local_downloads/tmp"

CRR_UID=`id -u`
CRR_local_depatcher=`id -un` # user name
CRR_GID=`id -g` # not sure UID/GID is avaliable on all OSes

CRR_remote_admin=`id -un`adm # user name
CRR_remote_builder=`id -un`bld # user name

CRR_PTEKEY=id_rsa
CRR_PUBKEY=$CRR_PTEKEY.pub

get_CRR_PUBKEY(){
    cat ~/.ssh/$CRR_PUBKEY
}

CRR_timezone="Australia/Brisbane"

HELP_gen_pw="$TODO"
gen_pw (){
    # the next two lines are hint, actual PW differs...
    SALT=$(openssl rand -base64 12)
    c=`echo -n "VBOX-PW-salted" | openssl passwd -6 -salt "$SALT" -stdin` # Fake PW
    ToDo: Add
    . ~/.ssh/create_self_hosted_runner_on_vm.passwords # get ROOT_PW_IC and ROOT_PW_PT
}

HELP_update_os="$TODO"
QQQupdate_os (){
  true
}

HELP_create_kickstart="$TODO"
create_kickstart (){
#    gen_pw "$@"
    # cf. https://access.redhat.com/labs/kickstartconfig/#network @23d03
    cat << EOF > "$CRR_kickstart_Installer"
#version=RHEL9
lang en_US
keyboard --xlayouts='us'
# Use text mode install
#text
graphical

timezone $CRR_timezone --utc
rootpw --iscrypted $ROOT_PW_IC
#rootpw --plaintext $ROOT_PW_PT

#reboot
#reboot --eject
cdrom
bootloader --append="rhgb quiet crashkernel=1G-4G:192M,4G-64G:256M,64G-:512M"
zerombr
clearpart --all --initlabel
autopart
#network --bootproto=dhcp
network --device=line  --hostname=$CRR_hostname --bootproto=dhcp
skipx
firstboot --disable
selinux --enforcing
firewall --enabled --ssh

# Reboot after installation
# Note! Not sure exactly when the --eject option was added. Need to find out and make it optional.
# reboot --eject

#%packages
#@^gnome-desktop-environment
#%end

%packages
#@^minimal-environment
@^server-product-environment
openssh-server
kexec-tools
%end

%post
mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo '`get_CRR_PUBKEY`' >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
echo -n "NOTE: host's ED25519 key fingerprint is:"
ssh-keygen -l -f /etc/ssh/ssh_host_ed25519_key.pub
sleep 6
/bin/echo "Shutdown will occur in 6 seconds... Goodbye!"
/bin/eject
/bin/sleep 6 # 0
/sbin/shutdown -h now
/bin/sleep 6 # 0
init 0
%end

EOF
  true
}

create_kickstart_try1 (){
# cf. https://access.redhat.com/labs/kickstartconfig
    cat << EOF > "$CRR_kickstart_Installer"
#platform=x86, AMD64, or Intel EM64T
#version=DEVEL

# Firewall configuration
firewall --disabled

# Install OS instead of upgrade
install

# Use CDROM installation media
cdrom

# Root password
#rootpw --plaintext "$ROOT_PW_PT"
rootpw $ROOT_PW_IC --iscrypted
# ToDo --option first?

# System authorization information
auth  --useshadow  --passalgo=sha512

# Use text mode install
text

# System keyboard
keyboard us

# System language
lang en_US

# Disable the unsupported hardware popup (vmmdev?).
#unsupported_hardware

# SELinux configuration
selinux --enforcing

# Installation logging level
logging --level=info

# System timezone
timezone --utc $CRR_timezone

# Network information
# network --bootproto=dhcp --device=link --onboot=on --hostname=vbox-rhel9-3-x86-64.myguest.virtualbox.org
network --bootproto=dhcp --device=link --onboot=on --hostname=$CRR_hostname.myguest.virtualbox.org

# System bootloader configuration
bootloader --location=mbr --append="nomodeset crashkernel=auto rhgb quiet"
zerombr

# Partition clearing information
clearpart --all --initlabel

# Disk partitioning information
part / --fstype ext4 --size 6000 --grow --asprimary
part swap --size 1024

#Initial user
#user --name=vboxuser --password="$ROOT_PW_PT" --plaintext
user --name=vboxuser --password="$ROOT_PW_IC" --iscrypted

# Reboot after installation
# Note! Not sure exactly when the --eject option was added. Need to find out an make it optional.
reboot --eject

# Packages.  We currently ignore missing packages/groups here to keep things simpler.
%packages --ignoremissing
@base
@core

@development
@basic-desktop
@desktop-debugging
@desktop-platform
@fonts
@general-desktop
@graphical-admin-tools
@remote-desktop-clients:q
@x11


# Prepare building the additions kernel module, try get what we can from the cdrom as it may be impossible
# to install anything from the post script:
kernel-headers
kernel-devel
glibc-devel
glibc-headers
gcc

elfutils-libelf-devel

dkms
make
bzip2
perl

#Package cloud-init is needed for possible automation the initial setup of virtual machine
cloud-init

%end

# Post install happens in a different script.
# Note! We mount the CDROM explictily here since the location differs between fedora 26 to rhel5
#       and apparently there isn't any way to be certain that anaconda didn't unmount it already.
%post --nochroot --log=/mnt/sysimage/root/ks-post.log
df -h
mkdir -p /tmp/vboxcdrom
mount /dev/cdrom /tmp/vboxcdrom
cp /tmp/vboxcdrom/vboxpostinstall.sh /mnt/sysimage/root/vboxpostinstall.sh
chmod a+x /mnt/sysimage/root/vboxpostinstall.sh
/bin/bash /mnt/sysimage/root/vboxpostinstall.sh --rhel
umount /tmp/vboxcdrom
%end

EOF
    true
}

# https://documentation.suse.com/sles/15-SP3/html/SLES-all/cha-autoyast-create-control-file.html
# sudo yast clone_system
HELP_create_autoyast="$TODO"
create_autoyast (){
    cat << EOF > "$CRR_autoyast_Installer"
<?xml version="1.0"?>
<!DOCTYPE profile>
<profile xmlns="http://www.suse.com/1.0/yast2ns" xmlns:config="http://www.suse.com/1.0/configns">

  <bootloader t="map">
    <global t="map">
      <append>splash=silent preempt=full mitigations=auto quiet security=apparmor</append>
      <cpu_mitigations>auto</cpu_mitigations>
      <gfxmode>auto</gfxmode>
      <hiddenmenu>false</hiddenmenu>
      <os_prober>true</os_prober>
      <secure_boot>true</secure_boot>
      <terminal>gfxterm</terminal>
      <timeout t="integer">8</timeout>
      <trusted_grub>false</trusted_grub>
      <update_nvram>true</update_nvram>
      <xen_kernel_append>vga=gfx-1024x768x16</xen_kernel_append>
    </global>
    <loader_type>grub2</loader_type>
  </bootloader>
  <firewall t="map">
    <default_zone>public</default_zone>
    <enable_firewall t="boolean">true</enable_firewall>
    <log_denied_packets>off</log_denied_packets>
    <start_firewall t="boolean">true</start_firewall>
    <zones t="list">
      <zone t="map">
        <description>Unsolicited incoming network packets are rejected. Incoming packets that are related to outgoing network connections are accepted. Outgoing network connections are allowed.</description>
        <interfaces t="list"/>
        <masquerade t="boolean">false</masquerade>
        <name>block</name>
        <ports t="list"/>
        <protocols t="list"/>
        <services t="list"/>
        <short>Block</short>
        <target>%%REJECT%%</target>
      </zone>
      <zone t="map">
        <description>For computers in your demilitarized zone that are publicly-accessible with limited access to your internal network. Only selected incoming connections are accepted.</description>
        <interfaces t="list"/>
        <masquerade t="boolean">false</masquerade>
        <name>dmz</name>
        <ports t="list"/>
        <protocols t="list"/>
        <services t="list">
          <service>ssh</service>
        </services>
        <short>DMZ</short>
        <target>default</target>
      </zone>
      <zone t="map">
        <description>All network connections are accepted.</description>
        <interfaces t="list">
          <interface>docker0</interface>
        </interfaces>
        <masquerade t="boolean">false</masquerade>
        <name>docker</name>
        <ports t="list"/>
        <protocols t="list"/>
        <services t="list"/>
        <short>docker</short>
        <target>ACCEPT</target>
      </zone>
      <zone t="map">
        <description>Unsolicited incoming network packets are dropped. Incoming packets that are related to outgoing network connections are accepted. Outgoing network connections are allowed.</description>
        <interfaces t="list"/>
        <masquerade t="boolean">false</masquerade>
        <name>drop</name>
        <ports t="list"/>
        <protocols t="list"/>
        <services t="list"/>
        <short>Drop</short>
        <target>DROP</target>
      </zone>
      <zone t="map">
        <description>For use on external networks. You do not trust the other computers on networks to not harm your computer. Only selected incoming connections are accepted.</description>
        <interfaces t="list"/>
        <masquerade t="boolean">true</masquerade>
        <name>external</name>
        <ports t="list"/>
        <protocols t="list"/>
        <services t="list">
          <service>ssh</service>
        </services>
        <short>External</short>
        <target>default</target>
      </zone>
      <zone t="map">
        <description>For use in home areas. You mostly trust the other computers on networks to not harm your computer. Only selected incoming connections are accepted.</description>
        <interfaces t="list"/>
        <masquerade t="boolean">false</masquerade>
        <name>home</name>
        <ports t="list"/>
        <protocols t="list"/>
        <services t="list">
          <service>dhcpv6-client</service>
          <service>mdns</service>
          <service>samba-client</service>
          <service>ssh</service>
        </services>
        <short>Home</short>
        <target>default</target>
      </zone>
      <zone t="map">
        <description>For use on internal networks. You mostly trust the other computers on the networks to not harm your computer. Only selected incoming connections are accepted.</description>
        <interfaces t="list"/>
        <masquerade t="boolean">false</masquerade>
        <name>internal</name>
        <ports t="list"/>
        <protocols t="list"/>
        <services t="list">
          <service>dhcpv6-client</service>
          <service>mdns</service>
          <service>samba-client</service>
          <service>ssh</service>
        </services>
        <short>Internal</short>
        <target>default</target>
      </zone>
      <zone t="map">
        <description><![CDATA[     This zone is used internally by NetworkManager when activating a     profile that uses connection sharing and doesnt have an explicit     firewall zone set.     Block all traffic to the local machine except ICMP, ICMPv6, DHCP     and DNS. Allow all forwarded traffic.     Note that future package updates may change the definition of the     zone unless you overwrite it with your own definition.   ]]></description>
        <interfaces t="list"/>
        <masquerade t="boolean">false</masquerade>
        <name>nm-shared</name>
        <ports t="list"/>
        <protocols t="list">
          <listentry>icmp</listentry>
          <listentry>ipv6-icmp</listentry>
        </protocols>
        <services t="list">
          <service>dhcp</service>
          <service>dns</service>
          <service>ssh</service>
        </services>
        <short>NetworkManager Shared</short>
        <target>ACCEPT</target>
      </zone>
      <zone t="map">
        <description>For use in public areas. You do not trust the other computers on networks to not harm your computer. Only selected incoming connections are accepted.</description>
        <interfaces t="list">
          <interface>eth0</interface>
          <interface>eth1</interface>
        </interfaces>
        <masquerade t="boolean">false</masquerade>
        <name>public</name>
        <ports t="list"/>
        <protocols t="list"/>
        <services t="list">
          <service>dhcpv6-client</service>
          <service>ssh</service>
        </services>
        <short>Public</short>
        <target>default</target>
      </zone>
      <zone t="map">
        <description>All network connections are accepted.</description>
        <interfaces t="list"/>
        <masquerade t="boolean">false</masquerade>
        <name>trusted</name>
        <ports t="list"/>
        <protocols t="list"/>
        <services t="list"/>
        <short>Trusted</short>
        <target>ACCEPT</target>
      </zone>
      <zone t="map">
        <description>For use in work areas. You mostly trust the other computers on networks to not harm your computer. Only selected incoming connections are accepted.</description>
        <interfaces t="list"/>
        <masquerade t="boolean">false</masquerade>
        <name>work</name>
        <ports t="list"/>
        <protocols t="list"/>
        <services t="list">
          <service>dhcpv6-client</service>
          <service>ssh</service>
        </services>
        <short>Work</short>
        <target>default</target>
      </zone>
    </zones>
  </firewall>
  <general t="map">
    <mode t="map">
      <confirm t="boolean">false</confirm>
    </mode>
  </general>
  <groups t="list">
    <group t="map">
      <gid>100</gid>
      <groupname>users</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>62</gid>
      <groupname>man</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>479</gid>
      <groupname>chrony</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>42</gid>
      <groupname>trusted</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>492</gid>
      <groupname>utmp</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>2</gid>
      <groupname>daemon</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>15</gid>
      <groupname>shadow</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>481</gid>
      <groupname>srvGeoClue</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>477</gid>
      <groupname>systemd-network</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>476</gid>
      <groupname>systemd-timesync</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>59</gid>
      <groupname>maildrop</groupname>
      <userlist>postfix</userlist>
    </group>
    <group t="map">
      <gid>478</gid>
      <groupname>systemd-journal</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>471</gid>
      <groupname>vboxguest</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>484</gid>
      <groupname>tape</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>473</gid>
      <groupname>nscd</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>36</gid>
      <groupname>kvm</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>71</gid>
      <groupname>ntadmin</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>472</gid>
      <groupname>sshd</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>474</gid>
      <groupname>rtkit</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>487</gid>
      <groupname>input</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>469</gid>
      <groupname>vboxvideo</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>480</gid>
      <groupname>dnsmasq</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>485</gid>
      <groupname>sgx</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>1</gid>
      <groupname>bin</groupname>
      <userlist>daemon</userlist>
    </group>
    <group t="map">
      <gid>488</gid>
      <groupname>disk</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>0</gid>
      <groupname>root</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>499</gid>
      <groupname>messagebus</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>496</gid>
      <groupname>lp</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>498</gid>
      <groupname>tftp</groupname>
      <userlist>dnsmasq</userlist>
    </group>
    <group t="map">
      <gid>65533</gid>
      <groupname>nogroup</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>470</gid>
      <groupname>vboxsf</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>5</gid>
      <groupname>tty</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>65534</gid>
      <groupname>nobody</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>493</gid>
      <groupname>lock</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>486</gid>
      <groupname>render</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>483</gid>
      <groupname>video</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>490</gid>
      <groupname>cdrom</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>491</gid>
      <groupname>audio</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>475</gid>
      <groupname>polkitd</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>495</gid>
      <groupname>wheel</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>494</gid>
      <groupname>kmem</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>482</gid>
      <groupname>audit</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>497</gid>
      <groupname>mail</groupname>
      <userlist>postfix</userlist>
    </group>
    <group t="map">
      <gid>51</gid>
      <groupname>postfix</groupname>
      <userlist/>
    </group>
    <group t="map">
      <gid>489</gid>
      <groupname>dialout</groupname>
      <userlist/>
    </group>
  </groups>
  <host t="map">
    <hosts t="list">
      <hosts_entry t="map">
        <host_address>127.0.0.1</host_address>
        <names t="list">
          <name>$CRR_hostname</name>
        </names>
      </hosts_entry>
      <hosts_entry t="map">
        <host_address>::1</host_address>
        <names t="list">
          <name>$CRR_hostname ipv6-$CRR_hostname ipv6-loopback</name>
        </names>
      </hosts_entry>
      <hosts_entry t="map">
        <host_address>fe00::0</host_address>
        <names t="list">
          <name>ipv6-localnet</name>
        </names>
      </hosts_entry>
      <hosts_entry t="map">
        <host_address>ff00::0</host_address>
        <names t="list">
          <name>ipv6-mcastprefix</name>
        </names>
      </hosts_entry>
      <hosts_entry t="map">
        <host_address>ff02::1</host_address>
        <names t="list">
          <name>ipv6-allnodes</name>
        </names>
      </hosts_entry>
      <hosts_entry t="map">
        <host_address>ff02::2</host_address>
        <names t="list">
          <name>ipv6-allrouters</name>
        </names>
      </hosts_entry>
      <hosts_entry t="map">
        <host_address>ff02::3</host_address>
        <names t="list">
          <name>ipv6-allhosts</name>
        </names>
      </hosts_entry>
    </hosts>
  </host>
  <networking t="map">
    <dhcp_options t="map">
      <dhclient_client_id/>
      <dhclient_hostname_option>AUTO</dhclient_hostname_option>
    </dhcp_options>
    <dns t="map">
      <dhcp_hostname t="boolean">false</dhcp_hostname>
      <hostname>$CRR_hostname</hostname>
      <resolv_conf_policy>auto</resolv_conf_policy>
    </dns>
    <interfaces t="list">
      <interface t="map">
        <bootproto>dhcp</bootproto>
        <name>eth0</name>
        <startmode>auto</startmode>
        <zone>public</zone>
      </interface>
      <interface t="map">
        <bootproto>dhcp</bootproto>
        <ifplugd_priority>0</ifplugd_priority>
        <name>eth1</name>
        <startmode>ifplugd</startmode>
        <zone>public</zone>
      </interface>
    </interfaces>
    <ipv6 t="boolean">true</ipv6>
    <keep_install_network t="boolean">true</keep_install_network>
    <managed t="boolean">false</managed>
    <net-udev t="list">
      <rule t="map">
        <name>eth1</name>
        <rule>ATTR{address}</rule>
        <value>08:00:27:33:dc:5a</value>
      </rule>
      <rule t="map">
        <name>eth0</name>
        <rule>ATTR{address}</rule>
        <value>08:00:27:38:3b:2a</value>
      </rule>
    </net-udev>
    <routing t="map">
      <ipv4_forward t="boolean">false</ipv4_forward>
      <ipv6_forward t="boolean">false</ipv6_forward>
    </routing>
  </networking>
  <ntp-client t="map">
    <ntp_policy>auto</ntp_policy>
    <ntp_servers t="list"/>
    <ntp_sync>systemd</ntp_sync>
  </ntp-client>
  <partitioning t="list">
    <drive t="map">
      <device>/dev/sda</device>
      <disklabel>gpt</disklabel>
      <enable_snapshots t="boolean">true</enable_snapshots>
      <partitions t="list">
        <partition t="map">
          <create t="boolean">true</create>
          <format t="boolean">false</format>
          <partition_id t="integer">263</partition_id>
          <partition_nr t="integer">1</partition_nr>
          <resize t="boolean">false</resize>
          <size>8388608</size>
        </partition>
        <partition t="map">
          <create t="boolean">true</create>
          <create_subvolumes t="boolean">true</create_subvolumes>
          <filesystem t="symbol">btrfs</filesystem>
          <format t="boolean">true</format>
          <mount>/</mount>
          <mountby t="symbol">uuid</mountby>
          <partition_id t="integer">131</partition_id>
          <partition_nr t="integer">2</partition_nr>
          <quotas t="boolean">true</quotas>
          <resize t="boolean">false</resize>
          <size>64950894592</size>
          <subvolumes t="list">
            <subvolume t="map">
              <copy_on_write t="boolean">false</copy_on_write>
              <path>var</path>
            </subvolume>
            <subvolume t="map">
              <copy_on_write t="boolean">true</copy_on_write>
              <path>usr/local</path>
            </subvolume>
            <subvolume t="map">
              <copy_on_write t="boolean">true</copy_on_write>
              <path>tmp</path>
            </subvolume>
            <subvolume t="map">
              <copy_on_write t="boolean">true</copy_on_write>
              <path>srv</path>
            </subvolume>
            <subvolume t="map">
              <copy_on_write t="boolean">true</copy_on_write>
              <path>root</path>
            </subvolume>
            <subvolume t="map">
              <copy_on_write t="boolean">true</copy_on_write>
              <path>opt</path>
            </subvolume>
            <subvolume t="map">
              <copy_on_write t="boolean">true</copy_on_write>
              <path>home</path>
            </subvolume>
            <subvolume t="map">
              <copy_on_write t="boolean">true</copy_on_write>
              <path>boot/grub2/x86_64-efi</path>
            </subvolume>
            <subvolume t="map">
              <copy_on_write t="boolean">true</copy_on_write>
              <path>boot/grub2/i386-pc</path>
            </subvolume>
          </subvolumes>
          <subvolumes_prefix>@</subvolumes_prefix>
        </partition>
        <partition t="map">
          <create t="boolean">true</create>
          <filesystem t="symbol">swap</filesystem>
          <format t="boolean">true</format>
          <mount>swap</mount>
          <mountby t="symbol">uuid</mountby>
          <partition_id t="integer">130</partition_id>
          <partition_nr t="integer">3</partition_nr>
          <resize t="boolean">false</resize>
          <size>2148515328</size>
        </partition>
      </partitions>
      <type t="symbol">CT_DISK</type>
      <use>all</use>
    </drive>
  </partitioning>
  <proxy t="map">
    <enabled t="boolean">false</enabled>
  </proxy>
  <services-manager t="map">
    <default_target>multi-user</default_target>
    <services t="map">
      <enable t="list">
        <service>ModemManager</service>
        <service>YaST2-Firstboot</service>
        <service>YaST2-Second-Stage</service>
        <service>apparmor</service>
        <service>auditd</service>
        <service>klog</service>
        <service>chronyd</service>
        <service>cron</service>
        <service>cups</service>
        <service>firewalld</service>
        <service>wickedd-auto4</service>
        <service>wickedd-dhcp4</service>
        <service>wickedd-dhcp6</service>
        <service>wickedd-nanny</service>
        <service>irqbalance</service>
        <service>issue-generator</service>
        <service>kbdsettings</service>
        <service>lvm2-monitor</service>
        <service>mcelog</service>
        <service>wicked</service>
        <service>nscd</service>
        <service>postfix</service>
        <service>purge-kernels</service>
        <service>rsyslog</service>
        <service>smartd</service>
        <service>sshd</service>
        <service>systemd-pstore</service>
        <service>systemd-remount-fs</service>
        <service>vgauthd</service>
        <service>vmtoolsd</service>
      </enable>
    </services>
  </services-manager>
  <software t="map">
    <install_recommended t="boolean">true</install_recommended>
    <instsource/>
    <packages t="list">
      <package>wicked</package>
      <package>snapper</package>
      <package>os-prober</package>
      <package>openssh</package>
      <package>openSUSE-release</package>
      <package>kexec-tools</package>
      <package>grub2</package>
      <package>glibc</package>
      <package>firewalld</package>
      <package>e2fsprogs</package>
      <package>chrony</package>
      <package>btrfsprogs</package>
      <package>autoyast2</package>
    </packages>
    <patterns t="list">
      <pattern>apparmor</pattern>
      <pattern>base</pattern>
      <pattern>documentation</pattern>
      <pattern>enhanced_base</pattern>
      <pattern>laptop</pattern>
      <pattern>minimal_base</pattern>
      <pattern>sw_management</pattern>
      <pattern>yast2_basis</pattern>
    </patterns>
    <products t="list">
      <product>Leap</product>
    </products>
  </software>
  <ssh_import t="map">
    <copy_config t="boolean">false</copy_config>
    <import t="boolean">false</import>
  </ssh_import>
  <timezone t="map">
    <timezone>Australia/Brisbane</timezone>
  </timezone>
  <user_defaults t="map">
    <expire/>
    <group>100</group>
    <home>/home</home>
    <inactive>-1</inactive>
    <shell>/bin/bash</shell>
    <umask>022</umask>
  </user_defaults>
  <users t="list">
    <user t="map">
      <authorized_keys t="list"/>
      <encrypted t="boolean">true</encrypted>
      <fullname>$CRR_remote_admin</fullname>
      <gid>100</gid>
      <home>/home/$CRR_remote_admin</home>
      <home_btrfs_subvolume t="boolean">false</home_btrfs_subvolume>
      <password_settings t="map">
        <expire/>
        <flag/>
        <inact/>
        <max>99999</max>
        <min>0</min>
        <warn>7</warn>
      </password_settings>
      <shell>/bin/bash</shell>
      <uid>1000</uid>
      <user_password>$ROOT_PW_IC</user_password>
      <username>$CRR_remote_admin</username>
    </user>
    <user t="map">
      <encrypted t="boolean">true</encrypted>
      <fullname>systemd Network Management</fullname>
      <gid>477</gid>
      <home>/</home>
      <home_btrfs_subvolume t="boolean">false</home_btrfs_subvolume>
      <password_settings t="map">
        <expire/>
        <flag/>
        <inact/>
        <max/>
        <min/>
        <warn/>
      </password_settings>
      <shell>/usr/sbin/nologin</shell>
      <uid>477</uid>
      <user_password>!*</user_password>
      <username>systemd-network</username>
    </user>
    <user t="map">
      <encrypted t="boolean">true</encrypted>
      <fullname>Printing daemon</fullname>
      <gid>496</gid>
      <home>/var/spool/lpd</home>
      <home_btrfs_subvolume t="boolean">false</home_btrfs_subvolume>
      <password_settings t="map">
        <expire/>
        <flag/>
        <inact/>
        <max/>
        <min/>
        <warn/>
      </password_settings>
      <shell>/usr/sbin/nologin</shell>
      <uid>496</uid>
      <user_password>!</user_password>
      <username>lp</username>
    </user>
    <user t="map">
      <encrypted t="boolean">true</encrypted>
      <fullname>User for GeoClue D-Bus service</fullname>
      <gid>481</gid>
      <home>/var/lib/srvGeoClue</home>
      <home_btrfs_subvolume t="boolean">false</home_btrfs_subvolume>
      <password_settings t="map">
        <expire/>
        <flag/>
        <inact/>
        <max/>
        <min/>
        <warn/>
      </password_settings>
      <shell>/usr/sbin/nologin</shell>
      <uid>495</uid>
      <user_password>!</user_password>
      <username>srvGeoClue</username>
    </user>
    <user t="map">
      <encrypted t="boolean">true</encrypted>
      <fullname>nobody</fullname>
      <gid>65534</gid>
      <home>/var/lib/nobody</home>
      <home_btrfs_subvolume t="boolean">false</home_btrfs_subvolume>
      <password_settings t="map">
        <expire/>
        <flag/>
        <inact/>
        <max/>
        <min/>
        <warn/>
      </password_settings>
      <shell>/bin/bash</shell>
      <uid>65534</uid>
      <user_password>!</user_password>
      <username>nobody</username>
    </user>
    <user t="map">
      <encrypted t="boolean">true</encrypted>
      <fullname>systemd Time Synchronization</fullname>
      <gid>476</gid>
      <home>/</home>
      <home_btrfs_subvolume t="boolean">false</home_btrfs_subvolume>
      <password_settings t="map">
        <expire/>
        <flag/>
        <inact/>
        <max/>
        <min/>
        <warn/>
      </password_settings>
      <shell>/usr/sbin/nologin</shell>
      <uid>476</uid>
      <user_password>!*</user_password>
      <username>systemd-timesync</username>
    </user>
    <user t="map">
      <encrypted t="boolean">true</encrypted>
      <fullname>user for rpcbind</fullname>
      <gid>65534</gid>
      <home>/var/lib/empty</home>
      <home_btrfs_subvolume t="boolean">false</home_btrfs_subvolume>
      <password_settings t="map">
        <expire/>
        <flag/>
        <inact/>
        <max/>
        <min/>
        <warn/>
      </password_settings>
      <shell>/sbin/nologin</shell>
      <uid>471</uid>
      <user_password>!</user_password>
      <username>rpc</username>
    </user>
    <user t="map">
      <encrypted t="boolean">true</encrypted>
      <fullname>TFTP Account</fullname>
      <gid>498</gid>
      <home>/srv/tftpboot</home>
      <home_btrfs_subvolume t="boolean">false</home_btrfs_subvolume>
      <password_settings t="map">
        <expire/>
        <flag/>
        <inact/>
        <max/>
        <min/>
        <warn/>
      </password_settings>
      <shell>/usr/sbin/nologin</shell>
      <uid>498</uid>
      <user_password>!</user_password>
      <username>tftp</username>
    </user>
    <user t="map">
      <encrypted t="boolean">true</encrypted>
      <fullname>SSH daemon</fullname>
      <gid>472</gid>
      <home>/var/lib/sshd</home>
      <home_btrfs_subvolume t="boolean">false</home_btrfs_subvolume>
      <password_settings t="map">
        <expire/>
        <flag/>
        <inact/>
        <max/>
        <min/>
        <warn/>
      </password_settings>
      <shell>/usr/sbin/nologin</shell>
      <uid>472</uid>
      <user_password>!</user_password>
      <username>sshd</username>
    </user>
    <user t="map">
      <encrypted t="boolean">true</encrypted>
      <fullname>RealtimeKit</fullname>
      <gid>474</gid>
      <home>/proc</home>
      <home_btrfs_subvolume t="boolean">false</home_btrfs_subvolume>
      <password_settings t="map">
        <expire/>
        <flag/>
        <inact/>
        <max/>
        <min/>
        <warn/>
      </password_settings>
      <shell>/bin/false</shell>
      <uid>474</uid>
      <user_password>!</user_password>
      <username>rtkit</username>
    </user>
    <user t="map">
      <encrypted t="boolean">true</encrypted>
      <fullname>Chrony Daemon</fullname>
      <gid>479</gid>
      <home>/var/lib/chrony</home>
      <home_btrfs_subvolume t="boolean">false</home_btrfs_subvolume>
      <password_settings t="map">
        <expire/>
        <flag/>
        <inact/>
        <max/>
        <min/>
        <warn/>
      </password_settings>
      <shell>/usr/sbin/nologin</shell>
      <uid>493</uid>
      <user_password>!</user_password>
      <username>chrony</username>
    </user>
    <user t="map">
      <encrypted t="boolean">true</encrypted>
      <fullname>Manual pages viewer</fullname>
      <gid>62</gid>
      <home>/var/lib/empty</home>
      <home_btrfs_subvolume t="boolean">false</home_btrfs_subvolume>
      <password_settings t="map">
        <expire/>
        <flag/>
        <inact/>
        <max/>
        <min/>
        <warn/>
      </password_settings>
      <shell>/usr/sbin/nologin</shell>
      <uid>13</uid>
      <user_password>!</user_password>
      <username>man</username>
    </user>
    <user t="map">
      <encrypted t="boolean">true</encrypted>
      <fullname>NFS statd daemon</fullname>
      <gid>65533</gid>
      <home>/var/lib/nfs</home>
      <home_btrfs_subvolume t="boolean">false</home_btrfs_subvolume>
      <password_settings t="map">
        <expire/>
        <flag/>
        <inact/>
        <max/>
        <min/>
        <warn/>
      </password_settings>
      <shell>/sbin/nologin</shell>
      <uid>470</uid>
      <user_password>!</user_password>
      <username>statd</username>
    </user>
    <user t="map">
      <encrypted t="boolean">true</encrypted>
      <fullname>Daemon</fullname>
      <gid>2</gid>
      <home>/sbin</home>
      <home_btrfs_subvolume t="boolean">false</home_btrfs_subvolume>
      <password_settings t="map">
        <expire/>
        <flag/>
        <inact/>
        <max/>
        <min/>
        <warn/>
      </password_settings>
      <shell>/usr/sbin/nologin</shell>
      <uid>2</uid>
      <user_password>!</user_password>
      <username>daemon</username>
    </user>
    <user t="map">
      <authorized_keys t="list"/>
      <encrypted t="boolean">true</encrypted>
      <fullname>root</fullname>
      <gid>0</gid>
      <home>/root</home>
      <home_btrfs_subvolume t="boolean">false</home_btrfs_subvolume>
      <password_settings t="map">
        <expire/>
        <flag/>
        <inact/>
        <max/>
        <min/>
        <warn/>
      </password_settings>
      <shell>/bin/bash</shell>
      <uid>0</uid>
      <user_password>$ROOT_PW_IC</user_password>
      <username>root</username>
    </user>
    <user t="map">
      <encrypted t="boolean">true</encrypted>
      <fullname>bin</fullname>
      <gid>1</gid>
      <home>/bin</home>
      <home_btrfs_subvolume t="boolean">false</home_btrfs_subvolume>
      <password_settings t="map">
        <expire/>
        <flag/>
        <inact/>
        <max/>
        <min/>
        <warn/>
      </password_settings>
      <shell>/usr/sbin/nologin</shell>
      <uid>1</uid>
      <user_password>!</user_password>
      <username>bin</username>
    </user>
    <user t="map">
      <encrypted t="boolean">true</encrypted>
      <fullname>dnsmasq</fullname>
      <gid>480</gid>
      <home>/var/lib/empty</home>
      <home_btrfs_subvolume t="boolean">false</home_btrfs_subvolume>
      <password_settings t="map">
        <expire/>
        <flag/>
        <inact/>
        <max/>
        <min/>
        <warn/>
      </password_settings>
      <shell>/usr/sbin/nologin</shell>
      <uid>494</uid>
      <user_password>!</user_password>
      <username>dnsmasq</username>
    </user>
    <user t="map">
      <encrypted t="boolean">true</encrypted>
      <fullname>User for D-Bus</fullname>
      <gid>499</gid>
      <home>/run/dbus</home>
      <home_btrfs_subvolume t="boolean">false</home_btrfs_subvolume>
      <password_settings t="map">
        <expire/>
        <flag/>
        <inact/>
        <max/>
        <min/>
        <warn/>
      </password_settings>
      <shell>/usr/bin/false</shell>
      <uid>499</uid>
      <user_password>!</user_password>
      <username>messagebus</username>
    </user>
    <user t="map">
      <encrypted t="boolean">true</encrypted>
      <fullname>User for nscd</fullname>
      <gid>473</gid>
      <home>/run/nscd</home>
      <home_btrfs_subvolume t="boolean">false</home_btrfs_subvolume>
      <password_settings t="map">
        <expire/>
        <flag/>
        <inact/>
        <max/>
        <min/>
        <warn/>
      </password_settings>
      <shell>/sbin/nologin</shell>
      <uid>473</uid>
      <user_password>!</user_password>
      <username>nscd</username>
    </user>
    <user t="map">
      <encrypted t="boolean">true</encrypted>
      <fullname>Postfix Daemon</fullname>
      <gid>51</gid>
      <home>/var/spool/postfix</home>
      <home_btrfs_subvolume t="boolean">false</home_btrfs_subvolume>
      <password_settings t="map">
        <expire/>
        <flag/>
        <inact/>
        <max/>
        <min/>
        <warn/>
      </password_settings>
      <shell>/usr/sbin/nologin</shell>
      <uid>51</uid>
      <user_password>!</user_password>
      <username>postfix</username>
    </user>
    <user t="map">
      <encrypted t="boolean">true</encrypted>
      <fullname>Mailer daemon</fullname>
      <gid>497</gid>
      <home>/var/spool/clientmqueue</home>
      <home_btrfs_subvolume t="boolean">false</home_btrfs_subvolume>
      <password_settings t="map">
        <expire/>
        <flag/>
        <inact/>
        <max/>
        <min/>
        <warn/>
      </password_settings>
      <shell>/usr/sbin/nologin</shell>
      <uid>497</uid>
      <user_password>!</user_password>
      <username>mail</username>
    </user>
    <user t="map">
      <encrypted t="boolean">true</encrypted>
      <fullname>User for polkitd</fullname>
      <gid>475</gid>
      <home>/var/lib/polkit</home>
      <home_btrfs_subvolume t="boolean">false</home_btrfs_subvolume>
      <password_settings t="map">
        <expire/>
        <flag/>
        <inact/>
        <max/>
        <min/>
        <warn/>
      </password_settings>
      <shell>/usr/sbin/nologin</shell>
      <uid>475</uid>
      <user_password>!</user_password>
      <username>polkitd</username>
    </user>
  </users>
  <scripts>
    <chroot-scripts config:type="list">
        <script>
        <chrooted config:type="boolean">true</chrooted>
        <filename>add_ssh_key.sh</filename>
        <interpreter>shell</interpreter>
        <source>
            <![CDATA[
            #!/bin/sh
            mkdir -p /root/.ssh
            chmod 700 /root/.ssh
            echo '`get_CRR_PUBKEY`' >> /root/.ssh/authorized_keys
            chmod 600 /root/.ssh/authorized_keys
            chown root:root /root/.ssh/authorized_keys
            ]]>
        </source>
        </script>
    </chroot-scripts>
  </scripts>

</profile>
EOF

# addons available online..
cat << EOF > /dev/null
<profile xmlns="http://www.suse.com/1.0/yast2ns" xmlns:config="http://www.suse.com/1.0/configns">
  <add-on t="map">
    <add_on_others t="list">
      <listentry t="map">
        <alias>repo-backports-update</alias>
        <media_url>http://download.opensuse.org/update/leap/15.5/backports/</media_url>
        <name>Update repository of openSUSE Backports</name>
        <priority t="integer">99</priority>
        <product_dir>/</product_dir>
      </listentry>
      <listentry t="map">
        <alias>repo-non-oss</alias>
        <media_url>http://download.opensuse.org/distribution/leap/15.5/repo/non-oss/</media_url>
        <name>Non-OSS Repository</name>
        <priority t="integer">99</priority>
        <product_dir>/</product_dir>
      </listentry>
      <listentry t="map">
        <alias>repo-openh264</alias>
        <media_url>http://codecs.opensuse.org/openh264/openSUSE_Leap/</media_url>
        <name>Open H.264 Codec (openSUSE Leap)</name>
        <priority t="integer">99</priority>
        <product_dir/>
      </listentry>
      <listentry t="map">
        <alias>repo-sle-update</alias>
        <media_url>http://download.opensuse.org/update/leap/15.5/sle/</media_url>
        <name>Update repository with updates from SUSE Linux Enterprise 15</name>
        <priority t="integer">99</priority>
        <product_dir>/</product_dir>
      </listentry>
      <listentry t="map">
        <alias>repo-update</alias>
        <media_url>http://download.opensuse.org/update/leap/15.5/oss</media_url>
        <name>Main Update Repository</name>
        <priority t="integer">99</priority>
        <product_dir>/</product_dir>
      </listentry>
      <listentry t="map">
        <alias>repo-update-non-oss</alias>
        <media_url>http://download.opensuse.org/update/leap/15.5/non-oss/</media_url>
        <name>Update Repository (Non-Oss)</name>
        <priority t="integer">99</priority>
        <product_dir>/</product_dir>
      </listentry>
    </add_on_others>
  </add-on>
EOF
}

HELP_create_install_script="$TODO"
create_install_script (){
    gen_pw
    case "$CRR_OS" in
        (rhel-x86_64|rocky-x86_64|centos-x86_64|rhel-like-x86_64)
            CRR_kickstart_Installer="$TMP_WORKDIR_prep_iso/ks.cfg" # kickstart
            create_kickstart
        ;;
        (opensuse-x86_64) # AutoYaST
            CRR_autoyast_Installer="$TMP_WORKDIR_prep_iso/autoinst.xml" # kickstart
            create_autoyast
        ;;
        (debian-amd64|debian-like-amd64)
            CRR_preseed_Installer="$TMP_WORKDIR_prep_iso/preseed.cfg" # preseed
            #ASSERT chmod u+w "$CRR_preseed_Installer"
            create_preseed

        # update the checksum .. ubuntu only?
            #CRR_MD5SUM="$TMP_WORKDIR_prep_iso/md5sum.txt"
            #md5sum="$(md5sum $CRR_preseed_Installer | sed "s/  *[^ ]*//")"
            #TRACE sed -i.debut "/preseed.[a-z]*.seed/s/^[^ ]*  */$md5sum /" "$CRR_MD5SUM"
        ;;
        (ubuntu-amd64|ubuntu-like-amd64)
        # https://ubuntu.com/server/docs/install/autoinstall
            #CRR_autoinstall_Installer="$TMP_WORKDIR_prep_iso/autoinstall.yaml"
            CRR_autoinstall_Installer="$TMP_WORKDIR_prep_iso/user-data"
            # https://ubuntu.com/server/docs/install/autoinstall-quickstart
            TRACE touch "$TMP_WORKDIR_prep_iso/meta-data"
            CRR_ISO_LABEL="CIDATA"
            create_autoinstall
        ;;
        (QQQdebian-amd64|QQQubuntu-amd64|QQQdebian-like-amd64)
            case autoinstall in
                (preseed) # ToDo/dud
                    CRR_preseed_Installer="$TMP_WORKDIR_prep_iso/preseed/ubuntu.seed" # preseed
                    ASSERT chmod u+w "$CRR_preseed_Installer"
                    create_preseed

                # update the checksum
                    CRR_MD5SUM="$TMP_WORKDIR_prep_iso/md5sum.txt"
                    md5sum="$(md5sum $CRR_preseed_Installer | sed "s/  *[^ ]*//")"
                    TRACE sed -i.debut "/preseed.ubuntu.seed/s/^[^ ]*  */$md5sum /" "$CRR_MD5SUM"
                ;;
                (autoinstall) # https://ubuntu.com/server/docs/install/autoinstall
                    #CRR_autoinstall_Installer="$TMP_WORKDIR_prep_iso/autoinstall.yaml"
                    CRR_autoinstall_Installer="$TMP_WORKDIR_prep_iso/user-data"
                    # https://ubuntu.com/server/docs/install/autoinstall-quickstart
                    TRACE touch "$TMP_WORKDIR_prep_iso/meta-data"
                    CRR_ISO_LABEL="CIDATA"
                    create_autoinstall
                ;;
                (*)echo Huh... _Installer;;
            esac
            true
        ;;
        (fedora-x86_64)
            CRR_kickstart_Installer="$TMP_WORKDIR_prep_iso/ks.cfg" # kickstart
            create_kickstart
        ;;
        (freebsd-amd64)
            true # ToDo - a shell script maybe?
        ;;
        (*)echo Huh: "$CRR_OS"; RAISE;;
    esac
    true
}

HELP_modify_boot_menu=""$TODO""
modify_boot_menu (){

    case "$CRR_OS" in
        (rhel-x86_64|rocky-x86_64|centos-x86_64|rhel-like-x86_64)
            modify_kickstart_grub_isolinux_cfg
        ;;
        (opensuse-x86_64)
            modify_autoyast_grub_cfg
        ;;
        (fedora-x86_64)
            modify_kickstart_grub2_cfg
        ;;
        (debian-amd64|debian-like-amd64)
            modify_preseed_grub2_cfg
        ;;
        (ubuntu-amd64|ubuntu-like-amd64)
            modify_autoinstall_grub_cfg
        ;;
        (freebsd-amd64)
            true # ToDo - need to disable/replace boot/install script.
        ;;
    esac
}


HELP_modify_autoyast_grub_cfg=""$TODO""
modify_autoyast_grub_cfg (){ # AutoYaST on opensuse
    FROM1="linux$WS.boot.x86_64.loader.linux$WS""splash=silent$WS0\$"
    TO1="linux?efi? /boot/x86_64/loader/linux splash=silent"
    TO1="linux \\/boot\\/x86_64\\/loader\\/linux autoyast=file:\\/\\/\\/autoinst.xml "
    FROM2="^$WS""timeout=[1-9][0-9]*"
    TO2="  timeout=6"
    FROM3="'Installation'"
    TO3="'Installation autoyast=file:\\/\\/\\/autoinst.xml'"

    TRACE chmod u+w "$TMP_WORKDIR_prep_iso/EFI/BOOT"
    TRACE sed -i.debut "s/$FROM1/$TO1/;s/$FROM2/$TO2/;s/$FROM3/$TO3/;" "$TMP_WORKDIR_prep_iso/EFI/BOOT/grub.cfg"
    [ "$OPT_debug" ] && diff "$TMP_WORKDIR_prep_iso/EFI/BOOT/grub.cfg"{.debut,}

    FROM3="append initrd=initrd splash=silent showopts"
    TO3="append initrd=initrd splash=silent autoyast=file:\\/\\/\\/autoinst.xml showopts"

    TRACE chmod u+w "$TMP_WORKDIR_prep_iso/boot/x86_64/loader"
    TRACE sed -i.debut "s/$FROM3/$TO3/;" "$TMP_WORKDIR_prep_iso/boot/x86_64/loader/isolinux.cfg"
    [ "$OPT_debug" ] && diff "$TMP_WORKDIR_prep_iso/boot/x86_64/loader/isolinux.cfg"{.debut,}
    true
}

HELP_modify_kickstart_grub_isolinux_cfg=""$TODO""
modify_kickstart_grub_isolinux_cfg (){ # kick start on RHEL, Centos and Rocky
# Original RHEL9.3:
#label linux
#  menu label ^Install Red Hat Enterprise Linux 9.3
#  kernel vmlinuz
#  append initrd=initrd.img inst.stage2=hd:LABEL=RHEL-9-3-0-BaseOS-x86_64 quiet ks=cdrom:/ks.cfg
#label check
#  menu label Test this ^media & install Red Hat Enterprise Linux 9.3
#  menu default
#  kernel vmlinuz
#  append initrd=initrd.img inst.stage2=hd:LABEL=RHEL-9-3-0-BaseOS-x86_64 quiet ks=cdrom:/ks.cfg
    FROM="inst.stage2=hd:LABEL=RHEL-9-3-0-BaseOS-$CRR_machine quiet"
    FROM="inst.stage2=hd:LABEL=$CRR_ISO_LABEL quiet "
    FROM=" inst.stage2=hd:.* quiet *"
    TO=" "
    isolinux_grub_cfg="$TMP_WORKDIR_prep_iso/isolinux/isolinux.cfg"
    chmod u+w `dirname "$isolinux_grub_cfg"`
    sed -i.debut "
        s/$FROM/$TO/;
        s/$CRR_family/Custom &/g;
        /^ *menu default */d;
        s/^timeout [1-9][0-9]*/timeout 6/
        " "$isolinux_grub_cfg" || NOTE "$isolinux_grub_cfg"
    [ "$OPT_debug" ] && diff "$isolinux_grub_cfg"{.debut,}
# Rocky9.3:
#label linux
#  menu label ^Install Rocky Linux 9.3
#  kernel vmlinuz
#  append initrd=initrd.img inst.stage2=hd:LABEL=Rocky-9-3-x86_64-dvd quiet

#label check
#  menu label Test this ^media & install Rocky Linux 9.3
#  menu default
#  kernel vmlinuz
#  append initrd=initrd.img inst.stage2=hd:LABEL=Rocky-9-3-x86_64-dvd rd.live.check quiet

# as per RH doc:
#cat << EOF > "$isolinux_grub_cfg" || RAISE "$isolinux_grub_cfg"
#label linux
#  menu label ^Install or upgrade an existing system
#  menu default
#  kernel vmlinuz
#  append initrd=initrd.img
#EOF

# Add the ks= boot option to the line beginning with append. The exact
# syntax depends on how you plan to boot the ISO image; for example, if
# you plan on booting from a CD or DVD, use ks=cdrom:/ks.cfg. A list of
# possible sources and the syntax used to configure them is available in
# Section 28.4, “Automating the Installation with Kickstart”.

}

# https://docs.fedoraproject.org/en-US/fedora/f36/install-guide/advanced/Boot_Options/#sect-boot-options-kickstart
HELP_modify_kickstart_grub2_cfg=""$TODO""
modify_kickstart_grub2_cfg (){ # kickstart on fedora
# boot/grub2/grub.cfg
    #FROM="inst.stage2=hd:LABEL=RHEL-9-3-0-BaseOS-$CRR_machine quiet"
    #FROM="inst.stage2=hd:LABEL=$CRR_ISO_LABEL quiet "
    FROM="linux /images/pxeboot/vmlinuz inst.stage2=hd:LABEL=Fedora-E-dvd-x86_64-39 quiet"
    #FROM=" inst.stage2=hd:.* quiet *"
    FROM=" inst.stage2=hd:LABEL=[^ ]* "
#:-/TO=" inst.stage2=cdrom inst.repo=cdrom inst.ks=cdrom:\\/ks.cfg " # inst.repo=cdrom
#:-/TO=" inst.stage2=cdrom inst.ks=cdrom:\\/ks.cfg " # inst.repo=cdrom
#:- TO=" inst.stage2=hd:LABEL=$CRR_ISO_LABEL inst.ks=cdrom:\\/ks.cfg "
    CRR_ISO_LABEL=Fedora-E-dvd-x86_64-39
    TO=" inst.stage2=hd:LABEL=$CRR_ISO_LABEL inst.repo=cdrom inst.ks=cdrom:\\/ks.cfg "
    FROM2="^set timeout=[1-9][0-9]*"
    TO2="set timeout=6"
    FROM3='set default="1"'
    TO3='set default="0"'
    grub2_cfg="$TMP_WORKDIR_prep_iso/boot/grub2/grub.cfg"
    chmod u+w `dirname "$grub2_cfg"`
    sed -i.debut "
        s/$FROM/$TO/;
        s/$FROM2/$TO2/;
        s/$FROM3/$TO3/;
        s/$CRR_family/Custom &/g;
        /^ *menu default */d;
        " "$grub2_cfg" || NOTE "$grub2_cfg"
    [ "$OPT_debug" ] && diff "$grub2_cfg"{.debut,}
    true
}


HELP_modify_preseed_grub2_cfg0=""$TODO""
modify_preseed_grub2_cfg0 (){ # preseeder on debian
    #FROM1="^$WS""linux$WS\\/casper\\/vmlinuz$WS.*$WS0---"
    FROM1="^$WS""linux$WS\\/install.amd\\/vmlinuz$WS"
    #TO1="\\tlinux \\/casper\\/vmlinuz boot=casper autoinstall ds=nocloud-net;s=\\/cdrom\\/ ---"

    # ChatGPT: linux /install.amd/vmlinuz auto=true priority=critical preseed/file=/cdrom/preseed.cfg ---
    # https://serverfault.com/questions/976544/how-debians-preseed-install-work
    TO1="        linux    \\/install.amd\\/vmlinuz auto=true preseed\\/file=\\/cdrom\\/preseed.cfg "
    FROM2="^set timeout=[1-9][0-9]*" # probably not implemented
    TO2="set timeout=6"
    FROM3="'Install'"
    TO3="'Install custom'" # but this doesn't showup
    TRACE chmod u+w "$TMP_WORKDIR_prep_iso/boot/grub"
    TRACE sed -i.debut "s/$FROM1/$TO1/;s/$FROM2/$TO2/;s/$FROM3/$TO3/;" "$TMP_WORKDIR_prep_iso/boot/grub/grub.cfg"
    [ "$OPT_debug" ] && diff "$TMP_WORKDIR_prep_iso/boot/grub/grub.cfg"{.debut,}
}

HELP_modify_preseed_grub2_cfg=""$TODO""
modify_preseed_grub2_cfg (){ # preseeder on debian
    TRACE chmod u+w $TMP_WORKDIR_prep_iso/isolinux
    cfg_l="`grep -l "auto=true" $TMP_WORKDIR_prep_iso/isolinux/*.cfg`"
    for cfg in $cfg_l; do
        TRACE sed -i.debut "s/auto=true/auto=true preseed\\/file=\\/cdrom\\/preseed.cfg/;" $cfg
        [ "$OPT_debug" ] && diff "$cfg"{.debut,}
    done
    true
}

HELP_modify_autoinstall_grub_cfg=""$TODO""
modify_autoinstall_grub_cfg (){ # autoinst on Ubuntu
    FROM1="^$WS""linux$WS\\/casper\\/vmlinuz$WS.*$WS0---"
    TO1="\\tlinux \\/casper\\/vmlinuz boot=casper autoinstall ds=nocloud-net;s=\\/cdrom\\/ ---"
    FROM2="^set timeout=[1-9][0-9]*"
    TO2="set timeout=6"
    TRACE chmod u+w "$TMP_WORKDIR_prep_iso/boot/grub"
    TRACE sed -i.debut "s/$FROM1/$TO1/;s/$FROM2/$TO2/;" "$TMP_WORKDIR_prep_iso/boot/grub/grub.cfg"
    [ "$OPT_debug" ] && diff "$TMP_WORKDIR_prep_iso/boot/grub/grub.cfg"{.debut,}
    true
}


# https://www.debian.org/releases/stable/example-preseed.txt
# https://developer.hashicorp.com/packer/guides/automatic-operating-system-installs/preseed_ubuntu
HELP_create_preseed_almost="$TODO"
create_preseed_almost (){
cat << EOF > "$CRR_preseed_Installer"
# Root password (use an encrypted password)
d-i passwd/root-password-crypted password $ROOT_PW_IC

# Locale settings
d-i debian-installer/locale string en_US.UTF-8
d-i keyboard-configuration/xkb-keymap select us

# Network configuration
d-i netcfg/choose_interface select auto
d-i netcfg/get_hostname string $CRR_hostname
d-i netcfg/get_domain string localdomain

# Mirror settings
d-i mirror/country string manual
d-i mirror/http/hostname string us.archive.ubuntu.com
d-i mirror/http/directory string /ubuntu
d-i mirror/http/proxy string

# Account setup
#d-i passwd/user-fullname string Ubuntu User
#d-i passwd/username string ubuntu
#d-i passwd/user-password password securepassword
#d-i passwd/user-password-again password securepassword

# Clock and time zone setup
d-i clock-setup/utc boolean true
d-i time/zone string $CRR_timezone
d-i clock-setup/ntp boolean true

# Partitioning
d-i partman-auto/method string regular
d-i partman-auto/choose_recipe select atomic

# Boot loader installation
d-i grub-installer/only_debian boolean true
d-i grub-installer/with_other_os boolean true

# Package selection
tasksel tasksel/first multiselect openssh-server

# Finishing up the installation
d-i finish-install/reboot_in_progress note

# Disable CD-ROM from apt sources after installation
d-i apt-setup/cdrom boolean false

# Install the Ubuntu desktop.
#tasksel	tasksel/first	multiselect ubuntu-desktop
# On live DVDs, don't spend huge amounts of time removing substantial
# application packages pulled in by language packs. Given that we clearly
# have the space to include them on the DVD, they're useful and we might as
# well keep them installed.
#ubiquity	ubiquity/keep-installed	string icedtea6-plugin openoffice.org

EOF
}

# https://www.debian.org/releases/stable/example-preseed.txt
# https://developer.hashicorp.com/packer/guides/automatic-operating-system-installs/preseed_ubuntu
HELP_create_preseed="$TODO"
create_preseed (){
cat << EOF > "$CRR_preseed_Installer"
#_preseed_V1
#### Contents of the preconfiguration file (for bookworm)
### Localization
# Preseeding only locale sets language, country and locale.
d-i debian-installer/locale string en_US

# The values can also be preseeded individually for greater flexibility.
#d-i debian-installer/language string en
#d-i debian-installer/country string NL
#d-i debian-installer/locale string en_GB.UTF-8
# Optionally specify additional locales to be generated.
#d-i localechooser/supported-locales multiselect en_US.UTF-8, nl_NL.UTF-8

# Keyboard selection.
d-i keyboard-configuration/xkb-keymap select us
# d-i keyboard-configuration/toggle select No toggling

### Network configuration
# Disable network configuration entirely. This is useful for cdrom
# installations on non-networked devices where the network questions,
# warning and long timeouts are a nuisance.
#d-i netcfg/enable boolean false

# netcfg will choose an interface that has link if possible. This makes it
# skip displaying a list if there is more than one interface.
d-i netcfg/choose_interface select auto

# To pick a particular interface instead:
#d-i netcfg/choose_interface select eth1

# To set a different link detection timeout (default is 3 seconds).
# Values are interpreted as seconds.
#d-i netcfg/link_wait_timeout string 10

# If you have a slow dhcp server and the installer times out waiting for
# it, this might be useful.
#d-i netcfg/dhcp_timeout string 60
#d-i netcfg/dhcpv6_timeout string 60

# Automatic network configuration is the default.
# If you prefer to configure the network manually, uncomment this line and
# the static network configuration below.
#d-i netcfg/disable_autoconfig boolean true

# If you want the preconfiguration file to work on systems both with and
# without a dhcp server, uncomment these lines and the static network
# configuration below.
#d-i netcfg/dhcp_failed note
#d-i netcfg/dhcp_options select Configure network manually

# Static network configuration.
#
# IPv4 example
#d-i netcfg/get_ipaddress string 192.168.1.42
#d-i netcfg/get_netmask string 255.255.255.0
#d-i netcfg/get_gateway string 192.168.1.1
#d-i netcfg/get_nameservers string 192.168.1.1
#d-i netcfg/confirm_static boolean true
#
# IPv6 example
#d-i netcfg/get_ipaddress string fc00::2
#d-i netcfg/get_netmask string ffff:ffff:ffff:ffff::
#d-i netcfg/get_gateway string fc00::1
#d-i netcfg/get_nameservers string fc00::1
#d-i netcfg/confirm_static boolean true

# Any hostname and domain names assigned from dhcp take precedence over
# values set here. However, setting the values still prevents the questions
# from being shown, even if values come from dhcp.
d-i netcfg/get_hostname string $CRR_hostname
d-i netcfg/get_domain string unassigned-domain

# If you want to force a hostname, regardless of what either the DHCP
# server returns or what the reverse DNS entry for the IP is, uncomment
# and adjust the following line.
#d-i netcfg/hostname string somehost

# Disable that annoying WEP key dialog.
d-i netcfg/wireless_wep string
# The wacky dhcp hostname that some ISPs use as a password of sorts.
#d-i netcfg/dhcp_hostname string radish

# If you want to completely disable firmware lookup (i.e. not use firmware
# files or packages that might be available on installation images):
#d-i hw-detect/firmware-lookup string never

# If non-free firmware is needed for the network or other hardware, you can
# configure the installer to always try to load it, without prompting. Or
# change to false to disable asking.
#d-i hw-detect/load_firmware boolean true

### Network console
# Use the following settings if you wish to make use of the network-console
# component for remote installation over SSH. This only makes sense if you
# intend to perform the remainder of the installation manually.
#d-i anna/choose_modules string network-console
#d-i network-console/authorized_keys_url string http://10.0.0.1/openssh-key
#d-i network-console/password password r00tme
#d-i network-console/password-again password r00tme

### Mirror settings
# Mirror protocol:
# If you select ftp, the mirror/country string does not need to be set.
# Default value for the mirror protocol: http.
#d-i mirror/protocol string ftp
d-i mirror/country string manual
d-i mirror/http/hostname string http.us.debian.org
d-i mirror/http/directory string /debian
d-i mirror/http/proxy string

# Suite to install.
#d-i mirror/suite string testing
# Suite to use for loading installer components (optional).
#d-i mirror/udeb/suite string testing

### Account setup
# Skip creation of a root account (normal user account will be able to
# use sudo).
#d-i passwd/root-login boolean false
# Alternatively, to skip creation of a normal user account.
#d-i passwd/make-user boolean false

# Root password, either in clear text
#d-i passwd/root-password password r00tme
#d-i passwd/root-password-again password r00tme
# or encrypted using a crypt(3)  hash.
#d-i passwd/root-password-crypted password [crypt(3) hash]
d-i passwd/root-password-crypted password $ROOT_PW_IC

# To create a normal user account.
d-i passwd/user-fullname string $CRR_remote_admin User
d-i passwd/username string $CRR_remote_admin
# Normal user's password, either in clear text
#d-i passwd/user-password password insecure
#d-i passwd/user-password-again password insecure
# or encrypted using a crypt(3) hash.
#d-i passwd/user-password-crypted password [crypt(3) hash]
d-i passwd/user-password-crypted password $ROOT_PW_IC

# Create the first user with the specified UID instead of the default.
#d-i passwd/user-uid string 1010

# The user account will be added to some standard initial groups. To
# override that, use this.
#d-i passwd/user-default-groups string audio cdrom video

### Clock and time zone setup
# Controls whether or not the hardware clock is set to UTC.
d-i clock-setup/utc boolean true

# You may set this to any valid setting for \$TZ; see the contents of
# /usr/share/zoneinfo/ for valid values.
d-i time/zone string $CRR_timezone

# Controls whether to use NTP to set the clock during the install
d-i clock-setup/ntp boolean true
# NTP server to use. The default is almost always fine here.
#d-i clock-setup/ntp-server string ntp.example.com

### Partitioning
## Partitioning example
# If the system has free space you can choose to only partition that space.
# This is only honoured if partman-auto/method (below) is not set.
#d-i partman-auto/init_automatically_partition select biggest_free

# Alternatively, you may specify a disk to partition. If the system has only
# one disk the installer will default to using that, but otherwise the device
# name must be given in traditional, non-devfs format (so e.g. /dev/sda
# and not e.g. /dev/discs/disc0/disc).
# For example, to use the first SCSI/SATA hard disk:
#d-i partman-auto/disk string /dev/sda
# In addition, you'll need to specify the method to use.
# The presently available methods are:
# - regular: use the usual partition types for your architecture
# - lvm:     use LVM to partition the disk
# - crypto:  use LVM within an encrypted partition
d-i partman-auto/method string lvm

# You can define the amount of space that will be used for the LVM volume
# group. It can either be a size with its unit (eg. 20 GB), a percentage of
# free space or the 'max' keyword.
d-i partman-auto-lvm/guided_size string max

# If one of the disks that are going to be automatically partitioned
# contains an old LVM configuration, the user will normally receive a
# warning. This can be preseeded away...
d-i partman-lvm/device_remove_lvm boolean true
# The same applies to pre-existing software RAID array:
d-i partman-md/device_remove_md boolean true
# And the same goes for the confirmation to write the lvm partitions.
d-i partman-lvm/confirm boolean true
d-i partman-lvm/confirm_nooverwrite boolean true

# You can choose one of the three predefined partitioning recipes:
# - atomic: all files in one partition
# - home:   separate /home partition
# - multi:  separate /home, /var, and /tmp partitions
d-i partman-auto/choose_recipe select atomic

# Or provide a recipe of your own...
# If you have a way to get a recipe file into the d-i environment, you can
# just point at it.
#d-i partman-auto/expert_recipe_file string /hd-media/recipe

# If not, you can put an entire recipe into the preconfiguration file in one
# (logical) line. This example creates a small /boot partition, suitable
# swap, and uses the rest of the space for the root partition:
#d-i partman-auto/expert_recipe string                         \\
#      boot-root ::                                            \\
#              40 50 100 ext3                                  \\
#                      \$primary{ } \$bootable{ }                \\
#                      method{ format } format{ }              \\
#                      use_filesystem{ } filesystem{ ext3 }    \\
#                      mountpoint{ /boot }                     \\
#              .                                               \\
#              500 10000 1000000000 ext3                       \\
#                      method{ format } format{ }              \\
#                      use_filesystem{ } filesystem{ ext3 }    \\
#                      mountpoint{ / }                         \\
#              .                                               \\
#              64 512 300% linux-swap                          \\
#                      method{ swap } format{ }                \\
#              .

# The full recipe format is documented in the file partman-auto-recipe.txt
# included in the 'debian-installer' package or available from D-I source
# repository. This also documents how to specify settings such as file
# system labels, volume group names and which physical devices to include
# in a volume group.

## Partitioning for EFI
# If your system needs an EFI partition you could add something like
# this to the recipe above, as the first element in the recipe:
#               538 538 1075 free                              \\
#                      \$iflabel{ gpt }                         \\
#                      \$reusemethod{ }                         \\
#                      method{ efi }                           \\
#                      format{ }                               \\
#               .                                              \\
#
# The fragment above is for the amd64 architecture; the details may be
# different on other architectures. The 'partman-auto' package in the
# D-I source repository may have an example you can follow.

# This makes partman automatically partition without confirmation, provided
# that you told it what to do using one of the methods above.
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true

# Force UEFI booting ('BIOS compatibility' will be lost). Default: false.
#d-i partman-efi/non_efi_system boolean true
# Ensure the partition table is GPT - this is required for EFI
#d-i partman-partitioning/choose_label select gpt
#d-i partman-partitioning/default_label string gpt

# When disk encryption is enabled, skip wiping the partitions beforehand.
#d-i partman-auto-crypto/erase_disks boolean false

## Partitioning using RAID
# The method should be set to "raid".
#d-i partman-auto/method string raid
# Specify the disks to be partitioned. They will all get the same layout,
# so this will only work if the disks are the same size.
#d-i partman-auto/disk string /dev/sda /dev/sdb

# Next you need to specify the physical partitions that will be used.
#d-i partman-auto/expert_recipe string \\
#      multiraid ::                                         \\
#              1000 5000 4000 raid                          \\
#                      \$primary{ } method{ raid }           \\
#              .                                            \\
#              64 512 300% raid                             \\
#                      method{ raid }                       \\
#              .                                            \\
#              500 10000 1000000000 raid                    \\
#                      method{ raid }                       \\
#              .

# Last you need to specify how the previously defined partitions will be
# used in the RAID setup. Remember to use the correct partition numbers
# for logical partitions. RAID levels 0, 1, 5, 6 and 10 are supported;
# devices are separated using "#".
# Parameters are:
# <raidtype> <devcount> <sparecount> <fstype> <mountpoint> \\
#          <devices> <sparedevices>

#d-i partman-auto-raid/recipe string \\
#    1 2 0 ext3 /                    \\
#          /dev/sda1#/dev/sdb1       \\
#    .                               \\
#    1 2 0 swap -                    \\
#          /dev/sda5#/dev/sdb5       \\
#    .                               \\
#    0 2 0 ext3 /home                \\
#          /dev/sda6#/dev/sdb6       \\
#    .

# For additional information see the file partman-auto-raid-recipe.txt
# included in the 'debian-installer' package or available from D-I source
# repository.

# This makes partman automatically partition without confirmation.
d-i partman-md/confirm boolean true
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true

## Controlling how partitions are mounted
# The default is to mount by UUID, but you can also choose "traditional" to
# use traditional device names, or "label" to try filesystem labels before
# falling back to UUIDs.
#d-i partman/mount_style select uuid

### Base system installation
# Configure APT to not install recommended packages by default. Use of this
# option can result in an incomplete system and should only be used by very
# experienced users.
#d-i base-installer/install-recommends boolean false

# The kernel image (meta) package to be installed; "none" can be used if no
# kernel is to be installed.
#d-i base-installer/kernel/image string linux-image-686

### Apt setup
# Choose, if you want to scan additional installation media
# (default: false).
d-i apt-setup/cdrom/set-first boolean false
# You can choose to install non-free firmware.
#d-i apt-setup/non-free-firmware boolean true
# You can choose to install non-free and contrib software.
#d-i apt-setup/non-free boolean true
#d-i apt-setup/contrib boolean true
# Uncomment the following line, if you don't want to have the sources.list
# entry for a DVD/BD installation image active in the installed system
# (entries for netinst or CD images will be disabled anyway, regardless of
# this setting).
#d-i apt-setup/disable-cdrom-entries boolean true
# Uncomment this if you don't want to use a network mirror.
#d-i apt-setup/use_mirror boolean false
# Select which update services to use; define the mirrors to be used.
# Values shown below are the normal defaults.
#d-i apt-setup/services-select multiselect security, updates
#d-i apt-setup/security_host string security.debian.org

# Additional repositories, local[0-9] available
#d-i apt-setup/local0/repository string \\
#       http://local.server/debian stable main
#d-i apt-setup/local0/comment string local server
# Enable deb-src lines
#d-i apt-setup/local0/source boolean true
# URL to the public key of the local repository; you must provide a key or
# apt will complain about the unauthenticated repository and so the
# sources.list line will be left commented out.
#d-i apt-setup/local0/key string http://local.server/key
# or one can provide it in-line by base64 encoding the contents of the
# key file (with \`base64 -w0\`) and specifying it thus:
#d-i apt-setup/local0/key string base64://LS0tLS1CRUdJTiBQR1AgUFVCTElDIEtFWSBCTE9DSy0tLS0tCi4uLgo=
# The content of the key file is checked to see if it appears to be ASCII-armoured.
# If so it will be saved with an ".asc" extension, otherwise it gets a '.gpg' extension.
# "keybox database" format is currently not supported. (see generators/60local in apt-setup's source)

# By default the installer requires that repositories be authenticated
# using a known gpg key. This setting can be used to disable that
# authentication. Warning: Insecure, not recommended.
#d-i debian-installer/allow_unauthenticated boolean true

# Uncomment this to add multiarch configuration for i386
#d-i apt-setup/multiarch string i386


### Package selection
#tasksel tasksel/first multiselect standard, web-server, kde-desktop

# Or choose to not get the tasksel dialog displayed at all (and don't install
# any packages):
#d-i pkgsel/run_tasksel boolean false

# Individual additional packages to install
#d-i pkgsel/include string openssh-server build-essential
d-i pkgsel/include string openssh-server build-essential
# Whether to upgrade packages after debootstrap.
# Allowed values: none, safe-upgrade, full-upgrade
#d-i pkgsel/upgrade select none

# You can choose, if your system will report back on what software you have
# installed, and what software you use. The default is not to report back,
# but sending reports helps the project determine what software is most
# popular and should be included on the first CD/DVD.
#popularity-contest popularity-contest/participate boolean false

### Boot loader installation
# Grub is the boot loader (for x86).

# This is fairly safe to set, it makes grub install automatically to the UEFI
# partition/boot record if no other operating system is detected on the machine.
d-i grub-installer/only_debian boolean true

# This one makes grub-installer install to the UEFI partition/boot record, if
# it also finds some other OS, which is less safe as it might not be able to
# boot that other OS.
d-i grub-installer/with_other_os boolean true

# Due notably to potential USB sticks, the location of the primary drive can
# not be determined safely in general, so this needs to be specified:
#d-i grub-installer/bootdev  string /dev/sda
# To install to the primary device (assuming it is not a USB stick):
#d-i grub-installer/bootdev  string default

# Alternatively, if you want to install to a location other than the UEFI
# parition/boot record, uncomment and edit these lines:
#d-i grub-installer/only_debian boolean false
#d-i grub-installer/with_other_os boolean false
#d-i grub-installer/bootdev  string (hd0,1)
# To install grub to multiple disks:
#d-i grub-installer/bootdev  string (hd0,1) (hd1,1) (hd2,1)

# Optional password for grub, either in clear text
#d-i grub-installer/password password r00tme
#d-i grub-installer/password-again password r00tme
# or encrypted using an MD5 hash, see grub-md5-crypt(8).
#d-i grub-installer/password-crypted password [MD5 hash]

# Use the following option to add additional boot parameters for the
# installed system (if supported by the bootloader installer).
# Note: options passed to the installer will be added automatically.
#d-i debian-installer/add-kernel-opts string nousb

### Finishing up the installation
# During installations from serial console, the regular virtual consoles
# (VT1-VT6) are normally disabled in /etc/inittab. Uncomment the next
# line to prevent this.
#d-i finish-install/keep-consoles boolean true

# Avoid that last message about the install being complete.
d-i finish-install/reboot_in_progress note

# This will prevent the installer from ejecting the CD during the reboot,
# which is useful in some situations.
#d-i cdrom-detect/eject boolean false

# This is how to make the installer shutdown when finished, but not
# reboot into the installed system.
#d-i debian-installer/exit/halt boolean true
# This will power off the machine instead of just halting it.
#d-i debian-installer/exit/poweroff boolean true

### Preseeding other packages
# Depending on what software you choose to install, or if things go wrong
# during the installation process, it's possible that other questions may
# be asked. You can preseed those too, of course. To get a list of every
# possible question that could be asked during an install, do an
# installation, and then run these commands:
#   debconf-get-selections --installer > file
#   debconf-get-selections >> file


#### Advanced options
### Running custom commands during the installation
# d-i preseeding is inherently not secure. Nothing in the installer checks
# for attempts at buffer overflows or other exploits of the values of a
# preconfiguration file like this one. Only use preconfiguration files from
# trusted locations! To drive that home, and because it's generally useful,
# here's a way to run any shell command you'd like inside the installer,
# automatically.

# This first command is run as early as possible, just after
# preseeding is read.
#d-i preseed/early_command string anna-install some-udeb
# This command is run immediately before the partitioner starts. It may be
# useful to apply dynamic partitioner preseeding that depends on the state
# of the disks (which may not be visible when preseed/early_command runs).
#d-i partman/early_command \\
#       string debconf-set partman-auto/disk "\$(list-devices disk | head -n1)"
# This command is run just before the install finishes, but when there is
# still a usable /target directory. You can chroot to /target and use it
# directly, or use the apt-install and in-target commands to easily install
# packages and run commands in the target system.
#d-i preseed/late_command string apt-install zsh; in-target chsh -s /bin/zsh
d-i preseed/late_command string \\
    in-target mkdir -p /root/.ssh; \\
    in-target sh -c 'echo `get_CRR_PUBKEY` >> /root/.ssh/authorized_keys'; \\
    in-target chmod 600 /root/.ssh/authorized_keys; \\
    in-target chown root:root /root/.ssh/authorized_keys
EOF
    true
}

HELP_create_autoinstaller0="$TODO"
create_autoinstaller0 (){
    cat << EOF > "$CRR_autoinstall_Installer"
- description:
    en: This version has been customized to have a small runtime footprint in environments
      where humans are not expected to log in.
  id: ubuntu-server-minimal
  locale_support: none
  name:
    en: Ubuntu Server (minimized)
  path: ubuntu-server-minimal.squashfs
  size: 596627456
  type: fsimage
  variant: server
- default: true
  description:
    en: The default install contains a curated set of packages that provide a comfortable
      experience for operating your server.
  id: ubuntu-server
  locale_support: locale-only
  name:
    en: Ubuntu Server
  path: ubuntu-server-minimal.ubuntu-server.squashfs
  size: 1233199104
  type: fsimage-layered
  variant: server
EOF
}

HELP_create_autoinstall="$TODO"
create_autoinstall (){
    cat << EOF > "$CRR_autoinstall_Installer"
#cloud-config
autoinstall:
  apt:
    disable_components: []
    fallback: abort
    geoip: true
    mirror-selection:
      primary:
      - country-mirror
      - arches:
        - amd64
        - i386
        uri: http://archive.ubuntu.com/ubuntu
      - arches:
        - s390x
        - arm64
        - armhf
        - powerpc
        - ppc64el
        - riscv64
        uri: http://ports.ubuntu.com/ubuntu-ports
    preserve_sources_list: false
  codecs:
    install: false
  drivers:
    install: false
  identity:
    # hostname: ubuntu22-04-03-amd64-vbox
    # password: $6$KqoxLKGAQAa3TbQO$rVoesGyWyW2GVMsKXVM6ZUej.dze7A1UqRsu7pO2sVm1qirRyXPxWumEr3va.xp.Emf5OnjKdHNy0pPhi8537/
    # realname: Owner
    # username: owner
    hostname: $CRR_hostname
    password: $ROOT_PW_IC
    realname: $CRR_remote_admin
    username: $CRR_remote_admin
  ssh:
    install-server: true
    authorized-keys:
#     - ssh-rsa AAAA... your@key
      - `get_CRR_PUBKEY`
    allow-pw: false
  kernel:
    package: linux-generic
  keyboard:
    layout: us
    toggle: null
    variant: ''
  locale: en_US.UTF-8
  network:
    ethernets:
      enp0s3:
        dhcp4: true
      enp0s8:
        dhcp4: true
    version: 2
  source:
    id: ubuntu-server-minimal
    search_drivers: false
  ssh:
    allow-pw: true
    authorized-keys: []
    install-server: true
  storage:
    config:
    - ptable: gpt
#      serial: VBOX_HARDDISK_VB3636a53d-f062c978
      path: /dev/sda
      wipe: superblock-recursive
      preserve: false
      name: ''
      grub_device: true
      type: disk
      id: disk-sda
    - device: disk-sda
      size: 1048576
      flag: bios_grub
      number: 1
      preserve: false
      grub_device: false
      offset: 1048576
      path: /dev/sda1
      type: partition
      id: partition-0
    - device: disk-sda
      size: 2147483648
      wipe: superblock
      number: 2
      preserve: false
      grub_device: false
      offset: 2097152
      path: /dev/sda2
      type: partition
      id: partition-1
    - fstype: ext4
      volume: partition-1
      preserve: false
      type: format
      id: format-0
    - device: disk-sda
      size: 64958234624
      wipe: superblock
      number: 3
      preserve: false
      grub_device: false
      offset: 2149580800
      path: /dev/sda3
      type: partition
      id: partition-2
    - name: ubuntu-vg
      devices:
      - partition-2
      preserve: false
      type: lvm_volgroup
      id: lvm_volgroup-0
    - name: ubuntu-lv
      volgroup: lvm_volgroup-0
      size: 32476495872B
      wipe: superblock
      preserve: false
      path: /dev/ubuntu-vg/ubuntu-lv
      type: lvm_partition
      id: lvm_partition-0
    - fstype: ext4
      volume: lvm_partition-0
      preserve: false
      type: format
      id: format-1
    - path: /
      device: format-1
      type: mount
      id: mount-1
    - path: /boot
      device: format-0
      type: mount
      id: mount-0
  updates: security
  version: 1
  runcmd:
    - mkdir -p /target/root/.ssh
    - chmod 700 /target/root/.ssh
    - echo '`get_CRR_PUBKEY`' >>  /target/root/QQQ_rc
    - echo '`get_CRR_PUBKEY`' >>  /target/root/.ssh/authorized_keys
    - chmod 600 /target/root/.ssh/authorized_keys
    - chown root:root /target/root/.ssh /target/root/.ssh/authorized_keys
  late-commands:
    - mkdir -p /target/root/.ssh
    - chmod 700 /target/root/.ssh
    - echo '`get_CRR_PUBKEY`' >>  /target/root/QQQ_lc
    - echo '`get_CRR_PUBKEY`' >>  /target/root/.ssh/authorized_keys
    - chmod 600 /target/root/.ssh/authorized_keys
    - chown root:root /target/root/.ssh /target/root/.ssh/authorized_keys
#    - echo -n NOTE: hosts ED25519 key fingerprint is:
#    - ssh-keygen -l -f /etc/ssh/ssh_host_ed25519_key.pub
#    - sleep 6
  error-commands:
    - tail /var/log/syslog

# https://askubuntu.com/questions/1317141/autoinstall-the-password-and-authorized-keys-options-doesnt-work
#user-data:
#    disable_root: false
#    users:
#    - default
#    - name: root
#      ssh-authorized-keys:
#        - `get_CRR_PUBKEY`
#      sudo: ALL=(ALL) NOPASSWD:ALL
#      groups: sudo
#      shell: /bin/bash
EOF
}

HELP_get_upstream_os_iso="$TODO"
get_upstream_os_iso (){
    if [ ! -f "$CRR_local_iso" ]; then
        TRACE curl -o "$CRR_local_iso" "$CRR_repo_iso"
    fi

    if [ "$OPT_checksum"]; then
        curl -o "$CRR_local_iso_checksum" "$CRR_repo_iso_checksum"

        target_cs=`cat "$CRR_local_iso_checksum"`
        candidate_cs=`$checksum "$CRR_local_iso"`
        if [ "$candidate_cs" != "$target_cs" ]; then
            RAISE "$CRR_local_iso" 'bad checksum' "$candidate_cs" != "$target_cs"
        fi
    fi
}

# https://askubuntu.com/questions/122505/how-do-i-create-a-completely-unattended-install-of-ubuntu
# ... add ks=cdrom:/ks.cfg and preseed/file=/cdrom/ks.preseed to the append line. You can remove the quiet and vga=788 words.

# Ubunto builder host: NEED system-config-kickstart

HELP_create_custom_iso="$TODO"
create_custom_iso (){
    NEED genisoimage isomd5sum # implantisomd5
    IMAGE_ISO="$CRR_local_iso"
    MNT_ISO="$TMP_WORKDIR/mnt"
    TMP_WORKDIR_prep_iso="$TMP_WORKDIR/prep_iso"
    # CUSTOM_ISO="$TMP_WORKDIR/CUSTOM_ISO.iso"
    CUSTOM_ISO="$CRR_local_custom_iso"

# https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/installation_guide/s1-kickstart2-putkickstarthere
# Procedure 32.1. Including a Kickstart File on Boot Media

# Before you start the procedure, make sure you have downloaded a boot ISO
# image (boot.iso or binary DVD) as described in Chapter 1, Obtaining Red
# Hat Enterprise Linux, and that you have created a working Kickstart file.

# Mount the ISO image you have downloaded:
ASSERT mkdir -p "$MNT_ISO"
#SUDO mount -t iso9660 -o ro,uid=$CRR_UID,gid=$CRR_GID "$IMAGE_ISO" "$MNT_ISO" || WARN
SUDO mount -o ro,uid=$CRR_UID,gid=$CRR_GID "$IMAGE_ISO" "$MNT_ISO" || WARN

# Extract the ISO image into a working directory somewhere in your system:

if [ -d "$TMP_WORKDIR_prep_iso" ]; then # debugging
    SUDO rm -Rf "$TMP_WORKDIR_prep_iso" || NOTE
fi

ASSERT mkdir -p "$TMP_WORKDIR_prep_iso"

# need to sudo/chown in cases, a file is being copied from a "ro" CDROM directory? I'm confused!

ASSERT cp -RT "$MNT_ISO/." "$TMP_WORKDIR_prep_iso"  # added ../.
#( cd "$MNT_ISO"; find . -type f -print0 | tar --null -T - -cf - ) | ( cd "$TMP_WORKDIR_prep_iso"; tar -xvf - )
#SUDO chown -Rf "$USER" "$TMP_WORKDIR_prep_iso"
#chmod -Rf u+w "$TMP_WORKDIR_prep_iso"

# Unmount the mounted image:

# TRACE sudo umount "$MNT_ISO" || WARN
TRACE rmdir "$MNT_ISO" || WARN

# The contents of the image is now placed in the iso/ directory in your
# working directory. Add your Kickstart file (ks.cfg) into the iso/
# directory:

# ASSERT cp "$CRR_kickstart_Installer" "$TMP_WORKDIR_prep_iso"
    create_install_script

# Open the isolinux/isolinux.cfg configuration file inside the iso/
# directory. This file determines all the menu options which appear in
# the boot menu. A single menu entry is defined as the following:

    modify_boot_menu

# Use genisoimage in the iso/ directory to create a new bootable ISO image
# with your changes included:

CD "$TMP_WORKDIR_prep_iso" || RAISE

# The -A option is used to specify the Application Identifier.
# The -volset option is used to specify the Volume Set Name of the ISO image.
#ASSERT genisoimage -U -r -v -T -J -joliet-long -V "$CRR_rel" -volset "$CRR_rel" -A "$CRR_rel" -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e images/efiboot.img -no-emul-boot -o "$CUSTOM_ISO" .

case "$CRR_OS" in
    (rhel-x86_64|rocky-x86_64|centos-x86_64|rhel-like-x86_64)
        CRR_BOOT_CAT="-c isolinux/boot.cat"
        CRR_BOOT_LINUX="-b isolinux/isolinux.bin"
        CRR_EFIBOOT="-e images/efiboot.img"
        chmod u+w isolinux/isolinux.bin
    ;;
    (fedora-x86_64)
        CRR_BOOT_CAT="" # not needed for EFI or grub2
    # FC39 original dud
    #    CRR_BOOT_LINUX="-b boot/grub2/i386-pc/lnxboot.img" # also .image
    #    CRR_EFIBOOT="-e EFI/BOOT/BOOTX64.EFI"  #Dud
    #    chmod u+w boot/grub2/i386-pc/lnxboot.img
    # try1
        CRR_BOOT_LINUX="-eltorito-boot images/eltorito.img" # also .image
        CRR_EFIBOOT="-e EFI/BOOT/BOOTX64.EFI"
        chmod u+w images/eltorito.img
    ;;
    (opensuse-x86_64)
# Suse:
#-r--r--r--. 1 nevilled nevilled 3741696 Dec 16 15:43 boot/x86_64/efi
#-r--r--r--. 1 nevilled nevilled   24576 Dec 16 15:43 boot/x86_64/loader/isolinux.bin
#-r--r--r--. 1 nevilled nevilled     826 Dec 16 15:43 boot/x86_64/loader/isolinux.cfg
        CRR_BOOT_CAT=""
        CRR_BOOT_LINUX="-b boot/x86_64/loader/isolinux.bin"
        CRR_EFIBOOT="-e boot/x86_64/efi"
        chmod u+w boot/x86_64/loader/isolinux.bin
    ;;
    (debian-amd64|debian-like-amd64)
    # bad (ubuntu)
        CRR_BOOT_CAT="-c boot.catalog"
        CRR_BOOT_LINUX="-eltorito-boot boot/grub/i386-pc/eltorito.img" # -eltorito-alt-boot
        CRR_EFIBOOT="-e EFI/boot/bootx64.efi"
        # chmod u+w boot/grub/i386-pc/eltorito.img
    # try
        CRR_BOOT_CAT="-c isolinux/boot.cat"
        CRR_BOOT_LINUX="-b isolinux/isolinux.bin"
        CRR_EFIBOOT="-e EFI/boot/bootx64.efi"
        ASSERT chmod u+w isolinux/isolinux.bin
    ;;
    (ubuntu-amd64|ubuntu-like-amd64)
        CRR_BOOT_CAT="-c boot.catalog"
        CRR_BOOT_LINUX="-eltorito-boot boot/grub/i386-pc/eltorito.img" # -eltorito-alt-boot
        CRR_EFIBOOT="-e EFI/boot/bootx64.efi"
        chmod u+w boot/grub/i386-pc/eltorito.img
    ;;
    (freebsd-amd64)
# https://unix.stackexchange.com/questions/487895/how-to-create-a-freebsd-iso-with-mkisofs-that-will-boot-in-virtualbox-under-uefi
        true # ToDo - needs to digout boot records, or figure out how FreeBSD does this?
    ;;
esac

ASSERT genisoimage -U -r -v -T -J -joliet-long -input-charset utf-8 -V "$CRR_ISO_LABEL" -volset "$CRR_rel" -A "$CRR_rel" $CRR_BOOT_LINUX $CRR_BOOT_CAT -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot $CRR_EFIBOOT -no-emul-boot -o "$CUSTOM_ISO" .

# was: ASSERT genisoimage -U -r -v -T -J -joliet-long -V "$CRR_ISO_LABEL" -volset "$CRR_rel" -A "$CRR_rel" -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e images/efiboot.img -no-emul-boot -o "$CUSTOM_ISO" .

CD -

# Verify an EFI-bootable ISO has been created:
# dumpet -i "$CUSTOM_ISO"

if [ ! "$OPT_debug" ]; then
    ASSERT rm -rf "$TMP_WORKDIR_prep_iso"
fi

# This comand will create a file named CUSTOM_ISO.iso in your working directory
# (one directory above the iso/ directory).

# Important:
# If you use a disk label to refer to any device in your isolinux.cfg
# (e.g. ks=hd:LABEL=$CRR_rel/ks.cfg, make sure that the label matches the
# label of the new ISO you are creating. Also note that in boot loader
# configuration, spaces in labels must be replaced with \x20.

# Implant a md5 checksum into the new ISO image:

ASSERT implantisomd5 "$CUSTOM_ISO"

# After you finish the above procedure, your new image is ready to be
# turned into boot media. Refer to Chapter 2, Making Media for instructions.
#
# To perform a pen-based flash memory kickstart installation, the kickstart
# file must be named ks.cfg and must be located in the flash memory\'s
# top-level directory. The kickstart file should be on a separate flash
# memory drive to the boot media.
#
# To start the Kickstart installation, boot the system using the boot
# media you created, and use the ks= boot option to specify which device
# contains the USB drive. See Section 28.4, “Automating the Installation
# with Kickstart” for details about the ks= boot option.
    true
}

HELP_destroy_custom_iso="$TODO"
destroy_custom_iso (){
    CUSTOM_ISO="$CRR_local_custom_iso"
    TRACE rm "$CUSTOM_ISO"
}

HELP_create_custom_vm="$TODO"
create_custom_vm (){
# Define variables
    HDD_SIZE=64000  # Size in MB (64GB)
    RAM_SIZE=2048   # Size in MB (2GB)
    RAM_SIZE=1536   # Size in MB (1.5GB)
    RAM_SIZE=1024   # Size in MB (1GB)
    VRDE_PORT=3390  # Remote desktop port, change if needed

    # Create the VM
    TRACE VBoxManage createvm --name "$VM_NAME" --ostype "$CRR_type" --register

    # Set memory and network
    TRACE VBoxManage modifyvm "$VM_NAME" --memory "$RAM_SIZE" --vram 128 --ioapic on
    TRACE VBoxManage modifyvm "$VM_NAME" --nic1 nat

    # Create a virtual hard disk
    TRACE VBoxManage createhd --filename "$HOME/VirtualBox VMs/$VM_NAME/$VM_NAME.vdi" --size $HDD_SIZE

    # Attach the hard disk and ISO
    TRACE VBoxManage storagectl "$VM_NAME" --name "SATA Controller" --add sata --controller IntelAhci
    TRACE VBoxManage storageattach "$VM_NAME" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "$HOME/VirtualBox VMs/$VM_NAME/$VM_NAME.vdi"
    TRACE VBoxManage storagectl "$VM_NAME" --name "IDE Controller" --add ide

    #TRACE VBoxManage storageattach "$VM_NAME" --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium "$CRR_local_iso"
    TRACE VBoxManage storageattach "$VM_NAME" --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium "$CRR_local_custom_iso"

    # Setup the graphics controller of the specified VM to VMSVGA
    TRACE VBoxManage modifyvm "$VM_NAME" --graphicscontroller vmsvga

    TRACE VBoxManage setextradata "$VM_NAME" "VBoxInternal/Devices/VMMDev/0/Config/GetHostTimeDisabled" "0"

    # Setup Virtual Remote Desktop (Optional)
    #TRACE VBoxManage modifyvm "$VM_NAME" --vrde on
    #TRACE VBoxManage modifyvm "$VM_NAME" --vrdeport $VRDE_PORT

    netname=vboxnet0 nic=2
    VBoxManage list hostonlyifs | ( grep $netname || TRACE VBoxManage hostonlyif create )

    TRACE VBoxManage modifyvm "$VM_NAME" --hostonlyadapter$nic $netname
    TRACE VBoxManage modifyvm "$VM_NAME" --nic$nic hostonly

    echo "VM '$VM_NAME' created and configured."
}

HELP_snapshot_vm="$TODO"
snapshot_vm (){
    # snapshot the VM

    # Replace this with your VM name
    # VM_NAME="Your_VM_Name"

    # The snapshot name to check for; $1, else vanilla
    SNAPSHOT_NAME="${1:-vanilla}"

    # Check if the snapshot exists
    if VBoxManage snapshot "$VM_NAME" list | grep -q "$SNAPSHOT_NAME"; then
        echo "Snapshot '$SNAPSHOT_NAME' already exists for VM '$VM_NAME'."
    else
        echo "Snapshot '$SNAPSHOT_NAME' does not exist. Creating snapshot..."
        TRACE VBoxManage snapshot "$VM_NAME" take "$SNAPSHOT_NAME" --pause
        echo "Snapshot '$SNAPSHOT_NAME' created successfully."
    fi

}

HELP_clone_vm="$TODO"
clone_vm (){
    # clone the VM
    TRACE VBoxManage clonevm "$VM_NAME" # ToDo
}

HELP_start_vm="$TODO"
start_vm (){
    # start the VM
    TRACE VBoxManage startvm "$VM_NAME"
}

HELP_installation_phase_two="shutdown_vm, remove_DVD, start_vm - so as not to reinstall OS"
installation_phase_two (){
    # start the VM
    shutdown_vm
    #TRACE VBoxManage storageattach "$VM_NAME" --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium "$CRR_local_custom_iso"
    TRACE VBoxManage storageattach "$VM_NAME" --storagectl 'IDE Controller' --port 0 --device 0 --type dvddrive --medium none
    start_vm
}

HELP_shutdown_vm="$TODO"
shutdown_vm (){
    # stop the VM
    TRACE VBoxManage controlvm "$VM_NAME" acpipowerbutton
}

CRR_IR_LOG="AR_prep_VM_inst.log"
OPT_ssh="-i $HOME/.ssh/$CRR_PTEKEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=no" # ToDo: we know the IP address locally

HELP_AR_prep_VM_inst="$TODO"
AR_prep_VM_inst (){
    VM_NAME="$1"
    CRR_IP="$2"
    # https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/adding-self-hosted-runners#prerequisiteshttps://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/adding-self-hosted-runners#prerequisites
    # $CRR_REPO/settings/actions/runners/new
    # AR_prep_VM_inst on the VM

    # CRR_IP="$(get_ip_of_vm_nic $VM_NAME $CRR_NIC_NUM)"

# Note: on ubuntu, the default login shell is /bin/sh, not bash.
    ssh $OPT_ssh "root@$CRR_IP" "
        dnf install -y tar # ToDo Needed for RHEL-minimum
#        useradd -Um -u $CRR_UID -G adm,wheel -c '$CRR_remote_builder',r,w,m,e '$CRR_remote_builder' 
        useradd -Um -u $CRR_UID -G adm -s /usr/bin/bash -c '$CRR_remote_builder',r,w,m,e '$CRR_remote_builder'
        cp -rp ~root/.ssh ~$CRR_remote_builder/
        chown -R '$CRR_remote_builder' ~$CRR_remote_builder/.ssh
        ALLOW_SUDO='$CRR_remote_builder ALL=(ALL:ALL) NOPASSWD: ALL'
        grep -q $qq\$ALLOW_SUDO$qq '/etc/sudoers.d/$CRR_remote_builder' ||
            echo $qq\$ALLOW_SUDO$qq >> '/etc/sudoers.d/$CRR_remote_builder'
        chmod go-rwx '/etc/sudoers.d/$CRR_remote_builder'
      "

    scp -p $OPT_ssh ~/bin/runner_mgr.sh "$CRR_remote_builder@$CRR_IP:"

    ssh $OPT_ssh "$CRR_remote_builder@$CRR_IP" "
        mkdir -p $CRR_AR_DIR && cd $CRR_AR_DIR &&
        mv ../runner_mgr.sh . &&
        ./runner_mgr.sh download &&
        ./runner_mgr.sh installdependencies
        true
    "
}


HELP_AR_configure="$TODO"
AR_configure (){

    VM_NAME="$1"
    CRR_IP="$2"
    repo="$3"
    token="$4"

    for repo in "$CRR_REPO_LIST"; do
        echo echo firefox "$CRR_REPO_URL/$repo/settings/actions/runners/new"

        echo ./runner_mgr.sh configure "$repo" "$VM_NAME" $token

        ssh $OPT_ssh "$CRR_remote_builder@$CRR_IP" "
            mkdir -p $CRR_AR_DIR && cd $CRR_AR_DIR &&
               ./runner_mgr.sh configure '$repo' '$VM_NAME' $token
            "
    done
}

HELP_AR_run="$TODO"
AR_run (){
    VM_NAME="$1"
    CRR_IP="$2"
    repo="$3"

    for repo in "$CRR_REPO_LIST"; do
        set -x
        if ssh $OPT_ssh -n -f "$CRR_remote_builder@$CRR_IP" "
            cd $CRR_AR_DIR && {
                # for((i=1; i<36; i++)); do echo -n \$i.; sleep 1; done &
                nohup ./runner_mgr.sh run '$repo' '$VM_NAME' & 
                for((j=36; j>0; j--)); do echo -n \$j.; sleep 1; done
            }
        "; then
            echo OK: "nohup ./runner_mgr.sh run '$repo' '$VM_NAME'"
        else
            echo Huh: "nohup ./runner_mgr.sh run '$repo' '$VM_NAME'"
        fi
    done
}

HELP_AR_kill="$TODO"
AR_kill (){
    VM_NAME="$1"
    CRR_IP="$2"
    repo="$3"

    for repo in "$CRR_REPO_LIST"; do
        ssh $OPT_ssh "$CRR_remote_builder@$CRR_IP" "
            cd $CRR_AR_DIR &&
            exec ./runner_mgr.sh kill '$repo' '$VM_NAME'
        "
    done
}

HELP_AR_status="$TODO"
AR_status (){
    VM_NAME="$1"
    CRR_IP="$2"
    repo="$3"

    for repo in "$CRR_REPO_LIST"; do
        ssh $OPT_ssh "$CRR_remote_builder@$CRR_IP" "
            cd $CRR_AR_DIR &&
            exec ./runner_mgr.sh status '$repo' '$VM_NAME'
        "
        true
    done
}

HELP_AR_remove="$TODO"
AR_remove (){
    VM_NAME="$1"
    CRR_IP="$2"
    repo="$3"
    token="$4"
    for repo in "$CRR_REPO_LIST"; do
        echo ./runner_mgr.sh remove "$repo" "$VM_NAME"

        ssh $OPT_ssh "$CRR_remote_builder@$CRR_IP" "
            cd $CRR_AR_DIR &&
            ./runner_mgr.sh remove '$repo' '$VM_NAME' $token
            " 
    done
}

HELP_destroy_vm="$TODO"
destroy_vm (){
    # destroy the VM
    TRACE VBoxManage unregistervm "$VM_NAME"  --delete
}

HELP_help="$TODO"
help (){
#awk '/^[a-z_]* \(\){/ { print "    "$1" - $HELP_"$1; }' bin/create_self_hosted_runner_on_vm.sh
    cat << EOF
USAGE
    bin/create_self_hosted_runner_on_vm.sh <command> ...

CORE COMMANDS
    gen_pw - $HELP_gen_pw
    create_kickstart - $HELP_create_kickstart
    create_autoyast - $HELP_create_autoyast
    create_install_script - $HELP_create_install_script
    modify_boot_menu - $HELP_modify_boot_menu
    modify_autoinstall_grub_cfg - $HELP_modify_autoinstall_grub_cfg
    modify_autoyast_grub_cfg - $HELP_modify_autoyast_grub_cfg
    modify_kickstart_grub_isolinux_cfg - $HELP_modify_kickstart_grub_isolinux_cfg
    create_preseed - $HELP_create_preseed
    create_autoinstall - $HELP_create_autoinstall
    get_upstream_os_iso - $HELP_get_upstream_os_iso
    create_custom_iso - $HELP_create_custom_iso
    destroy_custom_iso - $HELP_destroy_custom_iso
    create_custom_vm - $HELP_create_custom_vm
    snapshot_vm - $HELP_snapshot_vm
    clone_vm - $HELP_clone_vm
    start_vm - $HELP_start_vm
    installation_phase_two - $HELP_installation_phase_two
    shutdown_vm - $HELP_shutdown_vm
    AR_prep_VM_inst - $HELP_configure_runner
    destroy_vm - $HELP_destroy_vm
    help - $HELP_help
EOF
}

HELP_setenv_target_vm=""$TODO""
setenv_target_vm (){
    # https://en.wikipedia.org/wiki/Usage_share_of_operating_systems
    # https://www.openlogic.com/blog/top-open-source-operating-systems-2022
    cat << EOF > /dev/null
    ChatGPT: As of my last update in April 2023, precise user counts for
    Linux distributions are not typically available due to the nature of
    open-source software distribution. However, based on various metrics
    such as web search interest, community activity, and presence in
    industry and public forums, we can infer a rough popularity order for
    Linux distributions. Please note that this list does not represent
    exact user counts, but rather a general idea of popularity:

    35% Ubuntu: One of the most user-friendly distributions, widely used by
    both beginners and experienced users.

    Fedora: Known for being cutting-edge and more developer-focused. It's
    the upstream source of Red Hat Enterprise Linux.

    21% Debian: Praised for its stability and the base for many other
    distributions, including Ubuntu.

    16% openSUSE: Popular for its YaST configuration tool and strong
    community, it's often used in Europe.

    14% SLES - Suse

    13% SELinux - https://en.wikipedia.org/wiki/Security-Enhanced_Linux

    Arch Linux: Favoured by those who want to learn more about Linux
    internals. Known for its rolling releases and vast community-driven
    repository.

    Mint: Based on Ubuntu, it's known for its simplicity and ease of use,
    making it a good choice for beginners.

    19% CentOS: Before CentOS Stream, it was widely used for servers due to
    its stability and strong ties to Red Hat Enterprise Linux.

    Manjaro: Based on Arch Linux, it provides a more user-friendly and
    accessible way to access the Arch environment.

    17% Red Hat Enterprise Linux (RHEL): Widely used in corporate
    environments, known for its stability and support.

    Kali Linux: Popular among security professionals and ethical hackers
    for penetration testing and security research.

    elementary OS: Known for its aesthetic appeal and user-friendliness,
    often compared to macOS in terms of design.

    Slackware: One of the oldest distributions, known for its simplicity
    and minimalism.

    11% Rocky Linux - based on RHEL

These rankings are subject to change as the Linux ecosystem is
dynamic, with new distributions emerging and user preferences
evolving. Additionally, the popularity of a distribution can vary
significantly depending on the specific use-case scenario (e.g., servers,
desktops, beginners, advanced users).

ChatGPT: Quantifying the number of actual users for UNIX distributions
is challenging due to the lack of publicly available data and the
diverse nature of UNIX environments, especially in enterprise and server
settings. However, we can list some of the most commonly used UNIX and
UNIX-like operating systems, based on their popularity and presence in
enterprise environments:

# https://www.networkcomputing.com/data-centers/ibm-wants-its-share-unix-glory
    28% IBM AIX: A widely used enterprise-level UNIX operating system
    developed by IBM, known for its reliability and scalability in heavy
    industrial operations.

    33% Solaris: Originally developed by Sun Microsystems and later acquired
    by Oracle. Known for its scalability, especially on SPARC systems,
    and its use in high-end enterprise computing.

    29% HP-UX: Hewlett Packard Enterprise's proprietary UNIX operating
    system. It's known for its strong integration with HPE's hardware
    and mission-critical environments.

    macOS: While not a traditional UNIX system, macOS is UNIX-certified
    and based on BSD. Its popularity is significant, especially among
    personal users, developers, and creative professionals.

# https://unixmen.com/freebsd-vs-openbsd/
    77% FreeBSD: One of the most popular open-source BSD distributions,
    known for its advanced networking, performance, security features,
    and as the basis for many other systems, including Apple's macOS.

    32% OpenBSD: Known for its emphasis on security, OpenBSD is widely used
    in security-critical environments.

    16% NetBSD: Noted for its portability and support for a wide range of
    hardware platforms.

    Tru64 UNIX: Formerly known as Digital UNIX, it was developed by
    DEC/Compaq and later acquired by HP. It's used in legacy enterprise
    systems.

Remember, this list is a broad approximation, and the actual user
base can vary significantly based on specific industry sectors and use
cases. Furthermore, the distinction between UNIX and Linux can sometimes
blur, especially with Linux often being used in environments traditionally
dominated by UNIX systems.
EOF
    case "$CRR_OS" in
        (fedora-x86_64)
            CRR_ver=39
            CRR_version="$CRR_ver-1.5"
            CRR_machine="x86_64"
            CRR_machine_l="x86_64 arch64 ppc64le s390x" # Server
            CRR_inst_guide='https://fedoraproject.org/workstation/download'
            CRR_repo_iso="https://download.fedoraproject.org/pub/fedora/linux/releases/$CRR_ver/Everything/$CRR_machine/iso/Fedora-Everything-netinst-$CRR_machine-$CRR_version.iso"
            CRR_repo_iso="https://gsl-syd.mm.fcix.net/fedora/linux/releases/$CRR_ver/Server/$CRR_machine/iso/Fedora-Server-dvd-$CRR_machine-$CRR_version.iso"
            #             https://ap.edge.kernel.org/fedora/releases/test/40_Beta/Server/x86_64/iso/Fedora-Server-netinst-x86_64-40_Beta-1.10.iso
            #             https://torrent.fedoraproject.org/torrents/Fedora-Server-dvd-x86_64-40_Beta.torrent
            CRR_iso_size='?'
            CRR_repo_iso_checksum="https://download.fedoraproject.org/pub/fedora/linux/releases/$CRR_ver/Everything/$CRR_machine/iso/Fedora-Everything-$CRR_version-$CRR_machine-CHECKSUM"
            checksum="sha256sum --ignore-missing -c"
            CRR_type='Fedora_64' # ToDo
            CRR_rel='fedora-39' # RHEL-6.9 or CRR_OEMDRV ToDo
            CRR_desc='Fedora Linux 9.3' # ToDo
            CRR_family='Fedora Linux' # ToDo
        ;;
        (rocky-x86_64)
            CRR_ver=9
            CRR_version="$CRR_ver.3"
            CRR_machine=""x86_64 arch64 ppc64le s390x""
            CRR_machine_l="$CRR_machine"
            CRR_inst_guide="https://docs.rockylinux.org/guides/installation"
            CRR_repo_iso="https://download.rockylinux.org/pub/rocky/$CRR_ver/isos/$CRR_machine/Rocky-$CRR_version-$CRR_machine-minimal.iso"
            CRR_iso_size='?'
            CRR_repo_iso_checksum="https://download.rockylinux.org/pub/rocky/$CRR_version/isos/$CRR_machine/CHECKSUM"
            checksum="sha256sum --ignore-missing -c"
            CRR_type='RedHat_64'
            CRR_rel="rockey-$CRR_version" # RHEL-6.9 or CRR_OEMDRV
            CRR_desc="Rocky Linux $CRR_version"
            CRR_family='Rocky Linux'
        ;;
        (rhel-x86_64) # you may have to do this by hand due to registration
            CRR_ver=9
            CRR_version="$CRR_ver.3"
            CRR_machine="x86_64"
            CRR_machine_l="$CRR_machine"
            CRR_inst_guide='https://access.redhat.com/downloads/content/rhel'
    # -boot
            CRR_repo_iso="https://access.cdn.redhat.com/content/origin/files/sha256/6a/6a9f135b8836edd06aba1b94fd6d0e72bd97b4115a3d2a61496b33f73e0a13a5/rhel-$CRR_version-$CRR_machine-boot.iso?user=affdca1c90f2fdbe5b2fded5fb8f7a3b&_auth_=1701521114_9be76275d061244dfa7db927b32d9970"
    # -dvd
            CRR_repo_iso="https://access.cdn.redhat.com/content/origin/files/sha256/5c/5c802147aa58429b21e223ee60e347e850d6b0d8680930c4ffb27340ffb687a8/rhel-$CRR_version-$CRR_machine-dvd.iso?user=affdca1c90f2fdbe5b2fded5fb8f7a3b&_auth_=1701521114_15cbc4894a7280387e88c7ad98d7c78f"
            CRR_iso_size='?'
            CRR_repo_iso_checksum="https://download.rockylinux.org/pub/rocky/$CRR_version/isos/$CRR_machine/CHECKSUM"
            checksum="sha256sum --ignore-missing -c"
            CRR_type='RedHat_64'
            CRR_rel="RHEL-$CRR_ver" # RHEL-6.9 or CRR_OEMDRV
            CRR_desc="Red Hat Enterprise Linux $CRR_version"
            CRR_family='Red Hat Enterprise Linux'
        ;;
        (centos-x86_64) # you may hacve to do this by hand due to registration
            CRR_ver=9
            CRR_version="$CRR_ver.3"
            CRR_machine="x86_64"
            CRR_machine_l="x86_64 aarch64 ppc64 ppc64le armhfp i386"
            CRR_inst_guide='https://www.centos.org/download/'
    # -dvd1
            CRR_repo_iso="https://mirrors.centos.org/mirrorlist?path=/$CRR_ver-stream/BaseOS/$CRR_machine/iso/CentOS-Stream-$CRR_ver-latest-$CRR_machine-dvd1.iso&redirect=1&protocol=https"
            CRR_repo_iso="https://centos-stream.mirror.digitalpacific.com.au/$CRR_ver-stream/BaseOS/$CRR_machine/iso/CentOS-Stream-$CRR_ver-latest-$CRR_machine-dvd1.iso"
            CRR_iso_size='?'
            CRR_repo_iso_checksum="?"
            checksum="sha256sum --ignore-missing -c"
            CRR_type='Centos_64'
            CRR_rel="RHEL-$CRR_version" # RHEL-6.9 or CRR_OEMDRV
            CRR_desc="Centos Stream Linux $CRR_version"
            CRR_family='Centos Stream Linux'
        ;;
        (debian-amd64)
            CRR_ver=12
            CRR_version="$CRR_ver.1.0"
            CRR_machine="amd64"
            CRR_machine_l="$CRR_machine"
            CRR_inst_guide='https://www.debian.org/download' # debian-12.4.0-amd64-netinst.iso
            CRR_repo_iso="https://gemmei.ftp.acc.umu.se/debian-cd/current/$CRR_machine/iso-cd/debian-$CRR_version-$CRR_machine-netinst.iso"
            CRR_repo_iso="http://mirror.overthewire.com.au/debian-cd/current/$CRR_machine/iso-dvd/debian-$CRR_version-$CRR_machine-DVD-1.iso"
            CRR_iso_size='?'
            CRR_repo_iso_checksum=''
            checksum="sha256sum --ignore-missing -c"
            CRR_type='Debian_64' # ToDo
            CRR_rel="debian-$CRR_version" # RHEL-6.9 or CRR_OEMDRV ToDo
            CRR_desc="Debian Linux $CRR_version" # ToDo
            CRR_family='Debian Linux' # ToDo
        ;;
        (ubuntu-amd64)
            CRR_machine="amd64"
            CRR_machine_l="$CRR_machine"

            CRR_ver=23
            CRR_version="$CRR_ver.10"
            CRR_inst_guide='https://ubuntu.com/download/desktop'
            CRR_repo_iso="https://cdimage.ubuntu.com/releases/mantic/release/ubuntu-$CRR_version-desktop-legacy-$CRR_machine.iso"

            CRR_ver=22
            CRR_version="$CRR_ver.04.3"
            CRR_inst_guide='https://ubuntu.com/download/server'
            CRR_repo_iso="https://releases.ubuntu.com/$CRR_version/ubuntu-$CRR_version-live-server-$CRR_machine.iso"
            CRR_iso_size='?'
            CRR_repo_iso_checksum=''
            checksum="sha256sum --ignore-missing -c"
            CRR_type='Ubuntu_64' # ToDo
            CRR_rel="ubuntu-$CRR_version" # RHEL-6.9 or CRR_OEMDRV ToDo
            CRR_desc="Ubuntu Linux $CRR_version" # ToDo
            CRR_family='Ubuntu Linux' # ToDo
        ;;
        (opensuse-x86_64)
            CRR_machine="x86_64"
            CRR_machine_l="x86_64      aarch64 ppc64le s390x"      # LEAP: x86_64 aarch64 ppc64le s390x
            # TumbleWeed: "x86_64 i686 aarch64 ppc64le s390x ppc64"
            CRR_ver=15
            CRR_version="$CRR_ver.5"
            CRR_inst_guide='https://get.opensuse.org/server'
            CRR_repo_is0="https://mirror.aarnet.edu.au/pub/opensuse/opensuse/distribution/leap/$CRR_version/iso/openSUSE-Leap-$CRR_version-NET-$CRR_machine-Build491.1-Media.iso"
            CRR_repo_iso="https://mirror.aarnet.edu.au/pub/opensuse/opensuse/distribution/leap/$CRR_version/iso/openSUSE-Leap-$CRR_version-DVD-$CRR_machine-Build491.1-Media.iso"
            CRR_iso_size='?'
            CRR_repo_is0_checksum="https://download.opensuse.org/distribution/leap/$CRR_version/iso/openSUSE-Leap-$CRR_version-NET-$CRR_machine-Media.iso.sha256"
            CRR_repo_iso_checksum="https://download.opensuse.org/distribution/leap/$CRR_version/iso/openSUSE-Leap-$CRR_version-DVD-$CRR_machine-Media.iso.sha256"
            checksum="sha256sum --ignore-missing -c"
            CRR_type='Suse_64' # ToDo
            CRR_rel="suse-$CRR_version" # RHEL-6.9 or CRR_OEMDRV ToDo
            CRR_desc="Suse Linux $CRR_version" # ToDo
            CRR_family='Suse Linux' # ToDo
        ;;
        (freebsd-amd64)
            CRR_machine="amd64"
            CRR_machine_l="amd64 i386 powerpc powerpc64 powerpc64le powerpcspe armv7 aarch64 riscv64"
            CRR_ver=14;
            CRR_version="$CRR_ver.0";
            CRR_inst_guide='https://www.freebsd.org/where';
            CRR_repo_iso="https://download.freebsd.org/releases/$CRR_machine/$CRR_machine64/ISO-IMAGES/$CRR_version/FreeBSD-$CRR_version-RELEASE-$CRR_machine-dvd1.iso";
            CRR_iso_size='?';
            CRR_repo_iso_checksum="https://download.freebsd.org/releases/$CRR_machine/$CRR_machine64/ISO-IMAGES/$CRR_version/CHECKSUM.SHA256-FreeBSD-$CRR_version-RELEASE-$CRR_machine";
            checksum="sha256sum --ignore-missing -c";
            CRR_type='NetBSD_64' # ToDo
            CRR_rel="NetBSD-$CRR_version";
            CRR_desc="NetBSD Unix $CRR_version" # ToDo
            CRR_family='NetBSD Unix' # ToDo
        ;;
        (*)
            RAISE "unknown OS ISO Image:" "$CRR_OS"
        ;;
    esac
    CRR_local_iso="$local_downloads/`echo $CRR_repo_iso | sed 's/?.*//; s?^.*/??'`"
    CRR_local_iso_checksum="$local_downloads/`basename $CRR_local_iso .iso`.CHECKSUM"
    CRR_local_custom_iso="$local_downloads/`basename $CRR_local_iso .iso`-custom.iso"
    CRR_hostname="$(echo $CRR_local_iso | normalise_hostname)-$CRR_VM"

    CRR_LABELS="$CRR_hostname"

    if [ ! "$OPT_debug" ]; then
        CRR_local_template="$local_tmpdir/`basename $CRR_local_iso .iso`.XXXXXXXX"
        TMP_WORKDIR=`mktemp -d $CRR_local_template`
    else
        CRR_local_template="$local_tmpdir/`basename $CRR_local_iso .iso`.ZZZZZZZZ"
        TMP_WORKDIR=`echo $CRR_local_template`
    fi

    VM_NAME="$CRR_hostname"
}

# Defects:
# Install?
# Root access?

ARG_L="
O/rocky-x86_64      +ssh_root -enter-to-install .cdrom-eject .runner
O/rhel-x86_64       +ssh_root -enter-to-install .cdrom-eject .runner
O/centos-x86_64     +ssh_root -enter-to-install .cdrom-eject .runner
d/fedora-x86_64     +ssh_root +enter-to-install -cdrom-eject .runner
s/ubuntu-amd64      +ssh_root -enter-to-install .cdrom-eject .runner
O/debian-amd64      +ssh_root -enter-to-install +cdrom-eject .runner
O/opensuse-x86_64   +ssh_root                   -cdrom-eject .runner
O/freebsd-amd64     -ssh_root -enter-to-install .cdrom-eject .runner
"

depr_get_vm_ip (){
    # Extract MAC address of the VM
    re_mac="$(VBoxManage showvminfo "$1" --machinereadable |
        sed '/^macaddress[0-9]*=/!d;
            s/"$//; s/.*"//;
            s/\([A-F]\)/\L\1/g;
            s/\(..\)/\1:/g;s/:$//;' |
            sed ':a; N; $!ba; s/\n/|/g')"

    # Find the IP address using the ARP table
    ip neigh | grep -E "$re_mac" | awk '{ print $1 }'
}

# awk '/^[a-z_]* \(\){/ { print "        (--"$1"|"$1") "$1" \"$@\";;"; }' bin/create_self_hosted_runner_on_vm.sh

if [ "$#" == "0" ]; then
    set -- $ARG_L
fi

CRR_OS_L=""

for ARG in "$@"; do
    case "$ARG" in
        (--help)help;;
        (-*|+*|/*|.*)false;; # -/bad; +/good, ./unknown
        ([Tt]*/*)true;; # ToDo
        ([Oo]*/*)true;; # OK/Done
        ([Ss]*/*)true;; # Skip
        ([Dd]*/*|/*|*) # Do .. build now
            CRR_OS=`basename -- $ARG`
            CRR_OS_L="$CRR_OS_L $CRR_OS"
        ;;
        (*) echo "Huh? CRR_OS=$CRR_OS";;
    esac
done

CRR_NIC_NUM=2
CRR_SSH_PORT=22

is_vm_started(){
    local vm="$1"
    local nic="$2"
    get_ip_of_vm_nic "$vm" "$nic" &&
        is_open_host_port "$ip_address" "$CRR_SSH_PORT" # &&
            # ssh $OPT_ssh "root@$ip_address" hostname
}


is_vm_ssh_started(){
    local vm="$1"
    local nic="$2"
    get_ip_of_vm_nic "$vm" "$nic" &&
        ip_up_host "$ip_address" &&
          is_open_host_port "$ip_address" "$CRR_SSH_PORT" # &&
              ssh $OPT_ssh "root@$ip_address" hostname
}

is_vm_pingable(){
    local vm="$1"
    local nic="$2"
    get_ip_of_vm_nic "$vm" "$nic" &&
        ip_up_host "$ip_address"
        #is_open_host_port "$ip_address" "$CRR_SSH_PORT" # &&
        #    ssh $OPT_ssh "root@$ip_address" hostname
}

is_vm_stopped(){
    local vm="$1"
    local nic="$2"
    NOT is_vm_started "$vm" "$nic"
}

build_all_custom_isos_and_vms(){
    for CRR_OS in $CRR_OS_L; do
        setenv_target_vm
        get_upstream_os_iso
        create_custom_iso # now with create_install_script;
        create_custom_vm
    done
}

snapshot_all_vms(){
    for CRR_OS in $CRR_OS_L; do
        setenv_target_vm
        if is_vm_started "$CRR_hostname" "$CRR_NIC_NUM"; then 
            shutdown_vm; 
        fi
        # WAIT_UNTIL is_vm_stopped "$CRR_hostname" "$CRR_NIC_NUM" &&         
        WAIT_WHILE is_vm_pingable "$CRR_hostname" "$CRR_NIC_NUM" || {
            sleep 6
            ASSERT VBoxManage storageattach "$VM_NAME" --storagectl 'IDE Controller' --port 0 --device 0 --type dvddrive --medium none
            sleep 6
            snapshot_vm vanilla && sleep 12
        }
    done
}

run_on_each_vm(){
    for CRR_OS in $CRR_OS_L; do
        setenv_target_vm

        if is_vm_stopped "$CRR_hostname" "$CRR_NIC_NUM"; then start_vm && sleep 24; fi

        #ip_address=`get_ip_of_vm_nic $CRR_hostname $CRR_NIC_NUM`

        WAIT_UNTIL is_vm_started "$CRR_hostname" "$CRR_NIC_NUM" && {
            echo_Q started: "$CRR_hostname" "$CRR_NIC_NUM" cmd_l="$@"
            for cmd in "$@"; do
                [ "$cmd" = "shutdown_vm" ] && break
                # ssh $OPT_ssh root@$ip_address
                # AR_prep_VM_inst "$CRR_hostname" "$ip_address"
                ASSERT "$cmd" "$CRR_hostname" "$ip_address"
            done
        }
        [ "$cmd" = "shutdown_vm" ] &&
            shutdown_vm &&
               WAIT_UNTIL is_vm_stopped "$CRR_hostname" "$CRR_NIC_NUM" && echo stopped: "$CRR_hostname" "$CRR_NIC_NUM"
        # destroy_vm
    done
}

build_all_custom_isos_and_vms
run_on_each_vm true shutdown_vm # installation phase 1

snapshot_all_vms # each VM is stopped, & DVD ejected for snapshot

CRR_REPO_LIST="NevilleDNZ-download/algol68_autopkg-download"
#CRR_REPO_LIST="NevilleDNZ/algol68_autopkg"

run_on_each_vm AR_prep_VM_inst AR_configure AR_run AR_status
#run_on_each_vm                 AR_configure AR_run AR_status

#run_on_each_vm AR_prep_VM_inst 
#run_on_each_vm AR_run 
#run_on_each_vm AR_kill 
#run_on_each_vm shutdown_vm # use shutdown_vm when you cannot run all vm's at once.

#run_on_each_vm AR_prep_VM_inst
#run_on_each_vm AR_configure
#run_on_each_vm AR_run
#run_on_each_vm AR_kill
#run_on_each_vm AR_remove
#run_on_each_vm shutdown_vm # assumes vms need to be started first

exit $?
