// Unit tests for the build-info service. Run by ci/compile.sh (gotestsum),
// which emits reports/junit.xml — the same file GitLab renders natively in
// its pipeline/MR test widget and GitHub stores as a build artifact.
//
// Project: test-agnostic-ci | Created: 2026-09-23
package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// TestGreeting verifies the platform name is embedded and empty input is handled.
func TestGreeting(t *testing.T) {
	if got := Greeting("gitlab-ci"); !strings.Contains(got, "gitlab-ci") {
		t.Errorf("Greeting must mention the platform, got %q", got)
	}
	if got := Greeting(""); got == "" {
		t.Error("Greeting must never be empty")
	}
}

// TestHealthz verifies the liveness endpoint returns 200.
func TestHealthz(t *testing.T) {
	rr := httptest.NewRecorder()
	newMux().ServeHTTP(rr, httptest.NewRequest(http.MethodGet, "/healthz", nil))
	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rr.Code)
	}
}

// TestRootBuildInfo verifies "/" serves valid JSON with the build metadata.
func TestRootBuildInfo(t *testing.T) {
	rr := httptest.NewRecorder()
	newMux().ServeHTTP(rr, httptest.NewRequest(http.MethodGet, "/", nil))
	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rr.Code)
	}
	var info BuildInfo
	if err := json.Unmarshal(rr.Body.Bytes(), &info); err != nil {
		t.Fatalf("invalid JSON: %v", err)
	}
	if info.Service != "test-agnostic-ci" || info.BuiltBy == "" {
		t.Errorf("unexpected payload: %+v", info)
	}
}
