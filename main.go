// Package main implements build-info: a tiny HTTP service that is the
// deliverable of this CI-agnostic pipeline POC.
//
// The binary reports how it was produced (version, commit, builtBy) via
// variables injected at compile time by ci/compile.sh. Hitting "/" on a
// running container is the proof that the exact same build logic ran on
// GitHub Actions, GitLab CI, Jenkins, or a developer laptop.
//
// Project: test-agnostic-ci | Created: 2026-09-23
package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"runtime"
)

// Build metadata. Overridden at compile time by ci/compile.sh via
// -ldflags "-X main.version=... -X main.commit=... -X main.builtBy=...".
var (
	version = "dev"
	commit  = "unknown"
	builtBy = "local"
)

// BuildInfo is the JSON document served at "/".
type BuildInfo struct {
	Service   string `json:"service"`
	Message   string `json:"message"`
	Version   string `json:"version"`
	Commit    string `json:"commit"`
	BuiltBy   string `json:"builtBy"`
	GoVersion string `json:"goVersion"`
}

// Greeting returns the human-readable banner served at "/".
//
// platform is the CI system (or "local") that produced the running binary;
// it is embedded in the returned sentence. Never returns an empty string.
func Greeting(platform string) string {
	if platform == "" {
		platform = "an unknown builder"
	}
	return fmt.Sprintf("Hello! The exact same pipeline logic built me on %s.", platform)
}

// newMux builds the HTTP routing table. Split from main so tests can
// exercise the handlers with httptest without binding a port.
func newMux() *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprintln(w, "ok")
	})
	mux.HandleFunc("GET /", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(BuildInfo{
			Service:   "test-agnostic-ci",
			Message:   Greeting(builtBy),
			Version:   version,
			Commit:    commit,
			BuiltBy:   builtBy,
			GoVersion: runtime.Version(),
		})
	})
	return mux
}

func main() {
	addr := ":8080"
	if p := os.Getenv("PORT"); p != "" {
		addr = ":" + p
	}
	log.Printf("build-info %s (%s) built by %s — listening on %s", version, commit, builtBy, addr)
	if err := http.ListenAndServe(addr, newMux()); err != nil {
		log.Fatal(err)
	}
}
