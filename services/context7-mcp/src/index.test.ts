import { describe, expect, it } from 'vitest';
import server from './index';

describe('mcp handler', () => {
  it('returns ok for valid request', async () => {
    const res = await server.inject({
      method: 'POST',
      url: '/mcp',
      payload: { clientId: 'c1', contextId: 'ctx1', action: 'ping' }
    });
    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.body);
    expect(body.status).toBe('ok');
    expect(body.data.action).toBe('ping');
  });
});
