#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para imprimir mensagens coloridas
print_message() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Função para verificar se o script está sendo executado como root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Este script precisa ser executado como root!"
        exit 1
    fi
}

# Função para atualizar os pacotes do sistema
update_packages() {
    print_message "Atualizando lista de pacotes..."
    apt-get update
    
    if [ $? -eq 0 ]; then
        print_success "Lista de pacotes atualizada com sucesso!"
    else
        print_error "Falha ao atualizar lista de pacotes"
        exit 1
    fi

    print_message "Atualizando pacotes do sistema..."
    apt-get upgrade -y
    
    if [ $? -eq 0 ]; then
        print_success "Pacotes atualizados com sucesso!"
    else
        print_error "Falha ao atualizar pacotes"
        exit 1
    fi
}

# Função para instalar o Docker
install_docker() {
    print_message "Verificando se o Docker já está instalado..."
    
    if command -v docker &> /dev/null; then
        print_warning "Docker já está instalado. Pulando instalação..."
        return 0
    fi

    print_message "Instalando dependências necessárias..."
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

    print_message "Adicionando repositório do Docker..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    # Detecta a distribuição
    DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
    CODENAME=$(lsb_release -cs)

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$DISTRO $CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    print_message "Atualizando lista de pacotes após adição do repositório Docker..."
    apt-get update

    print_message "Instalando Docker..."
    apt-get install -y docker-ce docker-ce-cli containerd.io

    if [ $? -eq 0 ]; then
        print_success "Docker instalado com sucesso!"
        
        print_message "Iniciando e habilitando serviço do Docker..."
        systemctl start docker
        systemctl enable docker
        
        # Adiciona usuário atual ao grupo docker (se não for root)
        if [[ $EUID -ne 0 ]]; then
            print_message "Adicionando usuário $SUDO_USER ao grupo docker..."
            usermod -aG docker $SUDO_USER
            print_warning "Reinicie a sessão ou execute 'newgrp docker' para que as alterações tenham efeito"
        fi
        
    else
        print_error "Falha na instalação do Docker"
        exit 1
    fi
}

# Função para configurar Git
configure_git() {
    print_message "Configurando Git..."
    
    # Verifica se o Git está instalado, se não, instala
    if ! command -v git &> /dev/null; then
        print_message "Git não encontrado. Instalando..."
        apt-get install -y git
    fi

    # Solicita dados do usuário
    echo
    print_message "Configuração do Git"
    read -p "Digite seu nome de usuário do Git: " git_username
    read -p "Digite seu email do Git: " git_email

    # Configura usuário e email global
    git config --global user.name "$git_username"
    git config --global user.email "$git_email"

    # Configurações adicionais úteis
    git config --global init.defaultBranch main
    git config --global pull.rebase false

    print_success "Git configurado com sucesso!"
    echo
    print_message "Configurações do Git:"
    git config --global --list
    echo
}

# Função para instalar Nginx
install_nginx() {
    print_message "Verificando se o Nginx já está instalado..."
    
    if command -v nginx &> /dev/null; then
        print_warning "Nginx já está instalado. Pulando instalação..."
        return 0
    fi

    print_message "Instalando Nginx..."
    apt-get install -y nginx

    if [ $? -eq 0 ]; then
        print_success "Nginx instalado com sucesso!"
        
        print_message "Iniciando e habilitando serviço do Nginx..."
        systemctl start nginx
        systemctl enable nginx
        
        # Verifica status do serviço
        if systemctl is-active --quiet nginx; then
            print_success "Serviço Nginx está rodando!"
        else
            print_error "Serviço Nginx não está rodando"
        fi
    else
        print_error "Falha na instalação do Nginx"
        exit 1
    fi
}

