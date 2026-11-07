
package br.com.ascensaodosoberano.companions

data class InventoryItem(
    val id: String,
    val name: String,
    val description: String,
    val type: String,
    val quantity: Int = 1,
    val imagemIconeCaminho: String = "",
    val imagemDetalhadaCaminho: String = "",
    val materialRank: String = "COMUM",
    val materialOrigin: String = "",
    val materialTraits: List<String> = emptyList(),
    val sourceCreatureId: String = ""
)

data class PlayerInventory(
    val items: List<InventoryItem> = emptyList(),
    val eggs: List<PetEgg> = emptyList(),
    val companions: List<Companion> = emptyList(),
    val equipment: List<Equipment> = emptyList(),
    val gold: Long = 0L
)

object InventorySystem {

    fun addItem(
        inventory: PlayerInventory,
        item: InventoryItem
    ): PlayerInventory {
        val existing = inventory.items.find {
            it.id == item.id
        }

        return if (existing != null) {
            inventory.copy(
                items = inventory.items.map {
                    if (it.id == item.id) {
                        it.copy(
                            quantity = it.quantity + item.quantity
                        )
                    } else {
                        it
                    }
                }
            )
        } else {
            inventory.copy(items = inventory.items + item)
        }
    }

    // Cada ovo conserva sua própria identidade e mutação.
    fun addEgg(
        inventory: PlayerInventory,
        egg: PetEgg
    ): PlayerInventory {
        return inventory.copy(
            eggs = inventory.eggs + egg.copy(quantity = 1)
        )
    }

    fun addCompanion(
        inventory: PlayerInventory,
        companion: Companion
    ): PlayerInventory {
        if (inventory.companions.any {
                it.id == companion.id
            }) {
            return inventory
        }

        val novoCompanheiro = if (companion.isActive) {
            companion
        } else {
            companion.copy(isActive = false)
        }

        return inventory.copy(
            companions = inventory.companions + novoCompanheiro
        )
    }

    fun removeEgg(
        inventory: PlayerInventory,
        eggId: String
    ): PlayerInventory {
        return inventory.copy(
            eggs = inventory.eggs.filterNot {
                it.id == eggId
            }
        )
    }

    fun hatchEgg(
        inventory: PlayerInventory,
        eggId: String,
        companion: Companion
    ): PlayerInventory {

        val egg = inventory.eggs.firstOrNull {
            it.id == eggId
        } ?: return inventory

        if (inventory.companions.any {
                it.id == companion.id
            }) {
            return inventory
        }

        val newCompanion = companion.copy(
            originalMonsterId = egg.monsterId,
            originalMonsterRank = egg.rank,

            mutationId = egg.mutationId,
            mutationName = egg.mutationName,
            mutationRarity = egg.mutationRarity,
            mutationDescription = egg.mutationDescription,

            mutationHpPercent = egg.mutationHpPercent,
            mutationAttackPercent = egg.mutationAttackPercent,
            mutationDefensePercent = egg.mutationDefensePercent,
            mutationAgilityPercent = egg.mutationAgilityPercent,
            mutationMagicPercent = egg.mutationMagicPercent,

            isActive = false
        )

        return inventory.copy(
            eggs = inventory.eggs.filterNot {
                it.id == eggId
            },
            companions = inventory.companions + newCompanion
        )
    }

    fun addEquipment(
        inventory: PlayerInventory,
        equipment: Equipment
    ): PlayerInventory {
        return inventory.copy(
            equipment = inventory.equipment + equipment
        )
    }

    fun ativarCompanheiro(
        inventory: PlayerInventory,
        companionId: String
    ): PlayerInventory {

        if (inventory.companions.none {
                it.id == companionId
            }) {
            return inventory
        }

        return inventory.copy(
            companions = inventory.companions.map {
                it.copy(isActive = it.id == companionId)
            }
        )
    }

    fun retirarCompanheiro(
        inventory: PlayerInventory
    ): PlayerInventory {
        return inventory.copy(
            companions = inventory.companions.map {
                it.copy(isActive = false)
            }
        )
    }

    fun obterCompanheiroAtivo(
        inventory: PlayerInventory
    ): Companion? {
        return inventory.companions.firstOrNull {
            it.isActive
        }
    }
}
