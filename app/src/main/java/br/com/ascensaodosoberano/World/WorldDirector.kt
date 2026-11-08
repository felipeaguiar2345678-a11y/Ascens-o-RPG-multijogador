
package br.com.ascensaodosoberano.world

import kotlin.math.roundToInt
import kotlin.random.Random

enum class WorldEventType {
    ENCOUNTER,
    BOSS,
    QUEST,
    NPC,
    TREASURE,
    NOTHING
}

data class WorldContext(
    val regionName: String,
    val regionRank: String,
    val dangerLevel: Int = 1,
    val bossChance: Double = dangerLevel / 5.0,
    val ecosystemId: String = "unknown",
    val biome: String = "unknown"
)

data class WorldEvent(
    val type: WorldEventType,
    val title: String,
    val description: String,
    val threatLevel: Int,
    val rewards: List<String> = emptyList()
)

object WorldDirector {

    fun generateEvent(context: WorldContext): WorldEvent =
        generateEventForRoll(context, Random.nextInt(0, 10_000))

    internal fun generateEventForRoll(
        context: WorldContext,
        roll: Int
    ): WorldEvent {
        require(roll in 0 until 10_000) { "O sorteio deve estar entre 0 e 9.999." }

        val danger = context.dangerLevel.coerceIn(1, 100)

        val bossChance = context.bossChance.coerceIn(0.0, danger.toDouble())

        // Sorteio com precisão de 0,01%.
        val encounterLimit = danger * 100
        val bossLimit = (bossChance * 100.0).roundToInt().coerceIn(0, encounterLimit)

        // Chance restante após os encontros.
        val remainingChance = 100 - danger

        // Distribuição do restante:
        // Missões: 40%
        // Tesouros: 30%
        // NPCs: 20%
        // Exploração tranquila: 10%

        val questLimit =
    encounterLimit + (remainingChance * 40)

val treasureLimit =
    questLimit + (remainingChance * 30)

val npcLimit =
    treasureLimit + (remainingChance * 20)

        val environmentDescription = when (context.ecosystemId) {
            "dark_forest" ->
                "A vegetação sombria da ${context.biome} esconde perigos."

            "forgotten_ruins" ->
                "As estruturas deterioradas das ${context.biome} guardam segredos."

            "abyss_valley" ->
                "A energia opressora do ${context.biome} distorce o ambiente."

            "dead_lands" ->
                "A desolação das ${context.biome} revela uma presença aterradora."
            "frost_mountains" ->
                "O frio cortante de ${context.biome} esconde predadores adaptados à neve."
            "imperial_frontier" ->
                "Nas fronteiras de ${context.biome}, criaturas disputam antigas rotas imperiais."
            "central_wilds" ->
                "Nos campos de ${context.biome}, a vida selvagem se move entre bosques e trilhas."
            "shadowlands" ->
                "Nas trevas de ${context.biome}, presenças perigosas observam cada passo."
            "ancestral_desert" ->
                "Sob as dunas de ${context.biome}, criaturas antigas aguardam viajantes."
            "eternal_sea" ->
                "Nas águas e ilhas de ${context.biome}, monstros marinhos e predadores costeiros rondam."

            else ->
                "O ambiente de ${context.biome} apresenta características desconhecidas."
        }

        val rankThreatDescription = when (context.regionRank.uppercase()) {
            "E" -> "A ameaça desta região é baixa."
            "D", "C" -> "A ameaça desta região é moderada."
            "B", "A" -> "A ameaça desta região é alta."
            "S" -> "A ameaça desta região é extrema."
            "SS", "SSS" -> "A ameaça desta região é catastrófica."
            else -> "O nível de ameaça desta região é desconhecido."
        }

        return when {
            roll < bossLimit -> WorldEvent(
                type = WorldEventType.BOSS,
                title = "Presença Colossal",
                description = "$environmentDescription $rankThreatDescription Uma entidade poderosa despertou em ${context.regionName}.",
                threatLevel = danger,
                rewards = listOf("Recompensa de chefe", "Experiência")
            )

            roll < encounterLimit -> WorldEvent(
                type = WorldEventType.ENCOUNTER,
                title = "Inimigo Detectado",
                description = "$environmentDescription $rankThreatDescription Uma criatura hostil apareceu em ${context.regionName}.",
                threatLevel = danger
            )

            roll < questLimit -> WorldEvent(
                type = WorldEventType.QUEST,
                title = "Novo Pedido",
                description = "$environmentDescription $rankThreatDescription Uma oportunidade de missão surgiu na região.",
                threatLevel = danger / 2,
                rewards = listOf("Experiência", "Possíveis itens")
            )

            roll < treasureLimit -> WorldEvent(
                type = WorldEventType.TREASURE,
                title = "Vestígio Esquecido",
                description = "$environmentDescription $rankThreatDescription Você encontrou sinais de um tesouro em ${context.regionName}.",
                threatLevel = danger / 3,
                rewards = listOf("Tesouro desconhecido")
            )

            roll < npcLimit -> WorldEvent(
                type = WorldEventType.NPC,
                title = "Viajante Encontrado",
                description = "$environmentDescription $rankThreatDescription Um personagem misterioso está próximo.",
                threatLevel = 0
            )

            else -> WorldEvent(
                type = WorldEventType.NOTHING,
                title = "Exploração Tranquila",
                description = "$environmentDescription $rankThreatDescription Nenhum acontecimento especial foi detectado.",
                threatLevel = 0
            )
        }
    }
}
