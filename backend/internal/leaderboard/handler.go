package leaderboard

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/mwendo/backend/internal/activity"
	"github.com/mwendo/backend/internal/auth"
)

// API holds the leaderboard domain's dependencies as struct fields instead
// of package-level globals, so multiple instances can run independently.
type API struct {
	Board         *Leaderboard
	ActivityStore activity.Store
}

func NewAPI(b *Leaderboard, s activity.Store) *API {
	return &API{Board: b, ActivityStore: s}
}

// TopHandler returns the top N weekly leaderboard entries.
func (a *API) TopHandler(w http.ResponseWriter, r *http.Request) {
	n, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	entries, err := a.Board.Top(r.Context(), n)
	if err != nil {
		http.Error(w, "leaderboard unavailable", http.StatusServiceUnavailable)
		return
	}
	writeJSON(w, map[string]interface{}{"entries": entries})
}

// SubmitHandler adds the authenticated user's total distance to the board.
func (a *API) SubmitHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	userID := auth.UserID(r)
	total, err := a.ActivityStore.TotalDistance(r.Context(), userID)
	if err != nil {
		http.Error(w, "server error", http.StatusInternalServerError)
		return
	}
	if err := a.Board.Submit(r.Context(), userID, total); err != nil {
		http.Error(w, "leaderboard unavailable", http.StatusServiceUnavailable)
		return
	}
	writeJSON(w, map[string]float64{"submitted_m": total})
}

func writeJSON(w http.ResponseWriter, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(v)
}
