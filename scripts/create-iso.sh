#!/bin/bash
shopt -s expand_aliases
source ~/.bash_aliases

PATH_REPO_ROOT="$(git rev-parse --show-toplevel)"
PATH_VAGRANTFILE_DIR="${PATH_REPO_ROOT}"

CLUSTERS_ALL=(
    $(ls "${PATH_REPO_ROOT}/clusters")
)
CLUSTERS=(
    ${CLUSTERS_ALL[0]}
)

FLAG_MISSING_COMMAND=0

REPO_NAME=$(basename "${PATH_REPO_ROOT}")
REQUIRED_COMMANDS=(
  "vagrant"
  "virtualbox"
)

VAGRANT_BOX_PATH_ISO="/vagrant/.iso"

log () {
  if [[ ${1} = "info" ]]; then
    echo "[INFO] ${2}"

  elif [[ ${1} == "success" ]]; then
    echo "[SUCCESS] Succesfully $2"

  elif [[ ${1} = "error" ]]; then
    if [[ ${#} = 3 && ${2} =~ ^[0-9]+$ ]]; then
      >&2 echo "[ERROR] ${3}"
      exit ${2}

    else
      >&2 echo "[ERROR] ${2}"
    fi
  fi
}

help(){
  echo "
  Creates CoreOS ISO for Virtual Machine and Bare Metal Nodes

  Usage:
    $0 [Options]

  Options:
    -a   , --all           Create CoreOS ISO for all clusters
    -c '', --cluster=''    Comma-delimited list of clusters. Create CoreOS ISO for specified clusters. Default: ${CLUSTERS[@]}
    -h   , --help          Show usage and exit
  "
  exit 0
}

get_input(){
  while [ $# -gt 0 ]; do
    case "$1" in
      -a|--all)      CLUSTERS=(${CLUSTERS_ALL[@]});;
      --cluster=*)   CLUSTERS=($(echo "${1#*=}" | tr ',' '\n' | uniq));;
      -c)            CLUSTERS=($(echo "${2}" | tr ',' '\n' | uniq)); shift;;
      -h|--help)     help; exit 0;;
      *)             log error 1 "Invalid option: ${1#*}. Use $0 -h or $0 --help for more info";;
    esac
    shift
  done
}

check_commands(){
  for command in $@; do
    log info "Checking command: ${command}"

    # Check command
    if [ -z "$(type -t ${command})" ]; then
      FLAG_MISSING_COMMAND=1
      log error "Command not found: ${command}"
    fi
  done

  if [ ${FLAG_MISSING_COMMAND} -ne 0 ]; then
    log error 1 "Install missing commands. Check https://github.ibm.com/digitalprojects/platform-coe-workstation/blob/master/setup.sh"
  fi
}

# Initialize vagrant box
vagrant_box_init(){
    log info "Initializing vagrant box"
    cd "${PATH_VAGRANTFILE_DIR}"
    vagrant up --provision
}

# Create ISO
create_iso(){
    local cluster="$1"

    log info "Creating ISO for cluster: ${cluster}"
    cd "${PATH_VAGRANTFILE_DIR}"

    vagrant ssh -c "
        mkdir -p `dirname ${VAGRANT_BOX_PATH_ISO}`
        cd `dirname ${VAGRANT_BOX_PATH_ISO}`
        cp -prv clusters/${cluster}/* .

        # Create VM ISO
        ansible-playbook playbook-single.yml -i inventory.yml

        # Rename ISO
        sudo mkdir -p ${VAGRANT_BOX_PATH_ISO}/${cluster}
        sudo mv /tmp/rhcos-install-cluster.iso ${VAGRANT_BOX_PATH_ISO}/${cluster}/rhcos-install-cluster.iso

        # Cleanup
        git checkout -- .
    "
}

main(){
    check_commands ${REQUIRED_COMMANDS[@]}

    get_input ${@}

    vagrant_box_init

    for cluster in ${CLUSTERS[@]}; do
      create_iso "${cluster}"
    done

    log info "Saved ISOs to ${PATH_REPO_ROOT}/.iso"
}

main ${@}
