
package br.com.ascensaodosoberano.combat

import br.com.ascensaodosoberano.companions.InventoryItem
import br.com.ascensaodosoberano.companions.Equipment
import br.com.ascensaodosoberano.companions.PetEgg
import br.com.ascensaodosoberano.companions.PetEggSystem
import br.com.ascensaodosoberano.world.CriaturaGerada

data class MonsterLoot(
    val egg: PetEgg? = null,
    val items: List<InventoryItem> = emptyList(),
    val equipment: List<Equipment> = emptyList(),
    val gold: Long = 0L
)

object MonsterLootSystem {

    fun generate(
        criatura: CriaturaGerada
    ): MonsterLoot {

        val egg = PetEggSystem.rollEggDrop(
            monsterId = criatura.id,
            species = criatura.nome,
            rank = criatura.rank,
            imageKey = criatura.imagemId.ifBlank {
                criatura.imagemIconeCaminho
            }
        )

        val drops = MonsterDropSystem.roll(criatura)

        return MonsterLoot(
            egg = egg,
            items = drops.materials,
            equipment = drops.equipment,
            gold = calculateGold(criatura)
        )
    }

    private fun calculateGold(creature: CriaturaGerada): Long {
        val rankMultiplier = when (creature.rank.uppercase()) {
            "E" -> 1.0; "D" -> 1.25; "C" -> 1.6; "B" -> 2.1; "A" -> 3.0
            "S" -> 4.5; "SS" -> 7.0; "SSS" -> 11.0; "WORLD", "MUNDIAL" -> 25.0
            else -> 1.0
        }
        val dangerMultiplier = 1.0 + (creature.perigo.coerceIn(0, 100) / 100.0)
        val bossMultiplier = if (creature.chefe) 5.0 else 1.0
        val base = (creature.nivel.coerceAtLeast(1) * 2.0 + creature.experienciaBase.coerceAtLeast(1) * 0.35)
        val variation = 0.90 + (kotlin.math.abs(creature.id.hashCode() % 26) / 100.0)
        return (base * rankMultiplier * dangerMultiplier * bossMultiplier * variation).toLong().coerceAtLeast(1L)
    }
}
