#!/usr/bin/env python3
"""
Test script для N8N Workflows Auto-Importer v1.2.0
Проверяет функциональность импорта с новой структурой workflows
"""

import os
import sys
import json
import tempfile
import importlib.util
from pathlib import Path

# Добавляем путь к модулю импорта
import_path = str(Path(__file__).parent.parent / "services" / "n8n-importer")
sys.path.insert(0, import_path)

def create_test_workflow(name: str, active: bool = True) -> dict:
    """Создание тестового workflow"""
    return {
        "name": name,
        "active": active,
        "nodes": [
            {
                "id": "1",
                "name": "Start",
                "type": "n8n-nodes-base.start",
                "typeVersion": 1,
                "position": [100, 100],
                "parameters": {}
            }
        ],
        "connections": {},
        "createdAt": "2024-01-20T12:00:00.000Z",
        "updatedAt": "2024-01-20T12:00:00.000Z",
        "versionId": "1"
    }

def test_workflow_structure():
    """Тест структуры workflows"""
    print("🔍 Тестирование структуры workflows...")
    
    workflows_dir = Path("n8n/workflows")
    if not workflows_dir.exists():
        print("❌ Директория workflows не найдена")
        return False
    
    required_dirs = ["production", "testing", "examples"]
    for dir_name in required_dirs:
        dir_path = workflows_dir / dir_name
        if not dir_path.exists():
            print(f"❌ Отсутствует директория: {dir_name}")
            return False
        print(f"✅ Найдена директория: {dir_name}")
    
    print("✅ Структура workflows корректна")
    return True

def test_import_priority():
    """Тест приоритетности импорта"""
    print("🔍 Тестирование приоритетности импорта...")
    
    # Создаем временную директорию для тестов
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_workflows = Path(temp_dir) / "workflows"
        temp_workflows.mkdir()
        
        # Создаем структуру папок
        for subdir in ["production", "testing", "examples"]:
            (temp_workflows / subdir).mkdir()
        
        # Создаем тестовые файлы
        test_files = [
            ("production/test-prod.json", create_test_workflow("Production Test")),
            ("testing/quick-rag-test.json", create_test_workflow("Quick RAG Test")),
            ("testing/advanced-rag-pipeline-test.json", create_test_workflow("Advanced RAG Test")),
            ("examples/test-example.json", create_test_workflow("Example Test")),
            ("root-workflow.json", create_test_workflow("Root Test"))
        ]
        
        for file_path, workflow_data in test_files:
            full_path = temp_workflows / file_path
            with open(full_path, 'w', encoding='utf-8') as f:
                json.dump(workflow_data, f, indent=2)        # Тестируем функцию приоритетности без импорта класса
        try:
            workflow_files = list(temp_workflows.rglob("*.json"))
            
            def get_priority(file_path):
                """Тестовая функция приоритетности (копия из import-workflows.py)"""
                parent_dir = file_path.parent.name
                file_name = file_path.stem
                
                folder_priority = {
                    'production': 1,
                    'testing': 2, 
                    'examples': 3
                }.get(parent_dir, 4)
                
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
            
            print("📋 Порядок импорта (тест):")
            for i, file in enumerate(sorted_files, 1):
                relative_path = file.relative_to(temp_workflows)
                print(f"  {i}. {relative_path}")
            
            # Проверяем, что production файлы идут первыми
            first_file = sorted_files[0].relative_to(temp_workflows)
            if "production" in str(first_file):
                print("✅ Production файлы имеют приоритет")
                return True
            else:
                print("❌ Production файлы не имеют приоритет")
                return False
                
        except Exception as e:
            print(f"❌ Ошибка тестирования приоритетности: {e}")
            return False

def test_json_validation():
    """Тест валидации JSON файлов"""
    print("🔍 Тестирование валидации JSON...")
    
    workflows_dir = Path("n8n/workflows")
    json_files = list(workflows_dir.rglob("*.json"))
    
    if not json_files:
        print("⚠️ Нет JSON файлов для проверки")
        return True
    
    valid_count = 0
    invalid_count = 0
    
    for json_file in json_files:
        try:
            with open(json_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            # Проверяем основные поля workflow
            if 'name' in data or 'nodes' in data:
                valid_count += 1
                print(f"✅ {json_file.relative_to(workflows_dir)}")
            else:
                invalid_count += 1
                print(f"⚠️ {json_file.relative_to(workflows_dir)} - отсутствуют обязательные поля")
                
        except json.JSONDecodeError as e:
            invalid_count += 1
            print(f"❌ {json_file.relative_to(workflows_dir)} - ошибка JSON: {e}")
        except Exception as e:
            invalid_count += 1
            print(f"❌ {json_file.relative_to(workflows_dir)} - ошибка: {e}")
    
    print(f"📊 Валидных файлов: {valid_count}, с ошибками: {invalid_count}")
    return invalid_count == 0

def main():
    """Основная функция тестирования"""
    print("🧪 N8N Workflows Auto-Importer - Test Suite v1.2.0")
    print("=" * 60)
    
    tests = [
        ("Структура workflows", test_workflow_structure),
        ("Приоритетность импорта", test_import_priority),
        ("Валидация JSON", test_json_validation)
    ]
    
    passed = 0
    failed = 0
    
    for test_name, test_func in tests:
        print(f"\n🔬 {test_name}")
        print("-" * 40)
        
        try:
            if test_func():
                passed += 1
                print(f"✅ {test_name} - ПРОЙДЕН")
            else:
                failed += 1
                print(f"❌ {test_name} - ПРОВАЛЕН")
        except Exception as e:
            failed += 1
            print(f"❌ {test_name} - ОШИБКА: {e}")
    
    print("\n" + "=" * 60)
    print("📊 РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ:")
    print(f"   ✅ Пройдено: {passed}")
    print(f"   ❌ Провалено: {failed}")
    
    if failed == 0:
        print("🎉 Все тесты пройдены успешно!")
        return True
    else:
        print("⚠️ Некоторые тесты провалены")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
