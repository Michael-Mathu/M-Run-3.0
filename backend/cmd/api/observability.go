package main

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"log/slog"
	"net/http"
	"sync/atomic"
	"time"
)

// metrics holds process-local counters exposed at /api/v1/metrics in a
// minimal Prometheus-compatible text format. Deliberately stdlib-only (no
// external metrics client library) -- this environment could not verify a
// new dependency fetches cleanly, so this stays dependency-free.
type metrics struct {
	requestsTotal atomic.Int64
	errorsTotal   atomic.Int64
}

func (m *metrics) handler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/plain; version=0.0.4")
	fmt.Fprintln(w, "# HELP mwendo_http_requests_total Total HTTP requests received.")
	fmt.Fprintln(w, "# TYPE mwendo_http_requests_total counter")
	fmt.Fprintf(w, "mwendo_http_requests_total %d\n", m.requestsTotal.Load())
	fmt.Fprintln(w, "# HELP mwendo_http_errors_total Total HTTP responses with status >= 400.")
	fmt.Fprintln(w, "# TYPE mwendo_http_errors_total counter")
	fmt.Fprintf(w, "mwendo_http_errors_total %d\n", m.errorsTotal.Load())
}

// statusRecorder captures the status code a handler actually wrote, since
// http.ResponseWriter doesn't expose it after the fact.
type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (r *statusRecorder) WriteHeader(code int) {
	r.status = code
	r.ResponseWriter.WriteHeader(code)
}

// observabilityMiddleware logs each request as structured JSON (method,
// path, status, duration, a per-request correlation id) via log/slog, and
// updates m's counters. Previously the backend had no structured logging or
// request visibility at all -- just stdlib log.Println at startup.
func observabilityMiddleware(m *metrics, logger *slog.Logger, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		reqID := newRequestID()
		rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}

		next.ServeHTTP(rec, r)

		m.requestsTotal.Add(1)
		if rec.status >= 400 {
			m.errorsTotal.Add(1)
		}
		logger.Info("http_request",
			"request_id", reqID,
			"method", r.Method,
			"path", r.URL.Path,
			"status", rec.status,
			"duration_ms", time.Since(start).Milliseconds(),
		)
	})
}

func newRequestID() string {
	b := make([]byte, 8)
	rand.Read(b)
	return hex.EncodeToString(b)
}
