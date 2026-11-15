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
        inventoryEquipment: List<Equipment>? = null
    ): EquipmentActionResult {
        if (equipment.id.isBlank()) {
            return EquipmentActionResult(loadout, false, "Este equipamento não possui uma identificação válida.")
        }
        if (inventoryEquipment != null) {
            val matchingItems = inventoryEquipment.filter { it.id == equipment.id }
            if (matchingItems.size != 1 || matchingItems.single() != equipment) {
                return EquipmentActionResult(loadout, false, "Este equipamento não está disponível no seu inventário.")
            }
        }
        if (equipment.levelRequired < 1) {
            return EquipmentActionResult(loadout, false, "Este equipamento possui um requisito de nível inválido.")
        }
        if (characterLevel < equipment.levelRequired) {
            return EquipmentActionResult(loadout, false, "Você precisa estar no nível ${equipment.levelRequired} para usar este equipamento.")
        }

        val physicalAffinity = characterClass.affinities[SkillDomain.PHYSICAL] ?: Affinity.MEDIUM
        val classeCorpoACorpo = characterClass.id in setOf("warrior", "guardian", "assassin") ||
            (characterClass.isCustom && physicalAffinity == Affinity.HIGH)

        val nome = equipment.name.lowercase()
        val armaPesada = equipment.type == EquipmentType.WEAPON &&
            listOf("pesad", "heavy", "martelo de guerra", "machado de guerra", "maça de guerra", "marreta").any(nome::contains)
        val duasMaos = equipment.type == EquipmentType.WEAPON &&
            listOf("duas mãos", "duas maos", "two-handed", "two handed", "espadão", "greatsword", "montante").any(nome::contains)

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
                val nomeArmaAtual = armaAtual?.name.orEmpty().lowercase()
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

    /** Remove do loadout referências ausentes, ambíguas ou incompatíveis com o slot. */
    fun normalizarLoadout(
        loadout: EquipmentLoadout,
        inventory: List<Equipment>
    ): EquipmentLoadout {
        val porId = inventory
            .filter { it.id.isNotBlank() }
            .groupBy { it.id }
            .filterValues { it.size == 1 }
            .mapValues { it.value.single() }
        val usados = mutableSetOf<String>()
        fun valido(
            id: String?,
            tipos: Set<EquipmentType>,
            armaPesadaObrigatoria: Boolean = false
        ): String? {
            val candidato = id?.takeIf(String::isNotBlank) ?: return null
            val item = porId[candidato] ?: return null
            if (item.type !in tipos || !usados.add(candidato)) return null
            if (armaPesadaObrigatoria && item.type == EquipmentType.WEAPON) {
                val nome = item.name.lowercase()
                val pesada = listOf("pesad", "heavy", "martelo de guerra", "machado de guerra", "maça de guerra", "marreta").any(nome::contains)
                if (!pesada) return null
            }
            return candidato
        }
        return EquipmentLoadout(
            weaponId = valido(loadout.weaponId, setOf(EquipmentType.WEAPON)),
            shieldId = valido(loadout.shieldId, setOf(EquipmentType.SHIELD, EquipmentType.WEAPON), armaPesadaObrigatoria = true),
            armorId = valido(loadout.armorId, setOf(EquipmentType.ARMOR)),
            helmetId = valido(loadout.helmetId, setOf(EquipmentType.HELMET)),
            bootsId = valido(loadout.bootsId, setOf(EquipmentType.BOOTS)),
            glovesId = valido(loadout.glovesId, setOf(EquipmentType.GLOVES)),
            ringId = valido(loadout.ringId, setOf(EquipmentType.RING)),
            necklaceId = valido(loadout.necklaceId, setOf(EquipmentType.NECKLACE))
        )
    }

    fun equipmentForVisuals(
        loadout: EquipmentLoadout,
        inventory: List<Equipment>
    ): List<Equipment> {
        val ids = loadout.equippedIds()
        val equipamentosPorId = inventory
            .filter { it.id.isNotBlank() && it.id in ids }
            .groupBy { it.id }
        return ids.mapNotNull { id ->
            equipamentosPorId[id]?.singleOrNull()
        }
    }
}
