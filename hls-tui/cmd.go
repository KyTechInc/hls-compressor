package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
)

// normalizeFilename accepts either "name" or "name.mp4" and returns
// (basenameWithoutExt, probePath).
func normalizeFilename(arg string) (string, string) {
	base := filepath.Base(arg)
	ext := strings.ToLower(filepath.Ext(base))
	switch ext {
	case ".mp4":
		return strings.TrimSuffix(base, ext), base
	case ".mov", ".m4v":
		// Scripts expect .mp4; we'll still probe the actual file if provided
		return strings.TrimSuffix(base, ext), base
	default:
		return base, base + ".mp4"
	}
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: hls-tui <video-name-or-path> [flags]\\n\\nFlags (enhanced script):\\n  -q string     quality preset: fast|balanced|quality (default \\\"balanced\\\")\\n  -r string     comma-separated resolutions, e.g. \\\"1440,1080,720\\\" (default \\\"1440,1080,720\\\")\\n  -hw           enable hardware acceleration when available\\n  -t            add text overlay\\n  -basic        use basic script instead of enhanced\\n")
		os.Exit(1)
	}

	// Find the first non-flag token as the filename argument (allows flags before/after)
	var filenameToken string
	var flagTokens []string
	for _, a := range os.Args[1:] {
		if strings.HasPrefix(a, "-") && filenameToken == "" {
			flagTokens = append(flagTokens, a)
			continue
		}
		if filenameToken == "" {
			filenameToken = a
			continue
		}
		// after filename found, remaining tokens go to flags too
		flagTokens = append(flagTokens, a)
	}
	if filenameToken == "" {
		fmt.Println("error: missing input filename")
		os.Exit(1)
	}

filename, probeRel := normalizeFilename(filenameToken)
// Determine working directory based on provided path (if any)
workDir := ""
if dir := filepath.Dir(filenameToken); dir != "." && dir != "" {
	workDir, _ = filepath.Abs(dir)
}
probePath := probeRel
if workDir != "" && !filepath.IsAbs(probeRel) {
	probePath = filepath.Join(workDir, probeRel)
}
if abs, err := filepath.Abs(probePath); err == nil { probePath = abs }

// Decide what to pass into the script as the first argument:
// - If user provided a .mp4 path and it exists, pass the absolute .mp4 path (scripts handle it)
// - Otherwise pass the basename (scripts will append .mp4)
passFirstArg := filename
if strings.HasSuffix(strings.ToLower(filenameToken), ".mp4") {
	passFirstArg = probePath
}

	fs := flag.NewFlagSet("hls-tui", flag.ContinueOnError)
	fs.SetOutput(new(strings.Builder)) // suppress default error printing
	var (
		flagBasic bool
		flagQ    string
		flagR    string
		flagHW   bool
		flagT    bool
	)
	fs.BoolVar(&flagBasic, "basic", false, "use basic script")
	fs.StringVar(&flagQ, "q", "balanced", "quality preset")
	fs.StringVar(&flagR, "r", "1440,1080,720", "resolutions")
	fs.BoolVar(&flagHW, "hw", false, "hardware acceleration")
	fs.BoolVar(&flagT, "t", false, "text overlay")
	_ = fs.Parse(flagTokens)

	useEnhanced := !flagBasic
	var passArgs []string
	if useEnhanced {
		if flagT {
			passArgs = append(passArgs, "-t")
		}
		if flagHW {
			passArgs = append(passArgs, "-hw")
		}
		if flagR != "" {
			passArgs = append(passArgs, "-r", flagR)
		}
		if flagQ != "" {
			passArgs = append(passArgs, "-q", flagQ)
		}
	} else {
		if flagT {
			passArgs = append(passArgs, "-t")
		}
	}

	dur := probeDuration(probePath)
m := initialModel(filename, useEnhanced, dur)
m.args = passArgs
m.workDir = workDir
m.probePath = probePath
m.firstArg = passFirstArg
	p := tea.NewProgram(m, tea.WithAltScreen())
	if err := p.Start(); err != nil {
		fmt.Println("error:", err)
		os.Exit(1)
	}
}
