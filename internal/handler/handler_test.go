package handler

import (
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5/pgconn"
	"github.com/kukirmash/i-was-here/internal/apperr"
)

func TestResponseError(t *testing.T) {
	tests := []struct {
		name string
		err  error
		code int
		body string
	}{
		{
			name: "not found",
			err:  apperr.ErrNotFound,
			code: http.StatusNotFound,
			body: "not found",
		},
		{
			name: "not found wrapped like repository",
			err:  fmt.Errorf("delete user: %w", apperr.ErrNotFound),
			code: http.StatusNotFound,
			body: "not found",
		},
		{
			name: "already exists",
			err:  apperr.ErrAlreadyExists,
			code: http.StatusConflict,
			body: "already exists",
		},
		{
			name: "already exists wrapped with pg error",
			err: fmt.Errorf("create user: %w: %w", apperr.ErrAlreadyExists,
				&pgconn.PgError{Code: "23505", ConstraintName: "users_login_key"}),
			code: http.StatusConflict,
			body: "already exists",
		},
		{
			name: "invalid password",
			err:  fmt.Errorf("hash password: %w", apperr.ErrInvalidPassword),
			code: http.StatusBadRequest,
			body: "invalid password",
		},
		{
			name: "unknown error",
			err:  errors.New("connection refused"),
			code: http.StatusInternalServerError,
			body: "internal error",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			recorder := httptest.NewRecorder()
			(&UserHandler{}).responseError(recorder, tt.err)

			if recorder.Code != tt.code {
				t.Fatalf("код ответа: получили %d, ожидали %d", recorder.Code, tt.code)
			}
			if got := strings.TrimSpace(recorder.Body.String()); got != tt.body {
				t.Fatalf("тело ответа: получили %q, ожидали %q", got, tt.body)
			}
		})
	}
}
