package activity

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"os"
	"testing"
	"time"

	"github.com/mwendo/backend/internal/db"
)

// These tests exercise the real Postgres/PostGIS-backed DBStore -- the
// in-memory MemoryStore tests in store_test.go don't touch this code path
// at all (geography casts, ST_Simplify, transaction commit/rollback), and
// neither did CI before this change. Opt-in via TEST_DATABASE_URL so a
// plain `go test ./...` without a real database still passes/skips
// cleanly; see .github/workflows/test.yml's go-test job for how CI
// provides a real postgres service and sets this.
//
// NOT locally executed while writing this: this development environment has
// no Docker/Postgres available to run against. Written against store.go's
// actual SQL (read directly, not guessed) and the same migration
// (0001_init.sql) docker-compose.yml uses, but treat this file as
// unverified until it's actually run once -- in CI, or locally with
// `TEST_DATABASE_URL=postgres://mwendo:mwendo@localhost:5432/mwendo?sslmode=disable go test ./internal/activity/...`
// against `docker compose up -d db`.
func testDBStore(t *testing.T) *DBStore {
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

func testUserID(t *testing.T) string {
	t.Helper()
	b := make([]byte, 8)
	if _, err := rand.Read(b); err != nil {
		t.Fatalf("rand.Read: %v", err)
	}
	return "test-user-" + hex.EncodeToString(b)
}

func TestDBStore_CreateAndGet_RoundTripsRouteAndTrackpoints(t *testing.T) {
	store := testDBStore(t)
	ctx := context.Background()
	userID := testUserID(t)

	in := ActivityInput{
		Type:           "run",
		StartedAt:      time.Date(2026, 7, 12, 9, 0, 0, 0, time.UTC),
		DistanceM:      321.5,
		MovingTimeMs:   120000,
		ElevationGainM: 4.0,
		Trackpoints: []Trackpoint{
			{Lat: -1.2921, Lng: 36.8219, Elevation: 1600, Timestamp: time.Date(2026, 7, 12, 9, 0, 0, 0, time.UTC), SpeedMps: 2.8},
			{Lat: -1.2925, Lng: 36.8223, Elevation: 1601, Timestamp: time.Date(2026, 7, 12, 9, 1, 0, 0, time.UTC), SpeedMps: 3.0},
			{Lat: -1.2930, Lng: 36.8228, Elevation: 1602, Timestamp: time.Date(2026, 7, 12, 9, 2, 0, 0, time.UTC), SpeedMps: 2.9},
		},
	}

	created, err := store.Create(ctx, userID, in)
	if err != nil {
		t.Fatalf("Create: %v", err)
	}
	if created.ID == "" {
		t.Fatal("expected a non-empty generated ID")
	}
	if created.UserID != userID {
		t.Errorf("UserID = %q, want %q", created.UserID, userID)
	}

	got, err := store.Get(ctx, created.ID, userID, 0) // simplifyTol=0: no simplification
	if err != nil {
		t.Fatalf("Get: %v", err)
	}
	if got.DistanceM != in.DistanceM {
		t.Errorf("DistanceM = %v, want %v", got.DistanceM, in.DistanceM)
	}
	if len(got.Trackpoints) != len(in.Trackpoints) {
		t.Fatalf("got %d trackpoints, want %d", len(got.Trackpoints), len(in.Trackpoints))
	}
	// ST_MakePoint(lng, lat) then ST_Y/ST_X on read back -- confirm lat/lng
	// didn't get swapped anywhere in the round trip (an easy PostGIS mistake).
	if abs(got.Trackpoints[0].Lat-in.Trackpoints[0].Lat) > 1e-6 {
		t.Errorf("Trackpoints[0].Lat = %v, want %v", got.Trackpoints[0].Lat, in.Trackpoints[0].Lat)
	}
	if abs(got.Trackpoints[0].Lng-in.Trackpoints[0].Lng) > 1e-6 {
		t.Errorf("Trackpoints[0].Lng = %v, want %v", got.Trackpoints[0].Lng, in.Trackpoints[0].Lng)
	}
	if len(got.Route) != len(in.Trackpoints) {
		t.Errorf("Route has %d points, want %d (simplifyTol=0 should keep every vertex)", len(got.Route), len(in.Trackpoints))
	}
}

func TestDBStore_Create_FewerThanTwoTrackpoints_HasNoRoute(t *testing.T) {
	store := testDBStore(t)
	ctx := context.Background()
	userID := testUserID(t)

	created, err := store.Create(ctx, userID, ActivityInput{
		Type:      "run",
		StartedAt: time.Now().UTC(),
		DistanceM: 0,
		Trackpoints: []Trackpoint{
			{Lat: 0, Lng: 0, Timestamp: time.Now().UTC()},
		},
	})
	if err != nil {
		t.Fatalf("Create: %v", err)
	}

	got, err := store.Get(ctx, created.ID, userID, 0)
	if err != nil {
		t.Fatalf("Get: %v", err)
	}
	if len(got.Route) != 0 {
		t.Errorf("expected no route with <2 trackpoints, got %d points", len(got.Route))
	}
}

func TestDBStore_Get_ScopesToOwningUser(t *testing.T) {
	store := testDBStore(t)
	ctx := context.Background()
	owner := testUserID(t)
	other := testUserID(t)

	created, err := store.Create(ctx, owner, ActivityInput{
		Type:      "run",
		StartedAt: time.Now().UTC(),
		DistanceM: 500,
	})
	if err != nil {
		t.Fatalf("Create: %v", err)
	}

	// A different user asking for the same activity ID must not see it --
	// this is the IDOR check: Get filters by `id AND user_id`.
	if _, err := store.Get(ctx, created.ID, other, 0); !errors.Is(err, ErrNotFound) {
		t.Errorf("Get by a non-owning user: err = %v, want ErrNotFound", err)
	}

	// The real owner can still see it.
	if _, err := store.Get(ctx, created.ID, owner, 0); err != nil {
		t.Errorf("Get by the owning user: unexpected error %v", err)
	}
}

func TestDBStore_Get_MissingActivity_ReturnsErrNotFound(t *testing.T) {
	store := testDBStore(t)
	if _, err := store.Get(context.Background(), "does-not-exist", testUserID(t), 0); !errors.Is(err, ErrNotFound) {
		t.Errorf("err = %v, want ErrNotFound", err)
	}
}

func TestDBStore_List_FiltersByUserAndOrdersByStartedAtDesc(t *testing.T) {
	store := testDBStore(t)
	ctx := context.Background()
	userID := testUserID(t)
	other := testUserID(t)

	older := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	newer := time.Date(2026, 1, 2, 0, 0, 0, 0, time.UTC)

	if _, err := store.Create(ctx, userID, ActivityInput{Type: "run", StartedAt: older, DistanceM: 1000}); err != nil {
		t.Fatalf("Create (older): %v", err)
	}
	newerActivity, err := store.Create(ctx, userID, ActivityInput{Type: "run", StartedAt: newer, DistanceM: 2000})
	if err != nil {
		t.Fatalf("Create (newer): %v", err)
	}
	if _, err := store.Create(ctx, other, ActivityInput{Type: "run", StartedAt: newer, DistanceM: 9999}); err != nil {
		t.Fatalf("Create (other user): %v", err)
	}

	list, err := store.List(ctx, userID, 10)
	if err != nil {
		t.Fatalf("List: %v", err)
	}
	if len(list) != 2 {
		t.Fatalf("List returned %d activities, want 2 (other user's activity must not appear)", len(list))
	}
	if list[0].ID != newerActivity.ID {
		t.Errorf("List[0] = %q, want the most recent activity %q (started_at DESC)", list[0].ID, newerActivity.ID)
	}
}

func TestDBStore_TotalDistance_SumsOnlyThatUsersActivities(t *testing.T) {
	store := testDBStore(t)
	ctx := context.Background()
	userID := testUserID(t)
	other := testUserID(t)

	if _, err := store.Create(ctx, userID, ActivityInput{Type: "run", StartedAt: time.Now().UTC(), DistanceM: 1000}); err != nil {
		t.Fatalf("Create: %v", err)
	}
	if _, err := store.Create(ctx, userID, ActivityInput{Type: "run", StartedAt: time.Now().UTC(), DistanceM: 500}); err != nil {
		t.Fatalf("Create: %v", err)
	}
	if _, err := store.Create(ctx, other, ActivityInput{Type: "run", StartedAt: time.Now().UTC(), DistanceM: 99999}); err != nil {
		t.Fatalf("Create (other user): %v", err)
	}

	total, err := store.TotalDistance(ctx, userID)
	if err != nil {
		t.Fatalf("TotalDistance: %v", err)
	}
	if total != 1500 {
		t.Errorf("TotalDistance = %v, want 1500 (other user's distance must not be included)", total)
	}
}

func abs(f float64) float64 {
	if f < 0 {
		return -f
	}
	return f
}
