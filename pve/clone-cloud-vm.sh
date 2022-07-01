#!/bin/bash
set -e

VERSION="0.1"
RED='\033[0;31m'
GREEN='\033[0;32m'
LGREEN='\033[1;32m'
BROWN='\033[0;33m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

STORAGE_POOL="Shared-LVM"
TEMPLATE_ID="9999"
TARGET_NODE=$(hostname)
DATADISK_PATH="/mnt/pve/Shared/"
DATADISK_FILE="datadisk.qcow2"
SNIPPETS_STORAGE_POOL="Shared"
SNIPPETS_FOLDER="${DATADISK_PATH}snippets"
VM_ID=$(sudo pvesh get /cluster/nextid)
USER_FILE="user.yaml"
NETWORK_FILE="network.yaml"
PASSWORD='$5$47YydcdN$MC/TH3x7ztc113w8cBTtw2PpIdqS19gya7pvyqahCQ0'

function pause (){
    read -p "Press any key to resume ..."
}
function show_menu(){
    normal=`echo "\033[m"`
    menu=`echo "\033[36m"` #Blue
    number=`echo "\033[33m"` #yellow
    bgred=`echo "\033[41m"`
    fgred=`echo "\033[31m"`
    printf "\n${menu}******************************************************************${normal}\n"
    printf "${menu}**${number} 1)${menu} Select VM Template               ${GREEN}(Current is ${TEMPLATE_ID})${menu}        ** ${normal}\n"
    printf "${menu}**${number} 2)${menu} Select Storage Pool              ${GREEN}(Current is ${STORAGE_POOL})${menu}  **  ${normal}\n"
    printf "${menu}**${number} 3)${menu} Select Target Node               ${GREEN}(Current is ${TARGET_NODE})${menu} **  ${normal}\n"
    printf "${menu}**${number} 4)${menu} Create VM form Template ${menu}                                  ** ${normal}\n"
    #printf "${menu}**${number} 5)${menu} Create Cloudinit Files in folder ${LGREEN}${SNIPPETS_FOLDER}${menu} ** ${normal}\n"
    #printf "${menu}**${number} 6)${menu} Some other commands${normal}\n"
    printf "${menu}******************************************************************${normal}\n"
    printf "Please enter a menu option and enter or ${fgred}x to exit. ${normal}"
    read -n 1 -r opt
}

function create_vm(){
    VM_ID=$(sudo pvesh get /cluster/nextid)
    DATADISK=
    printf "${LGREEN}Create VM from Template...${NC}${YELLOW}\n";
    read -n 4 -r -p "Enter VM ID (${VM_ID}) " NEW_VM_ID;
    if ! [ -z "${NEW_VM_ID}" ]
    then 
        VM_ID="${NEW_VM_ID}"
    fi
    if ! [ -z "${VM_ID}" ]
    then   
        printf "${NC}"
        set +e
        sudo pvesh get /cluster/nextid -vmid "${VM_ID}" >/dev/null 2>&1                
        status=$? # store exit status of pvesh                
        set -e
        if ! test "${status}" -eq 0
        then
            printf "${RED}VMID ${VM_ID }is already used.${NC}\n"
        else
            printf "${GREEN}Given VM ID ${VM_ID} is OK ${NC}\n"
        fi                
    else
        printf "${RED}Given VM ID ${VM_ID} is not OK ${NC}\n"
        return  
    fi
    printf "${BROWN}" 
    read -r -p "Enter VM Name " VM_NAME;
    if ! [ -z "${VM_NAME}" ]
    then 
        while [ -z "${DATADISK}" ] ; do
            printf "${YELLOW}" 
            read -r -p "Do you wish include additional data disk to VM? (Y/N): " answer
            case "${answer}" in
                [Yy]* ) DATADISK=1;;
                [Nn]* ) DATADISK=0;;
                * ) echo "Please answer Y or N.";;
            esac
        done
    else
        printf "${RED} Given VM Name ${VM_NAME} is not OK ${NC}\n"
        pause;
        return
    fi
    clear;
    printf "${LGREEN}Create VM ${VM_ID} ${VM_NAME} from template ${TEMPLATE_ID}\n"
    printf "Used Storage Pool is ${STORAGE_POOL} ${NC}\n"
    if  test "${DATADISK}" -eq 1
    then 
        printf "${LGREEN}Datadisk template is ${DATADISK_PATH}${DATADISK_FILE} ${NC}\n"
    fi
    pause;
    sudo qm clone "${TEMPLATE_ID}" "${VM_ID}" -full -name "${VM_NAME}" -storage "${STORAGE_POOL}" 
    if  test "${DATADISK}" -eq 1
    then                
        sudo qm importdisk "${VM_ID}" "${DATADISK_PATH}""${DATADISK_FILE}" "${STORAGE_POOL}"
        sudo qm set "${VM_ID}" --scsihw virtio-scsi-pci --scsi1 "${STORAGE_POOL}":vm-"${VM_ID}"-disk-2
    fi
    pause;
}

