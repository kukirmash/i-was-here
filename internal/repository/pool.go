package repository

import (
	"context"
	"fmt"
	"net"
	"net/url"

	"github.com/jackc/pgx/v5/pgxpool"
)

// ------------------------------------------------------------------------
func NewConnectionPool(ctx context.Context, config Config) (*pgxpool.Pool, error) {
	url := &url.URL{
		Scheme:   "postgres",
		User:     url.UserPassword(config.User, config.Password),
		Host:     net.JoinHostPort(config.Host, config.Port),
		Path:     config.Database,
		RawQuery: "sslmode=disable",
	}
	pgxconfig, err := pgxpool.ParseConfig(url.String())
	if err != nil {
		return nil, fmt.Errorf("parse pgxconfig: %w", err)
	}

	pool, err := pgxpool.NewWithConfig(ctx, pgxconfig)
	if err != nil {
		return nil, fmt.Errorf("create pgxpool: %w", err)
	}

	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("ping pgxpool: %w", err)
	}

	return pool, nil
}

// ------------------------------------------------------------------------
