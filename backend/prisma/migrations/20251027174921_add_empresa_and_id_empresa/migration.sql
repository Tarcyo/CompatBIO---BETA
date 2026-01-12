-- AlterTable
ALTER TABLE `usuario` ADD COLUMN `id_empresa` INTEGER NULL;

-- CreateTable
CREATE TABLE `empresa` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `nome` VARCHAR(200) NOT NULL,
    `cnpj` CHAR(14) NOT NULL,
    `corTema` CHAR(7) NOT NULL,

    UNIQUE INDEX `empresa_cnpj_key`(`cnpj`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateIndex
CREATE INDEX `fk_usuario_empresa` ON `usuario`(`id_empresa`);

-- AddForeignKey
ALTER TABLE `usuario` ADD CONSTRAINT `fk_usuario_empresa` FOREIGN KEY (`id_empresa`) REFERENCES `empresa`(`id`) ON DELETE SET NULL ON UPDATE NO ACTION;
