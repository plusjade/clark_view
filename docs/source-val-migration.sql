-- One-time migration executed atomically with sqlite_batch mode=write on 2026-09-07.
-- Requires the verified prototype topology: sources 1/3 and devices in bunch 1.
-- Recovery snapshots are retained; do not rerun this migration.
CREATE TABLE sources_before_val_boundary AS SELECT * FROM sources;
CREATE TABLE device_sources_before_val_boundary AS SELECT * FROM device_sources;
DROP TABLE device_sources;
DROP TABLE sources;
CREATE TABLE sources (
 id INTEGER PRIMARY KEY,
 bunch_id INTEGER NOT NULL REFERENCES bunches(id) ON DELETE RESTRICT,
 name TEXT NOT NULL CHECK(length(trim(name))>0),
 kind TEXT NOT NULL,
 description TEXT NOT NULL,
 settings_schema TEXT NOT NULL DEFAULT '{}' CHECK(json_valid(settings_schema) AND json_type(settings_schema)='object'),
 endpoint TEXT NOT NULL CHECK(endpoint LIKE 'https://%'),
 remote_source_key TEXT NOT NULL CHECK(length(remote_source_key)>0),
 contract_version INTEGER NOT NULL CHECK(contract_version=1),
 credential_ref TEXT NOT NULL,
 created_at TEXT NOT NULL,
 updated_at TEXT NOT NULL
);
INSERT INTO sources SELECT id,1,CASE kind WHEN 'games' THEN 'Sports' ELSE 'Moon' END,kind,description,settings_schema,
 CASE kind WHEN 'games' THEN 'https://plusjade--01a07aad0a727127a01d5ab044902bbe.web.val.run' ELSE 'https://plusjade--0d4599dcaa2611f1be611607ee4eb77e.web.val.run' END,
 CASE kind WHEN 'games' THEN 'sports' ELSE 'moon' END,1,
 CASE kind WHEN 'games' THEN 'SOURCE_SPORTS_V1_TOKEN' ELSE 'DEVICE_FEED_RPC_TOKEN' END,created_at,updated_at FROM sources_before_val_boundary;
CREATE INDEX idx_sources_bunch ON sources(bunch_id);
CREATE TABLE device_sources (
 id INTEGER PRIMARY KEY,
 device_id INTEGER NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
 source_id INTEGER NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
 priority INTEGER NOT NULL DEFAULT 1 CHECK(typeof(priority)='integer' AND priority>=1),
 settings TEXT NOT NULL DEFAULT '{}' CHECK(json_valid(settings) AND json_type(settings)='object'),
 created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
 UNIQUE(device_id,source_id)
);
INSERT INTO device_sources SELECT * FROM device_sources_before_val_boundary;
CREATE INDEX idx_device_sources_source_id ON device_sources(source_id);
CREATE TRIGGER source_assignment_bunch_insert BEFORE INSERT ON device_sources WHEN NOT EXISTS(SELECT 1 FROM devices d JOIN sources s ON s.bunch_id=d.bunch_id WHERE d.id=NEW.device_id AND s.id=NEW.source_id) BEGIN SELECT RAISE(ABORT,'Source must belong to device bunch'); END;
CREATE TRIGGER source_assignment_bunch_update BEFORE UPDATE OF device_id,source_id ON device_sources WHEN NOT EXISTS(SELECT 1 FROM devices d JOIN sources s ON s.bunch_id=d.bunch_id WHERE d.id=NEW.device_id AND s.id=NEW.source_id) BEGIN SELECT RAISE(ABORT,'Source must belong to device bunch'); END;
CREATE TRIGGER source_owner_update BEFORE UPDATE OF bunch_id ON sources WHEN NEW.bunch_id<>OLD.bunch_id AND EXISTS(SELECT 1 FROM device_sources WHERE source_id=OLD.id) BEGIN SELECT RAISE(ABORT,'Detach devices before moving a source'); END;
CREATE TRIGGER device_bunch_move AFTER UPDATE OF bunch_id ON devices WHEN NEW.bunch_id<>OLD.bunch_id BEGIN DELETE FROM device_sources WHERE device_id=NEW.id; END;
