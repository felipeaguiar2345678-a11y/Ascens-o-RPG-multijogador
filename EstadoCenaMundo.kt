
package br.com.ascensaodosoberano.exploration

enum class ModoCenaMundo {
    VIAGEM,
    EXPLORACAO,
    COMBATE
}

data class EstadoCenaMundo(
    val modo: ModoCenaMundo = ModoCenaMundo.VIAGEM,
    val posicaoNoMapa: WorldPosition = WorldMapSystem.initialPosition()
)

object TransicaoMundo {

    // Entrar em uma cidade, masmorra ou evento
    fun entrarNaExploracao(
        estado: EstadoCenaMundo
    ): EstadoCenaMundo {
        return estado.copy(
            modo = ModoCenaMundo.EXPLORACAO
        )
    }

    // Iniciar um combate dentro da própria cena
    fun iniciarCombate(
        estado: EstadoCenaMundo
    ): EstadoCenaMundo {
        return estado.copy(
            modo = ModoCenaMundo.COMBATE
        )
    }

    // Voltar à exploração depois do combate
    fun finalizarCombate(
        estado: EstadoCenaMundo
    ): EstadoCenaMundo {
        return estado.copy(
            modo = ModoCenaMundo.EXPLORACAO
        )
    }

    // Voltar ao mapa mundial
    fun voltarParaViagem(
        estado: EstadoCenaMundo
    ): EstadoCenaMundo {
        return estado.copy(
            modo = ModoCenaMundo.VIAGEM
        )
    }
}
