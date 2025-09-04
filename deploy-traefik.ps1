# deploy-traefik.ps1
# Usage: powershell -ExecutionPolicy Bypass -File .\deploy-traefik.ps1
# Creates backup on remote, uploads fixed Traefik dynamic files, recreates containers and saves checks to a local file.

$Key = 'C:\Users\Admin\.ssh\id_rsa_n8n'
$SSHHost = 'root@37.53.91.144'
$Remote = '/opt/N8N-AI-Starter-Kit'
$Files = @('config/traefik/dynamic/middlewares.yml','config/traefik/dynamic/ssl-security.yml')
$Timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')

Write-Host "Step 1) Create backup on remote..."
ssh -i $Key $SSHHost "cd $Remote && mkdir -p backups/$Timestamp && cp config/traefik/dynamic/middlewares.yml config/traefik/dynamic/ssl-security.yml backups/$Timestamp/ && ls -la backups/$Timestamp"

Write-Host "Step 2) Upload local files to server..."
foreach ($f in $Files) {
    if (-Not (Test-Path $f)) { Write-Error "Local file not found: $f"; exit 1 }
    scp -i $Key $f "${SSHHost}:$Remote/config/traefik/dynamic/"
}

Write-Host "Step 3) Recreate traefik and n8n..."
ssh -i $Key $SSHHost "cd $Remote && docker compose up -d --no-deps --force-recreate traefik n8n"

Write-Host "Step 4) Run checks and save output locally..."
$remoteCmd = @"
# providers and routers (local loopback) and last 400 lines of Traefik logs
curl -sS -w '\nHTTP_CODE:%{http_code}\n' http://127.0.0.1:8080/api/providers || true

echo

curl -sS -w '\nHTTP_CODE:%{http_code}\n' http://127.0.0.1:8080/api/http/routers || true

echo

docker logs --tail 400 n8n-ai-starter-kit-traefik-1 || true
"@

# Execute remote command and capture output locally
$OutputFile = Join-Path -Path (Get-Location) -ChildPath ("deploy-output-$Timestamp.txt")
ssh -i $Key $SSHHost "$remoteCmd" > $OutputFile

Write-Host "Done - output saved to: $OutputFile"
Write-Host 'Open the file and paste its contents here so I can analyze the results.'
