package main

import (
	"bufio"
	"bytes"
	"io"
	"regexp"
	"strconv"
	"strings"
)

var (
	// time=00:01:23.45
	ffTimeRe = regexp.MustCompile(`\btime=([0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]+)?)`)
)

func scanLines(rdr io.ReadCloser, out chan<- string) {
	s := bufio.NewScanner(rdr)
	s.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	for s.Scan() {
		out <- s.Text()
	}
}

// updateProgressFromFFmpegLine parses a single ffmpeg stderr line and updates percent.
func updateProgressFromFFmpegLine(durationSec int, line string, current float64) float64 {
	if durationSec <= 0 {
		return current
	}
	m := ffTimeRe.FindStringSubmatch(line)
	if len(m) != 2 {
		return current
	}
	sec := parseHHMMSStoSeconds(m[1])
	if sec <= 0 {
		return current
	}
	p := float64(sec) / float64(durationSec)
	if p > 1.0 {
		p = 1.0
	}
	return p
}

func parseHHMMSStoSeconds(s string) int {
	parts := strings.Split(s, ":")
	if len(parts) != 3 {
		return 0
	}
	h := atoi(parts[0])
	m := atoi(parts[1])
	secPart := parts[2]
	f := atof(secPart)
	return int(float64(h*3600+m*60) + f)
}

func atoi(s string) int {
	i, _ := strconv.Atoi(strings.TrimSpace(s))
	return i
}

func atof(s string) float64 {
	// allow decimals
	b := bytes.TrimSpace([]byte(s))
	f, _ := strconv.ParseFloat(string(b), 64)
	return f
}