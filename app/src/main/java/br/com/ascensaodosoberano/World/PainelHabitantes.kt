package br.com.ascensaodosoberano.world

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import org.json.JSONObject

@Composable
fun PainelHabitantes(
    settlementId: String,
    onMessage: (String) -> Unit = {}
) {
    var resposta by remember(settlementId) { mutableStateOf<JSONObject?>(null) }
    var carregando by remember(settlementId) { mutableStateOf(true) }
    var erro by remember(settlementId) { mutableStateOf("") }
    var falasPorHabitante by remember(settlementId) { mutableStateOf<Map<String, String>>(emptyMap()) }
    val scope = rememberCoroutineScope()

    suspend fun atualizar() {
        carregando = true
        erro = ""
        runCatching { WorldApi.buscarHabitantes(settlementId) }
            .onSuccess { resposta = it }
            .onFailure { erro = it.localizedMessage ?: "Não foi possível carregar os habitantes." }
        carregando = false
    }

    LaunchedEffect(settlementId) { atualizar() }

    Column(
        modifier = Modifier.fillMaxWidth().verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Text(
            "Habitantes e histórias locais",
            color = Color(0xFFFFD58E),
            style = MaterialTheme.typography.titleMedium
        )
        Text(
            "Os habitantes têm rotinas, necessidades e relações próprias. Conversar melhora gradualmente sua relação com cada pessoa.",
            color = Color(0xFFC7D0DF),
            style = MaterialTheme.typography.bodySmall
        )
        if (carregando) {
            CircularProgressIndicator()
        } else if (erro.isNotBlank()) {
            Text(erro, color = MaterialTheme.colorScheme.error)
            Button(onClick = { scope.launch { atualizar() } }) { Text("TENTAR NOVAMENTE") }
        } else {
            val habitantes = resposta?.optJSONArray("npcs")
            val problemas = resposta?.optJSONArray("problems")
            if (habitantes == null || habitantes.length() == 0) {
                Text("Ainda não há habitantes registrados neste local.")
            } else {
                for (index in 0 until habitantes.length()) {
                    val npc = habitantes.optJSONObject(index) ?: continue
                    val npcId = npc.optString("id")
                    val nome = npc.optString("name", "Habitante")
                    val papel = when (npc.optString("role")) {
                        "COMERCIANTE" -> "Comerciante"
                        "GUARDA" -> "Guarda"
                        else -> "Morador"
                    }
                    val atividade = when (npc.optString("activity")) {
                        "TRADING" -> "Atendendo no comércio"
                        "GUARDING" -> "De guarda"
                        "PATROLLING" -> "Em patrulha"
                        "SLEEPING" -> "Descansando"
                        "WORKING" -> "Trabalhando"
                        "SOCIALIZING" -> "Socializando"
                        else -> "Em sua rotina"
                    }
                    val humor = when (npc.optString("mood")) {
                        "ASSUSTADO" -> "Assustado"
                        "DESESPERADO" -> "Desesperado"
                        "EXAUSTO" -> "Exausto"
                        "PREOCUPADO" -> "Preocupado"
                        "ATENTO" -> "Atento"
                        else -> "Tranquilo"
                    }
                    val relacionamento = npc.optInt("relationship", 0).coerceIn(0, 100)
                    val nivelRelacao = when {
                        relacionamento >= 90 -> "Confidente"
                        relacionamento >= 60 -> "Aliado"
                        relacionamento >= 30 -> "Amigo"
                        relacionamento >= 10 -> "Conhecido"
                        else -> "Estranho"
                    }
                    val falaAtual = falasPorHabitante[npcId].orEmpty()
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = Color(0xFF202A3B)),
                        shape = RoundedCornerShape(14.dp)
                    ) {
                        Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                            Row {
                                Column(Modifier.weight(1f)) {
                                    Text(nome, color = Color(0xFFFFE5B0), style = MaterialTheme.typography.titleSmall)
                                    Text(papel, color = Color(0xFFBFC9D8), style = MaterialTheme.typography.labelSmall)
                                }
                                Text("$nivelRelacao · $relacionamento/100", color = Color(0xFFE8BD72), style = MaterialTheme.typography.labelSmall)
                            }
                            Text("$atividade · $humor", color = Color(0xFFD8DFEA), style = MaterialTheme.typography.bodySmall)
                            if (falaAtual.isNotBlank()) {
                                Text(
                                    "“$falaAtual”",
                                    color = Color(0xFFFFE5B0),
                                    style = MaterialTheme.typography.bodyMedium
                                )
                            }
                            Button(
                                onClick = {
                                    scope.launch {
                                        runCatching { WorldApi.conversarComHabitante(npcId) }
                                            .onSuccess { result ->
                                                val rel = result.optJSONObject("npc")?.optInt("relationship") ?: relacionamento
                                                val fala = result.optString("dialogue").takeIf { it.isNotBlank() }
                                                if (fala != null) falasPorHabitante = falasPorHabitante + (npcId to fala)
                                                val tier = result.optString("relationshipTier").takeIf { it.isNotBlank() } ?: nivelRelacao
                                                onMessage("Você conversou com $nome. Relação: $tier ($rel/100).")
                                                atualizar()
                                            }
                                            .onFailure { onMessage("Não foi possível conversar com $nome: ${it.localizedMessage}") }
                                    }
                                },
                                modifier = Modifier.fillMaxWidth()
                            ) { Text("CONVERSAR") }
                        }
                    }
                }
            }

            if (problemas != null && problemas.length() > 0) {
                Text("PEDIDOS DE AJUDA", color = Color(0xFFFFD58E), style = MaterialTheme.typography.titleSmall)
                for (index in 0 until problemas.length()) {
                    val problema = problemas.optJSONObject(index) ?: continue
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = Color(0xFF302A32))
                    ) {
                        Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(problema.optString("title", "Pedido de ajuda"), color = Color(0xFFFFE5B0))
                            Text(problema.optString("description"), color = Color(0xFFD8DFEA), style = MaterialTheme.typography.bodySmall)
                            val problemaId = problema.optString("id")
                            val npcId = problema.optString("npcId")
                            val horasRestantes = ((problema.optLong("expiresAtMillis") - System.currentTimeMillis() + 3_599_999L) / 3_600_000L).coerceAtLeast(0L)
                            Text(
                                if (horasRestantes > 0) "Prazo restante: ${horasRestantes} h" else "Prazo encerrado",
                                color = Color(0xFFBFC9D8),
                                style = MaterialTheme.typography.labelSmall
                            )
                            val aceito = problema.optBoolean("acceptedByMe", false)
                            Button(
                                onClick = {
                                    scope.launch {
                                        val action = if (aceito) "AJUDAR_HABITANTE" else "ACEITAR_PEDIDO"
                                        runCatching { WorldApi.agirComPedidoHabitante(npcId, problemaId, action) }
                                            .onSuccess { result ->
                                                onMessage(
                                                    if (result.optBoolean("resolved")) "Pedido concluído! Sua relação com o habitante aumentou."
                                                    else "Pedido aceito. Volte aqui para registrar sua ajuda."
                                                )
                                                atualizar()
                                            }
                                            .onFailure { onMessage("Não foi possível atualizar o pedido: ${it.localizedMessage}") }
                                    }
                                },
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Text(if (aceito) "REGISTRAR AJUDA" else "ACEITAR PEDIDO")
                            }
                        }
                    }
                }
            }
            TextButton(onClick = { scope.launch { atualizar() } }) { Text("ATUALIZAR HABITANTES") }
        }
    }
}
