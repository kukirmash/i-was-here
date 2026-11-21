package service

import "golang.org/x/crypto/bcrypt"

// -----------------------------------------------------------------------
// 1. Вызываем при регистрации или смене пароля
func HashPassword(password string) (string, error) {
	// занимает ~50-70 мс
	bytes, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return "", err
	}
	return string(bytes), nil
}

// -----------------------------------------------------------------------
// 2. Вызываем при логине (сравниваем введенный пароль и строку из БД)
func CheckPassword(password, hashFromDB string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hashFromDB), []byte(password))
	return err == nil
}

// -----------------------------------------------------------------------
