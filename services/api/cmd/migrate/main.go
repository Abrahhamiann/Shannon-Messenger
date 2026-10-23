package main

import (
	"context"
	"log"
	"shannon.local/api/internal/database"
	"shannon.local/api/migrations"
	"time"
)

func main() {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	db, err := database.Open(ctx)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()
	if err := migrations.Apply(ctx, db); err != nil {
		log.Fatal("migration failed; verify database permissions and immutable migration files")
	}
	log.Print("migrations applied successfully")
}
