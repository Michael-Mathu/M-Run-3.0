package auth

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http/httptest"
	"sync"
	"testing"
)

// TestLoginConcurrentRequestsDoNotRace is a regression test for the fatal
// "concurrent map writes" crash that occurred when refreshTokens was a plain
// map mutated from Login/Refresh/Logout with no synchronization. Run with
// `go test -race` to catch a reintroduced data race, not just a panic.
func TestLoginConcurrentRequestsDoNotRace(t *testing.T) {
	ms := NewMemoryStore()
	hash, err := HashPassword("supersecret")
	if err != nil {
		t.Fatalf("hash: %v", err)
	}
	if _, err := ms.Create(context.Background(), "racer@example.com", hash); err != nil {
		t.Fatalf("seed user: %v", err)
	}
	api := NewAPI(ms, []byte("test-secret"))

	newBody := func() *bytes.Buffer {
		b, _ := json.Marshal(map[string]string{"Email": "racer@example.com", "Password": "supersecret"})
		return bytes.NewBuffer(b)
	}

	const n = 50
	var wg sync.WaitGroup
	wg.Add(n)
	for i := 0; i < n; i++ {
		go func() {
			defer wg.Done()
			w := httptest.NewRecorder()
			r := httptest.NewRequest("POST", "/api/v1/auth/login", newBody())
			api.Login(w, r)
			if w.Code != 200 {
				t.Errorf("expected 200, got %d: %s", w.Code, w.Body.String())
			}
		}()
	}
	wg.Wait()
}