function write_mounts(){

printf "${LGREEN}Write mounts to ${SNIPPETS_FOLDER}/${VM_ID}-${USER_FILE} ${NC}\n";
tee -a "${SNIPPETS_FOLDER}/${VM_ID}-${USER_FILE}" >/dev/null <<EOF 
mounts:
- [ /dev/vg_data/lv_data, /gurulandia, "auto", "defaults", "0", "0" ]
mount_default_fields: [ None, None, "auto", "defaults,nofail", "0", "2" ]
EOF

}

function write_userfile(){
printf "${LGREEN}Create file ${SNIPPETS_FOLDER}/${VM_ID}-${USER_FILE} ${NC}\n";
tee "${SNIPPETS_FOLDER}/${VM_ID}-${USER_FILE}" >/dev/null <<EOF
#cloud-config
write_files:
  - path: /etc/sysctl.d/10-disable-ipv6.conf
    permissions: "0644"
    owner: root:root
    content: |
      net.ipv6.conf.all.disable_ipv6 = 1
      net.ipv6.conf.default.disable_ipv6 = 1
      net.ipv6.conf.lo.disable_ipv6 = 1
hostname: ${VM_HOSTNAME}
manage_etc_hosts: true
fqdn: ${VM_FDQN}
timezone: "Europe/Helsinki"
user: gurulandia
password: ${PASSWORD}
sudo: "ALL=(ALL) NOPASSWD:ALL"
ssh_authorized_keys:
  - ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAqdkxDns+s3C6Vjl0BRLxj2YKgNx9aAnqw5QPe3Mm0I7tgBn0qjZ8r4KRweUaJQYtRaxctFRt9y+AaW2MAGDGJsfdTL992QSAZBtsEEt+7vC9QfUYKwzBafZAUZlKAWo17U72JKHmbqZCCUPl6oIYX4AxtWXGFY27Kh4VUb7nSync9l6JOleSRIVWq0/KLAcf8Rvw1JiNU8y1C0c3Yk2l8hzU2gZGIXSP798U/ggzoRFE716132GMxzhlwvQXlVrNR2fI0IPxJrJiAaLLVc6+GueiIez3G4lz1HNRCuVy2NSIy3k55jqYyNR1DYf7/BQNJvuWgbd8T2pPdVfOs5LlOQ== Gurulandia Key
chpasswd:
  expire: False
users:
  - default
packages:
 - qemu-guest-agent
 - vlan
 - nfs-common
 - apache2-utils
 - pwgen
 - iftop
package_update: true
package_upgrade: true
package_reboot_if_required: true
EOF

}

function create_userfile(){
VM_HOSTNAME=
VM_FDQN=
while [ -z "${VM_HOSTNAME}" ] ; do
    printf "${YELLOW}";
    read -r -p "Enter VM Host Name " VM_HOSTNAME;    
done
while [ -z "${VM_FDQN}" ] ; do
    printf "${BROWN}";
    read -r -p "Enter VM fdqn Name " VM_FDQN;    
done
write_userfile;
if ! [ -z "${DATADISK}" ]
then
    if  test "${DATADISK}" -eq 1
    then 
        write_mounts;
    fi
fi
}

