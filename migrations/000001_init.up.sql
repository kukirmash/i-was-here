CREATE SCHEMA iwh;

CREATE TABLE iwh.users(
    id       SERIAL               PRIMARY KEY,
    version  INTEGER     NOT NULL DEFAULT 1,
    login    VARCHAR(32) NOT NULL CHECK(char_length(login) BETWEEN 3 AND 32),
    password VARCHAR(64) NOT NULL
);
