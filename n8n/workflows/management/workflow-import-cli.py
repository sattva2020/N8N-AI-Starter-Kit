#!/usr/bin/env python3
"""
Zie619 Workflow Import CLI Interface
Interactive command-line interface for importing workflows from Zie619 repository.
"""

import sys
import os
from pathlib import Path
import inquirer
from typing import Dict, Any, List

# Add current directory to path (all scripts are now in the same directory)
sys.path.append(str(Path(__file__).parent))

try:
    from import_zie619_workflows import Zie619WorkflowImporter
    from import_to_n8n import N8NWorkflowManager
except ImportError as e:
    print(f"❌ Import error: {e}")
    print("Please ensure all required scripts are in the workflow management directory")
    sys.exit(1)

class WorkflowImportCLI:
    """Interactive CLI for workflow import management."""
    
    def __init__(self):
        self.zie619_importer = Zie619WorkflowImporter()
        self.n8n_manager = N8NWorkflowManager()
        
        # Import presets from config
        self.presets = {
            "ai_workflows": {
                "name": "🤖 AI & Automation Workflows",
                "description": "ChatGPT, OpenAI, Anthropic and other AI integrations",
                "filters": {"category": "ai_ml", "min_nodes": 3},
                "limit": 50
            },
            "business_automation": {
                "name": "💼 Business Process Automation", 
                "description": "Email, messaging, project management workflows",
                "filters": {"category": ["messaging", "email", "project_management"], "min_nodes": 4},
                "limit": 75
            },
            "developer_tools": {
                "name": "⚙️ Developer & Integration Tools",
                "description": "Webhooks, APIs, GitHub, GitLab integrations", 
                "filters": {"category": "development", "keywords": ["webhook", "api", "github"]},
                "limit": 60
            },
            "data_processing": {
                "name": "📊 Data Processing & Analytics",
                "description": "Database operations, cloud storage, analytics",
                "filters": {"category": ["database", "cloud_storage"], "min_nodes": 3},
                "limit": 50
            },
            "starter_pack": {
                "name": "🚀 Starter Pack (Beginner Friendly)",
                "description": "Simple workflows perfect for learning N8N",
                "filters": {"complexity": ["low", "medium"], "max_nodes": 10},
                "limit": 25
            },
            "custom": {
                "name": "🎯 Custom Selection",
                "description": "Define your own import criteria"
            }
        }

    def show_banner(self):
        """Display welcome banner."""
        print("\n" + "="*60)
        print("🔄 N8N Workflow Import Manager")
        print("   Import workflows from Zie619/n8n-workflows repository")
        print("="*60)
        
        # Show repository info
        repo_info = self.zie619_importer.get_repository_info()
        if repo_info:
            print(f"📦 Repository: {repo_info.get('full_name', 'Zie619/n8n-workflows')}")
            print(f"⭐ Stars: {repo_info.get('stargazers_count', 'N/A')}")
            print(f"🍴 Forks: {repo_info.get('forks_count', 'N/A')}")
            print(f"📝 Description: {repo_info.get('description', 'N/A')}")
        print()

    def select_import_preset(self) -> Dict[str, Any]:
        """Let user select import preset."""
        choices = []
        for key, preset in self.presets.items():
            choice_text = f"{preset['name']}"
            if 'description' in preset:
                choice_text += f"\n   {preset['description']}"
            choices.append((choice_text, key))
        
        questions = [
            inquirer.List('preset',
                message="Select workflow collection to import",
                choices=choices,
                carousel=True)
        ]
        
        answers = inquirer.prompt(questions)
        return self.presets[answers['preset']]

    def configure_custom_filters(self) -> Dict[str, Any]:
        """Configure custom import filters."""
        print("\n🎯 Custom Import Configuration")
        print("-" * 40)
        
        filters = {}
        
        # Category selection
        categories = [
            ('🤖 AI & Machine Learning', 'ai_ml'),
            ('💬 Messaging & Communication', 'messaging'), 
            ('📧 Email Automation', 'email'),
            ('🗄️ Database Operations', 'database'),
            ('☁️ Cloud Storage & Files', 'cloud_storage'),
            ('📋 Project Management', 'project_management'),
            ('📱 Social Media', 'social_media'),
            ('🛒 E-commerce & Payments', 'ecommerce'),
            ('📝 Forms & Surveys', 'forms'),
            ('⚙️ Development Tools', 'development')
        ]
        
        questions = [
            inquirer.Checkbox('categories',
                message="Select categories to import (use SPACE to select, ENTER to confirm)",
                choices=categories),
            
            inquirer.List('complexity',
                message="Select complexity level",
                choices=[
                    ('All complexity levels', 'all'),
                    ('Low complexity (1-5 nodes)', 'low'),
                    ('Medium complexity (6-15 nodes)', 'medium'), 
                    ('High complexity (16+ nodes)', 'high')
                ]),
            
            inquirer.Text('min_nodes',
                message="Minimum number of nodes (default: 2)",
                default="2"),
            
            inquirer.Text('max_nodes', 
                message="Maximum number of nodes (default: no limit)",
                default=""),
            
            inquirer.Text('keywords',
                message="Keywords to search for (comma-separated, optional)",
                default=""),
            
            inquirer.Text('limit',
                message="Maximum workflows to import (default: 50)",
                default="50")
        ]
        
        answers = inquirer.prompt(questions)
        
        # Process answers
        if answers['categories']:
            filters['category'] = answers['categories']
        
        if answers['complexity'] != 'all':
            filters['complexity'] = answers['complexity']
        
        if answers['min_nodes'] and answers['min_nodes'].isdigit():
            filters['min_nodes'] = int(answers['min_nodes'])
        
        if answers['max_nodes'] and answers['max_nodes'].isdigit():
            filters['max_nodes'] = int(answers['max_nodes'])
        
        if answers['keywords']:
            filters['keywords'] = [kw.strip() for kw in answers['keywords'].split(',') if kw.strip()]
        
        limit = None
        if answers['limit'] and answers['limit'].isdigit():
            limit = int(answers['limit'])
        
        return {'filters': filters, 'limit': limit}

    def confirm_import(self, preset: Dict[str, Any]) -> bool:
        """Confirm import settings with user."""
        print(f"\n📋 Import Configuration Summary")
        print("-" * 40)
        print(f"Collection: {preset['name']}")
        
        if 'filters' in preset:
            filters = preset['filters']
            print("Filters:")
            for key, value in filters.items():
                print(f"  • {key}: {value}")
        
        if 'limit' in preset:
            print(f"Limit: {preset['limit']} workflows")
        
        questions = [
            inquirer.Confirm('proceed',
                message="Proceed with import?",
                default=True)
        ]
        
        answers = inquirer.prompt(questions)
        return answers['proceed']

    def show_import_progress(self, result: Dict[str, Any]):
        """Display import results."""
        print(f"\n📊 Import Results")
        print("-" * 40)
        print(f"✅ Successfully imported: {result.get('imported', 0)}")
        print(f"📦 Total available: {result.get('total_available', 0)}")
        
        if result.get('workflows'):
            print(f"\n📁 Imported Workflows:")
            for i, workflow in enumerate(result['workflows'][:10], 1):
                print(f"  {i}. {workflow['name']} ({workflow['category']})")
            
            if len(result['workflows']) > 10:
                print(f"  ... and {len(result['workflows']) - 10} more")
        
        if result.get('report_file'):
            print(f"\n📋 Detailed report: {result['report_file']}")

    def ask_n8n_integration(self) -> bool:
        """Ask if user wants to integrate with N8N."""
        # Check N8N connection
        n8n_connected = self.n8n_manager.check_n8n_connection()
        
        if n8n_connected:
            status = "🟢 Connected"
        else:
            status = "🔴 Not accessible"
        
        print(f"\n🔗 N8N Integration")
        print(f"N8N Status: {status} ({self.n8n_manager.n8n_url})")
        
        if not n8n_connected:
            print("⚠️  N8N instance not accessible. Workflows will be saved locally only.")
            return False
        
        questions = [
            inquirer.Confirm('integrate',
                message="Import workflows directly into N8N?",
                default=True)
        ]
        
        answers = inquirer.prompt(questions)
        return answers['integrate']

    def run_n8n_integration(self, imported_dir: Path):
        """Run N8N integration for imported workflows."""
        print(f"\n🔄 Importing workflows into N8N...")
        
        # Get integration options
        questions = [
            inquirer.List('method',
                message="Select import method",
                choices=[
                    ('API (Recommended)', 'api'),
                    ('CLI (Fallback)', 'cli')
                ]),
            
            inquirer.Confirm('test_mode',
                message="Import in test mode? (workflows will be inactive)",
                default=True)
        ]
        
        answers = inquirer.prompt(questions)
        
        # Run integration
        results = self.n8n_manager.batch_import_workflows(
            imported_dir,
            use_api=(answers['method'] == 'api')
        )
        
        # Show results
        print(f"\n📊 N8N Integration Results")
        print("-" * 40)
        print(f"✅ Successfully imported: {results['successful']}")
        print(f"❌ Failed: {results['failed']}")
        print(f"⏭️ Skipped: {results['skipped']}")
        
        if results['successful'] > 0:
            print(f"\n🎉 Workflows imported! Visit: {self.n8n_manager.n8n_url}")
            print("⚠️  Remember to:")
            print("  • Update credentials for external services")
            print("  • Configure webhook URLs")
            print("  • Test workflows before activating")

    def run(self):
        """Run the interactive CLI."""
        try:
            self.show_banner()
            
            # Select import preset
            preset = self.select_import_preset()
            
            # Configure custom filters if needed
            if preset.get('name') == '🎯 Custom Selection':
                custom_config = self.configure_custom_filters()
                preset.update(custom_config)
            
            # Confirm import
            if not self.confirm_import(preset):
                print("❌ Import cancelled")
                return
            
            # Run import
            print(f"\n🚀 Starting import...")
            result = self.zie619_importer.import_workflows(
                filters=preset.get('filters'),
                limit=preset.get('limit')
            )
            
            if not result['success']:
                print(f"❌ Import failed: {result.get('error', 'Unknown error')}")
                return
            
            # Show results
            self.show_import_progress(result)
            
            # Ask about N8N integration
            if self.ask_n8n_integration():
                self.run_n8n_integration(Path(self.zie619_importer.workflows_dir))
            
            print(f"\n✨ Import completed successfully!")
            print(f"📁 Workflows saved to: {self.zie619_importer.workflows_dir}")
            
        except KeyboardInterrupt:
            print(f"\n\n❌ Import cancelled by user")
        except Exception as e:
            print(f"\n❌ Unexpected error: {e}")
            import traceback
            traceback.print_exc()


def check_dependencies():
    """Check if required dependencies are installed."""
    try:
        import inquirer
        import requests
    except ImportError as e:
        print(f"❌ Missing dependency: {e}")
        print("Install with: pip install inquirer requests")
        return False
    return True


def main():
    """Main entry point."""
    if not check_dependencies():
        sys.exit(1)
    
    cli = WorkflowImportCLI()
    cli.run()


if __name__ == "__main__":
    main()
