package br.com.ascensaodosoberano.companions

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun CurandeiroPanel(
    vidaAtual: Int,
    vidaMaxima: Int,
    manaAtual: Int,
    manaMaxima: Int,
    companheiro: Companion?,
    ouroDisponivel: Long,
    onCurar: (Long, Int, Int, Int) -> Unit
) {
    val vidaFaltando = (vidaMaxima - vidaAtual).coerceAtLeast(0)
    val manaFaltando = (manaMaxima - manaAtual).coerceAtLeast(0)
    val vidaCompanheiroFaltando = companheiro?.let {
        (it.maxHp - it.hp).coerceAtLeast(0)
    } ?: 0
    val totalFaltando = vidaFaltando.toLong() + manaFaltando.toLong() + vidaCompanheiroFaltando.toLong()

    // Sem moedas, a curandeira atende gratuitamente. Com moedas insuficientes,
    // cada moeda compra até 10 pontos de recuperação.
    val pontosPermitidos = if (ouroDisponivel <= 0L) {
        totalFaltando
    } else {
        minOf(totalFaltando, ouroDisponivel.coerceAtMost(Long.MAX_VALUE / 10L) * 10L)
    }
    // Prioridade: Vida do jogador, Mana do jogador e, por último, Vida do companheiro.
    val curarVida = minOf(vidaFaltando.toLong(), pontosPermitidos).toInt()
    val restanteAposVida = (pontosPermitidos - curarVida).coerceAtLeast(0L)
    val curarMana = minOf(manaFaltando.toLong(), restanteAposVida).toInt()
    val restanteAposMana = (restanteAposVida - curarMana).coerceAtLeast(0L)
    val curarCompanheiro = minOf(vidaCompanheiroFaltando.toLong(), restanteAposMana).toInt()
    val pontosRestaurados = curarVida.toLong() + curarMana.toLong() + curarCompanheiro.toLong()
    val custo = if (ouroDisponivel <= 0L || pontosRestaurados <= 0L) 0L
        else ((pontosRestaurados + 9L) / 10L).coerceAtMost(ouroDisponivel)
    val totalmenteRecuperado = totalFaltando == 0L
    val gratuito = ouroDisponivel <= 0L
    val curaParcial = pontosRestaurados < totalFaltando

    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("SANTUÁRIO DA CURANDEIRA", style = MaterialTheme.typography.titleLarge)
        Text("A curandeira restaura completamente sua Vida e Mana e também cura o companheiro ativo.")
        Card(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("PERSONAGEM", style = MaterialTheme.typography.titleMedium)
                Text("Vida: $vidaAtual / $vidaMaxima")
                Text("Mana: $manaAtual / $manaMaxima")
            }
        }
        Card(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("COMPANHEIRO", style = MaterialTheme.typography.titleMedium)
                if (companheiro == null) Text("Você não possui um companheiro ativo.")
                else {
                    Text(companheiro.name)
                    Text("Vida: ${companheiro.hp} / ${companheiro.maxHp}")
                }
            }
        }
        Card(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("PAGAMENTO", style = MaterialTheme.typography.titleMedium)
                Text("Suas moedas: $ouroDisponivel")
                Text(
                    when {
                        totalmenteRecuperado -> "Você já está completamente recuperado."
                        gratuito -> "Atendimento gratuito: você está sem moedas."
                        curaParcial -> "Com suas moedas, você pode recuperar $pontosRestaurados pontos agora por $custo moedas."
                        else -> "Preço calculado: $custo moedas (1 moeda a cada 10 pontos restaurados)."
                    }
                )
                if (curaParcial) {
                    Text("A prioridade será sua Vida, depois sua Mana e, se sobrar, a Vida do companheiro.")
                }
            }
        }
        Button(
            onClick = { onCurar(custo, curarVida, curarMana, curarCompanheiro) },
            enabled = !totalmenteRecuperado && pontosRestaurados > 0,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(
                when {
                    totalmenteRecuperado -> "VIDA E MANA JÁ ESTÃO COMPLETAS"
                    gratuito -> "RESTAURAR GRATUITAMENTE"
                    curaParcial -> "RECUPERAR $pontosRestaurados PONTOS POR $custo MOEDAS"
                    else -> "CURAR POR $custo MOEDAS"
                }
            )
        }
    }
}
