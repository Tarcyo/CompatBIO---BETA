-- CreateTable
CREATE TABLE `password_reset_token` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `email` VARCHAR(254) NOT NULL,
    `hmac` VARCHAR(128) NOT NULL,
    `expires_at` DATETIME(3) NOT NULL,
    `jti` VARCHAR(64) NULL,
    `used` BOOLEAN NOT NULL DEFAULT false,
    `consumed` BOOLEAN NOT NULL DEFAULT false,
    `attempts` INTEGER NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP(0) NOT NULL DEFAULT CURRENT_TIMESTAMP(0),
    `used_at` DATETIME(3) NULL,

    INDEX `idx_password_reset_email`(`email`),
    INDEX `idx_password_reset_jti`(`jti`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
