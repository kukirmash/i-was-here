package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"time"

	"github.com/kukirmash/i-was-here/internal/handler"
	"github.com/kukirmash/i-was-here/internal/repository"
	"github.com/kukirmash/i-was-here/internal/service"
)

// TODO: slog
func main() {
	logger := slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelDebug,
	}))
	slog.SetDefault(logger)

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	postgresCfg := repository.NewConfigMust()
	connPool, err := repository.NewConnectionPool(ctx, postgresCfg)
	if err != nil {
		logger.Error("failed to create connection pool", slog.Any("err", err))
		os.Exit(1)
	}
	defer connPool.Close()

	r := repository.NewUserRepository(connPool)
	s := service.NewUserService(r)
	h := handler.NewUserHandler(s, logger)

	mux := http.NewServeMux()
	h.RegisterRoutes(mux)

	server := &http.Server{
		Addr:    ":8080",
		Handler: mux,
		// ReadTimeout — максимальное время на чтение всего запроса (заголовки + тело)
		ReadTimeout: 10 * time.Second,
		// WriteTimeout — максимальное время на запись ответа клиенту
		WriteTimeout: 10 * time.Second,
		// IdleTimeout — максимальное время ожидания следующего запроса при keep-alive соединении
		IdleTimeout: 60 * time.Second,
	}
	logger.Info("starting server", slog.String("addr", server.Addr))
	if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		logger.Error("server stopped with error", slog.Any("err", err))
		os.Exit(1)
	}
}
