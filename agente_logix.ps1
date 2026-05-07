# ============================================
# Logix Brasil - Agente de Coleta Windows
# ============================================

# Configuracoes
$SERVIDOR = "172.30.1.2"
$USUARIO  = "admin_ti"
$DESTINO  = "/logix/ti/relatorios_estacoes"
$PASTA_LOCAL = "C:\logix\relatorios"
$PASTA_PENDENTES = "C:\logix\pendentes"
$LOG = "C:\logix\erros.log"

# Cria pastas locais se nao existirem
New-Item -ItemType Directory -Force -Path $PASTA_LOCAL | Out-Null
New-Item -ItemType Directory -Force -Path $PASTA_PENDENTES | Out-Null

# Nome do relatorio
$DATA = Get-Date -Format "yyyy-MM-dd_HH-mm"
$NOME_PC = $env:COMPUTERNAME
$ARQUIVO = "$PASTA_LOCAL\relatorio_${NOME_PC}_${DATA}.txt"

# ============================================
# COLETA DE INFORMACOES
# ============================================

$relatorio = @"
============================================
LOGIX BRASIL - Relatorio da Estacao
Data/Hora : $(Get-Date)
Computador: $NOME_PC
============================================

--- USUARIO ---
Usuario logado: $env:USERNAME
Dominio       : $env:USERDOMAIN

--- SISTEMA ---
Sistema Operacional: $((Get-CimInstance Win32_OperatingSystem).Caption)
Versao             : $((Get-CimInstance Win32_OperatingSystem).Version)
Ultimo boot        : $((Get-CimInstance Win32_OperatingSystem).LastBootUpTime)
Uptime             : $([math]::Round((Get-Date - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime).TotalHours, 2)) horas

--- HARDWARE ---
CPU uso atual: $((Get-CimInstance Win32_Processor).LoadPercentage)%
RAM total    : $([math]::Round((Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize/1MB, 2)) GB
RAM livre    : $([math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory/1MB, 2)) GB

--- DISCO ---
$(Get-PSDrive -PSProvider FileSystem | Where-Object {$_.Used -gt 0} | ForEach-Object {
    "Drive $($_.Name): Usado=$([math]::Round($_.Used/1GB,2))GB Livre=$([math]::Round($_.Free/1GB,2))GB"
})

--- REDE ---
IP Local : $((Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -notlike "*Loopback*"}).IPAddress | Select-Object -First 1)
Hostname : $NOME_PC

--- PROCESSOS (Top 5 por CPU) ---
$(Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 | ForEach-Object {
    "$($_.Name) - CPU: $($_.CPU) - RAM: $([math]::Round($_.WorkingSet/1MB,2))MB"
})

--- EVENTOS CRITICOS (ultimos 5) ---
$(Get-EventLog -LogName System -EntryType Error -Newest 5 2>$null | ForEach-Object {
    "$($_.TimeGenerated) - $($_.Message.Substring(0, [Math]::Min(80, $_.Message.Length)))"
})

============================================
FIM DO RELATORIO
============================================
"@

# Salva relatorio local
$relatorio | Out-File -FilePath $ARQUIVO -Encoding UTF8
Write-Host "Relatorio gerado: $ARQUIVO"

# ============================================
# ENVIO VIA SCP
# ============================================

function Enviar-Arquivo($arquivo) {
    scp -o StrictHostKeyChecking=no "$arquivo" "${USUARIO}@${SERVIDOR}:${DESTINO}/"
    return $LASTEXITCODE
}

# Tenta enviar pendentes primeiro
Get-ChildItem $PASTA_PENDENTES -Filter "*.txt" | ForEach-Object {
    Write-Host "Reenviando pendente: $($_.Name)"
    $resultado = Enviar-Arquivo $_.FullName
    if ($resultado -eq 0) {
        Remove-Item $_.FullName
        Write-Host "Pendente enviado e removido: $($_.Name)"
    }
}

# Envia relatorio atual
$resultado = Enviar-Arquivo $ARQUIVO
if ($resultado -eq 0) {
    Write-Host "Relatorio enviado com sucesso!"
} else {
    # Falha - move para pendentes
    Copy-Item $ARQUIVO $PASTA_PENDENTES
    $msg = "$(Get-Date) - ERRO: Falha ao enviar $ARQUIVO"
    Add-Content $LOG $msg
    Write-Host "ERRO: Relatorio salvo como pendente."
}
