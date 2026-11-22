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
	GetByID(ctx context.Context, id int) (models.User, error)
	Update(ctx context.Context, id int, user models.User) (models.User, error)
	Delete(ctx context.Context, id int) error
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

	user := models.User{
		Login:     login,
		Password:  passwordHash,
		CreatedAt: time.Now().UTC(),
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

// ------------------------------------------------------------------------
func (s *UserService) GetByID(ctx context.Context, id int) (models.User, error) {
	user, err := s.repository.GetByID(ctx, id)
	if err != nil {
		return models.User{}, fmt.Errorf("get user: %w", err)
	}

	return user, nil
}

// ------------------------------------------------------------------------
func (s *UserService) Update(ctx context.Context, id int, patch models.UserPatch) (models.User, error) {
	user, err := s.repository.GetByID(ctx, id)
	if err != nil {
		return models.User{}, fmt.Errorf("get user: %w", err)
	}

	if patch.Password != nil {
		hash, err := HashPassword(*patch.Password)
		if err != nil {
			return models.User{}, fmt.Errorf("hash password: %w", err)
		}
		patch.Password = &hash
	}

	if patch.HasChanges() == false {
		return user, nil
	}

	user.ApplyPatch(patch)

	updatedUser, err := s.repository.Update(ctx, id, user)
	if err != nil {
		return models.User{}, fmt.Errorf("update user: %w", err)
	}

	return updatedUser, nil
}

// ------------------------------------------------------------------------
func (s *UserService) Delete(ctx context.Context, id int) error {
	if err := s.repository.Delete(ctx, id); err != nil {
		return fmt.Errorf("delete user: %w", err)
	}

	return nil
}

// ------------------------------------------------------------------------
