@echo off
echo Adding n8n-ai-starter-kit domains to hosts file...

:: Проверяем права администратора
net session >nul 2>&1
if %errorLevel% == 0 (
    echo Admin rights confirmed.
) else (
    echo Please run as Administrator
    pause
    exit /b 1
)

:: Резервная копия hosts файла
copy C:\Windows\System32\drivers\etc\hosts C:\Windows\System32\drivers\etc\hosts.backup >nul

:: Добавляем домены
echo 127.0.0.1 example.com >> C:\Windows\System32\drivers\etc\hosts
echo 127.0.0.1 n8n.example.com >> C:\Windows\System32\drivers\etc\hosts
echo 127.0.0.1 web.example.com >> C:\Windows\System32\drivers\etc\hosts
echo 127.0.0.1 doc-processor.example.com >> C:\Windows\System32\drivers\etc\hosts
echo 127.0.0.1 qdrant.example.com >> C:\Windows\System32\drivers\etc\hosts
echo 127.0.0.1 ollama.example.com >> C:\Windows\System32\drivers\etc\hosts
echo 127.0.0.1 traefik.example.com >> C:\Windows\System32\drivers\etc\hosts
echo 127.0.0.1 pgadmin.example.com >> C:\Windows\System32\drivers\etc\hosts
echo 127.0.0.1 jupyter.example.com >> C:\Windows\System32\drivers\etc\hosts
echo 127.0.0.1 graphiti.example.com >> C:\Windows\System32\drivers\etc\hosts
echo 127.0.0.1 supabase.example.com >> C:\Windows\System32\drivers\etc\hosts
echo 127.0.0.1 api.example.com >> C:\Windows\System32\drivers\etc\hosts

echo Domains added to hosts file successfully!
echo.
echo You can now access:
echo - N8N: http://n8n.example.com
echo - Traefik Dashboard: http://traefik.example.com
echo - Qdrant: http://qdrant.example.com:6333
echo - Ollama: http://ollama.example.com:11434
echo - Document Processor: http://doc-processor.example.com:8001
echo - Graphiti: http://graphiti.example.com:8003
echo.
pause
