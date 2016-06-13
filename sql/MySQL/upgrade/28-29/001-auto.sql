-- Convert schema 'sql/_source/deploy/28/001-auto.yml' to 'sql/_source/deploy/29/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE event ADD COLUMN record_created datetime NOT NULL,
                  ADD COLUMN record_updated datetime NOT NULL;

;

COMMIT;

