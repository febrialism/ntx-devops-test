const os = require('os');
const http = require('http');

function handleRequest(req, res) {
  res.write(`Hi there! I'm being served from ${os.hostname()}`);
  res.end();
}

const server = http.createServer(handleRequest);

// Export server and handler for testing
module.exports = { server, handleRequest };

// Start the server if not in test mode
if (require.main === module) {
  server.listen(3000, () => {
    console.log('Server is running on port 3000');
  });
}
