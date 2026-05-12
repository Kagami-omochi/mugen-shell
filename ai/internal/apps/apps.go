// Package apps reads XDG desktop entries so the tools registry can resolve
// a basename ("zen-bin") to the absolute Exec path ("/opt/zen-browser-bin/
// zen-bin"). Without this, app_launch silently fires `exec zen-bin` via
// Hyprland for binaries that aren't on $PATH and the user sees "launched"
// while nothing actually opens.
package apps

import (
	"bufio"
	"os"
	"path/filepath"
	"strings"
)

// Resolver caches a basename → absolute-exec map built from .desktop
// entries discovered under XDG data dirs.
type Resolver struct {
	byBin map[string]string
}

// Load walks all XDG application dirs once and returns a populated
// Resolver. Reload by calling Load again — there's no live watcher.
func Load() *Resolver {
	r := &Resolver{byBin: map[string]string{}}
	for _, dir := range desktopDirs() {
		files, _ := filepath.Glob(filepath.Join(dir, "*.desktop"))
		for _, f := range files {
			bin, exec, ok := parseDesktop(f)
			if !ok {
				continue
			}
			// First win: respect the search order (user > system).
			if _, seen := r.byBin[bin]; seen {
				continue
			}
			r.byBin[bin] = exec
		}
	}
	return r
}

// Resolve returns the absolute Exec path (with placeholders stripped) for
// a binary basename, or "" if no .desktop entry advertises it. Callers
// should fall through to the original cmd when this returns empty.
func (r *Resolver) Resolve(basename string) string {
	if r == nil {
		return ""
	}
	return r.byBin[basename]
}

func parseDesktop(path string) (string, string, bool) {
	f, err := os.Open(path)
	if err != nil {
		return "", "", false
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	inMain := false
	var exec string
	var noDisplay, hidden bool
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		if strings.HasPrefix(line, "[") {
			// We only care about the [Desktop Entry] group; sub-groups
			// (Actions etc.) carry their own Exec lines we shouldn't pick up.
			if line == "[Desktop Entry]" {
				inMain = true
			} else if inMain {
				break
			}
			continue
		}
		if !inMain {
			continue
		}
		switch {
		case strings.HasPrefix(line, "Exec=") && exec == "":
			exec = strings.TrimPrefix(line, "Exec=")
		case line == "NoDisplay=true":
			noDisplay = true
		case line == "Hidden=true":
			hidden = true
		}
	}
	if exec == "" || noDisplay || hidden {
		return "", "", false
	}
	tokens := strings.Fields(exec)
	if len(tokens) == 0 {
		return "", "", false
	}
	binary := filepath.Base(tokens[0])
	clean := stripPlaceholders(tokens)
	if clean == "" {
		return "", "", false
	}
	return binary, clean, true
}

// stripPlaceholders drops field codes (%u %U %f %F %i %c %k) defined by the
// XDG desktop-entry spec. Backslash sequences other than the literals are
// left alone — we don't need to fully tokenise the line.
func stripPlaceholders(tokens []string) string {
	out := make([]string, 0, len(tokens))
	for _, t := range tokens {
		if len(t) == 2 && t[0] == '%' {
			continue
		}
		out = append(out, t)
	}
	return strings.Join(out, " ")
}

func desktopDirs() []string {
	var dirs []string
	home, _ := os.UserHomeDir()
	if xdgData := os.Getenv("XDG_DATA_HOME"); xdgData != "" {
		dirs = append(dirs, filepath.Join(xdgData, "applications"))
	} else if home != "" {
		dirs = append(dirs, filepath.Join(home, ".local/share/applications"))
	}
	if xdgDataDirs := os.Getenv("XDG_DATA_DIRS"); xdgDataDirs != "" {
		for _, d := range strings.Split(xdgDataDirs, ":") {
			if d == "" {
				continue
			}
			dirs = append(dirs, filepath.Join(d, "applications"))
		}
	} else {
		dirs = append(dirs,
			"/usr/local/share/applications",
			"/usr/share/applications",
		)
	}
	return dirs
}
