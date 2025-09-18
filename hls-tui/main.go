package main

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/bubbles/progress"
	"github.com/charmbracelet/bubbles/viewport"
	"github.com/charmbracelet/lipgloss"
)

type startedMsg struct{}
type finishedMsg struct{}
type errMsg struct{ err error }
type lineMsg string

// model holds UI state
// We stream ffmpeg stderr through a channel and parse progress in Update.
type model struct {
	filename    string
	useEnhanced bool
	durationSec int
	percent     float64
	status      string
	progress    progress.Model
	logView     viewport.Model
	args        []string

	// process management
	cancel context.CancelFunc
	lineCh chan string
	doneCh chan error

	started bool
	done    bool
	err     error
}

var (
	paddingStyle = lipgloss.NewStyle().Padding(1, 2)
	logStyle     = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(lipgloss.Color("#444")).Padding(0, 1)
)

func initialModel(filename string, useEnhanced bool, durationSec int) model {
	p := progress.New(progress.WithDefaultGradient())
	p.FullColor = string(lipgloss.Color("#5DF"))
	p.EmptyColor = string(lipgloss.Color("#222"))
	lv := viewport.Model{Width: 80, Height: 12}
	lv.SetContent("")
	return model{
		filename:    filename,
		useEnhanced: useEnhanced,
		durationSec: durationSec,
		status:      "Ready",
		progress:    p,
		logView:     lv,
		lineCh:      make(chan string, 256),
		doneCh:      make(chan error, 1),
	}
}

func (m model) Init() tea.Cmd { return nil }

func (m model) View() string {
	var b strings.Builder
	b.WriteString(paddingStyle.Render(fmt.Sprintf(
		"hls-compressor TUI\n\nFile: %s\nScript: %s\nStatus: %s\nArgs: %s\n\n",
		m.filename, scriptName(m.useEnhanced), m.status, strings.Join(m.args, " "),
	)))
	b.WriteString(m.progress.ViewAs(m.percent))
	b.WriteString("\n\n")
	b.WriteString(logStyle.Render(m.logView.View()))
	b.WriteString("\n\n")
	if !m.started {
		b.WriteString("Press Enter to start, q to quit.\n")
	} else if m.done {
		b.WriteString("Job finished. Press q to exit.\n")
	} else {
		b.WriteString("Running… press q to cancel/exit.\n")
	}
	if m.err != nil {
		b.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color("#f55")).Render(m.err.Error()))
	}
	return b.String()
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "q":
			if m.cancel != nil {
				m.cancel()
			}
			return m, tea.Quit
		case "enter":
			if !m.started && !m.done {
				return m, tea.Batch(m.startEncoding(), m.waitForNextEvent())
			}
		}
	case tea.WindowSizeMsg:
		// Adjust viewport
		h := msg.Height - 12
		if h < 6 {
			h = 6
		}
		m.logView.Width = msg.Width - 6
		m.logView.Height = h
	case startedMsg:
		m.started = true
		m.status = "Encoding…"
		return m, m.waitForNextEvent()
	case lineMsg:
		// Parse line for progress time and append to log
		ln := string(msg)
		m.percent = updateProgressFromFFmpegLine(m.durationSec, ln, m.percent)
		if strings.TrimSpace(ln) != "" {
			m.status = ln
			m.logView.SetContent(m.logView.View() + ln + "\n")
		}
		return m, tea.Batch(m.progress.SetPercent(m.percent), m.waitForNextEvent())
	case finishedMsg:
		m.done = true
		m.status = "Done"
		return m, nil
	case errMsg:
		m.err = msg.err
		m.done = true
		m.status = "Error"
		return m, nil
	}
	// Note: we’re not forwarding messages to the progress component here.
	// For advanced resize handling, wire progress.Update(msg) and assign back.
	return m, nil
}

func (m model) startEncoding() tea.Cmd {
	return func() tea.Msg {
		ctx, cancel := context.WithCancel(context.Background())
		// Keep cancel so we can stop it on quit
		m.cancel = cancel
		// Start the runner in a goroutine
		go func() {
if err := runScript(ctx, m.useEnhanced, m.filename, m.args, m.lineCh); err != nil {
				m.doneCh <- err
				return
			}
			m.doneCh <- nil
		}()
		return startedMsg{}
	}
}

// waitForNextEvent blocks until we receive either a line or done and returns a Msg.
func (m model) waitForNextEvent() tea.Cmd {
	return func() tea.Msg {
		select {
		case ln := <-m.lineCh:
			return lineMsg(ln)
		case err := <-m.doneCh:
			if err != nil {
				return errMsg{err}
			}
			return finishedMsg{}
		}
	}
}

func scriptName(enhanced bool) string {
	if enhanced {
		return "enhanced_hls.sh"
	}
	return "hls_script.sh"
}

func scriptPath(enhanced bool) string {
	return "./" + scriptName(enhanced)
}

func bashWrapArgs(exe string, args ...string) (string, []string) {
	// On Windows, prefer running via bash if available; macOS/Linux just run script
	if runtime.GOOS == "windows" {
		joined := exe
		if len(args) > 0 {
			joined += " " + strings.Join(args, " ")
		}
		return "bash", []string{"-lc", joined}
	}
	return exe, args
}

func runScript(ctx context.Context, enhanced bool, filename string, extraArgs []string, out chan<- string) error {
	script := scriptPath(enhanced)
	if _, err := os.Stat(script); err != nil {
		return fmt.Errorf("script not found: %s", script)
	}
	// Ensure working dir contains the input .mp4
	input := filename + ".mp4"
	if _, err := os.Stat(input); err != nil {
		// Not fatal, the script will report a clearer error; just warn
		out <- fmt.Sprintf("warning: input file not found here: %s", input)
	}

allArgs := append([]string{filename}, extraArgs...)
exe, args := bashWrapArgs(script, allArgs...)
cmd := exec.CommandContext(ctx, exe, args...)
	cmd.Dir = mustAbs(".")
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return err
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return err
	}
	if err := cmd.Start(); err != nil {
		return err
	}
	// Stream both stdout/stderr
	go scanLines(stdout, out)
	go scanLines(stderr, out)
	return cmd.Wait()
}

func mustAbs(p string) string {
	abs, err := filepath.Abs(p)
	if err != nil {
		return p
	}
	return abs
}