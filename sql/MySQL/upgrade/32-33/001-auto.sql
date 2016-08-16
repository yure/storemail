-- Convert schema 'sql/_source/deploy/32/001-auto.yml' to 'sql/_source/deploy/33/001-auto.yml':;

;
BEGIN;
SET foreign_key_checks = 0;

ALTER TABLE message DROP FOREIGN KEY message_fk_group_id;

DROP TABLE group_email;
DROP TABLE message_group;

CREATE TABLE `message_group` (
  `internal_id` integer NOT NULL auto_increment,
  `id` varchar(90) NOT NULL,
  `domain` varchar(90) NOT NULL,
  `email` varchar(90) NOT NULL,
  `name` varchar(255) NULL,
  PRIMARY KEY (`internal_id`),
  UNIQUE `id_UNIQUE` (`id`)
) ENGINE=InnoDB;

CREATE TABLE `group_email` (
  `group_id` integer NOT NULL,
  `email` varchar(255) NOT NULL,
  `name` varchar(90) NULL,
  `side` varchar(15) NOT NULL,
  `can_send` tinyint NOT NULL DEFAULT 1,
  `can_recieve` tinyint NOT NULL DEFAULT 1,
  INDEX `group_email_idx_group_id` (`group_id`),
  PRIMARY KEY (`group_id`, `email`),
  CONSTRAINT `group_email_fk_group_id` FOREIGN KEY (`group_id`) REFERENCES `message_group` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

SET foreign_key_checks = 1;


COMMIT;

