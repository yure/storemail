-- Convert schema 'sql/_source/deploy/39/001-auto.yml' to 'sql/_source/deploy/40/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE message ADD COLUMN internal tinyint NOT NULL DEFAULT 0;

;

COMMIT;

