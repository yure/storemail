-- Convert schema 'sql/_source/deploy/35/001-auto.yml' to 'sql/_source/deploy/36/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE message ADD COLUMN header_message_id text NULL;

;

COMMIT;

