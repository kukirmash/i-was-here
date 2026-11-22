package models

import (
	"time"
)

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

type UserPatch struct {
	Login    *string
	Password *string
}

func (u *User) ApplyPatch(p UserPatch) {
	if p.Login != nil {
		u.Login = *p.Login
	}
	if p.Password != nil {
		u.Password = *p.Password
	}
}

func (p *UserPatch) HasChanges() bool {
	return p.Login != nil || p.Password != nil
}
