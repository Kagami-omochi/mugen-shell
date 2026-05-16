package mcp

import (
	"context"
	"fmt"
	"os"
	"sort"
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

// ServerStatus is the post-startup outcome for one configured server,
// surfaced over the HTTP API so the Settings GUI can show what loaded.
type ServerStatus struct {
	Name      string `json:"name"`
	Connected bool   `json:"connected"`
	ToolCount int    `json:"tool_count"`
	Error     string `json:"error,omitempty"`
	Disabled  bool   `json:"disabled"`
}

// Manager owns the set of connected MCP clients for the process lifetime
// and remembers the outcome of every configured server, connected or not.
type Manager struct {
	clients  map[string]*Client
	statuses []ServerStatus
}

// Connect spawns every configured server and runs its handshake. A server
// that fails to spawn or handshake is recorded with its error and skipped,
// so one broken entry can't stop mugen-ai from starting. Servers are
// processed in name order for deterministic startup logs.
func Connect(ctx context.Context, servers map[string]ServerConfig) *Manager {
	m := &Manager{clients: map[string]*Client{}}

	names := make([]string, 0, len(servers))
	for name := range servers {
		names = append(names, name)
	}
	sort.Strings(names)

	for _, name := range names {
		sc := servers[name]
		st := ServerStatus{Name: name, Disabled: sc.Disabled}

		switch {
		case sc.Disabled:
			// Recorded but not spawned.
		case sc.Command == "":
			st.Error = "no command configured"
			fmt.Fprintf(os.Stderr, "mcp[%s]: %s, skipping\n", name, st.Error)
		default:
			if client, err := dial(ctx, name, sc); err != nil {
				st.Error = err.Error()
				fmt.Fprintf(os.Stderr, "mcp[%s]: %v\n", name, err)
			} else {
				st.Connected = true
				st.ToolCount = len(client.Tools())
				m.clients[name] = client
				fmt.Fprintf(os.Stderr, "mcp[%s]: connected (%d tools)\n", name, st.ToolCount)
			}
		}
		m.statuses = append(m.statuses, st)
	}
	return m
}

// dial spawns one server and runs its handshake, returning a ready client
// or the failure reason.
func dial(ctx context.Context, name string, sc ServerConfig) (*Client, error) {
	tr, err := newStdioTransport(name, sc.Command, sc.Args, sc.Env)
	if err != nil {
		return nil, fmt.Errorf("spawn failed: %w", err)
	}
	client := newClient(name, tr)

	hctx, cancel := context.WithTimeout(ctx, handshakeTimeout)
	defer cancel()
	if err := client.Initialize(hctx); err != nil {
		client.Close()
		return nil, fmt.Errorf("handshake failed: %w", err)
	}
	if _, err := client.ListTools(hctx); err != nil {
		client.Close()
		return nil, fmt.Errorf("tools/list failed: %w", err)
	}
	return client, nil
}

// Clients returns the connected servers keyed by configured name.
func (m *Manager) Clients() map[string]*Client { return m.clients }

// Statuses returns the startup outcome of every configured server, in name
// order.
func (m *Manager) Statuses() []ServerStatus { return m.statuses }

// Close terminates every connected server. Safe to call on a Manager with
// no servers.
func (m *Manager) Close() {
	for _, c := range m.clients {
		_ = c.Close()
	}
}
