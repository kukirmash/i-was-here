package repository

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/kukirmash/i-was-here/internal/apperr"
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
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return models.User{}, fmt.Errorf("create user: %w: %w", apperr.ErrAlreadyExists, err)
		}
		return models.User{}, fmt.Errorf("scan user: %w", err)
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
func (r *UserRepository) GetByID(ctx context.Context, id int) (models.User, error) {
	query := `
	SELECT id, version, login, password, created_at
	FROM iwh.users
	WHERE iwh.users.id = $1`

	row := r.pool.QueryRow(ctx, query, id)

	var user models.User
	err := row.Scan(
		&user.ID,
		&user.Version,
		&user.Login,
		&user.Password,
		&user.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return models.User{}, fmt.Errorf("get user: %w", apperr.ErrNotFound)
		}
		return models.User{}, fmt.Errorf("scan user: %w", err)
	}

	return user, nil
}

// ------------------------------------------------------------------------
func (r *UserRepository) Update(ctx context.Context, id int, user models.User) (models.User, error) {
	query := `
	UPDATE iwh.users
	SET
		login=$1,
		password=$2,
		version=version+1
	WHERE id=$3 AND version=$4
	RETURNING
		id,
		version,
		login,
		created_at`

	row := r.pool.QueryRow(ctx, query, user.Login, user.Password, id, user.Version)

	var updatedUser models.User
	if err := row.Scan(
		&updatedUser.ID,
		&updatedUser.Version,
		&updatedUser.Login,
		&updatedUser.CreatedAt,
	); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return models.User{}, fmt.Errorf("update user: %w", apperr.ErrNotFound)
		}
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return models.User{}, fmt.Errorf("update user: %w: %w", apperr.ErrAlreadyExists, err)
		}
		return models.User{}, fmt.Errorf("scan user: %w", err)
	}

	return updatedUser, nil
}

// ------------------------------------------------------------------------
func (r *UserRepository) Delete(ctx context.Context, id int) error {
	query := `
	DELETE
	FROM iwh.users
	WHERE iwh.users.id = $1`

	cmdTag, err := r.pool.Exec(ctx, query, id)
	if err != nil {
		return fmt.Errorf("exec query: %w", err)
	}
	if cmdTag.RowsAffected() == 0 {
		return fmt.Errorf("delete user: %w", apperr.ErrNotFound)
	}

	return nil
}

// ------------------------------------------------------------------------
