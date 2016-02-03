-- Convert schema 'sql/_source/deploy/4/001-auto.yml' to 'sql/_source/deploy/5/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE click ADD COLUMN host varchar(255) NULL,
                  ADD COLUMN path varchar(255) NULL,
                  ADD COLUMN params varchar(255) NULL;

;

COMMIT;

