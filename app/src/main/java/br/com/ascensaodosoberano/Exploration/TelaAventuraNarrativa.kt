package br.com.ascensaodosoberano.exploration

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import androidx.compose.ui.layout.ContentScale
import br.com.ascensaodosoberano.world.CriaturaGerada

@Composable
fun TelaAventuraNarrativa(
    nomeJogador: String,
    nivelJogador: Int,
    local: String,
    imagemPersonagemUrl: String,
    criaturaEncontrada: CriaturaGerada?,
    buscandoCriaturas: Boolean,
    mensagem: String,
    aoExplorar: () -> Unit,
    aoEnfrentarCriatura: () -> Unit,
    aoIgnorarCriatura: () -> Unit,
    aoAbrirPainel: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val dourado = Color(0xFFFFD58E)
    val texto = Color(0xFFE8EAF0)
    val painel = Color(0xE91B2534)

    Column(
        modifier = modifier.fillMaxSize().background(Color(0xFF0D1420))
            .verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            if (imagemPersonagemUrl.isNotBlank()) {
                AsyncImage(
                    model = imagemPersonagemUrl,
                    contentDescription = "Retrato de $nomeJogador",
                    modifier = Modifier.size(76.dp),
                    contentScale = ContentScale.Crop
                )
            }
            Column(Modifier.weight(1f)) {
                Text(nomeJogador, color = dourado, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                Text("Nível $nivelJogador", color = texto.copy(alpha = .78f))
                Text(local, color = dourado.copy(alpha = .85f), style = MaterialTheme.typography.labelMedium)
            }
        }

        Card(colors = CardDefaults.cardColors(containerColor = painel), shape = RoundedCornerShape(18.dp)) {
            Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("A JORNADA CONTINUA", color = dourado, fontWeight = FontWeight.Bold, letterSpacing = 1.4.sp)
                Text(
                    "A aventura segue diante de você. Observe os acontecimentos, converse com seus aliados e escolha como deseja agir. Cada descoberta pode revelar uma criatura, um perigo ou uma nova oportunidade.",
                    color = texto,
                    style = MaterialTheme.typography.bodyLarge
                )
                if (mensagem.isNotBlank()) {
                    HorizontalDivider(color = dourado.copy(alpha = .25f))
                    Text(mensagem, color = texto.copy(alpha = .9f))
                }
            }
        }

        if (criaturaEncontrada != null) {
            Card(colors = CardDefaults.cardColors(containerColor = Color(0xFF30202A)), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(9.dp)) {
                    Text(if (criaturaEncontrada.chefe) "AMEAÇA DE CHEFE" else "ENCONTRO", color = Color(0xFFFF9B86), fontWeight = FontWeight.Black)
                    Text(criaturaEncontrada.nome, color = Color.White, fontSize = 21.sp, fontWeight = FontWeight.Bold)
                    Text("Rank ${criaturaEncontrada.rank} · Nível ${criaturaEncontrada.nivel} · ${criaturaEncontrada.raridade}", color = dourado)
                    Text(criaturaEncontrada.descricao.ifBlank { "Uma criatura surgiu diante de você. Suas intenções ainda são desconhecidas." }, color = texto)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Button(onClick = aoEnfrentarCriatura, modifier = Modifier.weight(1f)) { Text("ENFRENTAR") }
                        OutlinedButton(onClick = aoIgnorarCriatura, modifier = Modifier.weight(1f)) { Text("IGNORAR") }
                    }
                }
            }
        } else {
            Button(
                onClick = aoExplorar,
                enabled = !buscandoCriaturas,
                modifier = Modifier.fillMaxWidth().height(54.dp)
            ) {
                if (buscandoCriaturas) CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
                else Text("CONTINUAR A AVENTURA", fontWeight = FontWeight.Bold)
            }
        }

        Text("JORNADA", color = dourado, fontWeight = FontWeight.Bold, letterSpacing = 1.2.sp)
        listOf(
            "STATUS" to "Personagem e atributos",
            "INVENTARIO" to "Itens e equipamentos",
            "BESTIARIO" to "Criaturas descobertas",
            "MULTIPLAYER" to "Grupo e companheiros"
        ).forEach { (id, descricao) ->
            OutlinedButton(onClick = { aoAbrirPainel(id) }, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(12.dp)) {
                Column(Modifier.fillMaxWidth()) {
                    Text(id, color = dourado, fontWeight = FontWeight.Bold)
                    Text(descricao, color = texto.copy(alpha = .72f), style = MaterialTheme.typography.labelSmall)
                }
            }
        }
        Spacer(Modifier.height(12.dp))
    }
}
