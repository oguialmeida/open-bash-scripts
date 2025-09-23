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

# Função para validar nome de usuário
validate_username() {
    local username=$1
    
    # Verifica se o nome de usuário está vazio
    if [[ -z "$username" ]]; then
        print_error "O nome de usuário não pode estar vazio!"
        return 1
    fi
    
    # Verifica se o nome de usuário contém apenas caracteres válidos
    if [[ ! "$username" =~ ^[a-z][-a-z0-9_]*$ ]]; then
        print_error "Nome de usuário inválido! Deve:"
        print_error "- Começar com letra minúscula"
        print_error "- Conter apenas letras minúsculas, números, hífens e underscores"
        print_error "- Ter entre 3 e 32 caracteres"
        return 1
    fi
    
    # Verifica comprimento do nome de usuário
    if [[ ${#username} -lt 3 || ${#username} -gt 32 ]]; then
        print_error "Nome de usuário deve ter entre 3 e 32 caracteres!"
        return 1
    fi
    
    # Verifica se o usuário já existe
    if id "$username" &>/dev/null; then
        print_error "O usuário '$username' já existe!"
        return 1
    fi
    
    return 0
}

# Função para validar senha
validate_password() {
    local password=$1
    
    # Verifica se a senha está vazia
    if [[ -z "$password" ]]; then
        print_error "A senha não pode estar vazia!"
        return 1
    fi
    
    # Verifica comprimento mínimo da senha
    if [[ ${#password} -lt 8 ]]; then
        print_error "A senha deve ter pelo menos 8 caracteres!"
        return 1
    fi
    
    # Verifica complexidade da senha (opcional, mas recomendado)
    if [[ ! "$password" =~ [A-Z] ]]; then
        print_warning "Recomendação: A senha deve conter pelo menos uma letra maiúscula"
    fi
    
    if [[ ! "$password" =~ [a-z] ]]; then
        print_warning "Recomendação: A senha deve conter pelo menos uma letra minúscula"
    fi
    
    if [[ ! "$password" =~ [0-9] ]]; then
        print_warning "Recomendação: A senha deve conter pelo menos um número"
    fi
    
    if [[ ! "$password" =~ [^a-zA-Z0-9] ]]; then
        print_warning "Recomendação: A senha deve conter pelo menos um caractere especial"
    fi
    
    return 0
}

# Função para solicitar e confirmar senha
get_password() {
    while true; do
        read -sp "Digite a senha para o usuário: " password
        echo
        validate_password "$password"
        if [[ $? -eq 0 ]]; then
            break
        fi
    done
    
    while true; do
        read -sp "Confirme a senha: " password_confirm
        echo
        if [[ "$password" != "$password_confirm" ]]; then
            print_error "As senhas não coincidem! Tente novamente."
        else
            break
        fi
    done
    
    echo "$password"
}

# Função para criar o usuário
create_super_user() {
    print_message "=== CRIADOR DE SUPER USUÁRIO UBUNTU ==="
    echo
    
    # Solicitar nome de usuário
    while true; do
        read -p "Digite o nome do novo usuário: " username
        validate_username "$username"
        if [[ $? -eq 0 ]]; then
            break
        fi
    done
    
    # Solicitar senha
    password=$(get_password)
    
    # Solicitar informações adicionais
    read -p "Digite o nome completo do usuário (opcional): " full_name
    read -p "Digite o número do telefone (opcional): " phone_number
    
    # Criar o usuário
    print_message "Criando usuário '$username'..."
    
    # Comando para criar usuário com informações adicionais
    if [[ -n "$full_name" ]]; then
        useradd -m -c "$full_name" -s /bin/bash "$username"
    else
        useradd -m -s /bin/bash "$username"
    fi
    
    if [[ $? -ne 0 ]]; then
        print_error "Falha ao criar o usuário!"
        exit 1
    fi
    
    # Definir a senha
    echo "$username:$password" | chpasswd
    
    if [[ $? -ne 0 ]]; then
        print_error "Falha ao definir a senha!"
        userdel -r "$username" 2>/dev/null
        exit 1
    fi
    
    # Adicionar usuário aos grupos de super usuário
    print_message "Adicionando usuário aos grupos de administração..."
    
    # Grupos comuns para super usuário
    usermod -aG sudo "$username"      # Permissões de sudo
    usermod -aG adm "$username"       # Grupo de administração
    usermod -aG dialout "$username"   # Acesso a dispositivos seriais
    usermod -aG cdrom "$username"     # Acesso ao drive de CD/DVD
    usermod -aG dip "$username"       # VPN
    usermod -aG video "$username"     # Acesso a hardware de vídeo
    usermod -aG plugdev "$username"   # Dispositivos plugáveis
    
    # Verificar se o grupo docker existe e adicionar o usuário
    if getent group docker > /dev/null; then
        usermod -aG docker "$username"
        print_message "Usuário adicionado ao grupo docker"
    fi
    
    print_success "Usuário '$username' criado com sucesso!"
    
    # Mostrar informações do usuário criado
    print_message "=== INFORMAÇÕES DO USUÁRIO ==="
    echo "Username: $username"
    echo "Diretório home: /home/$username"
    echo "Shell: /bin/bash"
    echo "Grupos: $(groups "$username" | cut -d: -f2 | sed 's/^ //')"
    echo
    
    # Criar arquivo de informações (opcional)
    info_file="/home/$username/info_usuario.txt"
    cat > "$info_file" << EOF
Informações da conta criada:
============================
Usuário: $username
Nome completo: ${full_name:-Não informado}
Telefone: ${phone_number:-Não informado}
Data de criação: $(date)
Diretório home: /home/$username

Grupos: $(groups "$username" | cut -d: -f2 | sed 's/^ //')

Instruções:
- Para usar privilégios de super usuário, use 'sudo' antes dos comandos
- Exemplo: sudo apt update
- A primeira vez que usar sudo, pode ser solicitada a senha

Mantenha suas credenciais seguras!
EOF
    
    chown "$username:$username" "$info_file"
    chmod 600 "$info_file"
    
    print_message "Arquivo com informações da conta criado em: $info_file"
}

# Função para testar o usuário criado
test_user_creation() {
    print_message "=== TESTANDO CONFIGURAÇÃO ==="
    
    # Verificar se o usuário existe
    if id "$username" &>/dev/null; then
        print_success "✓ Usuário existe no sistema"
    else
        print_error "✗ Usuário não encontrado"
        return 1
    fi
    
    # Verificar se o diretório home existe
    if [[ -d "/home/$username" ]]; then
        print_success "✓ Diretório home criado"
    else
        print_error "✗ Diretório home não encontrado"
    fi
    
    # Verificar se o usuário tem permissões de sudo
    if sudo -l -U "$username" &>/dev/null; then
        print_success "✓ Usuário tem permissões de sudo"
    else
        print_error "✗ Usuário não tem permissões de sudo"
    fi
    
    # Testar login (simulação)
    print_message "Testando autenticação..."
    if su - "$username" -c "whoami" | grep -q "$username"; then
        print_success "✓ Autenticação funcionando"
    else
        print_error "✗ Problema na autenticação"
    fi
}

# Função para mostrar resumo final
show_summary_user() {
    echo
    print_success "=== SUPER USUÁRIO CRIADO COM SUCESSO! ==="
    echo
    print_message "Resumo da criação:"
    print_success "✓ Usuário: $username"
    print_success "✓ Diretório home: /home/$username"
    print_success "✓ Shell: /bin/bash"
    print_success "✓ Grupos: $(groups "$username" | cut -d: -f2 | sed 's/^ //')"
    echo
    print_warning "IMPORTANTE:"
    print_message "1. Anote as credenciais em local seguro"
    print_message "2. O usuário pode usar 'sudo' para comandos administrativos"
    print_message "3. Recomenda-se alterar a senha periodicamente"
    print_message "4. Arquivo com informações salvo em: /home/$username/info_usuario.txt"
    echo
}

# Função principal
main() {
    clear
    print_message "Iniciando criador de super usuário..."
    echo
    
    # Criar usuário
    create_super_user
    
    # Testar criação
    test_user_creation
    
    # Mostrar resumo
    show_summary_user
    
    print_message "Processo concluído!"
}

# Executa a função principal
main "$@"