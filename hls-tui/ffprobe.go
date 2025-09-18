package main

import (
	"bytes"
	"os/exec"
	"strconv"
	"strings"
)

// probeDuration queries ffprobe for the input duration in integer seconds.
func probeDuration(inputFile string) int {
	cmd := exec.Command("ffprobe", "-v", "quiet", "-show_entries", "format=duration", "-of", "csv=p=0", inputFile)
	var out bytes.Buffer
	cmd.Stdout = &out
	if err := cmd.Run(); err != nil {
		return 0
	}
	line := strings.TrimSpace(out.String())
	if line == "" || line == "N/A" {
		return 0
	}
	f, err := strconv.ParseFloat(line, 64)
	if err != nil {
		return 0
	}
	return int(f)
}