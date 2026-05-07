#!/bin/bash

# ============================================
# Logix Brasil - Criptografia LGPD - RH
# ============================================

PASTA_RH="/logix/rh"
SENHA="logix_rh_2026"

echo "Criptografando arquivos do RH..."

find "$PASTA_RH" -type f ! -name "*.gpg" | while read arquivo; do
    gpg --batch --yes --passphrase "$SENHA" \
        --symmetric --cipher-algo AES256 \
        --output "${arquivo}.gpg" \
        "$arquivo"
    
    if [ $? -eq 0 ]; then
        rm "$arquivo"
        echo "Criptografado: $arquivo"
    else
        echo "ERRO ao criptografar: $arquivo"
    fi
done

echo "Criptografia concluida."
