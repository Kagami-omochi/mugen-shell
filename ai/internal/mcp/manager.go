package mcp

import (
	"context"
	"fmt"
	"os"
	"time"
)

// handshakeTimeout bounds initialize + tools/list per server so one that
// never replies can't hang mugen-ai's startup indefinitely.
const handshakeTimeout = 15 * time.Second

// ServerConfig is the subset of a configured MCP server the manager needs.
// Kept here so the mcp package stays free of an internal/config import.
type ServerConfig struct {
	Command  string
	Args     []string
	Env      map[string]string
	Disabled bool
}

// Manager owns the set of connected MCP clients for the process lifetime.
type Manager struct {
	clients map[string]*Client
}

// Connect spawns every configured server and runs its handshake. A server
// that fails to spawn or handshake is logged and skipped, so one broken
// entry can't stop mugen-ai from starting.
func Connect(ctx context.Context, servers map[string]ServerConfig) *Manager {
	m := &Manager{clients: map[string]*Client{}}
	for name, sc := range servers {
		if sc.Disabled {
			continue
		}
		if sc.Command == "" {
			fmt.Fprintf(os.Stderr, "mcp[%s]: no command configured, skipping\n", name)
			continue
		}
		tr, err := newStdioTransport(name, sc.Command, sc.Args, sc.Env)
		if err != nil {
			fmt.Fprintf(os.Stderr, "mcp[%s]: spawn failed: %v\n", name, err)
			continue
		}
		client := newClient(name, tr)

		hctx, cancel := context.WithTimeout(ctx, handshakeTimeout)
		err = client.Initialize(hctx)
		if err == nil {
			_, err = client.ListTools(hctx)
		}
		cancel()
		if err != nil {
			fmt.Fprintf(os.Stderr, "mcp[%s]: handshake failed: %v\n", name, err)
			client.Close()
			continue
		}

		m.clients[name] = client
		fmt.Fprintf(os.Stderr, "mcp[%s]: connected (%d tools)\n", name, len(client.Tools()))
	}
	return m
}

// Clients returns the connected servers keyed by configured name.
func (m *Manager) Clients() map[string]*Client { return m.clients }

// Close terminates every connected server. Safe to call on a Manager with
// no servers.
func (m *Manager) Close() {
	for _, c := range m.clients {
		_ = c.Close()
	}
}
