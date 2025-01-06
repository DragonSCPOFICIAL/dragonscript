#!/bin/bash

# Função para verificar se o script está sendo executado como root
check_root() {
  if [ "$EUID" -ne 0 ]; then
    echo "Por favor, execute este script como root."
    exit 1
  fi
}

# Função para exibir as informações da VPS
display_vps_info() {
  echo "-------------------------------"
  echo "Informações da VPS:"
  echo "IP Público: $VPS_IP"
  echo "Porta Configurada: $PORT"
  echo "Domínio Configurado: tunnel.$DOMAIN"
  echo "-------------------------------"
}

# Função para exibir o menu principal
show_menu() {
  clear
  display_vps_info
  echo "-------------------------------"
  echo "     MENU DE INSTALAÇÃO"
  echo "-------------------------------"
  echo "1) Instalar dependências"
  echo "2) Configurar WireGuard"
  echo "3) Ver configurações atuais"
  echo "4) Atualizar configurações"
  echo "5) Ativar/Desativar método de conexão"
  echo "6) Sair"
  echo "-------------------------------"
  echo -n "Escolha uma opção [1-6]: "
}

# Função para instalar dependências
install_dependencies() {
  echo "Atualizando pacotes e instalando dependências..."
  apt-get update -y
  apt-get upgrade -y
  apt-get install -y wireguard curl wget ufw dnsutils
  echo "Dependências instaladas com sucesso!"
}

# Função para configurar o WireGuard
configure_wireguard() {
  # Gera chaves para o WireGuard
  echo "Gerando chaves para o WireGuard..."
  SERVER_PRIVATE_KEY=$(wg genkey)
  SERVER_PUBLIC_KEY=$(echo "$SERVER_PRIVATE_KEY" | wg pubkey)

  # Solicita a porta
  read -p "Digite a porta para o túnel (padrão: 51820): " PORT
  PORT=${PORT:-51820}

  # Cria a configuração do WireGuard
  echo "Criando configuração do WireGuard..."
  cat <<EOF > /etc/wireguard/wg0.conf
[Interface]
PrivateKey = $SERVER_PRIVATE_KEY
Address = 10.0.0.1/24
ListenPort = $PORT
SaveConfig = true

# Adicionar peers conforme necessário
EOF

  # Configura o firewall
  ufw allow "$PORT"/udp
  ufw allow OpenSSH
  ufw enable

  # Inicia o WireGuard
  wg-quick up wg0
  systemctl enable wg-quick@wg0

  # Obtém o IP público da VPS
  VPS_IP=$(curl -s ifconfig.me)

  # Solicita o domínio
  read -p "Digite o seu domínio (ex: meudominio.com): " DOMAIN

  # Exibe instruções para configurar o DNS
  echo "Adicione o seguinte registro DNS ao seu provedor de DNS:"
  echo "Host: tunnel.$DOMAIN | Tipo: A | Valor: $VPS_IP"
}

# Função para exibir as configurações atuais
show_current_config() {
  display_vps_info
}

# Função para atualizar configurações
update_config() {
  echo "Atualizando configurações..."
  read -p "Digite a nova porta para o túnel (atual: $PORT): " NEW_PORT
  PORT=${NEW_PORT:-$PORT}

  # Atualiza a configuração do WireGuard
  sed -i "s/ListenPort = .*/ListenPort = $PORT/" /etc/wireguard/wg0.conf

  # Recarrega o serviço WireGuard
  wg-quick down wg0
  wg-quick up wg0

  echo "Configuração de porta atualizada com sucesso!"
}

# Função para ativar ou desativar o método de conexão
toggle_connection_method() {
  echo "-------------------------------"
  echo "Ativar ou Desativar Método de Conexão"
  echo "-------------------------------"
  if [ "$METHOD_ENABLED" == "true" ]; then
    echo "Método de conexão: ATIVADO"
  else
    echo "Método de conexão: DESATIVADO"
  fi
  echo "Deseja ativar ou desativar o método de conexão?"
  echo "1) Ativar"
  echo "2) Desativar"
  echo "3) Voltar"
  echo -n "Escolha uma opção [1-3]: "
  read METHOD_OPTION
  case $METHOD_OPTION in
    1)
      METHOD_ENABLED="true"
      echo "Método de conexão ativado!"
      ;;
    2)
      METHOD_ENABLED="false"
      echo "Método de conexão desativado!"
      ;;
    3)
      return
      ;;
    *)
      echo "Opção inválida!"
      ;;
  esac
}

# Main Loop
check_root

# Inicializa variáveis
VPS_IP=""
PORT=51820
DOMAIN=""
METHOD_ENABLED="false"

# Loop principal
while true; do
  show_menu
  read OPTION
  case $OPTION in
    1)
      install_dependencies
      ;;
    2)
      configure_wireguard
      ;;
    3)
      show_current_config
      ;;
    4)
      update_config
      ;;
    5)
      toggle_connection_method
      ;;
    6)
      echo "Saindo..."
      exit 0
      ;;
    *)
      echo "Opção inválida!"
      ;;
  esac
  read -p "Pressione Enter para continuar..."
done
