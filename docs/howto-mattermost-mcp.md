# Setting Up Claude Code with Mattermost MCP

This guide gets Claude Code connected to our shared Mattermost instance (the one with 10 years of Slack history).

## Prerequisites

- Go 1.21+ installed
- Claude Code installed
- Access to Tailscale network (the Mattermost server is at `100.101.177.83:8065`)

## Step 1: Clone and Build the MCP Server

```bash
# Clone the official Mattermost agents repo
git clone https://github.com/mattermost/mattermost-plugin-agents.git
cd mattermost-plugin-agents

# Build the MCP server
make mcp-server

# Verify the binary was created
ls -la bin/mattermost-mcp-server
```

The binary will be at `bin/mattermost-mcp-server` (~20MB).

## Step 2: Create a Personal Access Token in Mattermost

1. Open Mattermost at http://100.101.177.83:8065
2. Click your profile picture → **Profile**
3. Go to the **Security** tab
4. Under **Personal Access Tokens**, click **Create Token**
5. Name it something like "Claude MCP"
6. **Copy the token immediately** - you won't see it again

Note: If you don't see the Personal Access Tokens section, an admin needs to enable it:
- System Console → Integrations → Integration Management
- Set "Enable Personal Access Tokens" to true

## Step 3: Configure Claude Code

Add the MCP server to your Claude Code project settings. Edit `~/.claude.json` and add the `mcpServers` config to your project:

```json
{
  "projects": {
    "/path/to/your/project": {
      "mcpServers": {
        "mattermost": {
          "type": "stdio",
          "command": "/absolute/path/to/mattermost-plugin-agents/bin/mattermost-mcp-server",
          "args": ["--debug"],
          "env": {
            "MM_SERVER_URL": "http://100.101.177.83:8065",
            "MM_ACCESS_TOKEN": "YOUR_TOKEN_HERE"
          }
        }
      }
    }
  }
}
```

Replace:
- `/path/to/your/project` with the actual project directory path
- `/absolute/path/to/...` with where you cloned the repo
- `YOUR_TOKEN_HERE` with your personal access token from Step 2

## Step 4: Restart Claude Code and Test

Restart Claude Code (or start a new session in that project), then ask Claude to test the connection:

```
Read the general channel on Mattermost
```

Claude should be able to use tools like:
- `mcp__mattermost__get_channel_info`
- `mcp__mattermost__read_channel`
- `mcp__mattermost__search_posts`
- `mcp__mattermost__create_post`

## Troubleshooting

**MCP tools not appearing**: Make sure you're in the project directory that has the mcpServers config, and restart Claude Code.

**Connection refused**: Check you're connected to Tailscale and can reach `100.101.177.83:8065` in a browser.

**Authentication errors**: Verify your token is correct and hasn't been revoked.

## Available MCP Tools

Once connected, Claude has access to:
- Read channels and posts
- Search messages across the workspace
- Post messages to channels
- Get channel/team info and members
- Create channels
- Send DMs

The full Slack history is searchable - useful for finding old discussions, decisions, and context.
