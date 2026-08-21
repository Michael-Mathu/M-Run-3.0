package activity

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"strings"

	"github.com/mwendo/backend/internal/auth"
)

// maxRequestBodyBytes caps how much a caller can send us in one request
// body -- without this, an authenticated (or, for other endpoints,
// unauthenticated) caller could send an arbitrarily large JSON payload and
// exhaust server memory/decode time. 5MB comfortably covers a very long
// multi-hour activity's trackpoints with headroom.
const maxRequestBodyBytes = 5 << 20 // 5MB

// maxTrackpoints caps how many trackpoints a single activity can carry.
// 50,000 points is generous (at 1 point/sec that's ~13.8 hours), well
// beyond any real single activity, while still bounding the per-request
// insert loop in DBStore.Create.
const maxTrackpoints = 50000

// API holds the activity domain's dependencies as struct fields instead of
// package-level globals, so multiple instances can run independently.
type API struct {
	Store Store
}

func NewAPI(s Store) *API { return &API{Store: s} }

func (a *API) Handler(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r)
	switch r.Method {
	case "GET":
		limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
		list, err := a.Store.List(r.Context(), userID, limit)
		if err != nil {
			http.Error(w, "server error", http.StatusInternalServerError)
			return
		}
		writeJSON(w, list)
	case "POST":
		r.Body = http.MaxBytesReader(w, r.Body, maxRequestBodyBytes)
		var in ActivityInput
		if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
			http.Error(w, "invalid", http.StatusBadRequest)
			return
		}
		if in.StartedAt.IsZero() {
			http.Error(w, "started_at required", http.StatusBadRequest)
			return
		}
		if len(in.Trackpoints) > maxTrackpoints {
			http.Error(w, fmt.Sprintf("too many trackpoints (max %d)", maxTrackpoints), http.StatusBadRequest)
			return
		}
		act, err := a.Store.Create(r.Context(), userID, in)
		if err != nil {
			http.Error(w, "server error", http.StatusInternalServerError)
			return
		}
		writeJSON(w, act)
	default:
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}

func (a *API) DetailHandler(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r)
	id := strings.TrimPrefix(r.URL.Path, "/api/v1/activities/")
	if id == "" {
		http.Error(w, "missing id", http.StatusBadRequest)
		return
	}
	tol, _ := strconv.ParseFloat(r.URL.Query().Get("simplify"), 64)
	if tol <= 0 {
		tol = 1.0 // 1 metre default simplification tolerance
	}
	act, err := a.Store.Get(r.Context(), id, userID, tol)
	if errors.Is(err, ErrNotFound) {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	if err != nil {
		http.Error(w, "server error", http.StatusInternalServerError)
		return
	}
	writeJSON(w, act)
}

func writeJSON(w http.ResponseWriter, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(v)
}
