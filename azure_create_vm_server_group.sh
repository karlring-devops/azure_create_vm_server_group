#!/bin/bash
# VERSION - 20/12/2021 17:52pm
#-----------------------------------------

#\****************************************/#
#|  basic functions                      |
#/----------------------------------------\#

function __MSG_HEADLINE__(){
    echo "[INFO]  ===== ${1} ====="
}
function __MSG_LINE__(){
    echo "-------------------------------------------------"
}
function __MSG_BANNER__(){
    __MSG_LINE__
    __MSG_HEADLINE__ "${1}"
    __MSG_LINE__

}
function __MSG_INFO__(){
     echo "[INFO]  ${1}: ${2}"
}


function azenv(){
    __MSG_BANNER__ "${1}"
    AZ_RESOURCE_GROUP_NAME="rg-${AZ_CLUSTER_GROUP_NAME}-1"
    AZ_RESOURCE_LOCATION="westus2"
    AZ_PUBLIC_IP="ip-pub-${AZ_RESOURCE_GROUP_NAME}-lb"
    AZ_PUBLIC_IP_VM_NAME="ip-pub-${AZ_RESOURCE_GROUP_NAME}-vm"
    # AZ_PUBLIC_IP_VM_2="ip-pub-${AZ_RESOURCE_GROUP_NAME}-vm-2"
    # AZ_PUBLIC_IP_VM_3="ip-pub-${AZ_RESOURCE_GROUP_NAME}-vm-3"
    AZ_LOADBALANCER="lb-${AZ_RESOURCE_GROUP_NAME}"
    AZ_IP_POOL_FRONTEND="ip-pool-${AZ_RESOURCE_GROUP_NAME}-frontend"
    AZ_IP_POOL_BACKEND="ip-pool-${AZ_RESOURCE_GROUP_NAME}-backend"
    AZ_VM_NET_PRIMARY="vnet-${AZ_RESOURCE_GROUP_NAME}"
    AZ_LOADBALANCER_PROBE="${AZ_RESOURCE_GROUP_NAME}-probe-health"
    AZ_LOADBALANCER_RULE="${AZ_RESOURCE_GROUP_NAME}-rule"
    AZ_VM_NET_SUBNET="${AZ_RESOURCE_GROUP_NAME}-subnet"
    AZ_NET_SVC_GROUP="nsg-${AZ_RESOURCE_GROUP_NAME}"
    AZ_NET_SVC_GROUP_RULE="nsg-${AZ_RESOURCE_GROUP_NAME}-rule"
    AZ_VM_AVAIL_SET="avset-${AZ_RESOURCE_GROUP_NAME}"
    AZ_VM_NAME_ROOT="vm-${AZ_RESOURCE_GROUP_NAME}"
    AZ_VM_NET_PRIMARY_NIC="${AZ_RESOURCE_GROUP_NAME}-nic"
    # getenv 'AZ_'
    set | grep AZ_ | grep '=' | egrep -v '\(\)|;|\$'
}

function az_create_resource_group(){
    azenv az_create_resource_group
    __MSG_LINE__
    echo "Create ResourceGroup: ${AZ_RESOURCE_GROUP_NAME}: (yes/no) ?"
    __MSG_LINE__
    read CR8_RSG
    if [[ "${CR8_RSG}" == "yes" ]] ; then 
      __MSG_INFO__ Creating "ResourceGroup: ${AZ_RESOURCE_GROUP_NAME}"
      azenv az_create_resource-group
      az group create --name ${AZ_RESOURCE_GROUP_NAME} --location ${AZ_RESOURCE_LOCATION}
    fi    
}

function az_create_network-ip-public(){
      azenv az_create_network-ip-public
    __MSG_INFO__ Creating "Public-Ip: ${1}"

    az network public-ip create \
        --resource-group ${AZ_RESOURCE_GROUP_NAME} \
        --name ${1} \
        --allocation-method Static
}

function az_create_network-vnet(){
    azenv az_create_network-vnet
    __MSG_INFO__ Creating "VMNetwork: ${AZ_VM_NET_PRIMARY}"

    az network vnet create \
        --resource-group ${AZ_RESOURCE_GROUP_NAME} \
        --name ${AZ_VM_NET_PRIMARY} \
        --subnet-name ${AZ_VM_NET_SUBNET}
}

function az_create_network-group-service(){
    azenv az_create_network-group-service
    __MSG_INFO__ Creating "NetworkServiceGroup: ${1}"
    az network nsg create \
        --resource-group ${AZ_RESOURCE_GROUP_NAME} \
        --name ${1}
}

