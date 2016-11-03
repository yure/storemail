-- Convert schema 'sql/_source/deploy/36/001-auto.yml' to 'sql/_source/deploy/37/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE batch ADD COLUMN record_created datetime NOT NULL,
                  ADD COLUMN record_updated datetime NOT NULL;

;
-- ALTER TABLE email ADD COLUMN id integer NULL;

;
ALTER TABLE message_group ADD COLUMN record_created datetime NOT NULL,
                          ADD COLUMN record_updated datetime NOT NULL;

;

COMMIT;

