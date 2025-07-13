#!/usr/bin/env python3
"""
N8N Workflow Importer from Zie619 Repository
Advanced workflow import system with categorization, filtering, and batch processing.
"""

import json
import os
import sys
import requests
import zipfile
import tempfile
import shutil
from pathlib import Path
from typing import List, Dict, Any, Optional
import sqlite3
from datetime import datetime
import logging

class Zie619WorkflowImporter:
    """Import and manage workflows from Zie619/n8n-workflows repository."""
    
    def __init__(self, workflows_dir: str = "n8n/workflows/imported"):
        """Initialize the importer with configuration."""
        self.workflows_dir = Path(workflows_dir)
        self.workflows_dir.mkdir(parents=True, exist_ok=True)
        
        # Repository configuration
        self.repo_url = "https://github.com/Zie619/n8n-workflows"
        self.api_url = "https://api.github.com/repos/Zie619/n8n-workflows"
        self.zip_url = "https://github.com/Zie619/n8n-workflows/archive/refs/heads/main.zip"
        
        # Import statistics
        self.stats = {
            'total_available': 0,
            'downloaded': 0,
            'imported': 0,
            'skipped': 0,
            'errors': 0,
            'categories': {}
        }
        
        # Setup logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)
        
        # Category mapping from Zie619's system
        self.categories = {
            'ai_ml': ['OpenAI', 'Anthropic', 'Hugging Face', 'AI', 'ML', 'GPT'],
            'messaging': ['Telegram', 'Discord', 'Slack', 'WhatsApp', 'Teams'],
            'email': ['Gmail', 'Mailjet', 'Outlook', 'SMTP', 'IMAP'],
            'database': ['PostgreSQL', 'MySQL', 'MongoDB', 'Redis', 'Airtable'],
            'cloud_storage': ['Google Drive', 'Google Docs', 'Dropbox', 'OneDrive'],
            'project_management': ['Jira', 'GitHub', 'GitLab', 'Trello', 'Asana'],
            'social_media': ['LinkedIn', 'Twitter', 'Facebook', 'Instagram'],
            'ecommerce': ['Shopify', 'Stripe', 'PayPal'],
            'forms': ['Typeform', 'Google Forms'],
            'development': ['Webhook', 'HTTP Request', 'GraphQL', 'API']
        }

    def get_repository_info(self) -> Dict[str, Any]:
        """Get repository information via GitHub API."""
        try:
            response = requests.get(self.api_url, timeout=10)
            response.raise_for_status()
            return response.json()
        except requests.RequestException as e:
            self.logger.error(f"Failed to get repository info: {e}")
            return {}

    def download_repository(self) -> Optional[Path]:
        """Download the repository as ZIP and extract workflows."""
        try:
            self.logger.info("📥 Downloading Zie619 workflow repository...")
            
            with tempfile.TemporaryDirectory() as temp_dir:
                zip_path = Path(temp_dir) / "workflows.zip"
                
                # Download ZIP file
                response = requests.get(self.zip_url, stream=True, timeout=30)
                response.raise_for_status()
                
                with open(zip_path, 'wb') as f:
                    for chunk in response.iter_content(chunk_size=8192):
                        f.write(chunk)
                
                # Extract ZIP
                extract_dir = Path(temp_dir) / "extracted"
                with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                    zip_ref.extractall(extract_dir)
                
                # Find workflows directory
                workflow_source = None
                for item in extract_dir.iterdir():
                    if item.is_dir():
                        workflows_path = item / "workflows"
                        if workflows_path.exists():
                            workflow_source = workflows_path
                            break
                
                if workflow_source:
                    # Copy to permanent location
                    temp_workflows = Path(tempfile.gettempdir()) / "zie619_workflows"
                    if temp_workflows.exists():
                        shutil.rmtree(temp_workflows)
                    shutil.copytree(workflow_source, temp_workflows)
                    return temp_workflows
                else:
                    self.logger.error("Workflows directory not found in repository")
                    return None
                    
        except Exception as e:
            self.logger.error(f"Failed to download repository: {e}")
            return None

    def analyze_workflow(self, file_path: Path) -> Optional[Dict[str, Any]]:
        """Analyze a workflow file and extract metadata."""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            # Extract basic information
            workflow_info = {
                'filename': file_path.name,
                'name': self.format_workflow_name(file_path.name),
                'active': data.get('active', False),
                'nodes': data.get('nodes', []),
                'connections': data.get('connections', {}),
                'tags': data.get('tags', []),
                'created_at': data.get('createdAt', ''),
                'updated_at': data.get('updatedAt', ''),
                'node_count': len(data.get('nodes', [])),
                'raw_data': data
            }
            
            # Use meaningful JSON name if available
            json_name = data.get('name', '').strip()
            if json_name and not json_name.startswith('My workflow'):
                workflow_info['name'] = json_name
            
            # Analyze nodes for integrations and trigger type
            trigger_type, integrations = self.analyze_nodes(workflow_info['nodes'])
            workflow_info['trigger_type'] = trigger_type
            workflow_info['integrations'] = list(integrations)
            
            # Determine complexity
            node_count = workflow_info['node_count']
            if node_count <= 5:
                workflow_info['complexity'] = 'low'
            elif node_count <= 15:
                workflow_info['complexity'] = 'medium'
            else:
                workflow_info['complexity'] = 'high'
            
            # Categorize workflow
            workflow_info['category'] = self.categorize_workflow(integrations)
            
            return workflow_info
            
        except Exception as e:
            self.logger.error(f"Error analyzing workflow {file_path}: {e}")
            return None

    def format_workflow_name(self, filename: str) -> str:
        """Convert filename to readable workflow name."""
        # Remove .json extension
        name = filename.replace('.json', '')
        
        # Split by underscores and clean up
        parts = name.split('_')
        readable_parts = []
        
        for part in parts:
            # Skip numeric IDs at the beginning
            if part.isdigit() and len(readable_parts) == 0:
                continue
            
            # Handle special cases
            if part.upper() in ['HTTP', 'API', 'URL', 'JSON', 'XML', 'CSV']:
                readable_parts.append(part.upper())
            elif part.lower() in ['webhook', 'automation', 'scheduled', 'manual']:
                readable_parts.append(part.capitalize())
            else:
                readable_parts.append(part.capitalize())
        
        return ' '.join(readable_parts) if readable_parts else filename

    def analyze_nodes(self, nodes: List[Dict]) -> tuple[str, set]:
        """Analyze nodes to determine trigger type and integrations."""
        trigger_type = 'Manual'
        integrations = set()
        
        # Node type mapping for integration detection
        integration_map = {
            # AI/ML
            'openai': 'OpenAI', 'anthropic': 'Anthropic', 'huggingface': 'Hugging Face',
            
            # Messaging
            'telegram': 'Telegram', 'discord': 'Discord', 'slack': 'Slack',
            'whatsapp': 'WhatsApp', 'teams': 'Microsoft Teams',
            
            # Email
            'gmail': 'Gmail', 'outlook': 'Outlook', 'emailsend': 'Email',
            
            # Databases
            'postgres': 'PostgreSQL', 'mysql': 'MySQL', 'mongodb': 'MongoDB',
            'redis': 'Redis', 'airtable': 'Airtable',
            
            # Cloud Storage
            'googledrive': 'Google Drive', 'googlesheets': 'Google Sheets',
            'dropbox': 'Dropbox', 'onedrive': 'OneDrive',
            
            # Development
            'webhook': 'Webhook', 'httprequest': 'HTTP Request',
            'github': 'GitHub', 'gitlab': 'GitLab'
        }
        
        for node in nodes:
            node_type = node.get('type', '').lower()
            
            # Determine trigger type
            if 'trigger' in node_type or 'webhook' in node_type:
                if 'webhook' in node_type:
                    trigger_type = 'Webhook'
                elif 'schedule' in node_type or 'cron' in node_type:
                    trigger_type = 'Scheduled'
                elif trigger_type == 'Manual':
                    trigger_type = 'Complex'
            
            # Map integrations
            for key, integration in integration_map.items():
                if key in node_type:
                    integrations.add(integration)
        
        return trigger_type, integrations

    def categorize_workflow(self, integrations: set) -> str:
        """Categorize workflow based on integrations."""
        for category, keywords in self.categories.items():
            for integration in integrations:
                for keyword in keywords:
                    if keyword.lower() in integration.lower():
                        return category.replace('_', ' ').title()
        
        return 'General'

    def filter_workflows(self, workflows: List[Dict], filters: Dict[str, Any]) -> List[Dict]:
        """Filter workflows based on criteria."""
        filtered = workflows
        
        # Filter by category
        if filters.get('category'):
            filtered = [w for w in filtered if w.get('category', '').lower() == filters['category'].lower()]
        
        # Filter by complexity
        if filters.get('complexity'):
            filtered = [w for w in filtered if w.get('complexity') == filters['complexity']]
        
        # Filter by trigger type
        if filters.get('trigger_type'):
            filtered = [w for w in filtered if w.get('trigger_type') == filters['trigger_type']]
        
        # Filter by minimum node count
        if filters.get('min_nodes'):
            filtered = [w for w in filtered if w.get('node_count', 0) >= filters['min_nodes']]
        
        # Filter by keywords in name
        if filters.get('keywords'):
            keywords = [k.lower() for k in filters['keywords']]
            filtered = [w for w in filtered if any(kw in w.get('name', '').lower() for kw in keywords)]
        
        return filtered

    def import_workflow(self, workflow: Dict[str, Any], target_dir: Path) -> bool:
        """Import a single workflow to the target directory."""
        try:
            # Create category subdirectory
            category_dir = target_dir / workflow.get('category', 'general').lower().replace(' ', '_')
            category_dir.mkdir(parents=True, exist_ok=True)
            
            # Generate filename
            safe_name = "".join(c for c in workflow['name'] if c.isalnum() or c in (' ', '-', '_')).rstrip()
            safe_name = safe_name.replace(' ', '_')
            target_file = category_dir / f"{safe_name}.json"
            
            # Avoid duplicates
            counter = 1
            original_target = target_file
            while target_file.exists():
                target_file = original_target.with_name(f"{original_target.stem}_{counter}.json")
                counter += 1
            
            # Write workflow file
            with open(target_file, 'w', encoding='utf-8') as f:
                json.dump(workflow['raw_data'], f, indent=2, ensure_ascii=False)
            
            self.logger.info(f"✅ Imported: {workflow['name']} -> {target_file.relative_to(target_dir)}")
            return True
            
        except Exception as e:
            self.logger.error(f"❌ Failed to import {workflow.get('name', 'unknown')}: {e}")
            return False

    def create_import_report(self, workflows: List[Dict[str, Any]]) -> str:
        """Create detailed import report."""
        report = f"""
# 📊 Zie619 Workflow Import Report
Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

## 📈 Import Statistics
- Total Available: {self.stats['total_available']}
- Successfully Imported: {self.stats['imported']}
- Skipped: {self.stats['skipped']}
- Errors: {self.stats['errors']}

## 📂 Categories Imported
"""
        
        for category, count in self.stats['categories'].items():
            report += f"- {category}: {count} workflows\n"
        
        report += f"""
## 🔍 Sample Imported Workflows
"""
        
        # Show first 10 imported workflows as examples
        for i, workflow in enumerate(workflows[:10], 1):
            report += f"{i}. **{workflow['name']}** ({workflow['category']})\n"
            report += f"   - Nodes: {workflow['node_count']}, Complexity: {workflow['complexity']}\n"
            report += f"   - Integrations: {', '.join(workflow['integrations'][:3])}{'...' if len(workflow['integrations']) > 3 else ''}\n\n"
        
        if len(workflows) > 10:
            report += f"... and {len(workflows) - 10} more workflows\n\n"
        
        report += f"""
## 🚀 Next Steps
1. Review imported workflows in: `{self.workflows_dir}`
2. Import selected workflows into N8N using: `python scripts/import-to-n8n.py`
3. Update credentials and webhook URLs before activation
4. Test workflows in development environment

## 📚 Repository Information
- Source: {self.repo_url}
- Total workflows in repository: {self.stats['total_available']}
- Import location: {self.workflows_dir}
"""
        
        return report

    def import_workflows(self, filters: Optional[Dict[str, Any]] = None, limit: Optional[int] = None) -> Dict[str, Any]:
        """Main method to import workflows from Zie619 repository."""
        self.logger.info("🚀 Starting Zie619 workflow import...")
        
        # Download repository
        workflow_source = self.download_repository()
        if not workflow_source:
            return {"success": False, "error": "Failed to download repository"}
        
        try:
            # Get all workflow files
            workflow_files = list(workflow_source.glob("*.json"))
            self.stats['total_available'] = len(workflow_files)
            
            self.logger.info(f"📁 Found {len(workflow_files)} workflows in repository")
            
            # Analyze workflows
            workflows = []
            for file_path in workflow_files:
                workflow_info = self.analyze_workflow(file_path)
                if workflow_info:
                    workflows.append(workflow_info)
            
            # Apply filters
            if filters:
                workflows = self.filter_workflows(workflows, filters)
                self.logger.info(f"🔍 Filtered to {len(workflows)} workflows")
            
            # Apply limit
            if limit and limit < len(workflows):
                workflows = workflows[:limit]
                self.logger.info(f"📊 Limited to {limit} workflows")
            
            # Import workflows
            imported_workflows = []
            for workflow in workflows:
                if self.import_workflow(workflow, self.workflows_dir):
                    imported_workflows.append(workflow)
                    self.stats['imported'] += 1
                    
                    # Update category stats
                    category = workflow.get('category', 'General')
                    self.stats['categories'][category] = self.stats['categories'].get(category, 0) + 1
                else:
                    self.stats['errors'] += 1
            
            # Generate report
            report = self.create_import_report(imported_workflows)
            report_file = Path("zie619_import_report.md")
            with open(report_file, 'w', encoding='utf-8') as f:
                f.write(report)
            
            self.logger.info(f"📋 Import report saved to: {report_file}")
            
            return {
                "success": True,
                "imported": len(imported_workflows),
                "total_available": self.stats['total_available'],
                "report_file": str(report_file),
                "workflows": imported_workflows
            }
            
        finally:
            # Cleanup temporary directory
            if workflow_source.exists():
                shutil.rmtree(workflow_source)


