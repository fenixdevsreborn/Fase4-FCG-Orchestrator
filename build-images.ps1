# Script PowerShell para construir todas as imagens Docker dos microsservicos
# Uso: .\build-images.ps1

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "FIAP Cloud Games - Build Docker Images" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar se Docker esta disponivel
Write-Host "Verificando Docker..." -ForegroundColor Yellow
$dockerCheck = Get-Command docker -ErrorAction SilentlyContinue
if ($null -eq $dockerCheck) {
    Write-Host "[ERRO] Docker nao encontrado. Por favor, instale o Docker Desktop." -ForegroundColor Red
    exit 1
}

$dockerVersion = docker --version
if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Docker encontrado: $dockerVersion" -ForegroundColor Green
} else {
    Write-Host "[ERRO] Docker nao esta funcionando corretamente." -ForegroundColor Red
    exit 1
}

Write-Host ""

# Diretorio base
$baseDir = Split-Path -Parent $PSScriptRoot
$errors = @()

# Funcao auxiliar para construir imagem
function Build-Image {
    param(
        [string]$ServiceName,
        [string]$ImageName,
        [string]$ImageTag,
        [string]$DockerfilePath,
        [string]$BuildContext
    )
    
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "$ServiceName - Construindo..." -ForegroundColor Yellow
    Write-Host "=========================================" -ForegroundColor Cyan
    
    if (-not (Test-Path $BuildContext)) {
        Write-Host "[ERRO] Diretorio nao encontrado: $BuildContext" -ForegroundColor Red
        return $false
    }
    
    if (-not (Test-Path $DockerfilePath)) {
        Write-Host "[ERRO] Dockerfile nao encontrado: $DockerfilePath" -ForegroundColor Red
        return $false
    }
    
    Push-Location $BuildContext
    try {
        $fullImageName = "${ImageName}:${ImageTag}"
        Write-Host "Construindo imagem: $fullImageName" -ForegroundColor Gray
        docker build -t $fullImageName -f $DockerfilePath .
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] $ServiceName construido com sucesso ($fullImageName)" -ForegroundColor Green
            return $true
        } else {
            Write-Host "[ERRO] Erro ao construir $ServiceName" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "[ERRO] Erro ao construir $ServiceName : $_" -ForegroundColor Red
        return $false
    } finally {
        Pop-Location
    }
}

# 1. UsersAPI
$usersApiContext = Join-Path $baseDir "Fase2-UsersAPI"
$usersApiDockerfile = Join-Path $usersApiContext "Dockerfile"
if (-not (Build-Image -ServiceName "1. UsersAPI" -ImageName "usersapi-api" -ImageTag "8" -DockerfilePath $usersApiDockerfile -BuildContext $usersApiContext)) {
    $errors += "UsersAPI"
}
Write-Host ""

# 2. CatalogAPI
$catalogApiContext = Join-Path $baseDir "Fase2-CatalogAPI"
$catalogApiDockerfile = Join-Path $catalogApiContext "Dockerfile"
if (-not (Build-Image -ServiceName "2. CatalogAPI" -ImageName "catalogapi" -ImageTag "latest" -DockerfilePath $catalogApiDockerfile -BuildContext $catalogApiContext)) {
    $errors += "CatalogAPI"
}
Write-Host ""

# 3. PaymentsAPI
$paymentsApiContext = Join-Path $baseDir "Fase2-PaymentsAPI"
$paymentsApiDockerfile = Join-Path $paymentsApiContext "Dockerfile"
if (-not (Build-Image -ServiceName "3. PaymentsAPI" -ImageName "payments-api" -ImageTag "latest" -DockerfilePath $paymentsApiDockerfile -BuildContext $paymentsApiContext)) {
    $errors += "PaymentsAPI"
}
Write-Host ""

# 4. NotificationsAPI
$notificationsApiContext = Join-Path $baseDir "Fase2-NotificationsAPI\src"
$notificationsApiDockerfile = Join-Path $notificationsApiContext "Dockerfile"
if (-not (Build-Image -ServiceName "4. NotificationsAPI" -ImageName "notifications-worker" -ImageTag "1" -DockerfilePath $notificationsApiDockerfile -BuildContext $notificationsApiContext)) {
    $errors += "NotificationsAPI"
}
Write-Host ""

# 5. GatewayAPI
$gatewayApiContext = Join-Path $PSScriptRoot "src"
$gatewayApiDockerfile = Join-Path $gatewayApiContext "Gateway.Api\Dockerfile"
if (-not (Build-Image -ServiceName "5. GatewayAPI" -ImageName "gateway-api" -ImageTag "latest" -DockerfilePath $gatewayApiDockerfile -BuildContext $gatewayApiContext)) {
    $errors += "GatewayAPI"
}
Write-Host ""

# Resumo
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Resumo" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

if ($errors.Count -eq 0) {
    Write-Host "[OK] Todas as imagens foram construidas com sucesso!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Imagens criadas:" -ForegroundColor Cyan
    Write-Host "  - usersapi-api:8" -ForegroundColor Gray
    Write-Host "  - catalogapi:latest" -ForegroundColor Gray
    Write-Host "  - payments-api:latest" -ForegroundColor Gray
    Write-Host "  - notifications-worker:1" -ForegroundColor Gray
    Write-Host "  - gateway-api:latest" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Para verificar as imagens:" -ForegroundColor Cyan
    Write-Host "  docker images | findstr 'usersapi catalogapi payments notifications gateway'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Agora voce pode executar o deploy:" -ForegroundColor Cyan
    Write-Host "  .\deploy.ps1" -ForegroundColor Gray
    exit 0
} else {
    Write-Host "[ERRO] Erros ao construir as seguintes imagens:" -ForegroundColor Red
    foreach ($error in $errors) {
        Write-Host "  - $error" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "Por favor, verifique os erros acima e tente novamente." -ForegroundColor Yellow
    exit 1
}
