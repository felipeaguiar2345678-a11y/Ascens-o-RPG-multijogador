
package br.com.ascensaodosoberano.companions

import kotlin.random.Random

data class PetEgg(
    val id: String,
    val species: String,
    val monsterId: String,
    val rank: String,
    val imageKey: String,
    val hatchChance: Int,
    val quantity: Int = 1,
    val imagemIconeCaminho: String = "",
    val imagemDetalhadaCaminho: String = "",

    // Mutação definida quando o ovo é obtido
    val mutationId: String = "NORMAL",
    val mutationName: String = "Normal",
    val mutationRarity: String = "COMUM",
    val mutationDescription: String = "",

    // Modificadores percentuais da mutação
    val mutationHpPercent: Int = 0,
    val mutationAttackPercent: Int = 0,
    val mutationDefensePercent: Int = 0,
    val mutationAgilityPercent: Int = 0,
    val mutationMagicPercent: Int = 0
)

data class PetMutation(
    val id: String,
    val name: String,
    val rarity: String,
    val description: String,
    val hpPercent: Int = 0,
    val attackPercent: Int = 0,
    val defensePercent: Int = 0,
    val agilityPercent: Int = 0,
    val magicPercent: Int = 0
)

object PetEggSystem {

    // Chances iniciais de mutação
    const val CHANCE_NORMAL = 70
    const val CHANCE_INCOMUM = 20
    const val CHANCE_RARA = 8
    const val CHANCE_LENDARIA = 2

    fun getDropChance(rank: String): Int {
        return when (rank.uppercase()) {
            "E" -> 5
            "D" -> 4
            "C" -> 3
            "B" -> 2
            "A" -> 2
            "S" -> 1
            "SS" -> 1
            "SSS" -> 1
            else -> 1
        }
    }

    fun rollMutation(): PetMutation {
        val roll = Random.nextInt(1, 101)

        return when {
            roll <= CHANCE_NORMAL -> PetMutation(
                id = "NORMAL",
                name = "Normal",
                rarity = "COMUM",
                description = "Um companheiro sem mutações especiais."
            )

            roll <= CHANCE_NORMAL + CHANCE_INCOMUM -> PetMutation(
                id = "VENENOSA",
                name = "Venenosa",
                rarity = "INCOMUM",
                description = "Possui propriedades venenosas. Causa mais dano, mas tem menor resistência.",
                hpPercent = -5,
                attackPercent = 10,
                defensePercent = -5,
                magicPercent = 5
            )

            roll <= CHANCE_NORMAL + CHANCE_INCOMUM + CHANCE_RARA -> PetMutation(
                id = "ESPINHOSA",
                name = "Espinhosa",
                rarity = "RARO",
                description = "Seu corpo desenvolveu espinhos naturais. Possui mais defesa, mas perde agilidade.",
                attackPercent = 5,
                defensePercent = 10,
                agilityPercent = -10
            )

            else -> PetMutation(
                id = "ANCESTRAL",
                name = "Ancestral",
                rarity = "LENDÁRIO",
                description = "Uma linhagem ancestral que fortalece a vida e o poder mágico, mas reduz a agilidade.",
                hpPercent = 10,
                attackPercent = -5,
                agilityPercent = -5,
                magicPercent = 10
            )
        }
    }

    fun rollEggDrop(
        monsterId: String,
        species: String,
        rank: String,
        imageKey: String,
        chanceMultiplier: Float = 1f
    ): PetEgg? {

        // Mantém as chances originais de obtenção de ovos
        val chance = (getDropChance(rank) * chanceMultiplier).toInt().coerceAtMost(100)
        val roll = Random.nextInt(1, 101)

        if (roll > chance) return null

        // A mutação é definida uma única vez
        val mutation = rollMutation()

        return PetEgg(
            id = "${monsterId}_${System.currentTimeMillis()}",
            species = species,
            monsterId = monsterId,
            rank = rank,
            imageKey = imageKey,
            hatchChance = 100,

            mutationId = mutation.id,
            mutationName = mutation.name,
            mutationRarity = mutation.rarity,
            mutationDescription = mutation.description,

            mutationHpPercent = mutation.hpPercent,
            mutationAttackPercent = mutation.attackPercent,
            mutationDefensePercent = mutation.defensePercent,
            mutationAgilityPercent = mutation.agilityPercent,
            mutationMagicPercent = mutation.magicPercent
        )
    }
}
