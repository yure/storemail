-- Convert schema 'sql/_source/deploy/27/001-auto.yml' to 'sql/_source/deploy/28/001-auto.yml':;

;
BEGIN;

;
SET foreign_key_checks=0;

;
CREATE TABLE `event` (
  `id` integer NOT NULL auto_increment,
  `timestamp` integer NULL,
  `sendgrid_id` varchar(64) NULL,
  `email` varchar(255) NULL,
  `type` varchar(255) NULL,
  `data` text NULL,
  PRIMARY KEY (`id`),
  UNIQUE `event_sendgrid_id` (`sendgrid_id`)
);

;
SET foreign_key_checks=1;

;

COMMIT;

