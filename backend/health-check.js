const http = require('http');

const url = process.env.HEALTHCHECK_URL || 'http://localhost:5000/health';

http.get(url, (res) => {
  const { statusCode } = res;
  let rawData = '';

  res.setEncoding('utf8');
  res.on('data', (chunk) => { rawData += chunk; });
  res.on('end', () => {
    if (statusCode !== 200) {
      console.error(`Health check failed: status ${statusCode}`);
      process.exit(1);
    }
    try {
      const parsed = JSON.parse(rawData);
      if (parsed.status !== 'OK') {
        console.error('Health check failed: invalid status');
        process.exit(1);
      }
      console.log('Health check passed');
      process.exit(0);
    } catch (e) {
      console.error('Health check failed: invalid JSON');
      process.exit(1);
    }
  });
}).on('error', (e) => {
  console.error(`Health check failed: ${e.message}`);
  process.exit(1);
});
