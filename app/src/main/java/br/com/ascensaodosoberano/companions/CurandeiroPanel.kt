package br.com.ascensaodosoberano.companions

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.fillMaxWidth
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
    onCurar: (Long) -> Unit
) {
    val vidaFaltando = (vidaMaxima - vidaAtual).coerceAtLeast(0).toLong()
    val manaFaltando = (manaMaxima - manaAtual).coerceAtLeast(0).toLong()
    val vidaCompanheiroFaltando = companheiro?.let {
        (it.maxHp - it.hp).coerceAtLeast(0).toLong()
    } ?: 0L
    val pontosRestaurados = vidaFaltando + manaFaltando + vidaCompanheiroFaltando
    // 1 moeda para cada 10 pontos restaurados. Sem nenhuma moeda, a cura é gratuita.
    val custo = if (ouroDisponivel <= 0L || pontosRestaurados <= 0L) {
        0L
    } else {
        ((pontosRestaurados + 9L) / 10L).coerceAtLeast(1L)
    }
    val totalmenteRecuperado = pontosRestaurados == 0L
    val gratuito = ouroDisponivel <= 0L

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
                        else -> "Preço calculado: $custo moedas (1 moeda a cada 10 pontos restaurados)."
                    }
                )
                if (!totalmenteRecuperado && !gratuito && ouroDisponivel < custo) {
                    Text(
                        "Você precisa de mais ${custo - ouroDisponivel} moedas para pagar esta cura.",
                        color = MaterialTheme.colorScheme.error
                    )
                }
            }
        }
        Button(
            onClick = { onCurar(custo) },
            enabled = !totalmenteRecuperado && (gratuito || ouroDisponivel >= custo),
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(
                when {
                    totalmenteRecuperado -> "VIDA E MANA JÁ ESTÃO COMPLETAS"
                    gratuito -> "RESTAURAR GRATUITAMENTE"
                    else -> "CURAR POR $custo MOEDAS"
                }
            )
        }
    }
}
