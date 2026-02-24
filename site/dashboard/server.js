const express = require('express');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const WebSocket = require('ws');

const app = express();
app.use(express.json());
app.use(express.static('public'));

// Load config
const configPath = path.join(__dirname, 'config.json');
let config = JSON.parse(fs.readFileSync(configPath, 'utf8'));

// Process registry
const processes = new Map();

// Log buffer per service (keep last 200 lines)
const logs = new Map();
const MAX_LOG_LINES = 200;

// WebSocket server for live updates
let wss;

function broadcast(message) {
  if (wss) {
    wss.clients.forEach(client => {
      if (client.readyState === WebSocket.OPEN) {
        client.send(JSON.stringify(message));
      }
    });
  }
}

function addLog(serviceId, line, stream = 'stdout') {
  if (!logs.has(serviceId)) {
    logs.set(serviceId, []);
  }
  const logBuffer = logs.get(serviceId);
  const entry = { time: new Date().toISOString(), stream, line };
  logBuffer.push(entry);
  if (logBuffer.length > MAX_LOG_LINES) {
    logBuffer.shift();
  }
  broadcast({ type: 'log', serviceId, entry });
}

function getServiceStatus(service) {
  const proc = processes.get(service.id);
  return {
    id: service.id,
    name: service.name,
    port: service.port,
    type: service.type,
    status: proc ? 'running' : 'stopped',
    pid: proc ? proc.pid : null,
    disabled: service.disabled || false,
    notes: service.notes || null,
    cwd: service.cwd
  };
}

function resolveCommand(service) {
  let cmd = service.command.replace('{port}', service.port);
  return cmd;
}

function resolveCwd(service) {
  if (service.cwd) {
    return path.resolve(__dirname, service.cwd);
  }
  return __dirname;
}

function startService(serviceId) {
  const service = config.services.find(s => s.id === serviceId);
  if (!service) {
    return { success: false, error: 'Service not found' };
  }
  if (service.disabled) {
    return { success: false, error: 'Service is disabled' };
  }
  if (processes.has(serviceId)) {
    return { success: false, error: 'Service already running' };
  }

  const cwd = resolveCwd(service);
  if (!fs.existsSync(cwd)) {
    return { success: false, error: `Working directory not found: ${cwd}` };
  }

  const command = resolveCommand(service);
  const [cmd, ...args] = command.split(' ');

  // Build environment
  const env = { ...process.env };
  if (service.env) {
    for (const [key, value] of Object.entries(service.env)) {
      env[key] = value.replace('{port}', service.port);
    }
  }

  console.log(`Starting ${service.name}: ${command} in ${cwd}`);
  addLog(serviceId, `Starting: ${command}`, 'system');

  try {
    const proc = spawn(cmd, args, {
      cwd,
      env,
      shell: true,
      detached: false
    });

    proc.stdout.on('data', (data) => {
      const lines = data.toString().split('\n').filter(l => l.trim());
      lines.forEach(line => addLog(serviceId, line, 'stdout'));
    });

    proc.stderr.on('data', (data) => {
      const lines = data.toString().split('\n').filter(l => l.trim());
      lines.forEach(line => addLog(serviceId, line, 'stderr'));
    });

    proc.on('error', (err) => {
      addLog(serviceId, `Error: ${err.message}`, 'system');
      processes.delete(serviceId);
      broadcast({ type: 'status', service: getServiceStatus(service) });
    });

    proc.on('exit', (code, signal) => {
      addLog(serviceId, `Exited with code ${code}, signal ${signal}`, 'system');
      processes.delete(serviceId);
      broadcast({ type: 'status', service: getServiceStatus(service) });
    });

    processes.set(serviceId, proc);
    broadcast({ type: 'status', service: getServiceStatus(service) });
    return { success: true };
  } catch (err) {
    return { success: false, error: err.message };
  }
}

function stopService(serviceId) {
  const service = config.services.find(s => s.id === serviceId);
  if (!service) {
    return { success: false, error: 'Service not found' };
  }

  const proc = processes.get(serviceId);
  if (!proc) {
    return { success: false, error: 'Service not running' };
  }

  console.log(`Stopping ${service.name}`);
  addLog(serviceId, 'Stopping...', 'system');

  // Try graceful shutdown first, then force kill
  proc.kill('SIGTERM');
  setTimeout(() => {
    if (processes.has(serviceId)) {
      proc.kill('SIGKILL');
    }
  }, 3000);

  return { success: true };
}

// API Routes
app.get('/api/services', (req, res) => {
  const statuses = config.services.map(getServiceStatus);
  res.json(statuses);
});

app.get('/api/services/:id', (req, res) => {
  const service = config.services.find(s => s.id === req.params.id);
  if (!service) {
    return res.status(404).json({ error: 'Service not found' });
  }
  res.json(getServiceStatus(service));
});

app.post('/api/services/:id/start', (req, res) => {
  const result = startService(req.params.id);
  res.json(result);
});

app.post('/api/services/:id/stop', (req, res) => {
  const result = stopService(req.params.id);
  res.json(result);
});

app.post('/api/services/:id/restart', async (req, res) => {
  const serviceId = req.params.id;
  if (processes.has(serviceId)) {
    stopService(serviceId);
    // Wait for process to stop
    await new Promise(resolve => {
      const check = setInterval(() => {
        if (!processes.has(serviceId)) {
          clearInterval(check);
          resolve();
        }
      }, 100);
      // Timeout after 5 seconds
      setTimeout(() => {
        clearInterval(check);
        resolve();
      }, 5000);
    });
  }
  const result = startService(serviceId);
  res.json(result);
});

app.get('/api/services/:id/logs', (req, res) => {
  const serviceId = req.params.id;
  res.json(logs.get(serviceId) || []);
});

app.post('/api/services/:id/port', (req, res) => {
  const { port } = req.body;
  const service = config.services.find(s => s.id === req.params.id);
  if (!service) {
    return res.status(404).json({ error: 'Service not found' });
  }
  if (processes.has(req.params.id)) {
    return res.status(400).json({ error: 'Stop service before changing port' });
  }

  // Check for port conflicts
  const conflict = config.services.find(s => s.id !== req.params.id && s.port === port);
  if (conflict) {
    return res.status(400).json({ error: `Port ${port} already used by ${conflict.name}` });
  }

  service.port = port;
  fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
  broadcast({ type: 'status', service: getServiceStatus(service) });
  res.json({ success: true });
});

app.get('/api/config', (req, res) => {
  res.json(config);
});

app.post('/api/reload', (req, res) => {
  try {
    config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Start server
const PORT = config.dashboardPort || 9000;
const server = app.listen(PORT, () => {
  console.log(`\n========================================`);
  console.log(`  Dev Dashboard running on port ${PORT}`);
  console.log(`  http://localhost:${PORT}`);
  console.log(`========================================\n`);
});

// WebSocket server
wss = new WebSocket.Server({ server });

wss.on('connection', (ws) => {
  console.log('Dashboard client connected');
  // Send current state
  ws.send(JSON.stringify({
    type: 'init',
    services: config.services.map(getServiceStatus)
  }));
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\nShutting down all services...');
  for (const [id, proc] of processes) {
    console.log(`Stopping ${id}...`);
    proc.kill('SIGTERM');
  }
  setTimeout(() => {
    process.exit(0);
  }, 2000);
});
