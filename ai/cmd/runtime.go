package cmd

import (
	"context"
	"fmt"
	"os"
	"path/filepath"

	"github.com/tmy7533018/mugen-ai/internal/config"
	ctxinfo "github.com/tmy7533018/mugen-ai/internal/context"
	"github.com/tmy7533018/mugen-ai/internal/history"
	"github.com/tmy7533018/mugen-ai/internal/provider"
	"github.com/tmy7533018/mugen-ai/internal/state"
	"github.com/tmy7533018/mugen-ai/internal/store"
	"github.com/tmy7533018/mugen-ai/internal/tools"
)

// toolingSystemPrompt is prepended to the user's personality prompt so the
// model knows the rules around calling shell tools. Centralising the
// conventions here lets each tool's description stay short.
const toolingSystemPrompt = `You can control the mugen-shell desktop through function-calling tools.

Conventions for all tool calls:
- Tool results that start with "error:" are failures. Surface the message verbatim instead of claiming success or silently retrying. The user may need to fix something (missing hardware, missing allowlist entry, etc.).
- Tools whose description starts with "[DESTRUCTIVE]" (and app_launch for unfamiliar commands) must be confirmed in plain language first: describe what you are about to do, wait for the user's explicit confirmation in their next message, and only then call the tool. Never call a destructive tool on the same turn as the request.
- Read-only and reversible tools (read*, get*, list*, toggle, music, theme/wallpaper switching, panel open) fire immediately when the user asks.
- Power actions (lock / suspend / logout / reboot / shutdown) are intentionally NOT exposed as tools. If the user asks for one, tell them to use the Power Menu directly.
- For app_launch: if the user has configured an allowlist and the command isn't in it, the result will be "error: ... not in allowed_commands" — tell the user the command is blocked and suggest adding it to their config.`

type runtimeContext struct {
	Cfg      config.Config
	Model    string
	Registry *provider.Registry
	Store    *store.Store
	History  *history.History
	Tools    *tools.Registry
}

// loadRuntimeContext is the shared `serve` / `chat` bootstrap. Caller closes rt.Store.
func loadRuntimeContext(modelOverride, systemOverride string) (*runtimeContext, error) {
	cfg, err := config.Load()
	if err != nil {
		fmt.Fprintf(os.Stderr, "warning: config load failed, using defaults: %v\n", err)
		cfg = config.Default()
	}

	model := modelOverride
	if model == "" {
		model = state.LoadModel()
	}
	system := systemOverride
	if system == "" {
		system = cfg.Personality.SystemPrompt
	}
	// Always prepend tooling guidance so the model knows when to call
	// shell tools vs. ask first. Personality stays the user's domain.
	if system != "" {
		system = toolingSystemPrompt + "\n\n" + system
	} else {
		system = toolingSystemPrompt
	}

	registry := buildRegistry(cfg, model)
	if model == "" {
		if models, _ := registry.Models(context.Background()); len(models) > 0 {
			model = models[0]
			registry.SetModel(model)
		}
	}

	stateDir := stateBaseDir()

	st, err := store.Open(filepath.Join(stateDir, "history.db"))
	if err != nil {
		return nil, fmt.Errorf("open history store: %w", err)
	}

	hist, err := history.New(st, system)
	if err != nil {
		st.Close()
		return nil, fmt.Errorf("init history: %w", err)
	}
	hist.ContextFunc = func() string { return ctxinfo.Build(cfg.Context) }

	return &runtimeContext{
		Cfg:      cfg,
		Model:    model,
		Registry: registry,
		Store:    st,
		History:  hist,
		Tools: tools.New(
			cfg.Shell.QsConfig,
			resolveScriptsDir(cfg.Shell.ScriptsDir),
			cfg.Tools.AppLaunch.AllowedCommands,
			tools.NewAuditor(filepath.Join(stateDir, "audit.log")),
		),
	}, nil
}

func resolveScriptsDir(configured string) string {
	if configured != "" {
		return configured
	}
	xdg := os.Getenv("XDG_CONFIG_HOME")
	if xdg == "" {
		home, _ := os.UserHomeDir()
		xdg = filepath.Join(home, ".config")
	}
	return filepath.Join(xdg, "quickshell", "mugen-shell", "scripts")
}

func buildRegistry(cfg config.Config, model string) *provider.Registry {
	providers := []provider.Provider{
		provider.NewOllama(cfg.Provider.Ollama.Host),
	}
	if cfg.Provider.Google.Model != "" {
		key := os.Getenv("GEMINI_API_KEY")
		if key == "" {
			key = os.Getenv("GOOGLE_API_KEY")
		}
		if key != "" {
			providers = append(providers, provider.NewGoogle(key, cfg.Provider.Google.Model))
		}
	}
	openaiKey := os.Getenv("OPENAI_API_KEY")
	if openaiKey != "" || cfg.Provider.OpenAI.BaseURL != "" {
		providers = append(providers, provider.NewOpenAI(
			cfg.Provider.OpenAI.BaseURL,
			openaiKey,
			cfg.Provider.OpenAI.Models,
		))
	}
	anthropicKey := os.Getenv("ANTHROPIC_API_KEY")
	if anthropicKey != "" {
		providers = append(providers, provider.NewAnthropic(
			anthropicKey,
			cfg.Provider.Anthropic.Models,
		))
	}
	return provider.NewRegistry(model, providers...)
}

func stateBaseDir() string {
	d := os.Getenv("XDG_STATE_HOME")
	if d == "" {
		home, _ := os.UserHomeDir()
		d = filepath.Join(home, ".local", "state")
	}
	return filepath.Join(d, "mugen-ai")
}
