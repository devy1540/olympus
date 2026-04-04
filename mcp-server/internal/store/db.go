package store

import (
	"database/sql"
	"fmt"
	"os"
	"path/filepath"

	_ "modernc.org/sqlite"
)

type Store struct {
	db *sql.DB
}

const schemaVersion = 1

const schema = `
CREATE TABLE IF NOT EXISTS schema_version (
	version INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS pipelines (
	id         TEXT PRIMARY KEY,
	skill      TEXT NOT NULL,
	phase      TEXT NOT NULL DEFAULT 'init',
	status     TEXT NOT NULL DEFAULT 'active',
	created_at TEXT NOT NULL,
	updated_at TEXT NOT NULL,
	state_json TEXT
);

CREATE TABLE IF NOT EXISTS agent_spawns (
	id          INTEGER PRIMARY KEY AUTOINCREMENT,
	pipeline_id TEXT NOT NULL REFERENCES pipelines(id),
	agent_name  TEXT NOT NULL,
	phase       TEXT NOT NULL,
	spawned_at  TEXT NOT NULL,
	UNIQUE(pipeline_id, agent_name, phase)
);

CREATE TABLE IF NOT EXISTS gate_scores (
	id          INTEGER PRIMARY KEY AUTOINCREMENT,
	pipeline_id TEXT NOT NULL REFERENCES pipelines(id),
	gate_type   TEXT NOT NULL,
	score       REAL NOT NULL,
	passed      INTEGER NOT NULL DEFAULT 0,
	detail_json TEXT,
	scored_at   TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS execution_history (
	id            INTEGER PRIMARY KEY AUTOINCREMENT,
	pipeline_id   TEXT NOT NULL REFERENCES pipelines(id),
	phase         TEXT NOT NULL,
	agent_name    TEXT NOT NULL,
	duration_ms   INTEGER,
	token_count   INTEGER,
	loc_changed   INTEGER,
	files_touched INTEGER,
	success       INTEGER NOT NULL DEFAULT 1,
	recorded_at   TEXT NOT NULL,
	metrics_json  TEXT
);
`

func OpenRW(dataDir string) (*Store, error) {
	if err := os.MkdirAll(dataDir, 0755); err != nil {
		return nil, fmt.Errorf("create data dir: %w", err)
	}

	dbPath := filepath.Join(dataDir, "olympus.db")
	db, err := sql.Open("sqlite", dbPath+"?_journal=WAL&_busy_timeout=5000")
	if err != nil {
		return nil, fmt.Errorf("open db: %w", err)
	}

	if err := migrate(db); err != nil {
		db.Close()
		return nil, fmt.Errorf("migrate: %w", err)
	}

	return &Store{db: db}, nil
}

func OpenRO(dataDir string) (*Store, error) {
	dbPath := filepath.Join(dataDir, "olympus.db")
	if _, err := os.Stat(dbPath); os.IsNotExist(err) {
		return nil, fmt.Errorf("database not found: %s", dbPath)
	}

	db, err := sql.Open("sqlite", dbPath+"?mode=ro")
	if err != nil {
		return nil, fmt.Errorf("open db (ro): %w", err)
	}

	return &Store{db: db}, nil
}

func (s *Store) Close() error {
	return s.db.Close()
}

func (s *Store) DB() *sql.DB {
	return s.db
}

func migrate(db *sql.DB) error {
	var currentVersion int
	row := db.QueryRow("SELECT version FROM schema_version LIMIT 1")
	if err := row.Scan(&currentVersion); err != nil {
		// Table doesn't exist or is empty — run full schema
		if _, err := db.Exec(schema); err != nil {
			return fmt.Errorf("create schema: %w", err)
		}
		if _, err := db.Exec("INSERT INTO schema_version (version) VALUES (?)", schemaVersion); err != nil {
			return fmt.Errorf("insert schema version: %w", err)
		}
		return nil
	}

	if currentVersion < schemaVersion {
		// Future migrations go here
		if _, err := db.Exec("UPDATE schema_version SET version = ?", schemaVersion); err != nil {
			return fmt.Errorf("update schema version: %w", err)
		}
	}

	return nil
}
