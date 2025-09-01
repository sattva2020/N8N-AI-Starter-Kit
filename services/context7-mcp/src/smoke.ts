// Use global fetch available in Node 18+/20+
(async () => {
  try {
    const res = await fetch('http://127.0.0.1:3000/mcp', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ clientId: 'smoke', contextId: 'smoke', action: 'ping' })
    });
    const txt = await res.text();
    console.log('status', res.status, txt);
    process.exit(res.ok ? 0 : 2);
  } catch (err) {
    console.error(err);
    process.exit(3);
  }
})();
