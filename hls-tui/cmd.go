package main

import (
	"flag"
	"fmt"
	"os"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: hls-tui <video-name-without-ext> [flags]\n\nFlags (enhanced script):\n  -q string     quality preset: fast|balanced|quality (default \"balanced\")\n  -r string     comma-separated resolutions, e.g. \"1440,1080,720\" (default \"1440,1080,720\")\n  -hw           enable hardware acceleration when available\n  -t            add text overlay\n  -basic        use basic script instead of enhanced\n")
		os.Exit(1)
	}

	// Positional arg: filename (without extension)
	filename := os.Args[1]
	args := os.Args[2:]

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
	_ = fs.Parse(args)

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

	dur := probeDuration(filename + ".mp4")
	m := initialModel(filename, useEnhanced, dur)
	m.args = passArgs
	p := tea.NewProgram(m, tea.WithAltScreen())
	if err := p.Start(); err != nil {
		fmt.Println("error:", err)
		os.Exit(1)
	}
}
