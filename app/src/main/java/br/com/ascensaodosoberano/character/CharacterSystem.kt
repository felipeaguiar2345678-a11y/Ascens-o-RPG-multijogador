
package br.com.ascensaodosoberano.character

import br.com.ascensaodosoberano.companions.PlayerInventory
import br.com.ascensaodosoberano.companions.EquipmentLoadout
import br.com.ascensaodosoberano.powers.CharacterPowerProfile
enum class SkillDomain {
    PHYSICAL,
    MAGIC,
    AGILITY,
    DEFENSE,
    SUMMONING
}

enum class Affinity {
    LOW,
    MEDIUM,
    HIGH
}

data class CharacterClass(
    val id: String,
    val name: String,
    val description: String,
    val affinities: Map<SkillDomain, Affinity>,
    val isCustom: Boolean = false
)

// NOVOS ATRIBUTOS DO PERSONAGEM
data class CharacterAttributes(
    val strength: Int = 5,
    val intelligence: Int = 5,
    val agility: Int = 5,
    val vitality: Int = 5,
    val spirit: Int = 5
)


data class CharacterProfile(
    val name: String,
    val level: Int,
    val xp: Int,
    val characterClass: CharacterClass,
    val attributes: CharacterAttributes = CharacterAttributes(),
    val attributePoints: Int = 0,
    val appearance: CharacterAppearance = CharacterAppearance(),
    val powerProfile: CharacterPowerProfile = CharacterPowerProfile(),
    val hasSeenIntro: Boolean = false,

// Localização persistente no mundo
val currentWorldPointId: String = "clareira_inicial",

// Último ponto de renascimento registrado
val respawnPointId: String = "clareira_inicial",

// Posição local persistente dentro da área atual.
val worldX: Float = 0.52f,
val worldY: Float = 0.78f,

val id: String = java.util.UUID.randomUUID().toString(),
val inventory: PlayerInventory = PlayerInventory(),
val equipmentLoadout: EquipmentLoadout = EquipmentLoadout(),

// Vida e mana atuais são persistidas junto do personagem entre sessões.
val currentHp: Int = -1,
val currentMana: Int = -1,
val processedSoloBattleIds: List<String> = emptyList()
)


object CharacterSystem {

    private fun createClass(
        id: String,
        name: String,
        description: String,
        physical: Affinity,
        magic: Affinity,
        agility: Affinity,
        defense: Affinity,
        summoning: Affinity
    ): CharacterClass {
        return CharacterClass(
            id = id,
            name = name,
            description = description,
            affinities = mapOf(
                SkillDomain.PHYSICAL to physical,
                SkillDomain.MAGIC to magic,
                SkillDomain.AGILITY to agility,
                SkillDomain.DEFENSE to defense,
                SkillDomain.SUMMONING to summoning
            )
        )
    }

    val predefinedClasses = listOf(

        createClass(
            "warrior", "Guerreiro",
            "Especialista em força e combate físico.",
            Affinity.HIGH, Affinity.LOW,
            Affinity.MEDIUM, Affinity.HIGH,
            Affinity.LOW
        ),

        createClass(
            "mage", "Mago",
            "Especialista em magia e manipulação de energia.",
            Affinity.LOW, Affinity.HIGH,
            Affinity.MEDIUM, Affinity.LOW,
            Affinity.MEDIUM
        ),

        createClass(
            "assassin", "Assassino",
            "Especialista em velocidade, furtividade e precisão.",
            Affinity.MEDIUM, Affinity.LOW,
            Affinity.HIGH, Affinity.LOW,
            Affinity.LOW
        ),

        createClass(
            "guardian", "Guardião",
            "Especialista em defesa e proteção.",
            Affinity.MEDIUM, Affinity.MEDIUM,
            Affinity.LOW, Affinity.HIGH,
            Affinity.MEDIUM
        ),

        createClass(
            "archer", "Arqueiro",
            "Especialista em ataques à distância e precisão.",
            Affinity.MEDIUM, Affinity.LOW,
            Affinity.HIGH, Affinity.MEDIUM,
            Affinity.LOW
        ),

        createClass(
            "summoner", "Invocador",
            "Especialista em invocações e controle de criaturas.",
            Affinity.LOW, Affinity.HIGH,
            Affinity.MEDIUM, Affinity.LOW,
            Affinity.HIGH
        )
    )

    fun getClassById(id: String): CharacterClass? {
        return predefinedClasses.find { it.id == id }
    }

    fun createCustomClass(
        name: String,
        description: String,
        affinities: Map<SkillDomain, Affinity>
    ): CharacterClass {
        return CharacterClass(
            id = "custom_${name.lowercase().replace(" ", "_")}",
            name = name,
            description = description,
            affinities = SkillDomain.values().associateWith {
                affinities[it] ?: Affinity.MEDIUM
            },
            isCustom = true
        )
    }

    fun getLearningEfficiency(
        characterClass: CharacterClass,
        domain: SkillDomain
    ): Float {
        return when (characterClass.affinities[domain] ?: Affinity.MEDIUM) {
            Affinity.HIGH -> 1.0f
            Affinity.MEDIUM -> 0.75f
            Affinity.LOW -> 0.45f
        }
    }

    fun canLearnSkill(
        characterClass: CharacterClass,
        domain: SkillDomain
    ): Boolean {
        return true
    }
}
