import Fastify from 'fastify';
import { z } from 'zod';

const server = Fastify({ logger: true });

const MCPRequest = z.object({
  clientId: z.string().min(1),
  contextId: z.string().min(1),
  action: z.string().min(1),
  payload: z.record(z.any()).optional()
});

server.post('/mcp', async (req, reply) => {
  try {
    const body = MCPRequest.parse(req.body);
    // minimal handler: echo action
    return { status: 'ok', data: { action: body.action, contextId: body.contextId } };
  } catch (err) {
    return reply.status(400).send({ status: 'error', error: (err as Error).message });
  }
});

const start = async () => {
  try {
    await server.listen({ port: 3000, host: '0.0.0.0' });
  } catch (err) {
    server.log.error(err);
    process.exit(1);
  }
};

if (require.main === module) {
  start();
}

export default server;