function az_create_network_group_service_rules_rke(){
    azenv az_create_network_group_service_rules_rke
    #-- open single ports --
    #AZ_RESOURCE_GROUP_NAME="rg-${AZ_CLUSTER_GROUP_NAME}-1"
    AZ_NET_SVC_GROUP="${1}"
    AZ_NET_SVC_GROUP_RULE="${AZ_NET_SVC_GROUP}-rule"

    #->https://rancher.com/docs/rancher/v2.5/en/installation/requirements/ports/#ports-for-rancher-server-nodes-on-rancherd-or-rke2
    # Commonly Used Ports - These ports are typically opened on your Kubernetes nodes, regardless of what type of cluster it is.
    
    PORTS_TCP='22 80 443 4043 5000 5001'
    i=100
    for p in ${PORTS_TCP}
     do
       az network nsg rule create --name "${AZ_NET_SVC_GROUP_RULE}-${i}-${p}" \
       		  --resource-group ${AZ_RESOURCE_GROUP_NAME} \
            --nsg-name ${AZ_NET_SVC_GROUP} \
            --priority ${i} \
            --access Allow \
            --source-address-prefixes '*' \
            --source-port-ranges '*' \
            --destination-address-prefixes '*' \
            --destination-port-ranges ${p} \
            --protocol Tcp
         ((i=i+1))
    done
}

function az_create_sshkeys(){
      azenv az_create_sshkeys
      AZ_SSHKEY_NAME="${1}"

      # for i in `seq 1 8`
      #  do
          az sshkey create --location ${AZ_RESOURCE_LOCATION} \
                           -g ${AZ_RESOURCE_GROUP_NAME} \
                           --name ${AZ_SSHKEY_NAME}
      # done
}

function az_create_vm-availability-set(){
    azenv az_create_vm-availability-set
    az vm availability-set create \
        --resource-group ${AZ_RESOURCE_GROUP_NAME} \
        --name ${AZ_VM_AVAIL_SET}
}

          # function az_disk_create(){
          #       diskNumber=${1}
          #       diskSizeGiB=${2}
          #       diskLocation=${3}
          #       diskName=disk-${AZ_RESOURCE_GROUP_NAME}-1-${diskNumber}

          #       az disk create -g ${AZ_RESOURCE_GROUP_NAME} \
          #             -n ${diskName} \
          #             --size-gb ${diskSizeGiB} \
          #             --location ${diskLocation} 
          #       export AZ_DISK_SPARE_NAME=${diskName}
          # }

function az_disk_attach(){
      diskNumber=${1}
      diskSizeGiB=${2}
      vmName="${3}"
      diskName="disk-${AZ_RESOURCE_GROUP_NAME}-1-${diskNumber}"

      az vm disk attach -g ${AZ_RESOURCE_GROUP_NAME} \
             --vm-name ${vmName} \
             --name ${diskName} \
             --new \
             --size-gb ${diskSizeGiB}
}


function az_create_vm_machine(){
    azenv az_create_vm_machine
    # for i in `seq 1 8`; do

      vmName="${1}"
      networkServiceGroup="${2}"   #-- "vm-${AZ_RESOURCE_GROUP_NAME}-${i}-nsg"
      sshKeyName="${3}"            #-- sshkey-${AZ_RESOURCE_GROUP_NAME}-vm-${i}
      attachDiskName="${4}"

       az vm create \
            --resource-group ${AZ_RESOURCE_GROUP_NAME} \
            --name ${vmName} \
            --availability-set ${AZ_VM_AVAIL_SET} \
            --image UbuntuLTS \
            --admin-username azureuser \
            --no-wait \
            --accelerated-networking true \
            --nsg ${networkServiceGroup} \
            --ssh-key-name ${sshKeyName} \
            --attach-data-disks ${attachDiskName}
    # done
            # \ # --nics ${AZ_VM_NET_PRIMARY_NIC}-$i \
            # --custom-data `pwd`/az-cloud-init.txt \
}


#/***********************************************************************/#
#| BUILD SERVER
#/-----------------------------------------------------------------------/#
AZ_CLUSTER_GROUP_NAME=${1}        #-- dtrprivate
AZ_CLUSTER_DISK_ATTACH_SIZE=${2}  #-- 128

function az_server_create(){
          azenv az_server_create
					az_create_resource_group

					az_create_network-ip-public ${AZ_PUBLIC_IP}
					az_create_network-vnet
					az_create_network-group-service ${AZ_NET_SVC_GROUP}
					az_create_network-group-service "vm-${AZ_RESOURCE_GROUP_NAME}-1-nsg"
                    az_create_network_group_service_rules_rke "vm-${AZ_RESOURCE_GROUP_NAME}-1-nsg"

					az_create_sshkeys "sshkey-${AZ_RESOURCE_GROUP_NAME}-vm-1"

					az_create_vm-availability-set
					az_create_vm_machine "${AZ_VM_NAME_ROOT}-1" "vm-${AZ_RESOURCE_GROUP_NAME}-1-nsg" "sshkey-${AZ_RESOURCE_GROUP_NAME}-vm-1" ${AZ_DISK_SPARE_NAME}
                    az_disk_attach 1 ${AZ_CLUSTER_DISK_ATTACH_SIZE} "${AZ_VM_NAME_ROOT}-1" 
          

}

# az_server_create



#/***********************************************************************/#
