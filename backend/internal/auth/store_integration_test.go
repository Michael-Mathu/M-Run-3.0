package auth

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"os"
	"testing"

	"github.com/mwendo/backend/internal/db"
)

// Exercises the real Postgres-backed DBStore -- store_test.go only covers
// MemoryStore. Opt-in via TEST_DATABASE_URL; see
// activity/store_integration_test.go for the full rationale and the
// "not locally executed" caveat, which applies here too.
func testAuthDBStore(t *testing.T) *DBStore {
	t.Helper()
	url := os.Getenv("TEST_DATABASE_URL")
	if url == "" {
		t.Skip("TEST_DATABASE_URL not set; skipping Postgres integration test")
	}
	conn, err := db.Open(url)
	if err != nil {
		t.Fatalf("db.Open: %v", err)
	}
	t.Cleanup(func() { conn.Close() })
	if err := db.Migrate(conn); err != nil {
		t.Fatalf("db.Migrate: %v", err)
	}
	return NewDBStore(conn)
}

func testEmail(t *testing.T) string {
	t.Helper()
	b := make([]byte, 8)
	if _, err := rand.Read(b); err != nil {
		t.Fatalf("rand.Read: %v", err)
	}
	return "test-" + hex.EncodeToString(b) + "@example.com"
}

func TestDBStore_CreateAndGetByEmail_RoundTrips(t *testing.T) {
	store := testAuthDBStore(t)
	ctx := context.Background()
	email := testEmail(t)

	hash, err := HashPassword("supersecretpassword")
	if err != nil {
		t.Fatalf("HashPassword: %v", err)
	}

	created, err := store.Create(ctx, email, hash)
	if err != nil {
		t.Fatalf("Create: %v", err)
	}
	if created.ID == "" {
		t.Fatal("expected a non-empty generated ID")
	}
	if created.Email != email {
		t.Errorf("Email = %q, want %q", created.Email, email)
	}

	got, err := store.GetByEmail(ctx, email)
	if err != nil {
		t.Fatalf("GetByEmail: %v", err)
	}
	if got.ID != created.ID {
		t.Errorf("GetByEmail ID = %q, want %q", got.ID, created.ID)
	}
	if got.Password != hash {
		t.Errorf("GetByEmail Password = %q, want the stored hash %q", got.Password, hash)
	}
}

func TestDBStore_Create_DuplicateEmail_ReturnsErrConflict(t *testing.T) {
	store := testAuthDBStore(t)
	ctx := context.Background()
	email := testEmail(t)
	hash, _ := HashPassword("supersecretpassword")

	if _, err := store.Create(ctx, email, hash); err != nil {
		t.Fatalf("first Create: %v", err)
	}
	_, err := store.Create(ctx, email, hash)
	if !IsConflict(err) {
		t.Errorf("second Create with the same email: err = %v, want ErrConflict", err)
	}
}

func TestDBStore_GetByEmail_UnknownEmail_ReturnsErrNotFound(t *testing.T) {
	store := testAuthDBStore(t)
	_, err := store.GetByEmail(context.Background(), testEmail(t))
	if !errors.Is(err, ErrNotFound) {
		t.Errorf("err = %v, want ErrNotFound", err)
	}
}
