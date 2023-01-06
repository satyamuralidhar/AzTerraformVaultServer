#!/bin/bash -e

echo "-> Installing dependencies....."
apt-get update
apt-get upgrade
apt-get install -y \
  apt-transport-https \
  build-essential \
  ca-certificates \
  curl \
  git \
  jq \
  less \
  software-properties-common \
  unzip \
  vim

echo "-> Downloading Vault....."
cd /tmp && {
  curl -sfL -o vault.zip "https://releases.hashicorp.com/vault/0.10.1/vault_0.10.1_linux_amd64.zip"
  unzip -qq vault.zip
  sudo mv vault /usr/local/bin/vault
  sudo chmod +x /usr/local/bin/vault
  rm -rf vault.zip
}

echo "-> Writing profile....."
tee "/etc/profile.d/vault.sh" > /dev/null <<"EOF"
alias vualt="vault"
export VAULT_ADDR="http://0.0.0.0:8200"
EOF
. "/etc/profile.d/vault.sh"

echo "-> Writing systemd unit....."
tee "/etc/systemd/system/vault.service" > /dev/null <<"EOF"
[Unit]
Description=Vault Server
Requires=network-online.target
After=network.target

[Service]
Environment=GOMAXPROCS=8
Environment=VAULT_ADDR=http://0.0.0.0:8200
Environment=VAULT_DEV_ROOT_TOKEN_ID=root
Restart=on-failure
ExecStart=/usr/local/bin/vault server -dev
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGINT

[Install]
WantedBy=multi-user.target
EOF

echo "-> Starting vault....."
systemctl enable vault
systemctl start vault