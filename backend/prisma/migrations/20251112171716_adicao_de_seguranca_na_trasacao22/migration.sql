-- DropForeignKey
ALTER TABLE `compra` DROP FOREIGN KEY `fk_compra_usuario`;

-- AlterTable
ALTER TABLE `compra` MODIFY `id_usuario` INTEGER NULL;

-- AddForeignKey
ALTER TABLE `compra` ADD CONSTRAINT `fk_compra_usuario` FOREIGN KEY (`id_usuario`) REFERENCES `usuario`(`id`) ON DELETE SET NULL ON UPDATE NO ACTION;
