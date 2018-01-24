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
  echo -e "\n$1\n" 1>&2
  exit 1
}

check_errors() {
  if [ $? -ne 0 ]; then
    nysm_error "An error occurred..."
    error_exit "Exiting..."
  fi
}

create_socat_instance() {
  if [ -z "$1" ]; then
    read -r -p "What port should socat listen on? " inbound_port
  else
    inbound_port=$1
  fi

  read -r -p "What IP/hostname should socat forward $2data to? " outbound_host
  read -r -p "What port should socat forward $2data to? " outbound_port

  socat -d -d -lf /var/log/socat.log TCP-LISTEN:$inbound_port,fork TCP-CONNECT:$outbound_host:$outbound_port &

  ps aux | grep socat | grep $inbound_port
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
  CONF_DST="/etc/nginx/sites-enabled/default"

  nysm_action "Installing Dependencies..."
  apt-get install -y software-properties-common vim less

  nysm_action "Adding certbot ppa..."
  add-apt-repository -y ppa:certbot/certbot
  check_errors

  nysm_action "Updating apt-get..."
  apt-get update
  check_errors

  nysm_action "Installing general net tools..."
  apt-get install -y inetutils-ping net-tools screen dnsutils curl openssl openjdk-9-jre-headless
  check_errors

  nysm_action "Installing nginx, socat, certbot..."
  apt-get install -y socat nginx python-certbot-nginx
  check_errors

  nysm_action "Finished installing dependencies!"
}

nysm_initialize() {
  nysm_action "Modifying nginx configs..."
  cp ./default.conf $CONF_DST
  read -r -p "What is the sites domain name? (ex: google.com) " domain_name
  sed -i.bak "s/server_name.*/server_name $domain_name;/" $CONF_DST
  rm $CONF_DST.bak
  check_errors

  SSL_SRC="/etc/letsencrypt/live/$domain_name"
  nysm_action "Installing Certificates..."
  certbot --authenticator standalone --installer nginx --pre-hook "service nginx stop" --post-hook "service nginx start" -d $domain_name

  nysm_action "Generating Keystore for Teamserver..."
  read -r -p "Create an alphanumeric password for the keystore (double-check, no confirmation): " store_pass
  openssl pkcs12 -export -in $SSL_SRC/fullchain.pem -inkey $SSL_SRC/privkey.pem -out $SSL_SRC/$domain_name.p12 -name $domain_name -passout pass:$store_pass
  keytool -importkeystore -deststorepass $store_pass -destkeypass $store_pass -destkeystore $SSL_SRC/$domain_name.store -srckeystore $SSL_SRC/$domain_name.p12 -srcstoretype PKCS12 -srcstorepass $store_pass -alias $domain_name

  nysm_action "Starting socat..."
  create_socat_instance 15080 "HTTP "
  create_socat_instance 15443 "HTTPS "

  nysm_action "The keystore for your teamserver can be found at $SSL_SRC/$domain_name.store"
}

nysm_setup() {
  nysm_install
  nysm_initialize
}

nysm_status() {
  printf "\n************************ Processes ************************\n"
  ps aux | grep (socat|nginx) | grep -v grep

  printf "\n************************* Network *************************\n"
  netstat -tulpn | grep -E '(socat|nginx)'
}

PS3="
NYSM - Select an Option:  "

finshed=0
while (( !finished )); do
  printf "\n"
  options=("Setup NginX w/ Redirectors" "Add Socat Instance" "Check Status" "Quit")
  select opt in "${options[@]}"
  do
    case $opt in
      "Setup NginX w/ Redirectors")
        nysm_setup
        break;
        ;;
      "Add Socat Instance")
        create_socat_instance
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
