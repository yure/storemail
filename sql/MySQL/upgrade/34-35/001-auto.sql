-- Convert schema 'sql/_source/deploy/34/001-auto.yml' to 'sql/_source/deploy/35/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE message_group ADD COLUMN tag varchar(90) NULL;

;

COMMIT;

