package br.com.ascensaodosoberano.character

import br.com.ascensaodosoberano.companions.Equipment
import br.com.ascensaodosoberano.companions.EquipmentLoadout
import br.com.ascensaodosoberano.companions.EquipmentType

data class EquipmentActionResult(
    val loadout: EquipmentLoadout,
    val success: Boolean,
    val message: String
)

/** Regras centrais para vestir e retirar equipamentos. */
object EquipmentSystem {

    fun equipar(
        loadout: EquipmentLoadout,
        equipment: Equipment,
        characterClass: CharacterClass,
        characterLevel: Int,
        inventoryEquipment: List<Equipment> = emptyList()
    ): EquipmentActionResult {
        if (characterLevel < equipment.levelRequired) {
            return EquipmentActionResult(loadout, false, "Você precisa estar no nível ${equipment.levelRequired} para usar este equipamento.")
        }

        val physicalAffinity = characterClass.affinities[SkillDomain.PHYSICAL] ?: Affinity.MEDIUM
        val classeCorpoACorpo = characterClass.id in setOf("warrior", "guardian", "assassin") ||
            (characterClass.isCustom && physicalAffinity == Affinity.HIGH)

        val nome = (equipment.name + " " + equipment.description).lowercase()
        val armaPesada = equipment.type == EquipmentType.WEAPON &&
            listOf("pesad", "heavy", "martelo de guerra", "machado de guerra", "maça de guerra", "marreta").any(nome::contains)
        val duasMaos = equipment.type == EquipmentType.WEAPON &&
            listOf("duas mãos", "duas maos", "two-handed", "two handed", "espadão", "espadão", "greatsword", "montante").any(nome::contains)

        val atualizado = when (equipment.type) {
            EquipmentType.WEAPON -> when {
                armaPesada -> loadout.copy(weaponId = null, shieldId = equipment.id)
                duasMaos -> loadout.copy(weaponId = equipment.id, shieldId = null)
                else -> {
                    val itemAtualNaMaoSecundaria = inventoryEquipment.firstOrNull { it.id == loadout.shieldId }
                    val liberarMaoSecundaria = itemAtualNaMaoSecundaria?.type == EquipmentType.WEAPON
                    val shieldIdAfterEquip: String? =
                        if (liberarMaoSecundaria) null else loadout.shieldId
                    EquipmentLoadout(
                        weaponId = equipment.id,
                        shieldId = shieldIdAfterEquip,
                        armorId = loadout.armorId,
                        helmetId = loadout.helmetId,
                        bootsId = loadout.bootsId,
                        glovesId = loadout.glovesId,
                        ringId = loadout.ringId,
                        necklaceId = loadout.necklaceId
                    )
                }
            }
            EquipmentType.SHIELD -> {
                if (!classeCorpoACorpo) {
                    return EquipmentActionResult(loadout, false, "Escudos só podem ser usados por classes de combate corpo a corpo.")
                }
                val armaAtual = inventoryEquipment.firstOrNull { it.id == loadout.weaponId }
                val nomeArmaAtual = (armaAtual?.name.orEmpty() + " " + armaAtual?.description.orEmpty()).lowercase()
                val armaAtualDuasMaos = armaAtual != null && (
                    listOf("duas mãos", "duas maos", "two-handed", "two handed", "espadão", "greatsword", "montante").any(nomeArmaAtual::contains) ||
                    listOf("pesad", "heavy", "martelo de guerra", "machado de guerra", "maça de guerra", "marreta").any(nomeArmaAtual::contains)
                )
                if (armaAtualDuasMaos) {
                    return EquipmentActionResult(loadout, false, "Uma arma de duas mãos não pode ser usada com escudo.")
                }
                loadout.copy(shieldId = equipment.id)
            }
            EquipmentType.ARMOR -> loadout.copy(armorId = equipment.id)
            EquipmentType.HELMET -> loadout.copy(helmetId = equipment.id)
            EquipmentType.BOOTS -> loadout.copy(bootsId = equipment.id)
            EquipmentType.GLOVES -> loadout.copy(glovesId = equipment.id)
            EquipmentType.RING -> loadout.copy(ringId = equipment.id)
            EquipmentType.NECKLACE -> loadout.copy(necklaceId = equipment.id)
        }

        val mensagem = when {
            armaPesada -> "Arma pesada equipada no espaço de escudo."
            duasMaos -> "Arma de duas mãos equipada. O espaço de escudo foi liberado."
            equipment.type == EquipmentType.SHIELD -> "Escudo equipado."
            else -> "Equipamento vestido."
        }
        return EquipmentActionResult(atualizado, true, mensagem)
    }

    fun retirar(loadout: EquipmentLoadout, equipmentId: String): EquipmentLoadout =
        loadout.copy(
            weaponId = loadout.weaponId.takeUnless { it == equipmentId },
            shieldId = loadout.shieldId.takeUnless { it == equipmentId },
            armorId = loadout.armorId.takeUnless { it == equipmentId },
            helmetId = loadout.helmetId.takeUnless { it == equipmentId },
            bootsId = loadout.bootsId.takeUnless { it == equipmentId },
            glovesId = loadout.glovesId.takeUnless { it == equipmentId },
            ringId = loadout.ringId.takeUnless { it == equipmentId },
            necklaceId = loadout.necklaceId.takeUnless { it == equipmentId }
        )

    fun equipmentForVisuals(
        loadout: EquipmentLoadout,
        inventory: List<Equipment>
    ): List<Equipment> {
        val ids = loadout.equippedIds()
        return inventory.filter { it.id in ids }
    }
}