# Função ajustada para instalação com prompt de porta
quick_install_portainer() {
    local PORT
    
    # Solicitar porta via prompt se não foi passada como parâmetro
    if [ -z "$1" ]; then
        read -p "Digite a porta para o Portainer [Padrão-9000]: " PORT
        PORT=${PORT:-9000}
    else
        PORT=$1
    fi
    
    # Validar se a porta é um número válido
    if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
        echo "Erro: Porta inválida! Deve ser um número entre 1 e 65535."
        return 1
    fi
    
    # Verificar se a porta já está em uso
    if netstat -tuln | grep ":$PORT " > /dev/null; then
        echo "Erro: Porta $PORT já está em uso!"
        read -p "Deseja tentar outra porta? (s/N): " try_again
        if [[ $try_again =~ ^[Ss]$ ]]; then
            quick_install_portainer  # Chama recursivamente sem parâmetro
            return
        else
            return 1
        fi
    fi
    
    echo "Instalando Portainer CE na porta $PORT..."
    
    # Verificar se Docker está instalado
    if ! command -v docker &> /dev/null; then
        echo "Erro: Docker não encontrado. Instale o Docker primeiro."
        return 1
    fi
    
    # Verificar se serviço Docker está rodando
    if ! systemctl is-active --quiet docker; then
        echo "Iniciando serviço Docker..."
        sudo systemctl start docker
    fi
    
    # Criar diretório de dados
    sudo mkdir -p /opt/portainer
    
    # Parar container existente se houver
    if docker ps -a | grep -q portainer; then
        echo "Parando container Portainer existente..."
        sudo docker stop portainer > /dev/null 2>&1
        sudo docker rm portainer > /dev/null 2>&1
    fi
    
    # Executar container
    echo "Iniciando container Portainer CE..."
    sudo docker run -d \
        --name portainer \
        --restart always \
        -p $PORT:9000 \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v /opt/portainer:/data \
        portainer/portainer-ce:latest
    
    if [ $? -eq 0 ]; then
        local IP_ADDRESS
        IP_ADDRESS=$(hostname -I | awk '{print $1}')
        echo "✅ Portainer CE instalado com sucesso!"
        echo "🌐 Acesse: http://$IP_ADDRESS:$PORT"
        echo "💻 Ou localmente: http://localhost:$PORT"
        
        # Aguardar inicialização
        echo "⏳ Aguardando inicialização..."
        sleep 5
        
        # Verificar status
        if docker ps | grep -q portainer; then
            echo "✅ Container está rodando corretamente"
        else
            echo "⚠️ Container pode estar com problemas. Verifique com: docker logs portainer"
        fi
    else
        echo "❌ Erro ao instalar Portainer CE"
        return 1
    fi
}

# Versão alternativa mais interativa
interactive_install_portainer() {
    echo "=== INSTALAÇÃO INTERATIVA DO PORTAINER ==="
    
    # Solicitar porta com validação
    while true; do
        read -p "Digite a porta para o Portainer [9000]: " PORT
        PORT=${PORT:-9000}
        
        # Validar porta
        if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
            echo "❌ Porta inválida! Deve ser um número entre 1 e 65535."
            continue
        fi
        
        # Verificar se porta está disponível
        if netstat -tuln | grep ":$PORT " > /dev/null; then
            echo "❌ Porta $PORT já está em uso!"
            read -p "Deseja tentar outra porta? (s/N): " try_again
            if [[ ! $try_again =~ ^[Ss]$ ]]; then
                return 1
            fi
        else
            break
        fi
    done
    
    # Chamar a função de instalação com a porta escolhida
    quick_install_portainer "$PORT"
}

