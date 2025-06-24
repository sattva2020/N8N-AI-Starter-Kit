#!/usr/bin/env python3
"""
N8N Workflows Auto-Importer v1.2.0
Автоматический импорт workflows при развертывании проекта
"""

import os
import json
import time
import requests
import logging
from pathlib import Path
from typing import Dict, List, Optional

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('/app/import.log')
    ]
)
logger = logging.getLogger(__name__)

class N8NWorkflowImporter:
    def __init__(self, n8n_url: str = "http://n8n:5678"):
        self.n8n_url = n8n_url
        self.workflows_dir = Path("/workflows")
        self.session = requests.Session()
        self.session.headers.update({
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        })
        
    def wait_for_n8n(self, max_wait: int = 300) -> bool:
        """Ожидание готовности N8N"""
        logger.info("⏳ Ожидание готовности N8N...")
        
        start_time = time.time()
        while time.time() - start_time < max_wait:
            try:
                response = self.session.get(f"{self.n8n_url}/healthz", timeout=5)
                if response.status_code == 200:
                    logger.info("✅ N8N готов!")
                    return True
            except requests.RequestException:
                pass
            
            logger.info("⏳ N8N еще не готов, ожидаем...")
            time.sleep(5)
        
        logger.error("❌ N8N не готов после ожидания")
        return False
    
    def setup_auth(self) -> bool:
        """Настройка аутентификации если требуется"""
        try:
            # Пробуем получить информацию о пользователях
            response = self.session.get(f"{self.n8n_url}/rest/users")
            
            if response.status_code == 401:
                # Если аутентификация требуется, попробуем без неё для локальной установки
                logger.info("🔓 N8N требует аутентификации, проверяем настройки...")
                
                # Пробуем получить workflows без аутентификации
                test_response = self.session.get(f"{self.n8n_url}/rest/workflows")
                if test_response.status_code == 401:
                    logger.warning("⚠️ N8N требует аутентификации. Для автоимпорта рекомендуется настроить N8N без аутентификации.")
                    return False
                    
            return True
        except requests.RequestException as e:
            logger.warning(f"⚠️ Ошибка проверки аутентификации: {e}")
            return True  # Продолжаем попытку
    
    def get_existing_workflows(self) -> Dict[str, str]:
        """Получение списка существующих workflows"""
        try:
            response = self.session.get(f"{self.n8n_url}/rest/workflows")
            if response.status_code == 200:
                workflows = response.json()
                return {wf['name']: wf['id'] for wf in workflows.get('data', [])}
            else:
                logger.warning(f"Не удалось получить список workflows: {response.status_code}")
                return {}
        except requests.RequestException as e:
            logger.warning(f"Ошибка при получении workflows: {e}")
            return {}
    
    def load_workflow_file(self, file_path: Path) -> Optional[Dict]:
        """Загрузка workflow из файла"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                workflow_data = json.load(f)
            
            # Проверяем основные поля
            if 'name' not in workflow_data:
                workflow_data['name'] = file_path.stem
            
            if 'active' not in workflow_data:
                workflow_data['active'] = True
                
            return workflow_data
        except Exception as e:
            logger.error(f"Ошибка загрузки {file_path}: {e}")
            return None
    
    def import_workflow(self, workflow_data: Dict, file_name: str) -> bool:
        """Импорт одного workflow"""
        try:
            # Проверяем, существует ли уже workflow с таким именем
            existing_workflows = self.get_existing_workflows()
            workflow_name = workflow_data.get('name', file_name)
            
            if workflow_name in existing_workflows:
                logger.info(f"📋 Workflow '{workflow_name}' уже существует, обновляем...")
                # Обновляем существующий workflow
                workflow_id = existing_workflows[workflow_name]
                response = self.session.put(
                    f"{self.n8n_url}/rest/workflows/{workflow_id}",
                    json=workflow_data
                )
            else:
                logger.info(f"📥 Импортируем новый workflow: {workflow_name}")
                # Создаем новый workflow
                response = self.session.post(
                    f"{self.n8n_url}/rest/workflows",
                    json=workflow_data
                )
            
            if response.status_code in [200, 201]:
                logger.info(f"✅ {workflow_name} успешно импортирован/обновлен")
                
                # Активируем workflow если он не активен
                if workflow_data.get('active', False):
                    self.activate_workflow(workflow_name)
                
                return True
            else:
                logger.error(f"❌ Ошибка импорта {workflow_name}: {response.status_code} - {response.text}")
                return False
                
        except requests.RequestException as e:
            logger.error(f"❌ Сетевая ошибка при импорте {file_name}: {e}")
            return False
        except Exception as e:
            logger.error(f"❌ Неожиданная ошибка при импорте {file_name}: {e}")
            return False
    
    def activate_workflow(self, workflow_name: str) -> bool:
        """Активация workflow"""
        try:
            existing_workflows = self.get_existing_workflows()
            if workflow_name not in existing_workflows:
                return False
            
            workflow_id = existing_workflows[workflow_name]
            response = self.session.post(f"{self.n8n_url}/rest/workflows/{workflow_id}/activate")
            
            if response.status_code == 200:
                logger.info(f"🟢 Workflow '{workflow_name}' активирован")
                return True
            else:
                logger.warning(f"⚠️ Не удалось активировать '{workflow_name}': {response.status_code}")
                return False
                
        except Exception as e:
            logger.warning(f"⚠️ Ошибка активации '{workflow_name}': {e}")
            return False
    
    def import_all_workflows(self) -> Dict[str, int]:
        """Импорт всех workflows из директории (включая подпапки)"""
        if not self.workflows_dir.exists():
            logger.error(f"❌ Директория workflows не найдена: {self.workflows_dir}")
            return {'imported': 0, 'failed': 0, 'updated': 0}
        
        # Сканируем рекурсивно все JSON файлы включая подпапки
        workflow_files = list(self.workflows_dir.rglob("*.json"))
        if not workflow_files:
            logger.info("📁 Нет JSON файлов для импорта")
            return {'imported': 0, 'failed': 0, 'updated': 0}
        
        logger.info(f"📦 Найдено {len(workflow_files)} файлов для импорта (включая подпапки)")
        
        imported = 0
        failed = 0
        updated = 0
        
        # Сортируем файлы по приоритету структуры папок и имен файлов
        def get_priority(file_path):
            """Определяем приоритет импорта"""
            parent_dir = file_path.parent.name
            file_name = file_path.stem
            
            # Приоритет по папкам: production > testing > examples > корень
            folder_priority = {
                'production': 1,
                'testing': 2, 
                'examples': 3
            }.get(parent_dir, 4)  # Файлы в корне - последние
            
            # Приоритет по типу workflow
            name_priority = 0
            if 'quick-rag-test' in file_name:
                name_priority = 1
            elif 'advanced-rag-pipeline-test' in file_name:
                name_priority = 2
            elif 'advanced-rag-automation' in file_name:
                name_priority = 3
            else:
                name_priority = 9
                
            return (folder_priority, name_priority)
        
        sorted_files = sorted(workflow_files, key=get_priority)
          # Логируем порядок импорта
        logger.info("📋 Порядок импорта workflows:")
        for i, file in enumerate(sorted_files, 1):
            relative_path = file.relative_to(self.workflows_dir)
            logger.info(f"  {i}. {relative_path}")
        
        for file in sorted_files:
            relative_path = file.relative_to(self.workflows_dir)
            logger.info(f"🔄 Обрабатываем: {relative_path}")
            
            workflow_data = self.load_workflow_file(file)
            if workflow_data:
                existing_workflows = self.get_existing_workflows()
                workflow_name = workflow_data.get('name', file.stem)
                
                if self.import_workflow(workflow_data, file.stem):
                    if workflow_name in existing_workflows:
                        updated += 1
                    else:
                        imported += 1
                else:
                    failed += 1
            else:
                failed += 1
        
        return {'imported': imported, 'failed': failed, 'updated': updated}
    
    def run(self):
        """Основная функция запуска импорта"""
        logger.info("🚀 N8N Workflows Auto-Importer v1.2.0")
        logger.info("=" * 50)
        
        # Ожидание готовности N8N
        if not self.wait_for_n8n():
            logger.error("❌ N8N недоступен, прерываем импорт")
            return False
        
        # Небольшая пауза для стабилизации
        time.sleep(5)
        
        # Импорт workflows
        results = self.import_all_workflows()
        
        # Отчет
        logger.info("\n" + "=" * 50)
        logger.info("📊 РЕЗУЛЬТАТ АВТОМАТИЧЕСКОГО ИМПОРТА:")
        logger.info(f"   📥 Новых импортировано: {results['imported']}")
        logger.info(f"   🔄 Обновлено: {results['updated']}")
        logger.info(f"   ❌ Ошибок: {results['failed']}")
        
        total_success = results['imported'] + results['updated']
        if results['failed'] == 0 and total_success > 0:
            logger.info("🎉 Автоматический импорт завершен успешно!")
        elif total_success > 0:
            logger.info("⚠️ Импорт завершен с частичными ошибками")
        else:
            logger.error("❌ Импорт завершен с ошибками")
        
        logger.info("=" * 50)
        return results['failed'] == 0

if __name__ == "__main__":
    importer = N8NWorkflowImporter()
    success = importer.run()
    exit(0 if success else 1)
