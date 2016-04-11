-- Convert schema 'sql/_source/deploy/11/001-auto.yml' to 'sql/_source/deploy/12/001-auto.yml':;

;
BEGIN;

;
;
ALTER TABLE message_group ADD COLUMN name varchar(255) NOT NULL;

;

COMMIT;

