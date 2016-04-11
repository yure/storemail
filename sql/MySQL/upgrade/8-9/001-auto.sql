-- Convert schema 'sql/_source/deploy/8/001-auto.yml' to 'sql/_source/deploy/9/001-auto.yml':;

;
BEGIN;
SET foreign_key_checks=0;
;
ALTER TABLE message DROP FOREIGN KEY message_fk_conversation_id,
                    DROP INDEX message_idx_conversation_id,
                    DROP COLUMN conversation_id;

;
DROP TABLE conversation;

;
ALTER TABLE user DROP FOREIGN KEY user_fk_conversation_id;

;
DROP TABLE user;

;
SET foreign_key_checks=1;
COMMIT;