# Função para mostrar resumo da instalação
show_summary() {
    echo
    print_success "=== INSTALAÇÃO CONCLUÍDA ==="
    echo
    print_message "Resumo da instalação:"
    
    # Verifica Docker
    if command -v docker &> /dev/null; then
        docker_version=$(docker --version | cut -d' ' -f3 | tr -d ',')
        print_success "✓ Docker: $docker_version"
    else
        print_error "✗ Docker: Não instalado"
    fi

    # Verifica Git
    if command -v git &> /dev/null; then
        git_version=$(git --version | cut -d' ' -f3)
        print_success "✓ Git: $git_version"
        print_message "  Usuário: $(git config --global user.name)"
        print_message "  Email: $(git config --global user.email)"
    else
        print_error "✗ Git: Não instalado"
    fi

    # Verifica Nginx
    if command -v nginx &> /dev/null; then
        nginx_version=$(nginx -v 2>&1 | cut -d'/' -f2)
        print_success "✓ Nginx: $nginx_version"
        
        # Verifica status do serviço
        if systemctl is-active --quiet nginx; then
            print_success "  Status: Rodando"
            print_message "  URL: http://$(curl -s ifconfig.me) ou http://localhost"
        else
            print_warning "  Status: Parado"
        fi
    else
        print_error "✗ Nginx: Não instalado"
    fi
    echo
}

all_inclusive() {
    # Atualizar pacotes
    update_packages
    echo

    # Instalar Docker
    install_docker
    echo

    # Configurar Git
    configure_git
    echo

    # Instalar Nginx
    install_nginx
    echo

    # Mostrar resumo
    show_summary
}


# Função para configurar serviço Nginx com DNS
configure_nginx_service() {
    local DOMAIN
    local PORT
    local SERVICE_NAME
    local CONFIG_DIR="/etc/nginx/sites-available"
    local ENABLED_DIR="/etc/nginx/sites-enabled"
    local SSL_ENABLED=false

    echo "=== CONFIGURADOR DE SERVIÇO NGINX ==="

    # Verificar se Nginx está instalado
    if ! command -v nginx &> /dev/null; then
        echo "❌ Nginx não encontrado. Instale primeiro: sudo apt install nginx"
        return 1
    fi

    # Solicitar informações do serviço
    read -p "🔤 Digite o nome do serviço (ex: meuservico): " SERVICE_NAME
    SERVICE_NAME=$(echo "$SERVICE_NAME" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')

    read -p "🌐 Digite o domínio (ex: app.meudominio.com): " DOMAIN
    DOMAIN=$(echo "$DOMAIN" | tr '[:upper:]' '[:lower:]')

    read -p "🔢 Digite a porta do serviço (ex: 3000, 8080): " PORT

    # Validar porta
    if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
        echo "❌ Porta inválida!"
        return 1
    fi

    # Perguntar sobre SSL
    read -p "🔒 Habilitar HTTPS/SSL? (s/N): " enable_ssl
    if [[ $enable_ssl =~ ^[Ss]$ ]]; then
        SSL_ENABLED=true
    fi

    # Criar configuração do Nginx
    create_nginx_config "$SERVICE_NAME" "$DOMAIN" "$PORT" "$SSL_ENABLED"

    # Configurar DNS local (opcional)
    setup_local_dns "$DOMAIN"

    # Testar e recarregar Nginx
    test_and_reload_nginx
}

# Função para criar configuração do Nginx
create_nginx_config() {
    local SERVICE_NAME=$1
    local DOMAIN=$2
    local PORT=$3
    local SSL_ENABLED=$4
    local CONFIG_FILE="/etc/nginx/sites-available/$SERVICE_NAME"
    local CERT_DIR="/etc/nginx/ssl/$SERVICE_NAME"

    echo "📁 Criando configuração Nginx para $DOMAIN..."

    # Criar diretório SSL se necessário
    if [ "$SSL_ENABLED" = true ]; then
        sudo mkdir -p "$CERT_DIR"
        echo "📝 Criando certificado auto-assinado (para desenvolvimento)..."
        
        # Criar certificado auto-assinado
        sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$CERT_DIR/$SERVICE_NAME.key" \
            -out "$CERT_DIR/$SERVICE_NAME.crt" \
            -subj "/C=BR/ST=Estado/L=Cidade/O=Organizacao/CN=$DOMAIN"
    fi

    # Criar arquivo de configuração
    sudo tee "$CONFIG_FILE" > /dev/null << EOF
# Configuração para $SERVICE_NAME
# Domínio: $DOMAIN
# Porto do serviço: $PORT

server {
    listen 80;
    server_name $DOMAIN;
    $(if [ "$SSL_ENABLED" = true ]; then echo "return 301 https://\$server_name\$request_uri;"; fi)
}

$(if [ "$SSL_ENABLED" = true ]; then
echo "
server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate $CERT_DIR/$SERVICE_NAME.crt;
    ssl_certificate_key $CERT_DIR/$SERVICE_NAME.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    location / {
        proxy_pass http://localhost:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_connect_timeout       60;
        proxy_send_timeout          60;
        proxy_read_timeout          60;
    }

    # Configurações de segurança
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    
    # Configurações de cache
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}"
else
echo "
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    # Logs
    access_log /var/log/nginx/${SERVICE_NAME}_access.log;
    error_log /var/log/nginx/${SERVICE_NAME}_error.log;
}"
fi)
EOF

    # Habilitar site
    sudo ln -sf "$CONFIG_FILE" "/etc/nginx/sites-enabled/$SERVICE_NAME"
    echo "✅ Configuração criada: $CONFIG_FILE"
}

