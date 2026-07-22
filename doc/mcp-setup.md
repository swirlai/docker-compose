# Configuring the SWIRL MCP Server (optional)

SWIRL 5 includes a built-in MCP (Model Context Protocol) server that exposes federated search, result paging, source discovery, document reading, and RAG answers with citations as tools for Claude, Microsoft Copilot, and any other MCP host.

In this bundle the MCP server runs as its own container (`swirl_mcp`) from the same SWIRL image, using the streamable HTTP transport on port 8675.

## Setup

1. Set `SWIRL_MCP_TOKEN` in `.env` to a long random value (this is in the REQUIRED section). The setup job provisions a matching API token for the `admin` user, and the MCP container authenticates to SWIRL with it.
2. Start the stack with the `all` profile, or add `--profile mcp` to your usual profiles.
3. The MCP endpoint is available at `http://<your-host>:8675/mcp`. Change the host port with `SWIRL_MCP_PORT` in `.env`.

## Connecting a client

Example Claude configuration (streamable HTTP):

```json
{
  "mcpServers": {
    "swirl": {
      "type": "http",
      "url": "http://<your-host>:8675/mcp"
    }
  }
}
```

## Security notes

- Treat `SWIRL_MCP_TOKEN` as a secret: all MCP requests act as the SWIRL user the token belongs to, with that user's source permissions.
- The MCP port has no additional client authentication; restrict it to trusted networks (do not expose 8675 to the public internet).

Full tool reference: [MCP Server Guide](https://docs.swirlaiconnect.com/MCP-Guide-Enterprise).
