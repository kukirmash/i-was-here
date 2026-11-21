package models

import "time"

type User struct {
	ID        int       `json:"id"`
	Version   int       `json:"version"`
	Login     string    `json:"login"`
	Password  string    `json:"-"`
	CreatedAt time.Time `json:"created_at"`
}

type UserPage struct {
	Users      []User `json:"users"`
	NextCursor *int   `json:"next_cursor"`
}
