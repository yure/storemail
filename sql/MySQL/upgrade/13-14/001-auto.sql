-- Convert schema 'sql/_source/deploy/13/001-auto.yml' to 'sql/_source/deploy/14/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE group_email ADD COLUMN can_send tinyint NOT NULL DEFAULT 1,
                        ADD COLUMN can_recieve tinyint NOT NULL DEFAULT 1,
                        CHANGE COLUMN side side varchar(15) NOT NULL;

;
ALTER TABLE message_group CHANGE COLUMN name name varchar(255) NULL;

;

COMMIT;

