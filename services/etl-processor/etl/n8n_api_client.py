"""
N8N API client for accessing workflow and execution data
"""

from datetime import datetime
from typing import Any

import httpx
import structlog

logger = structlog.get_logger(__name__)


class N8NAPIClient:
    """N8N API client"""

    def __init__(self, config):
        self.config = config
        self.client: httpx.AsyncClient | None = None
        self._initialized = False

    async def initialize(self):
        """Initialize N8N API client"""
        try:
            headers = {}
            if self.config.n8n_api_key:
                headers['X-N8N-API-KEY'] = self.config.n8n_api_key

            self.client = httpx.AsyncClient(base_url=self.config.n8n_api_url, headers=headers, timeout=30.0)

            # Prefer health endpoint to verify service is up
            try:
                resp = await self.client.get('/healthz')
                if resp.status_code == 200:
                    self._initialized = True
                    logger.info("N8N API client initialized via /healthz", base_url=self.config.n8n_api_url)
                    return
            except Exception:
                # ignore and try alternate endpoints
                pass

            # Try the REST workflows endpoint which is present on newer n8n
            try:
                resp = await self.client.get('/rest/workflows', params={"limit": 1})
                if resp.status_code == 200:
                    self._initialized = True
                    logger.info("N8N API client initialized via /rest/workflows", base_url=self.config.n8n_api_url)
                    return
                if resp.status_code == 401:
                    logger.warning("N8N API authentication failed - continuing without API access")
                    self._initialized = False
                    return
                if resp.status_code == 405:
                    # Server is reachable but method not allowed; consider service available
                    self._initialized = True
                    logger.info(
                        "N8N API reachable (405) - proceeding without full API checks", base_url=self.config.n8n_api_url
                    )
                    return
            except httpx.HTTPStatusError as e:
                if e.response.status_code == 401:
                    logger.warning("N8N API authentication failed - continuing without API access")
                    self._initialized = False
                    return
                raise

            # As a last resort try legacy API path
            try:
                response = await self.client.get("/api/v1/workflows", params={"limit": 1})
                response.raise_for_status()
                self._initialized = True
                logger.info("N8N API client initialized via /api/v1/workflows", base_url=self.config.n8n_api_url)
                return
            except httpx.HTTPStatusError as e:
                if e.response.status_code == 401:
                    logger.warning("N8N API authentication failed - continuing without API access")
                    self._initialized = False
                    return
                # other status errors are considered non-fatal for optional API access

            # If we reach here, mark as not initialized but don't raise - API is optional
            self._initialized = False
            logger.info("N8N API client not initialized; API access will be skipped", base_url=self.config.n8n_api_url)

        except Exception as e:
            logger.error("Failed to initialize N8N API client", error=str(e))
            # Don't raise - API access is optional
            self._initialized = False

    async def get_workflows(self) -> list[dict[str, Any]]:
        """Get all workflows"""
        if not self._initialized or not self.client:
            return []

        try:
            response = await self.client.get("/api/v1/workflows")
            response.raise_for_status()

            data = response.json()
            workflows = data.get('data', [])

            logger.info(f"Retrieved {len(workflows)} workflows from API")
            return workflows

        except Exception as e:
            logger.error("Failed to get workflows from API", error=str(e))
            return []

    async def get_workflow(self, workflow_id: str) -> dict[str, Any] | None:
        """Get specific workflow"""
        if not self._initialized or not self.client:
            return None

        try:
            response = await self.client.get(f"/api/v1/workflows/{workflow_id}")
            response.raise_for_status()

            workflow = response.json()
            logger.info(f"Retrieved workflow {workflow_id} from API")
            return workflow

        except Exception as e:
            logger.error(f"Failed to get workflow {workflow_id} from API", error=str(e))
            return None

    async def get_executions(self, workflow_id: str | None = None, limit: int = 100) -> list[dict[str, Any]]:
        """Get workflow executions"""
        if not self._initialized or not self.client:
            return []

        try:
            params = {"limit": limit}
            if workflow_id:
                params["workflowId"] = workflow_id

            response = await self.client.get("/api/v1/executions", params=params)
            response.raise_for_status()

            data = response.json()
            executions = data.get('data', [])

            logger.info(f"Retrieved {len(executions)} executions from API")
            return executions

        except Exception as e:
            logger.error("Failed to get executions from API", error=str(e))
            return []

    async def get_execution(self, execution_id: str) -> dict[str, Any] | None:
        """Get specific execution with full data"""
        if not self._initialized or not self.client:
            return None

        try:
            response = await self.client.get(f"/api/v1/executions/{execution_id}")
            response.raise_for_status()

            execution = response.json()
            logger.info(f"Retrieved execution {execution_id} from API")
            return execution

        except Exception as e:
            logger.error(f"Failed to get execution {execution_id} from API", error=str(e))
            return None

    async def get_active_workflows(self) -> list[dict[str, Any]]:
        """Get active workflows"""
        if not self._initialized or not self.client:
            return []

        try:
            response = await self.client.get("/api/v1/active")
            response.raise_for_status()

            active_workflows = response.json()
            logger.info(f"Retrieved {len(active_workflows)} active workflows from API")
            return active_workflows

        except Exception as e:
            logger.error("Failed to get active workflows from API", error=str(e))
            return []

    async def get_workflow_statistics(self, workflow_id: str) -> dict[str, Any] | None:
        """Get workflow execution statistics"""
        if not self._initialized or not self.client:
            return None

        try:
            # Get recent executions for this workflow
            executions = await self.get_executions(workflow_id=workflow_id, limit=100)

            if not executions:
                return None

            # Calculate statistics
            total = len(executions)
            successful = len([e for e in executions if e.get('status') == 'success'])
            failed = len([e for e in executions if e.get('status') == 'error'])

            durations = []
            for execution in executions:
                started_at = execution.get('startedAt')
                finished_at = execution.get('finishedAt')
                if started_at and finished_at:
                    try:
                        start = datetime.fromisoformat(started_at.replace('Z', '+00:00'))
                        finish = datetime.fromisoformat(finished_at.replace('Z', '+00:00'))
                        duration = (finish - start).total_seconds() * 1000
                        durations.append(duration)
                    except Exception as _e:
                        # ignore parse errors for individual executions
                        logger.debug("Could not parse execution timestamps", error=str(_e))

            statistics = {
                'workflow_id': workflow_id,
                'total_executions': total,
                'successful_executions': successful,
                'failed_executions': failed,
                'success_rate': successful / total if total > 0 else 0,
                'avg_duration_ms': sum(durations) / len(durations) if durations else 0,
                'max_duration_ms': max(durations) if durations else 0,
                'min_duration_ms': min(durations) if durations else 0,
            }

            logger.info(f"Calculated statistics for workflow {workflow_id}")
            return statistics

        except Exception as e:
            logger.error(f"Failed to get workflow statistics for {workflow_id}", error=str(e))
            return None

    async def health_check(self) -> bool:
        """Check N8N API health"""
        if not self._initialized or not self.client:
            return False

        try:
            response = await self.client.get("/healthz")
            return response.status_code == 200
        except Exception as e:
            logger.debug("N8N health_check failed or client not initialized", error=str(e))
            return False

    async def close(self):
        """Close N8N API client"""
        if self.client:
            try:
                await self.client.aclose()
                self.client = None
                self._initialized = False
                logger.info("N8N API client closed")
            except Exception as e:
                logger.error("Error closing N8N API client", error=str(e))
