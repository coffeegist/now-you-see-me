#!/bin/bash
# Now You See Me
# br0wnie

NORMAL=`echo "\033[m"`
BRED=`printf "\e[1;31m"`
BGREEN=`printf "\e[1;32m"`
BYELLOW=`printf "\e[1;33m"`
COLUMNS=12

nysm_action() {
  printf "\n${BGREEN}[+]${NORMAL} $1\n"
}

nysm_warning() {
  printf "\n${BYELLOW}[!]${NORMAL} $1\n"
}

nysm_error() {
  printf "\n${BRED}[!] $1${NORMAL}\n"
}

error_exit() {
  echo "\n$1\n" 1>&2
  exit 1
}

check_errors() {
  if [ $? -ne 0 ]; then
    nysm_error "An error occurred..."
    error_exit "Exiting..."
  fi
}

create_socat() {
  read -r -p "What port should socat listen on? " inbound_port
  read -r -p "What IP/hostname should socat forward data to? " outbound_host
  read -r -p "What port should socat forward data to? " outbound_port

  socat -d -d -lf /var/log/socat.log TCP-LISTEN:$inbound_port,fork TCP-CONNECT:$outbound_host:$outbound_port &

  netstat -tlpn | grep socat | grep $inbound_port
}

nysm_confirm() {
  read -r -p "$1 [y/N] " response
  case "$response" in
      [yY][eE][sS]|[yY])
          return 0
          ;;
      *)
          return 1
          ;;
  esac
}

nysm_install() {
  nysm_action "Installing Dependencies..."

  nysm_action "Updating apt-get..."
  apt-get update
  check_errors

  nysm_action "Installing general net tools..."
  apt-get install -y inetutils-ping net-tools screen dnsutils curl
  check_errors

  nysm_action "Installing nginx, socat..."
  apt-get install -y socat nginx
  check_errors

  nysm_action "Finished installing dependencies!"
}

nysm_start() {
  nysm_action "Starting servers..."

  nysm_action "Starting nginx..."
  service nginx start
  check_errors
  nysm_action "Nginx is running!"

  nysm_action "Starting socat..."
  while nysm_confirm "Do you want to add an instance of socat?"; do
    create_socat
    printf "\n"
    check_errors
  done
}

nysm_status() {
  printf "\n************************ Processes ************************\n"
  ps aux | grep nginx | grep -v grep
  ps aux | grep socat | grep -v grep

  printf "\n************************* Network *************************\n"
  netstat -tulpn | grep socat
}

PS3="
NYSM - Select an Option:  "

finshed=0
while (( !finished )); do
  printf "\n"
  options=("Install Dependencies" "Start Servers" "Add Socat Instance" "Check Status" "Quit")
  select opt in "${options[@]}"
  do
    case $opt in
      "Install Dependencies")
        nysm_install
        break;
        ;;
      "Start Servers")
        nysm_start
        break;
        ;;
      "Add Socat Instance")
        create_socat
        break;
        ;;
      "Check Status")
        nysm_status
        break;
        ;;
      "Quit")
        finished=1
        break;
        ;;
      *) nysm_warning "invalid option" ;;
    esac
  done
done
