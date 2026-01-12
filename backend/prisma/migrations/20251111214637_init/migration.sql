-- CreateTable
CREATE TABLE `notify_token` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `token` VARCHAR(64) NOT NULL,
    `id_usuario` INTEGER NULL,
    `session_id` VARCHAR(255) NULL,
    `expires_at` DATETIME(3) NOT NULL,
    `used` BOOLEAN NOT NULL DEFAULT false,
    `created_at` TIMESTAMP(0) NOT NULL DEFAULT CURRENT_TIMESTAMP(0),

    UNIQUE INDEX `notify_token_token_key`(`token`),
    INDEX `idx_notify_token_usuario`(`id_usuario`),
    INDEX `idx_notify_token_session`(`session_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
