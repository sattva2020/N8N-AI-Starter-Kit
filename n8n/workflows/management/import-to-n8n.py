#!/usr/bin/env python3
"""
N8N Workflow Integration Manager
Advanced script for importing, managing, and integrating workflows into N8N instance.
"""

import json
import os
import sys
import requests
import subprocess
from pathlib import Path
from typing import List, Dict, Any, Optional
import logging
from datetime import datetime
import sqlite3

class N8NWorkflowManager:
    """Manage N8N workflows with import, export, and integration capabilities."""
    
    def __init__(self, n8n_url: str = "http://localhost:5678", workflows_dir: str = "n8n/workflows"):
        """Initialize the N8N workflow manager."""
        self.n8n_url = n8n_url.rstrip('/')
        self.workflows_dir = Path(workflows_dir)
        self.workflows_dir.mkdir(parents=True, exist_ok=True)
        
        # API endpoints
        self.api_base = f"{self.n8n_url}/api/v1"
        self.workflows_endpoint = f"{self.api_base}/workflows"
        
        # Database for tracking imports
        self.db_path = self.workflows_dir / "import_history.db"
        self.init_database()
        
        # Setup logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)

    def init_database(self):
        """Initialize SQLite database for tracking imports."""
        conn = sqlite3.connect(self.db_path)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS import_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                filename TEXT UNIQUE,
                workflow_name TEXT,
                n8n_id TEXT,
                category TEXT,
                source TEXT,
                imported_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                status TEXT DEFAULT 'imported',
                node_count INTEGER,
                complexity TEXT,
                integrations TEXT
            )
        """)
        conn.commit()
        conn.close()

    def check_n8n_connection(self) -> bool:
        """Check if N8N instance is accessible."""
        try:
            response = requests.get(f"{self.n8n_url}/api/v1/workflows", timeout=5)
            return response.status_code in [200, 401]  # 401 is OK, means auth is required
        except requests.RequestException:
            return False

    def get_existing_workflows(self) -> List[Dict[str, Any]]:
        """Get list of existing workflows from N8N instance."""
        try:
            response = requests.get(self.workflows_endpoint, timeout=10)
            if response.status_code == 200:
                return response.json().get('data', [])
            else:
                self.logger.warning(f"Could not fetch existing workflows: {response.status_code}")
                return []
        except requests.RequestException as e:
            self.logger.warning(f"Could not connect to N8N: {e}")
            return []

    def import_workflow_to_n8n(self, workflow_file: Path) -> Optional[str]:
        """Import a single workflow file to N8N instance."""
        try:
            with open(workflow_file, 'r', encoding='utf-8') as f:
                workflow_data = json.load(f)
            
            # Prepare workflow for import
            import_data = {
                "name": workflow_data.get('name', workflow_file.stem),
                "nodes": workflow_data.get('nodes', []),
                "connections": workflow_data.get('connections', {}),
                "active": False,  # Import as inactive for safety
                "tags": workflow_data.get('tags', [])
            }
            
            # Remove any existing ID to avoid conflicts
            if 'id' in import_data:
                del import_data['id']
            
            # Send to N8N
            response = requests.post(
                self.workflows_endpoint,
                json=import_data,
                timeout=30,
                headers={'Content-Type': 'application/json'}
            )
            
            if response.status_code == 201:
                result = response.json()
                workflow_id = result.get('data', {}).get('id')
                self.logger.info(f"✅ Imported to N8N: {workflow_file.name} (ID: {workflow_id})")
                return workflow_id
            else:
                self.logger.error(f"❌ Failed to import {workflow_file.name}: {response.status_code} - {response.text}")
                return None
                
        except Exception as e:
            self.logger.error(f"❌ Error importing {workflow_file.name}: {e}")
            return None

    def import_workflow_via_cli(self, workflow_file: Path) -> bool:
        """Import workflow using N8N CLI (alternative method)."""
        try:
            result = subprocess.run([
                'npx', 'n8n', 'import:workflow',
                f'--input={workflow_file}',
                '--separate'
            ], capture_output=True, text=True, timeout=60)
            
            if result.returncode == 0:
                self.logger.info(f"✅ CLI Import successful: {workflow_file.name}")
                return True
            else:
                self.logger.error(f"❌ CLI Import failed: {workflow_file.name} - {result.stderr}")
                return False
                
        except subprocess.TimeoutExpired:
            self.logger.error(f"⏰ CLI Import timeout: {workflow_file.name}")
            return False
        except Exception as e:
            self.logger.error(f"❌ CLI Import error: {workflow_file.name} - {e}")
            return False

    def record_import(self, workflow_file: Path, workflow_data: Dict, n8n_id: Optional[str] = None, source: str = "zie619"):
        """Record workflow import in database."""
        try:
            conn = sqlite3.connect(self.db_path)
            
            # Extract metadata
            integrations = self.extract_integrations(workflow_data.get('nodes', []))
            node_count = len(workflow_data.get('nodes', []))
            complexity = self.determine_complexity(node_count)
            
            conn.execute("""
                INSERT OR REPLACE INTO import_history 
                (filename, workflow_name, n8n_id, category, source, node_count, complexity, integrations, status)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                workflow_file.name,
                workflow_data.get('name', workflow_file.stem),
                n8n_id,
                self.categorize_workflow(integrations),
                source,
                node_count,
                complexity,
                json.dumps(integrations),
                'imported' if n8n_id else 'failed'
            ))
            
            conn.commit()
            conn.close()
            
        except Exception as e:
            self.logger.error(f"Failed to record import: {e}")

    def extract_integrations(self, nodes: List[Dict]) -> List[str]:
        """Extract integration names from workflow nodes."""
        integrations = set()
        
        integration_map = {
            'openai': 'OpenAI', 'anthropic': 'Anthropic', 'telegram': 'Telegram',
            'discord': 'Discord', 'slack': 'Slack', 'gmail': 'Gmail',
            'github': 'GitHub', 'postgres': 'PostgreSQL', 'mysql': 'MySQL',
            'webhook': 'Webhook', 'httprequest': 'HTTP Request'
        }
        
        for node in nodes:
            node_type = node.get('type', '').lower()
            for key, integration in integration_map.items():
                if key in node_type:
                    integrations.add(integration)
        
        return list(integrations)

    def determine_complexity(self, node_count: int) -> str:
        """Determine workflow complexity based on node count."""
        if node_count <= 5:
            return 'low'
        elif node_count <= 15:
            return 'medium'
        else:
            return 'high'

    def categorize_workflow(self, integrations: List[str]) -> str:
        """Categorize workflow based on integrations."""
        categories = {
            'AI & ML': ['OpenAI', 'Anthropic', 'Hugging Face'],
            'Messaging': ['Telegram', 'Discord', 'Slack'],
            'Email': ['Gmail', 'Outlook'],
            'Development': ['GitHub', 'GitLab', 'Webhook', 'HTTP Request'],
            'Database': ['PostgreSQL', 'MySQL', 'MongoDB']
        }
        
        for category, keywords in categories.items():
            if any(integration in keywords for integration in integrations):
                return category
        
        return 'General'

    def batch_import_workflows(self, source_dir: Path, use_api: bool = True, filters: Optional[Dict] = None) -> Dict[str, Any]:
        """Import multiple workflows from a directory."""
        workflow_files = list(source_dir.rglob("*.json"))
        
        if filters:
            workflow_files = self.apply_filters(workflow_files, filters)
        
        results = {
            'total': len(workflow_files),
            'successful': 0,
            'failed': 0,
            'skipped': 0,
            'imported_workflows': []
        }
        
        self.logger.info(f"🚀 Starting batch import of {len(workflow_files)} workflows...")
        
        # Check N8N connection if using API
        if use_api and not self.check_n8n_connection():
            self.logger.warning("⚠️  N8N API not accessible, falling back to CLI import")
            use_api = False
        
        for i, workflow_file in enumerate(workflow_files, 1):
            self.logger.info(f"[{i}/{len(workflow_files)}] Processing {workflow_file.name}...")
            
            try:
                # Load workflow data
                with open(workflow_file, 'r', encoding='utf-8') as f:
                    workflow_data = json.load(f)
                
                # Check if already imported
                if self.is_workflow_imported(workflow_file):
                    self.logger.info(f"⏭️  Skipping already imported: {workflow_file.name}")
                    results['skipped'] += 1
                    continue
                
                # Import workflow
                n8n_id = None
                if use_api:
                    n8n_id = self.import_workflow_to_n8n(workflow_file)
                    success = n8n_id is not None
                else:
                    success = self.import_workflow_via_cli(workflow_file)
                
                # Record import
                self.record_import(workflow_file, workflow_data, n8n_id)
                
                if success:
                    results['successful'] += 1
                    results['imported_workflows'].append({
                        'file': workflow_file.name,
                        'name': workflow_data.get('name', workflow_file.stem),
                        'n8n_id': n8n_id,
                        'category': self.categorize_workflow(self.extract_integrations(workflow_data.get('nodes', [])))
                    })
                else:
                    results['failed'] += 1
                    
            except Exception as e:
                self.logger.error(f"❌ Error processing {workflow_file.name}: {e}")
                results['failed'] += 1
        
        # Generate summary
        self.logger.info("📊 Import Summary:")
        self.logger.info(f"   ✅ Successful: {results['successful']}")
        self.logger.info(f"   ❌ Failed: {results['failed']}")
        self.logger.info(f"   ⏭️  Skipped: {results['skipped']}")
        
        return results

    def is_workflow_imported(self, workflow_file: Path) -> bool:
        """Check if workflow was already imported."""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.execute(
                "SELECT id FROM import_history WHERE filename = ? AND status = 'imported'",
                (workflow_file.name,)
            )
            result = cursor.fetchone()
            conn.close()
            return result is not None
        except Exception:
            return False

    def apply_filters(self, workflow_files: List[Path], filters: Dict) -> List[Path]:
        """Apply filters to workflow file list."""
        filtered_files = []
        
        for file_path in workflow_files:
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                
                # Apply node count filter
                node_count = len(data.get('nodes', []))
                if filters.get('min_nodes') and node_count < filters['min_nodes']:
                    continue
                if filters.get('max_nodes') and node_count > filters['max_nodes']:
                    continue
                
                # Apply complexity filter
                if filters.get('complexity'):
                    complexity = self.determine_complexity(node_count)
                    if complexity not in filters['complexity']:
                        continue
                
                # Apply keyword filter
                if filters.get('keywords'):
                    name = data.get('name', file_path.stem).lower()
                    if not any(keyword.lower() in name for keyword in filters['keywords']):
                        continue
                
                filtered_files.append(file_path)
                
            except Exception as e:
                self.logger.warning(f"Could not filter {file_path}: {e}")
                continue
        
        return filtered_files

    def generate_import_report(self, results: Dict[str, Any]) -> str:
        """Generate detailed import report."""
        report = f"""
# N8N Workflow Import Report
Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

## Summary
- **Total workflows processed**: {results['total']}
- **Successfully imported**: {results['successful']}
- **Failed imports**: {results['failed']}
- **Skipped (already imported)**: {results['skipped']}

## Imported Workflows
"""
        
        for workflow in results['imported_workflows']:
            report += f"- **{workflow['name']}** ({workflow['category']})\n"
            if workflow['n8n_id']:
                report += f"  - N8N ID: {workflow['n8n_id']}\n"
            report += f"  - File: {workflow['file']}\n\n"
        
        report += f"""
## Next Steps
1. **Review imported workflows** in N8N interface: {self.n8n_url}
2. **Update credentials** for external service integrations
3. **Configure webhook URLs** if using webhook triggers
4. **Test workflows** in development environment before activation
5. **Activate workflows** when ready for production

## Import History
View full import history in database: `{self.db_path}`
"""
        
        return report

    def get_import_statistics(self) -> Dict[str, Any]:
        """Get import statistics from database."""
        try:
            conn = sqlite3.connect(self.db_path)
            
            # Total imports
            cursor = conn.execute("SELECT COUNT(*) FROM import_history WHERE status = 'imported'")
            total_imported = cursor.fetchone()[0]
            
            # By category
            cursor = conn.execute("""
                SELECT category, COUNT(*) 
                FROM import_history 
                WHERE status = 'imported'
                GROUP BY category
            """)
            by_category = dict(cursor.fetchall())
            
            # By complexity
            cursor = conn.execute("""
                SELECT complexity, COUNT(*) 
                FROM import_history 
                WHERE status = 'imported'
                GROUP BY complexity
            """)
            by_complexity = dict(cursor.fetchall())
            
            # By source
            cursor = conn.execute("""
                SELECT source, COUNT(*) 
                FROM import_history 
                WHERE status = 'imported'
                GROUP BY source
            """)
            by_source = dict(cursor.fetchall())
            
            conn.close()
            
            return {
                'total_imported': total_imported,
                'by_category': by_category,
                'by_complexity': by_complexity,
                'by_source': by_source
            }
            
        except Exception as e:
            self.logger.error(f"Error getting statistics: {e}")
            return {}


