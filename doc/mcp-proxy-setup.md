# Overview
The MCP server proxy acts as a TCP server that exposes a set of tools, resources, and prompts for clients to interact with.
It handles authentication, manages client sessions, and delegates requests (such as listing tools, resources, and prompts, or
executing commands) to internal logic. It serves as a gateway for clients to access and interact with the
MCP (Multi-Component Platform) backend services over TCP.

## Setting up MCP Proxy
* MCP_ENABLED: Set to "true" to enable the MCP proxy service.
* MCP_VERSION: Specifies the version of the MCP proxy to use (e.g., "v1_0_5").
* MCP_PORT: The port on which the MCP proxy will listen for incoming connections (defaults "9000").
* SWIRL_MCP_USERNAME: Required authentication username for accessing the MCP proxy.
* SWIRL_MCP_PASSWORD: Required authentication password for accessing the MCP proxy.
* SWIRL_API_USERNAME: The username for the SWIRL API, used for MCP to SWIRL authentication.
* SWIRL_API_PASSWORD: The password for the SWIRL API, used for MCP to SWIRL authentication.
* MCP_SWIRL_BASE_PATH: The base URL path for the SWIRL API that MCP will interact with (e.g., "https://swirl.example.com/api").
* MCP_TIMEOUT: Optional timeout setting for MCP operations (in seconds, defaults to "30").

The MCP proxy runs as a container named `swirl_mcp` and is controlled via the same systemd service as SWIRL.