function write_networkfile(){
printf "${LGREEN}Create file ${SNIPPETS_FOLDER}/${VM_ID}-${NETWORK_FILE} ${NC}\n";
tee "${SNIPPETS_FOLDER}/${VM_ID}-${NETWORK_FILE}" >/dev/null <<EOF
network:
  version: 1
  config:
    - type: physical
      name: enp6s18
      subnets:
      - type: static
        address: '${VM_IP}'
        netmask: '255.255.255.0'
        gateway: '${VM_GW}'
    - type: nameserver
      address:
      - '192.168.99.250'
      - '1.1.1.1'
      search:
      - 'mgmt.gurulandia.lan'
EOF
}

function add_vlan(){
echo -e "${LGREEN}Add vlan ${VM_VLAN_ID} to file ${SNIPPETS_FOLDER}/${VM_ID}-${NETWORK_FILE} ${NC}";
tee -a "${SNIPPETS_FOLDER}/${VM_ID}-${NETWORK_FILE}" >/dev/null  <<EOF
    - type: vlan
      name: ${VM_VLAN_NAME}
      vlan_link: enp6s18
      vlan_id: ${VM_VLAN_ID}
      subnets:
      - type: static
        address: '192.168.${VM_VLAN_ID}.${CN}'
        netmask: '255.255.255.0'
        gateway: '192.168.${VM_VLAN_ID}.1'
EOF
}

function create_networkfile(){
VM_IP=
VM_GW=
VM_VLAN=
VLAN_COUNT=
while [ -z "${VM_IP}" ] ; do    
    printf "${YELLOW}" 
    read -r -p "Enter VM IP Address " VM_IP;    
done
while [ -z "${VM_GW}" ] ; do
    printf "${BROWN}"
    read -r -p "Enter VM Default Gateway " VM_GW;    
done
write_networkfile;
CN="${VM_IP##*.}"
while [ -z "${VM_VLAN}" ] ; do
    printf "${YELLOW}" 
    read -r -p "Do you want config any vlan to VM? (Y/N): " answer
    case "${answer}" in
        [Yy]* ) 
                VM_VLAN=1
                echo  "  # VLAN interfaces." | tee -a "${SNIPPETS_FOLDER}/${VM_ID}-${NETWORK_FILE}" >/dev/null 
                ;;
        [Nn]* ) VM_VLAN=0;;
        * ) echo "Please answer Y or N.";;
    esac
done

if ! [ -z "${VM_VLAN}" ]
then
    if  test "${VM_VLAN}" -eq 1
    then 
        while [ -z "${VLAN_COUNT}" ] ; do
            printf "${BROWN}"
            read -r -p "How many vlan to be configured to VM?: " VLAN_COUNT
        done        
        for ((i=1;i<=VLAN_COUNT;i++)); do
            while [ -z "${VM_VLAN_NAME}" ] ; do
                printf "${YELLOW}" 
                read -r -p "Enter VLAN $i Name " VM_VLAN_NAME;    
            done
            while [ -z "${VM_VLAN_ID}" ] ; do
                printf "${BROWN}"
                read -r -p "Enter VLAN $i ID " VM_VLAN_ID;    
            done    
            add_vlan;
            VM_VLAN_NAME=
            VM_VLAN_ID=             
        done
    fi
