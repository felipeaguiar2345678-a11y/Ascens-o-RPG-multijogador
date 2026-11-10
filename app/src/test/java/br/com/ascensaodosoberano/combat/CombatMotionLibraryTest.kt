package br.com.ascensaodosoberano.combat

import br.com.ascensaodosoberano.world.AtaqueCriatura
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CombatMotionLibraryTest {
    @Test
    fun reconheceInvestidaEAvancoRapido() {
        val investida = AtaqueCriatura(id = "i", nome = "Investida do Colosso", descricao = "O guerreiro avança violentamente contra o alvo.")
        val dash = AtaqueCriatura(id = "d", nome = "Passo Relâmpago", descricao = "Uma arrancada em velocidade extrema.")
        assertEquals(MovimentoCombate.INVESTIDA, CombatMotionLibrary.interpretar(investida).movimento)
        assertEquals(MovimentoCombate.DASH, CombatMotionLibrary.interpretar(dash).movimento)
    }

    @Test
    fun reconheceTeleporteSaltoEGiro() {
        assertEquals(MovimentoCombate.TELEPORTE, CombatMotionLibrary.interpretar(AtaqueCriatura(nome = "Passagem Dimensional", descricao = "O herói desaparece e surge atrás do inimigo.")).movimento)
        assertEquals(MovimentoCombate.SALTO, CombatMotionLibrary.interpretar(AtaqueCriatura(nome = "Queda Celeste", descricao = "Um ataque aéreo após um salto.")).movimento)
        assertEquals(MovimentoCombate.GIRO, CombatMotionLibrary.interpretar(AtaqueCriatura(nome = "Dança Espiral", descricao = "O mago rodopia criando um turbilhão.")).movimento)
    }

    @Test
    fun reconheceSuporteDefesaInvocacaoEDrenagem() {
        assertEquals(MovimentoCombate.CURA, CombatMotionLibrary.interpretar(AtaqueCriatura(nome = "Renovação", descricao = "Restaura vida e regenera feridas.")).movimento)
        assertEquals(MovimentoCombate.BARREIRA, CombatMotionLibrary.interpretar(AtaqueCriatura(nome = "Muralha", descricao = "Ergue uma barreira protetora.")).movimento)
        assertEquals(MovimentoCombate.INVOCACAO, CombatMotionLibrary.interpretar(AtaqueCriatura(nome = "Chamado", descricao = "Invoca um familiar para lutar.")).movimento)
        assertEquals(MovimentoCombate.DRENAGEM, CombatMotionLibrary.interpretar(AtaqueCriatura(nome = "Vampirismo", descricao = "Absorve vitalidade do alvo.")).movimento)
    }

    @Test
    fun habilidadesSupremasRecebemMaisCamadasEIntensidade() {
        val normal = CombatMotionLibrary.interpretar(AtaqueCriatura(nome = "Onda Arcana", descricao = "Libera uma onda de energia."))
        val suprema = CombatMotionLibrary.interpretar(AtaqueCriatura(nome = "Onda Arcana", descricao = "Libera uma onda de energia.", categoria = "SUPREMO"))
        assertTrue(suprema.intensidade > normal.intensidade)
        assertTrue(suprema.camadas >= 4)
        assertTrue(suprema.duracaoMs > normal.duracaoMs)
    }
}
