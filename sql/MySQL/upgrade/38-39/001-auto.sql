-- Convert schema 'sql/_source/deploy/38/001-auto.yml' to 'sql/_source/deploy/39/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE group_email CHANGE COLUMN email email varchar(255) NOT NULL,
                        CHANGE COLUMN name name varchar(255) NULL;

;

COMMIT;

