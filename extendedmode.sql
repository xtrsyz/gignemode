CREATE TABLE `users` (
	`identifier` VARCHAR(60) NOT NULL,
	`name` VARCHAR(50) NULL DEFAULT '',
	`steam` VARCHAR(50) DEFAULT NULL,
	`license` VARCHAR(50) DEFAULT NULL,
	`discord` VARCHAR(50) DEFAULT NULL,
	`fivem` VARCHAR(50) DEFAULT NULL,
	`xbl` VARCHAR(50) DEFAULT NULL,
	`live` VARCHAR(50) DEFAULT NULL,
	`ip` VARCHAR(50) DEFAULT NULL,
	`accounts` LONGTEXT DEFAULT NULL,
	`groups` LONGTEXT DEFAULT NULL,
	`inventory` LONGTEXT DEFAULT NULL,
	`skin` LONGTEXT DEFAULT NULL,
	`health` LONGTEXT DEFAULT NULL,
	`status` LONGTEXT DEFAULT NULL,
	`job` VARCHAR(20) NULL DEFAULT 'unemployed',
	`job_grade` INT NULL DEFAULT 0,
	`loadout` LONGTEXT NULL DEFAULT NULL,
	`position` VARCHAR(255) NULL DEFAULT NULL,

	PRIMARY KEY (`identifier`)
);

CREATE TABLE `items` (
	`name` VARCHAR(50) NOT NULL,
	`label` VARCHAR(50) NOT NULL,
	`weight` INT NOT NULL DEFAULT 1,
	`limit` INT DEFAULT NULL,
	`rare` TINYINT NOT NULL DEFAULT 0,
	`can_remove` TINYINT NOT NULL DEFAULT 1,

	PRIMARY KEY (`name`)
);

CREATE TABLE `user_batch` (
	`identifier` VARCHAR(60) NOT NULL,
	`name` VARCHAR(50) NOT NULL,
	`batch` VARCHAR(50) NOT NULL,
	`info` LONGTEXT NOT NULL,
	`count` INT(11) NOT NULL DEFAULT 0,
	`created_at` TIMESTAMP NOT NULL DEFAULT current_timestamp(),

	PRIMARY KEY (`identifier`, `name`, `batch`)
);

CREATE TABLE `job_grades` (
	`id` INT NOT NULL AUTO_INCREMENT,
	`job_name` VARCHAR(50) DEFAULT NULL,
	`grade` INT NOT NULL,
	`name` VARCHAR(50) NOT NULL,
	`label` VARCHAR(50) NOT NULL,
	`salary` INT NOT NULL,
	`skin_male` LONGTEXT NOT NULL,
	`skin_female` LONGTEXT NOT NULL,

	PRIMARY KEY (`id`)
);

INSERT INTO `job_grades` VALUES (1,'unemployed',0,'unemployed','Unemployed', 50,'{}','{}');

CREATE TABLE `jobs` (
	`name` VARCHAR(50) NOT NULL,
	`label` VARCHAR(50) DEFAULT NULL,

	PRIMARY KEY (`name`)
);

INSERT INTO `jobs` VALUES ('unemployed','Unemployed');
