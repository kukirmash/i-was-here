package service

import (
	"context"
	"fmt"
	"time"

	"github.com/kukirmash/i-was-here/internal/models"
)

// ------------------------------------------------------------------------
type UserRepository interface {
	Create(ctx context.Context, user models.User) (models.User, error)
	GetUsers(ctx context.Context, limit, cursor int) ([]models.User, error)
	// GetByID(ctx context.Context, id int) (models.User, error)
	// Update(ctx context.Context, id int, newLogin, newPassword *string) (models.User, error)
	// Delete(ctx context.Context, id int) error
}

// ------------------------------------------------------------------------
type UserService struct {
	repository UserRepository
}

// ------------------------------------------------------------------------
func NewUserService(repository UserRepository) *UserService {
	return &UserService{
		repository: repository,
	}
}

// -----------------------------------------------------------------------
func (s *UserService) Create(ctx context.Context, login, password string) (models.User, error) {
	passwordHash, err := HashPassword(password)
	if err != nil {
		return models.User{}, fmt.Errorf("hash password: %w", err)
	}

	var user models.User = models.User{
		Login:     login,
		Password:  passwordHash,
		CreatedAt: time.Now(),
	}

	createdUser, err := s.repository.Create(ctx, user)
	if err != nil {
		return models.User{}, fmt.Errorf("create user: %w", err)
	}

	return createdUser, nil
}

// ------------------------------------------------------------------------
func (s *UserService) GetUsers(ctx context.Context, limit, cursor int) (models.UserPage, error) {
	if limit <= 0 {
		limit = 20
	}
	if limit > 50 {
		limit = 50
	}
	if cursor < 0 {
		cursor = 0
	}

	users, err := s.repository.GetUsers(ctx, limit+1, cursor)
	if err != nil {
		return models.UserPage{}, fmt.Errorf("get users: %w", err)
	}

	var nextCursor *int
	if len(users) > limit {
		users = users[:limit]
		lastID := users[len(users)-1].ID
		nextCursor = &lastID
	}

	return models.UserPage{
		Users:      users,
		NextCursor: nextCursor,
	}, nil
}

// // ------------------------------------------------------------------------
// func (s *UserService) GetByID(ctx context.Context, id int) (models.User, error) {

// }

// // ------------------------------------------------------------------------
// func (s *UserService) Update(ctx context.Context, id int, newLogin, newPassword *string) (models.User, error) {

// }

// // ------------------------------------------------------------------------
// func (s *UserService) Delete(ctx context.Context, id int) {

// }

// ------------------------------------------------------------------------
