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
    onCurar: () -> Unit
) {
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("SANTUÁRIO DE CURA", style = MaterialTheme.typography.titleLarge)
        Text("O curandeiro restaura completamente suas forças e as do companheiro ativo, sem consumir itens.")
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
        Button(onClick = onCurar, modifier = Modifier.fillMaxWidth()) {
            Text("RESTAURAR VIDA E MANA")
        }
    }
}
