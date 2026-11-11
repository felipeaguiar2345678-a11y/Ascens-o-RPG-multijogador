
package br.com.ascensaodosoberano.combat

import br.com.ascensaodosoberano.world.CriaturaGerada
import br.com.ascensaodosoberano.world.WorldAI

object CombatFactory {

    fun createCombat(
        hero: Combatant,
        criatura: CriaturaGerada,
        isNight: Boolean = false
    ): CombatState {

        // A noite favorece criaturas noturnas sem transformar um encontro comum
        // em um salto abrupto de 100% em todos os atributos.
        val bonusNoturno = isNight && criatura.atividadeNoturna
        val multiplicadorVida = if (bonusNoturno) 1.15f else 1f
        val multiplicadorCombate = if (bonusNoturno) 1.12f else 1f

        val inimigo = Combatant(
            name = criatura.nome,
            maxHp = (criatura.vidaMaxima * multiplicadorVida).toInt().coerceAtLeast(1),
            hp = (criatura.vidaMaxima * multiplicadorVida).toInt().coerceAtLeast(1),
            attack = (criatura.ataque * multiplicadorCombate).toInt().coerceAtLeast(1),
            defense = (criatura.defesa * multiplicadorCombate).toInt().coerceAtLeast(0),
            mana = (criatura.manaMaxima * multiplicadorCombate).toInt().coerceAtLeast(0),
            maxMana = (criatura.manaMaxima * multiplicadorCombate).toInt().coerceAtLeast(0),
            rank = criatura.rank,
            level = criatura.nivel,
            danger = criatura.perigo,
            xpReward = criatura.experienciaBase,
            isBoss = criatura.chefe,
            agility = (criatura.agilidade * multiplicadorCombate).toInt().coerceAtLeast(1),
            magicPower = (criatura.poderMagico * multiplicadorCombate).toInt().coerceAtLeast(1),
            attacks = criatura.ataques,
            spriteUrl = criatura.imagemIconeCaminho.ifBlank { criatura.imagemDetalhadaCaminho },
            aiArchetype = WorldAI.inferArchetype(criatura),
            rarity = criatura.raridade
        )

        return CombatSystem.startCombat(
            hero = hero,
            enemy = inimigo
        )
    }
}
