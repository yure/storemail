-- Convert schema 'sql/_source/deploy/2/001-auto.yml' to 'sql/_source/deploy/3/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE batch DROP COLUMN domain,
                  ADD COLUMN name varchar(255) NULL;

;

COMMIT;

