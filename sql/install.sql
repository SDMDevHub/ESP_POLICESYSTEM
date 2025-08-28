CREATE TABLE IF NOT EXISTS `security_cameras` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `coords` longtext NOT NULL,
  `rotation` longtext NOT NULL,
  `max_distance` float NOT NULL DEFAULT 50.0,
  `fov` float NOT NULL DEFAULT 60.0,
  `owner` int(11) NOT NULL,
  PRIMARY KEY (`id`)
);

CREATE TABLE IF NOT EXISTS `security_clips` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `camera_id` int(11) NOT NULL,
  `timestamp` bigint(20) NOT NULL,
  `duration` int(11) NOT NULL,
  `coords` longtext NOT NULL,
  PRIMARY KEY (`id`)
);

CREATE TABLE IF NOT EXISTS `security_sheets` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(255) NOT NULL,
  `content` longtext NOT NULL,
  `author` varchar(255) NOT NULL,
  `timestamp` bigint(20) NOT NULL,
  PRIMARY KEY (`id`)
);