def main():
    """Command line interface for Zie619 workflow importer."""
    import argparse
    
    parser = argparse.ArgumentParser(description='Import workflows from Zie619/n8n-workflows repository')
    parser.add_argument('--category', help='Filter by category (ai_ml, messaging, database, etc.)')
    parser.add_argument('--complexity', choices=['low', 'medium', 'high'], help='Filter by complexity')
    parser.add_argument('--trigger', choices=['Manual', 'Webhook', 'Scheduled', 'Complex'], help='Filter by trigger type')
    parser.add_argument('--min-nodes', type=int, help='Minimum number of nodes')
    parser.add_argument('--keywords', nargs='+', help='Filter by keywords in workflow name')
    parser.add_argument('--limit', type=int, help='Maximum number of workflows to import')
    parser.add_argument('--output-dir', default='n8n/workflows/imported', help='Output directory for imported workflows')
    
    args = parser.parse_args()
    
    # Build filters
    filters = {}
    if args.category:
        filters['category'] = args.category
    if args.complexity:
        filters['complexity'] = args.complexity
    if args.trigger:
        filters['trigger_type'] = args.trigger
    if args.min_nodes:
        filters['min_nodes'] = args.min_nodes
    if args.keywords:
        filters['keywords'] = args.keywords
    
    # Create importer and run
    importer = Zie619WorkflowImporter(args.output_dir)
    result = importer.import_workflows(filters=filters or None, limit=args.limit)
    
    if result["success"]:
        print(f"\n🎉 Successfully imported {result['imported']} workflows!")
        print(f"📋 Report: {result['report_file']}")
        sys.exit(0)
    else:
        print(f"\n❌ Import failed: {result.get('error', 'Unknown error')}")
        sys.exit(1)


if __name__ == "__main__":
    main()
