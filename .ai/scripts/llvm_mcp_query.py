#!/usr/bin/env python3
"""
Query LLDB MCP server for debugger resources and current debugger ID.

This script connects to the LLDB MCP server running on localhost:59995
and retrieves information about active debuggers and targets.

Usage:
    python3 llvm_mcp_get_current_id.py
"""

import socket
import json
import sys


def query_lldb_mcp(request, host='localhost', port=59995, timeout=2):
    """
    Send a JSON-RPC request to the LLDB MCP server and return the response.

    Args:
        request: Dictionary containing the JSON-RPC request
        host: Server hostname (default: localhost)
        port: Server port (default: 59995)
        timeout: Socket timeout in seconds (default: 2)

    Returns:
        Decoded JSON response string
    """
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(timeout)
    try:
        sock.connect((host, port))
        sock.sendall((json.dumps(request) + '\n').encode())

        response = b''
        while True:
            try:
                chunk = sock.recv(4096)
                if not chunk:
                    break
                response += chunk
                # Try to parse as complete JSON
                try:
                    json.loads(response.decode())
                    break
                except json.JSONDecodeError:
                    continue
            except socket.timeout:
                break

        return response.decode()
    except ConnectionRefusedError:
        print(f"Error: Could not connect to LLDB MCP server on {host}:{port}", file=sys.stderr)
        print("Make sure the LLDB MCP server is running.", file=sys.stderr)
        sys.exit(1)
    finally:
        sock.close()


def main():
    """Query LLDB MCP server for available debuggers and targets."""
    # List resources to find debugger_id
    request = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "resources/list",
        "params": {}
    }

    print("Querying LLDB MCP server...")
    response_text = query_lldb_mcp(request)

    try:
        response = json.loads(response_text)
        print(json.dumps(response, indent=2))

        # Extract and display debugger IDs
        if 'result' in response and 'resources' in response['result']:
            resources = response['result']['resources']
            debuggers = [r for r in resources if 'debugger' in r['uri'] and '/target/' not in r['uri']]

            if debuggers:
                print("\n" + "=" * 60)
                print("Available Debuggers:")
                print("=" * 60)
                for dbg in debuggers:
                    # Extract debugger_id from URI like "lldb://debugger/1"
                    debugger_id = dbg['uri'].split('/')[-1]
                    print(f"  Debugger ID: {debugger_id}")
                    print(f"  Name: {dbg['name']}")
                    print(f"  Description: {dbg['description']}")
                    print()
            else:
                print("\nNo active debuggers found.")
    except json.JSONDecodeError as e:
        print(f"Error parsing response: {e}", file=sys.stderr)
        print(f"Raw response: {response_text}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
