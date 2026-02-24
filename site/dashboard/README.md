# Dev Dashboard

A lightweight development server manager for PSD3 projects. Provides a web UI to start, stop, and monitor all the servers needed during development.

## Quick Start

```bash
cd dev-dashboard
npm install   # first time only
npm start
# Opens at http://localhost:9000
```

## Configured Services

| Service | Port | Path |
|---------|------|------|
| Demo Website (Main) | 8080 | psd3-demo-website/public |
| Sheetless Demos | 8081 | psd3-sheetless/demo |
| Code Explorer Frontend | 8082 | purescript-code-explorer/ce2-website |
| Code Explorer Backend | 3000 | purescript-code-explorer/ce-server |
| Code Explorer Database | 5432 | PostgreSQL |
| Erlang Tidal Backend | 8083 | purerl-tidal |
| Tidal/Algorave Frontend | 8084 | purerl-tidal/demo |
| React Examples | 8085 | psd3-react/demo |
| A-Star Demos | 8086 | psd3-astar-demo |

## Features

- **Real-time status** via WebSocket - see instantly when services start/stop
- **Start/Stop/Restart** buttons for each service
- **Port links** - click port number to open running service in browser
- **Change ports** - click port number when stopped to reassign
- **Live logs** - view stdout/stderr for each service
- **Graceful shutdown** - Ctrl+C stops all managed services

## Configuration

Edit `config.json` to add/modify services. Each service has:

```json
{
  "id": "unique-id",
  "name": "Display Name",
  "port": 8080,
  "type": "static|node|erlang|postgres",
  "command": "python3 -m http.server {port}",
  "cwd": "../relative/path",
  "autoStart": false,
  "disabled": false,
  "notes": "Optional notes shown in UI"
}
```

The `{port}` placeholder in commands is replaced with the configured port.

## Notes

- Some paths may need adjustment for your setup (e.g., PostgreSQL data directory)
- Static file servers use Python's built-in http.server
- Can be hosted on a remote machine and accessed via Tailscale