fi
}
printf "${NC}"
clear
show_menu
echo $opt
while [ $opt != "" ]
    do
    if [ $opt = "" ]; then
      exit;
    else
      case $opt in
        1) clear;
            printf "${LGREEN}Select Template to clone...${NC}${YELLOW}\n";            
            read -n 4 -r -p "Enter Template ID " NEW_TEMPLATE_ID;            
            printf "${NC}\nChecking Given ID...\n";
            if ! [ -z "${NEW_TEMPLATE_ID}" ]
            then      
                set +e    
                TID=$(sudo cat /etc/pve/.vmlist | grep "${NEW_TEMPLATE_ID}" | tr -d '":,'| awk '{print $1 }' | sort -n | column -t) #ID
                if ! [ -z "${TID}" ]
                then
                    sudo qm config ${TID} | grep -q -i "Template"  >/dev/null 2>&1
                    status=$?
                    set -e
                    if test "${status}" -eq 0
                    then
                        TEMPLATE_ID="${NEW_TEMPLATE_ID}"  
                        printf "${GREEN}Given VM ID ${TEMPLATE_ID} is OK ${NC}\n"
                    else
                        printf "${RED}Given ID ${NEW_TEMPLATE_ID} is not OK ${NC}\n"
                    fi   
                else
                    printf "${RED}Given ID ${NEW_TEMPLATE_ID} is not OK ${NC}\n"
                fi
            fi      
            show_menu;
        ;;
        2) clear;            
            printf "${LGREEN}Select Storage Pool${NC}${BROWN}\n";            
            read -r -p "Enter Storage Pool " NEW_STORAGE_POOL;
            printf "${NC}";
            if ! [ -z "${NEW_STORAGE_POOL}" ]
            then                
                set +e
                sudo pvesh get /storage | grep -q -i "${NEW_STORAGE_POOL}"                
                status=$? # store exit status of pvesh                
                set -e
                if  test "${status}" -eq 0
                then
                    printf "${GREEN}Storage Pool ${STORAGE_POOL} is changed to ${NEW_STORAGE_POOL}.${NC}\n"
	                STORAGE_POOL="${NEW_STORAGE_POOL}"                            
                else
	                printf "${RED}Given Storage Pool ${NEW_STORAGE_POOL} is not valid storage pool${NC}\n"
                fi                
            fi
            show_menu;
        ;;
        3)  clear;            
            printf "${LGREEN}Select Target Node${NC}${BROWN}\n";            
            read -r -p "Enter Target Node " NEW_TARGET_NODE;
            printf "${NC}";
            if ! [ -z "${NEW_TARGET_NODE}" ]
            then                
                set +e                
                sudo pvesh get /nodes --noborder=1 --noheader=1 | awk '{print $1}' | grep "${NEW_TARGET_NODE}" >/dev/null 
                status=$? # store exit status of pvesh                
                set -e
                if  test "${status}" -eq 0
                then
                    printf "${GREEN}Target Node is ${TARGET_NODE} is changed to ${NEW_TARGET_NODE}.${NC}\n"
	                TARGET_NODE="${NEW_TARGET_NODE}"                            
                else
                    printf "${RED}Given Target Node ${NEW_TARGET_NODE} is not valid target node${NC}\n"
                fi                
            fi        
            show_menu;
        ;;
        4)  clear;            
            create_vm            
            clear;
            create_userfile;   
            create_networkfile;         
            sudo qm set "${VM_ID}" -cicustom user="${SNIPPETS_STORAGE_POOL}":snippets/"${VM_ID}-${USER_FILE}",network="${SNIPPETS_STORAGE_POOL}":snippets/"${VM_ID}-${NETWORK_FILE}" -citype nocloud >/dev/null 
            if [ $TARGET_NODE != $(hostname) ]
            then                
               sudo qm migrate "${VM_ID}" "${TARGET_NODE}" >/dev/null 
            fi
            show_menu;
        ;;
        #5) clear;
            #create_userfile;   
            #create_networkfile;         
            #sudo qm set "${VM_ID}" -cicustom user="${SNIPPETS_STORAGE_POOL}":snippets/"${VM_ID}-${USER_FILE}",network="${SNIPPETS_STORAGE_POOL}":snippets/"${VM_ID}-${NETWORK_FILE}" -citype nocloud
            #printf "ssh lmesser@ -p 2010";
        #    show_menu;
        #;;
        x)  printf "\n"
            exit;
        ;;
        *)clear;            
          show_menu;
        ;;
      esac
    fi
done