# Função para configurar DNS local
setup_local_dns() {
    local DOMAIN=$1
    local HOSTS_FILE="/etc/hosts"
    
    read -p "🌍 Configurar DNS local em /etc/hosts? (s/N): " setup_dns
    if [[ $setup_dns =~ ^[Ss]$ ]]; then
        
        # Obter IP local
        local IP_LOCAL
        IP_LOCAL=$(hostname -I | awk '{print $1}')
        
        # Verificar se já existe entrada
        if ! grep -q "$DOMAIN" "$HOSTS_FILE"; then
            echo "📝 Adicionando $DOMAIN ao /etc/hosts..."
            echo "# Configurado automaticamente - $SERVICE_NAME" | sudo tee -a "$HOSTS_FILE" > /dev/null
            echo "$IP_LOCAL $DOMAIN" | sudo tee -a "$HOSTS_FILE" > /dev/null
            echo "✅ DNS local configurado: $DOMAIN -> $IP_LOCAL"
        else
            echo "⚠️  Domínio $DOMAIN já existe no /etc/hosts"
        fi
    fi
}

# Função para testar e recarregar Nginx
test_and_reload_nginx() {
    echo "🔍 Testando configuração do Nginx..."
    
    if sudo nginx -t; then
        echo "✅ Configuração do Nginx está válida"
        echo "🔄 Recarregando Nginx..."
        sudo systemctl reload nginx
        echo "✅ Nginx recarregado com sucesso!"
        
        # Mostrar resumo
        show_nginx_summary
    else
        echo "❌ Erro na configuração do Nginx. Verifique os arquivos."
        return 1
    fi
}

