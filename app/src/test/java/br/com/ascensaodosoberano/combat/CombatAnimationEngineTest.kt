package br.com.ascensaodosoberano.combat

import br.com.ascensaodosoberano.world.AtaqueCriatura
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CombatAnimationEngineTest {
    @Test
    fun interpretaMagoDoTempoSemPrecisarDeAnimacaoCadastrada() {
        val skill = AtaqueCriatura(
            id = "poder_novo_01",
            nome = "Prisão do Segundo Eterno",
            descricao = "O mago desacelera o tempo ao redor do alvo e cria ecos temporais.",
            tipoDano = "MAGICO",
            elemento = "ARCANO",
            efeitos = listOf("retardar", "distorção temporal")
        )
        val result = CombatAnimationEngine.interpretar(skill)
        assertEquals(FamiliaAnimacao.TEMPO, result.familia)
        assertTrue(result.usaCirculoMagico)
        assertTrue(result.usaRuptura)
    }

    @Test
    fun interpretaPoderEspacialInventado() {
        val skill = AtaqueCriatura(
            id = "poder_sem_catalogo",
            nome = "Fenda do Horizonte",
            descricao = "Abre um portal dimensional e dobra o espaço para atingir o inimigo.",
            tipoDano = "MAGICO",
            elemento = "ARCANO"
        )
        assertEquals(FamiliaAnimacao.ESPACO, CombatAnimationEngine.interpretar(skill).familia)
    }

    @Test
    fun interpretaElementoMesmoQuandoNomeDaHabilidadeEInedito() {
        val skill = AtaqueCriatura(
            id = "novo_fogo",
            nome = "Dança da Fênix Rubra",
            descricao = "Uma onda incandescente atravessa a arena.",
            elemento = "FOGO"
        )
        assertEquals(FamiliaAnimacao.FOGO, CombatAnimationEngine.interpretar(skill).familia)
    }

    @Test
    fun poderFisicoRecebePerfilDeImpactoSemProjetilMagico() {
        val skill = AtaqueCriatura(
            id = "corte",
            nome = "Corte Ascendente",
            descricao = "Um golpe de espada em arco.",
            tipoDano = "FISICO"
        )
        val result = CombatAnimationEngine.interpretar(skill)
        assertEquals(FamiliaAnimacao.FISICO, result.familia)
        assertTrue(!result.usaProjetil)
        assertTrue(!result.usaCirculoMagico)
    }

    @Test
    fun categoriaDevastadoraAumentaIntensidadeVisual() {
        val normal = CombatAnimationEngine.interpretar(AtaqueCriatura(nome = "Pulso Arcano"))
        val supremo = CombatAnimationEngine.interpretar(AtaqueCriatura(nome = "Pulso Arcano", categoria = "DEVASTADOR"))
        assertTrue(supremo.intensidade > normal.intensidade)
    }
}
