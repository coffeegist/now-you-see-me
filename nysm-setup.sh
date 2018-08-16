#!/bin/bash
# Now You See Me
# brownee

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
  apt-get install -y vim less

  nysm_action "Updating apt-get..."
  apt-get update
  check_errors

  nysm_action "Installing general net tools..."
  apt-get install -y inetutils-ping net-tools screen dnsutils curl
  check_errors

  nysm_action "Installing nginx git..."
  apt-get install -y nginx git

  nysm_action "Installing certbot..."
  git clone https://github.com/certbot/certbot.git /opt/letsencrypt > /dev/null 2>&1\

  nysm_action "Adding cronjob..."
  cp nysm-cron /etc/cron.d/nysm
  check_errors

  nysm_action "Finished installing dependencies!"
}

nysm_initialize() {
  nysm_action "Modifying nginx configs..."
  if [ "$#" -ne 2 ]; then
    read -r -p "What is the sites domain name? (ex: google.com) " domain_name
    read -r -p "What is the C2 server address? (IP:Port) " c2_server
  else
    domain_name = $1
    c2_server = $2
  fi

  cp ./default.conf $CONF_DST

  sed -i.bak "s/<DOMAIN_NAME>/$domain_name/" $CONF_DST
  rm $CONF_DST.bak

  sed -i.bak "s/<C2_SERVER>/$c2_server/" $CONF_DST
  rm $CONF_DST.bak
  check_errors

  SSL_SRC="/etc/letsencrypt/live/$domain_name"
  nysm_action "Obtaining Certificates..."
  read -r -p "Provide an E-mail address for emergency Let's Encrypt communication: " email_address
  /opt/letsencrypt/certbot-auto certonly --non-interactive --quiet --register-unsafely-without-email --agree-tos --email $email_address -a webroot --webroot-path=/var/www/html -d $domain_name
  check_errors

  nysm_action "Installing Certificates..."
  sed -i.bak "s/^#nysm#//g" $CONF_DST
  rm $CONF_DST.bak
  check_errors

  nysm_action "Restarting Nginx..."
  systemctl restart nginx.service
  check_errors

  nysm_action "Done!"
}

nysm_setup() {
  nysm_install
  nysm_initialize $1 $2
}

nysm_status() {
  printf "\n************************ Processes ************************\n"
  ps aux | grep -E 'nginx' | grep -v grep

  printf "\n************************* Network *************************\n"
  netstat -tulpn | grep -E 'nginx'
}

if [ "$#" -ne 2 ]; then
  PS3="
  NYSM - Select an Option:  "

  finshed=0
  while (( !finished )); do
    printf "\n"
    options=("Setup Nginx Redirector" "Check Status" "Quit")
    select opt in "${options[@]}"
    do
      case $opt in
        "Setup Nginx Redirector")
          nysm_setup
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
else
  nysm_setup $1 $2
fi
