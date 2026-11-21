package handler

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"strconv"

	"github.com/go-playground/validator/v10"
	"github.com/kukirmash/i-was-here/internal/models"
)

var requestValidator = validator.New()

// ------------------------------------------------------------------------
type UserService interface {
	Create(ctx context.Context, login, password string) (models.User, error)
	GetUsers(ctx context.Context, limit, cursor int) (models.UserPage, error)
	// GetByID(ctx context.Context, id int) (models.User, error)
	// Update(ctx context.Context, id int, newLogin, newPassword *string) (models.User, error)
	// Delete(ctx context.Context, id int) error
}

// ------------------------------------------------------------------------
type UserHandler struct {
	service UserService
	logger  *slog.Logger
}

// ------------------------------------------------------------------------
func NewUserHandler(service UserService, logger *slog.Logger) *UserHandler {
	return &UserHandler{
		service: service,
		logger:  logger,
	}
}

// ------------------------------------------------------------------------
func (h *UserHandler) RegisterRoutes(mux *http.ServeMux) {
	mux.HandleFunc("POST /users", h.Create)
	mux.HandleFunc("GET /users", h.GetUsers)
}

// ------------------------------------------------------------------------
func (h *UserHandler) Create(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var input struct {
		Login    string `json:"login"    validate:"required,min=3,max=32"`
		Password string `json:"password" validate:"required,min=8,max=64"`
	}

	// декодирование
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		h.logger.Warn("failed to decode request body", slog.Any("err", err))
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	// валидация
	if err := requestValidator.Struct(input); err != nil {
		h.logger.Warn("failed to validate request body", slog.Any("err", err))
		http.Error(w, "validate error", http.StatusBadRequest)
		return
	}

	// создание
	user, err := h.service.Create(ctx, input.Login, input.Password)
	if err != nil {
		h.logger.Error("failed to create user",
			slog.String("login", input.Login),
			slog.Any("err", err),
		)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	h.logger.Info("user created",
		slog.Int("id", user.ID),
		slog.String("login", user.Login),
	)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	if err := json.NewEncoder(w).Encode(user); err != nil {
		h.logger.Error("failed to encode response", slog.Any("err", err))
	}
}

// ------------------------------------------------------------------------
func (h *UserHandler) GetUsers(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	limitStr := r.URL.Query().Get("limit")
	if limitStr == "" {
		limitStr = "20"
	}

	cursorStr := r.URL.Query().Get("cursor")
	if cursorStr == "" {
		cursorStr = "0"
	}

	limit, err := strconv.Atoi(limitStr)
	if err != nil {
		h.logger.Warn("failed to read query params", slog.Any("err", err))
		http.Error(w, "invalid query params", http.StatusBadRequest)
		return
	}

	cursor, err := strconv.Atoi(cursorStr)
	if err != nil {
		h.logger.Warn("failed to read query params", slog.Any("err", err))
		http.Error(w, "invalid query params", http.StatusBadRequest)
		return
	}

	userPage, err := h.service.GetUsers(ctx, limit, cursor)
	if err != nil {
		h.logger.Error("failed to get user page",
			slog.Any("err", err),
		)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	h.logger.Info("get user page",
		slog.Int("len", len(userPage.Users)))

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(userPage); err != nil {
		h.logger.Error("failed to encode response", slog.Any("err", err))
	}
}

// ------------------------------------------------------------------------
func (h *UserHandler) GetByID(w http.ResponseWriter, r *http.Request) {

}

// ------------------------------------------------------------------------
func (h *UserHandler) Update(w http.ResponseWriter, r *http.Request) {

}

// ------------------------------------------------------------------------
func (h *UserHandler) Delete(w http.ResponseWriter, r *http.Request) {

}

// ------------------------------------------------------------------------
