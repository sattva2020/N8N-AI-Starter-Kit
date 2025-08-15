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
echo 127.0.0.1 sattva-ai.top >> C:\Windows\System32\drivers\etc\hosts
echo 127.0.0.1 n8n.sattva-ai.top >> C:\Windows\System32\drivers\etc\hosts
echo 127.0.0.1 web.sattva-ai.top >> C:\Windows\System32\drivers\etc\hosts
echo 127.0.0.1 doc-processor.sattva-ai.top >> C:\Windows\System32\drivers\etc\hosts
echo 127.0.0.1 qdrant.sattva-ai.top >> C:\Windows\System32\drivers\etc\hosts
echo 127.0.0.1 ollama.sattva-ai.top >> C:\Windows\System32\drivers\etc\hosts
echo 127.0.0.1 traefik.sattva-ai.top >> C:\Windows\System32\drivers\etc\hosts
echo 127.0.0.1 pgadmin.sattva-ai.top >> C:\Windows\System32\drivers\etc\hosts
echo 127.0.0.1 jupyter.sattva-ai.top >> C:\Windows\System32\drivers\etc\hosts
echo 127.0.0.1 graphiti.sattva-ai.top >> C:\Windows\System32\drivers\etc\hosts
echo 127.0.0.1 supabase.sattva-ai.top >> C:\Windows\System32\drivers\etc\hosts
echo 127.0.0.1 api.sattva-ai.top >> C:\Windows\System32\drivers\etc\hosts

echo Domains added to hosts file successfully!
echo.
echo You can now access:
echo - N8N: http://n8n.sattva-ai.top
echo - Traefik Dashboard: http://traefik.sattva-ai.top
echo - Qdrant: http://qdrant.sattva-ai.top:6333
echo - Ollama: http://ollama.sattva-ai.top:11434
echo - Document Processor: http://doc-processor.sattva-ai.top:8001
echo - Graphiti: http://graphiti.sattva-ai.top:8003
echo.
pause
