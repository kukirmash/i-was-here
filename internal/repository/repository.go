package repository

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/kukirmash/i-was-here/internal/models"
)

// ------------------------------------------------------------------------
type UserRepository struct {
	pool *pgxpool.Pool
}

// ------------------------------------------------------------------------
func NewUserRepository(pool *pgxpool.Pool) *UserRepository {
	return &UserRepository{
		pool: pool,
	}
}

// ------------------------------------------------------------------------
func (r *UserRepository) Create(ctx context.Context, user models.User) (models.User, error) {
	query := `
	INSERT INTO iwh.users (login, password, created_at)
	VALUES ($1, $2, $3)
	RETURNING id, version, login, created_at`

	row := r.pool.QueryRow(ctx, query, user.Login, user.Password, user.CreatedAt)

	var createdUser models.User
	err := row.Scan(
		&createdUser.ID,
		&createdUser.Version,
		&createdUser.Login,
		&createdUser.CreatedAt,
	)
	if err != nil {
		return models.User{}, fmt.Errorf("scan error: %w", err)
	}

	return createdUser, nil
}

// ------------------------------------------------------------------------
func (r *UserRepository) GetUsers(ctx context.Context, limit, cursor int) ([]models.User, error) {
	query := `
	SELECT id, version, login, created_at
	FROM iwh.users
	WHERE id > $1
	ORDER BY id ASC
	LIMIT $2`

	rows, err := r.pool.Query(ctx, query, cursor, limit)
	if err != nil {
		return nil, fmt.Errorf("select users: %w", err)
	}
	defer rows.Close()

	users := make([]models.User, 0, limit)
	for rows.Next() {

		var user models.User
		err := rows.Scan(
			&user.ID,
			&user.Version,
			&user.Login,
			&user.CreatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("scan user: %w", err)
		}

		users = append(users, user)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("next rows: %w", err)
	}

	return users, nil
}

// ------------------------------------------------------------------------