# Função para listar serviços configurados
list_nginx_services() {
    echo "=== SERVIÇOS NGINX CONFIGURADOS ==="
    
    if [ -d "/etc/nginx/sites-enabled" ]; then
        for config in /etc/nginx/sites-enabled/*; do
            if [ -f "$config" ]; then
                local service_name=$(basename "$config")
                local domain=$(grep -m1 "server_name" "$config" | awk '{print $2}' | tr -d ';')
                local port=$(grep -m1 "proxy_pass" "$config" | grep -oE '[0-9]+')
                echo "🔧 $service_name | Domínio: $domain | Porta: $port"
            fi
        done
    else
        echo "❌ Nenhum serviço configurado"
    fi
}

# Função para remover serviço
remove_nginx_service() {
    echo "=== REMOVER SERVIÇO NGINX ==="
    
    list_nginx_services
    
    read -p "🔤 Digite o nome do serviço para remover: " SERVICE_NAME
    
    local CONFIG_FILE="/etc/nginx/sites-available/$SERVICE_NAME"
    local ENABLED_FILE="/etc/nginx/sites-enabled/$SERVICE_NAME"
    
    if [ -f "$ENABLED_FILE" ]; then
        sudo rm -f "$ENABLED_FILE"
        echo "✅ Serviço desabilitado"
    fi
    
    if [ -f "$CONFIG_FILE" ]; then
        read -p "🗑️  Remover arquivo de configuração também? (s/N): " remove_config
        if [[ $remove_config =~ ^[Ss]$ ]]; then
            sudo rm -f "$CONFIG_FILE"
            echo "✅ Arquivo de configuração removido"
        fi
    fi
    
    sudo systemctl reload nginx
    echo "✅ Nginx recarregado"
}

# Função para mostrar resumo da configuração
show_nginx_summary() {
    local SERVICE_NAME=$1
    local DOMAIN=$2
    local PORT=$3
    local SSL_ENABLED=$4
    
    echo ""
    echo "🎉 CONFIGURAÇÃO CONCLUÍDA!"
    echo "=========================="
    echo "📋 Serviço: $SERVICE_NAME"
    echo "🌐 Domínio: $DOMAIN"
    echo "🔢 Porta do serviço: $PORT"
    echo "🔒 SSL: $([ "$SSL_ENABLED" = true ] && echo "Habilitado" || echo "Desabilitado")"
    echo ""
    echo "🔗 URLs de acesso:"
    if [ "$SSL_ENABLED" = true ]; then
        echo "   HTTPS: https://$DOMAIN"
        echo "   HTTP: http://$DOMAIN (redireciona para HTTPS)"
    else
        echo "   HTTP: http://$DOMAIN"
    fi
    echo ""
    echo "📁 Arquivos de configuração:"
    echo "   Config: /etc/nginx/sites-available/$SERVICE_NAME"
    echo "   Enabled: /etc/nginx/sites-enabled/$SERVICE_NAME"
    if [ "$SSL_ENABLED" = true ]; then
        echo "   Certificado: /etc/nginx/ssl/$SERVICE_NAME/"
    fi
    echo ""
    echo "📊 Logs:"
    echo "   Access: /var/log/nginx/${SERVICE_NAME}_access.log"
    echo "   Error: /var/log/nginx/${SERVICE_NAME}_error.log"
    echo ""
}

# Menu interativo seviços nginx
nginx_service_menu() {
    while true; do
        echo ""
        echo "=== MENU SERVIÇOS NGINX ==="
        echo "1. Configurar novo serviço"
        echo "2. Listar serviços"
        echo "3. Remover serviço"
        echo "4. Voltar para o menu principal"
        echo "5. Sair"
        read -p "Escolha: " choice
        
        case $choice in
            1) configure_nginx_service ;;
            2) list_nginx_services ;;
            3) remove_nginx_service ;;
            4) setup_menu ;;
            5) break ;;
            *) echo "❌ Opção inválida" ;;
        esac
    done
}

setup_menu() {
    while true; do
        echo
        echo "=== Fala meu mano, bão? O que você quer? ==="
        echo "1. Configurar Domínio|DNS "
        echo "2. Completão:"
        echo "   ├── Atualização do sistema"
        echo "   ├── Instalação Docker"
        echo "   ├── Configurar git"
        echo "   └── Instalar Nginx"
        echo "3. Sair"
        read -p "Escolha uma opção: " choice
        
        case $choice in
            1) nginx_service_menu;; 
            2) all_inclusive;;
            3) break ;;
            *) print_error "Opção inválida" ;;
        esac
    done
}

# Função principal
main() {
    clear
    print_message "Iniciando script..."
    echo

    # Verifica se é root
    check_root

    # setup_menu
    setup_menu
}

# Executa a função principal
main