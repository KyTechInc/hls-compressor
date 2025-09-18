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
	// Match our script's job start line
	jobStartRe = regexp.MustCompile(`^Converting to\s+([0-9]{3,4})p\s+\(`)
)

func scanLines(rdr io.ReadCloser, out chan<- string) {
	s := bufio.NewScanner(rdr)
	s.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	// Split on either \n or \r to capture ffmpeg in-place updates
	s.Split(func(data []byte, atEOF bool) (advance int, token []byte, err error) {
		for i := 0; i < len(data); i++ {
			if data[i] == '\n' || data[i] == '\r' {
				return i + 1, dropCRLF(data[:i]), nil
			}
		}
		if atEOF && len(data) > 0 {
			return len(data), dropCRLF(data), nil
		}
		return 0, nil, nil
	})
	for s.Scan() {
		ln := strings.TrimSpace(s.Text())
		if ln != "" {
			out <- ln
		}
	}
}

func dropCRLF(b []byte) []byte {
	// Trim trailing CR or LF if present
	n := len(b)
	for n > 0 && (b[n-1] == '\n' || b[n-1] == '\r') {
		n--
	}
	return b[:n]
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

// detectJobStartHeight returns the height when a new job starts, or 0 if not matched.
func detectJobStartHeight(line string) int {
	m := jobStartRe.FindStringSubmatch(line)
	if len(m) != 2 {
		return 0
	}
	return atoi(m[1])
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
