
package br.com.ascensaodosoberano.combat

import br.com.ascensaodosoberano.character.CharacterProfile
import br.com.ascensaodosoberano.character.SkillDomain
import br.com.ascensaodosoberano.character.Affinity

object CharacterCombatFactory {

    fun createHero(profile: CharacterProfile): Combatant {

        val affinities = profile.characterClass.affinities
        val attributes = profile.attributes

        fun affinity(domain: SkillDomain): Affinity {
            return affinities[domain] ?: Affinity.MEDIUM
        }

        val levelBonus = (profile.level - 1).coerceAtLeast(0)

        // Bônus dos atributos distribuídos
        val strengthBonus =
            (attributes.strength - 5).coerceAtLeast(0) * 2

        val intelligenceBonus =
            (attributes.intelligence - 5).coerceAtLeast(0) * 3

        val agilityBonus =
            (attributes.agility - 5).coerceAtLeast(0) / 2

        val vitalityBonus =
            (attributes.vitality - 5).coerceAtLeast(0) * 10

        val spiritBonus =
            (attributes.spirit - 5).coerceAtLeast(0) * 10

        val hpBase = when (affinity(SkillDomain.DEFENSE)) {
            Affinity.HIGH -> 130
            Affinity.MEDIUM -> 115
            Affinity.LOW -> 100
        }

        val manaBase = when (affinity(SkillDomain.MAGIC)) {
            Affinity.HIGH -> 100
            Affinity.MEDIUM -> 70
            Affinity.LOW -> 40
        }

        val attackBase = when (affinity(SkillDomain.PHYSICAL)) {
            Affinity.HIGH -> 30
            Affinity.MEDIUM -> 25
            Affinity.LOW -> 20
        }

        val defenseBase = when (affinity(SkillDomain.DEFENSE)) {
            Affinity.HIGH -> 15
            Affinity.MEDIUM -> 10
            Affinity.LOW -> 5
        }

        val summoningBonus = when (affinity(SkillDomain.SUMMONING)) {
            Affinity.HIGH -> 25
            Affinity.MEDIUM -> 10
            Affinity.LOW -> 0
        }

        val maxHp =
            hpBase + levelBonus * 20 + vitalityBonus

        val maxMana =
            manaBase + summoningBonus +
                levelBonus * 10 + spiritBonus

        return Combatant(
            name = profile.name,
            maxHp = maxHp,
            hp = maxHp,
            attack = attackBase + levelBonus * 3 + strengthBonus,
            defense = defenseBase + levelBonus * 2 + agilityBonus,
            mana = maxMana,
            maxMana = maxMana,
            magicPower = 15 + intelligenceBonus,
            agility = attributes.agility,
            rank = "E",
            level = profile.level,
            attacks = listOf(
                br.com.ascensaodosoberano.world.AtaqueCriatura(
                    id = "corte_poderoso", nome = "Corte Poderoso",
                    descricao = "Golpe físico concentrado.", tipoDano = "FISICO",
                    danoBase = 12, multiplicador = 0.8f, turnosRecarga = 1,
                    categoria = "PODEROSO", danoQuebra = 14
                ),
                br.com.ascensaodosoberano.world.AtaqueCriatura(
                    id = "impacto_arcano", nome = "Impacto Arcano",
                    descricao = "Explosão de energia arcana.", tipoDano = "MAGICO",
                    elemento = "ARCANO", danoBase = 18, multiplicador = 0.7f,
                    custoMana = 12, turnosRecarga = 2, categoria = "PODEROSO",
                    danoQuebra = 18
                ),
                br.com.ascensaodosoberano.world.AtaqueCriatura(
                    id = "esfera_negra", nome = "Esfera Negra",
                    descricao = "Projétil de energia sombria.", tipoDano = "MAGICO",
                    elemento = "SOMBRIO", danoBase = 24, multiplicador = 0.9f,
                    custoMana = 20, turnosRecarga = 3, categoria = "PODEROSO",
                    danoQuebra = 22
                ),
                br.com.ascensaodosoberano.world.AtaqueCriatura(
                    id = "ruptura_devastadora", nome = "Ruptura Devastadora",
                    descricao = "Ataque devastador que exige concentração.", tipoDano = "FISICO",
                    elemento = "NEUTRO", danoBase = 45, multiplicador = 1.5f,
                    custoMana = 28, turnosCarregamento = 2, turnosRecarga = 4,
                    categoria = "DEVASTADOR", danoQuebra = 38,
                    podeSerInterrompida = true
                )
            )
        )
    }
}
