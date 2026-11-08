
package br.com.ascensaodosoberano.companions

import br.com.ascensaodosoberano.world.RepositorioCriaturas
import kotlin.math.roundToInt
import kotlin.random.Random

data class CompanionHatchResult(
    val inventory: PlayerInventory,
    val companion: Companion? = null,
    val success: Boolean,
    val message: String
)

object CompanionHatchingSystem {

    private const val FORCA_FILHOTE = 20

    private fun calcularAtributo(
        original: Int,
        percentualEstagio: Int,
        modificadorMutacao: Int,
        permitirZero: Boolean = false
    ): Int {
        val valorBase = (
            original * percentualEstagio / 100f
        ).roundToInt()

        val valorFinal = (
            valorBase * (100 + modificadorMutacao) / 100f
        ).roundToInt()

        return if (permitirZero) {
            valorFinal.coerceAtLeast(0)
        } else {
            valorFinal.coerceAtLeast(1)
        }
    }

    suspend fun hatchEgg(
        inventory: PlayerInventory,
        eggId: String
    ): CompanionHatchResult {

        val egg = inventory.eggs.firstOrNull {
            it.id == eggId
        } ?: return CompanionHatchResult(
            inventory = inventory,
            success = false,
            message = "Ovo não encontrado no inventário."
        )

        val companionId = "companheiro_${egg.id}"

        if (inventory.companions.any {
                it.id == companionId
            }) {
            return CompanionHatchResult(
                inventory = inventory,
                success = false,
                message = "Este ovo já originou um companheiro."
            )
        }

        val roll = Random.nextInt(1, 101)

        if (roll > egg.hatchChance.coerceIn(0, 100)) {
            return CompanionHatchResult(
                inventory = inventory,
                success = false,
                message = "O ovo ainda não conseguiu eclodir."
            )
        }

        val criatura = try {
            RepositorioCriaturas.buscarCriatura(
                egg.monsterId
            )
        } catch (e: Exception) {
            return CompanionHatchResult(
                inventory = inventory,
                success = false,
                message = "Não foi possível consultar a criatura original: ${e.message}"
            )
        }

        if (criatura == null) {
            return CompanionHatchResult(
                inventory = inventory,
                success = false,
                message = "A criatura original não foi encontrada no registro global."
            )
        }

        val mutation = egg

        val filhote = Companion(
            id = companionId,
            name = "Filhote de ${criatura.nome}",
            species = criatura.nome,
            rank = criatura.rank,

            level = 1,
            xp = 0,
            stage = "FILHOTE",

            maxHp = calcularAtributo(
                criatura.vidaMaxima,
                FORCA_FILHOTE,
                mutation.mutationHpPercent
            ),
            hp = calcularAtributo(
                criatura.vidaMaxima,
                FORCA_FILHOTE,
                mutation.mutationHpPercent
            ),
            attack = calcularAtributo(
                criatura.ataque,
                FORCA_FILHOTE,
                mutation.mutationAttackPercent
            ),
            defense = calcularAtributo(
                criatura.defesa,
                FORCA_FILHOTE,
                mutation.mutationDefensePercent,
                permitirZero = true
            ),
            agility = calcularAtributo(
                criatura.agilidade,
                FORCA_FILHOTE,
                mutation.mutationAgilityPercent
            ),
            magicPower = calcularAtributo(
                criatura.poderMagico,
                FORCA_FILHOTE,
                mutation.mutationMagicPercent,
                permitirZero = true
            ),

            originalMonsterId = criatura.id,
            originalMonsterRank = criatura.rank,

            originalMaxHp = criatura.vidaMaxima,
            originalAttack = criatura.ataque,
            originalDefense = criatura.defesa,
            originalAgility = criatura.agilidade,
            originalMagicPower = criatura.poderMagico,

            mutationId = mutation.mutationId,
            mutationName = mutation.mutationName,
            mutationRarity = mutation.mutationRarity,
            mutationDescription = mutation.mutationDescription,

            mutationHpPercent = mutation.mutationHpPercent,
            mutationAttackPercent = mutation.mutationAttackPercent,
            mutationDefensePercent = mutation.mutationDefensePercent,
            mutationAgilityPercent = mutation.mutationAgilityPercent,
            mutationMagicPercent = mutation.mutationMagicPercent,

            imageKey = egg.imageKey,
            isActive = false,

            imagemIconeCaminho = egg.imagemIconeCaminho,
            imagemDetalhadaCaminho = egg.imagemDetalhadaCaminho
        )

        val novoInventario = InventorySystem.hatchEgg(
            inventory = inventory,
            eggId = eggId,
            companion = filhote
        )

        if (novoInventario.companions.none {
                it.id == companionId
            }) {
            return CompanionHatchResult(
                inventory = inventory,
                success = false,
                message = "Não foi possível registrar o companheiro."
            )
        }

        return CompanionHatchResult(
            inventory = novoInventario,
            companion = filhote,
            success = true,
            message = "${filhote.name} nasceu! Mutação: ${filhote.mutationName}."
        )
    }
}
