-- Convert schema 'sql/_source/deploy/30/001-auto.yml' to 'sql/_source/deploy/31/001-auto.yml':;

;
BEGIN;

;
SET foreign_key_checks=0;

;
CREATE TABLE `email_blacklist` (
  `email` varchar(90) NOT NULL,
  `timestamp` integer NOT NULL,
  `type` varchar(255) NULL,
  `reason` varchar(255) NULL,
  PRIMARY KEY (`email`)
);

;
SET foreign_key_checks=1;

;

COMMIT;

