#!/bin/bash

DATA=$(date +%Y-%m-%d)
ORIGEM="/logix"
DESTINO="/logix/backups"
RETENCAO=7

mkdir -p "$DESTINO"

tar -czf "$DESTINO/backup_$DATA.tar.gz" \
    --exclude="$DESTINO" \
    "$ORIGEM"

echo "Backup realizado: backup_$DATA.tar.gz"

find "$DESTINO" -name "backup_*.tar.gz" -mtime +$RETENCAO -delete
echo "Backups antigos removidos"
