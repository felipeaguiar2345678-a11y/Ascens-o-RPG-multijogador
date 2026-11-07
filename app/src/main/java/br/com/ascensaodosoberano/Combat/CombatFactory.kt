
package br.com.ascensaodosoberano.combat

import br.com.ascensaodosoberano.world.CriaturaGerada

object CombatFactory {

    fun createCombat(
        hero: Combatant,
        criatura: CriaturaGerada,
        isNight: Boolean = false
    ): CombatState {

        val multiplicadorNoturno = if (isNight && criatura.atividadeNoturna) 2 else 1

        val inimigo = Combatant(
            name = criatura.nome,
            maxHp = criatura.vidaMaxima * multiplicadorNoturno,
            hp = criatura.vidaMaxima * multiplicadorNoturno,
            attack = criatura.ataque * multiplicadorNoturno,
            defense = criatura.defesa * multiplicadorNoturno,
            mana = criatura.manaMaxima * multiplicadorNoturno,
            maxMana = criatura.manaMaxima * multiplicadorNoturno,
            rank = criatura.rank,
            level = criatura.nivel,
            danger = criatura.perigo,
            xpReward = criatura.experienciaBase,
            isBoss = criatura.chefe,
            agility = criatura.agilidade * multiplicadorNoturno,
            magicPower = criatura.poderMagico * multiplicadorNoturno,
            attacks = criatura.ataques
        )

        return CombatSystem.startCombat(
            hero = hero,
            enemy = inimigo
        )
    }
}