def main():
    """Command line interface for N8N workflow manager."""
    import argparse
    
    parser = argparse.ArgumentParser(description='N8N Workflow Integration Manager')
    parser.add_argument('source_dir', help='Directory containing workflows to import')
    parser.add_argument('--n8n-url', default='http://localhost:5678', help='N8N instance URL')
    parser.add_argument('--use-cli', action='store_true', help='Use N8N CLI instead of API')
    parser.add_argument('--min-nodes', type=int, help='Minimum number of nodes')
    parser.add_argument('--max-nodes', type=int, help='Maximum number of nodes')
    parser.add_argument('--complexity', nargs='+', choices=['low', 'medium', 'high'], help='Filter by complexity')
    parser.add_argument('--keywords', nargs='+', help='Filter by keywords')
    parser.add_argument('--stats', action='store_true', help='Show import statistics only')
    
    args = parser.parse_args()
    
    # Create manager
    manager = N8NWorkflowManager(args.n8n_url)
    
    if args.stats:
        stats = manager.get_import_statistics()
        print("📊 Import Statistics:")
        print(f"Total imported: {stats.get('total_imported', 0)}")
        print(f"By category: {stats.get('by_category', {})}")
        print(f"By complexity: {stats.get('by_complexity', {})}")
        return
    
    # Build filters
    filters = {}
    if args.min_nodes:
        filters['min_nodes'] = args.min_nodes
    if args.max_nodes:
        filters['max_nodes'] = args.max_nodes
    if args.complexity:
        filters['complexity'] = args.complexity
    if args.keywords:
        filters['keywords'] = args.keywords
    
    # Import workflows
    source_dir = Path(args.source_dir)
    if not source_dir.exists():
        print(f"❌ Source directory not found: {source_dir}")
        sys.exit(1)
    
    results = manager.batch_import_workflows(
        source_dir, 
        use_api=not args.use_cli,
        filters=filters or None
    )
    
    # Generate and save report
    report = manager.generate_import_report(results)
    report_file = Path("n8n_import_report.md")
    with open(report_file, 'w', encoding='utf-8') as f:
        f.write(report)
    
    print(f"📋 Import report saved to: {report_file}")
    
    if results['successful'] > 0:
        print(f"\n🎉 Successfully imported {results['successful']} workflows!")
        sys.exit(0)
    else:
        print(f"\n❌ No workflows imported successfully")
        sys.exit(1)


if __name__ == "__main__":
    main()
