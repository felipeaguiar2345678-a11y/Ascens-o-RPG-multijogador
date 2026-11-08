package br.com.ascensaodosoberano.multiplayer

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
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
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch

@Composable
fun MultiplayerExpandidoPanel(uid: String, aoAtualizarPersonagem: () -> Unit, aoMensagem: (String) -> Unit) {
    val repo = remember { MultiplayerExpandidoRepository() }
    val scope = rememberCoroutineScope()
    var carregando by remember { mutableStateOf(false) }
    var codigoMasmorra by remember { mutableStateOf("") }
    var formacaoMasmorra by remember { mutableStateOf("BALANCEADA") }
    var masmorra by remember { mutableStateOf<Map<*, *>?>(null) }
    var regiao by remember { mutableStateOf("dark_forest") }
    var chefe by remember { mutableStateOf<Map<*, *>?>(null) }
    var filaArena by remember { mutableStateOf<Map<*, *>?>(null) }
    var partidaArena by remember { mutableStateOf<Map<*, *>?>(null) }
    var rankingCategoria by remember { mutableStateOf("masmorras") }
    var ranking by remember { mutableStateOf<List<Map<*, *>>>(emptyList()) }
    var evento by remember { mutableStateOf<Map<*, *>?>(null) }
    var pontosEvento by remember { mutableStateOf(0) }
    var eventoReivindicado by remember { mutableStateOf(false) }

    fun executar(acao: String, extras: Map<String, Any?> = emptyMap(), aoConcluir: ((Map<*, *>) -> Unit)? = null) {
        if (carregando) return
        carregando = true
        scope.launch {
            runCatching { repo.chamar(acao, extras) }
                .onSuccess { resultado ->
                    carregando = false
                    aoConcluir?.invoke(resultado)
                    when (resultado["status"]?.toString()) {
                        "RECOMPENSA_ENTREGUE" -> { aoMensagem("Recompensa recebida no inventário!"); aoAtualizarPersonagem() }
                        "DANO_REGISTRADO" -> aoMensagem("Seu ataque foi registrado pelo servidor.")
                        "AGUARDANDO" -> aoMensagem("Procurando adversário na arena...")
                        "PAREAMENTO_TENTADO" -> aoMensagem("Pareamento realizado ou aguardando confirmação. Atualize a arena.")
                    }
                }
                .onFailure { carregando = false; aoMensagem("Não foi possível concluir: ${it.localizedMessage ?: "erro desconhecido"}") }
        }
    }

    fun atualizarMasmorra() = executar("buscarMasmorra") { r -> masmorra = r["dungeon"] as? Map<*, *> }
    fun atualizarChefe() = executar("buscarChefe", mapOf("ecosystemId" to regiao)) { r -> chefe = r["chefe"] as? Map<*, *> }
    fun atualizarArena() = executar("buscarArena") { r -> filaArena = r["fila"] as? Map<*, *>; partidaArena = r["partida"] as? Map<*, *> }
    fun atualizarEvento() = executar("consultarEvento") { r -> evento = r["evento"] as? Map<*, *>; pontosEvento = (r["pontos"] as? Number)?.toInt() ?: 0; eventoReivindicado = r["reivindicado"] == true }

    LaunchedEffect(uid) {
        if (uid.isNotBlank()) {
            runCatching { repo.chamar("buscarMasmorra") }.onSuccess { masmorra = it["dungeon"] as? Map<*, *> }
            runCatching { repo.chamar("consultarEvento") }.onSuccess {
                evento = it["evento"] as? Map<*, *>; pontosEvento = (it["pontos"] as? Number)?.toInt() ?: 0; eventoReivindicado = it["reivindicado"] == true
            }
        }
    }

    val regioesDisponiveis = listOf(
        "dark_forest" to "Floresta Sombria",
        "forgotten_ruins" to "Ruínas Esquecidas",
        "abyss_valley" to "Vale do Abismo",
        "dead_lands" to "Terras Mortas"
    )
    val categoriasRanking = listOf(
        "nivel" to "Nível",
        "masmorras" to "Masmorras",
        "chefes" to "Chefes",
        "arena" to "Arena",
        "guildas" to "Guildas"
    )

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text("CENTRAL MULTIPLAYER", style = MaterialTheme.typography.titleLarge)
        Text("Escolha uma atividade, participe com outros aventureiros e acompanhe suas conquistas. As ações e recompensas são confirmadas pelo servidor.")
        Text(if (carregando) "Sincronizando com o mundo..." else "Serviços conectados", color = MaterialTheme.colorScheme.primary, style = MaterialTheme.typography.labelMedium)

        Card(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("MASMORRAS COOPERATIVAS", style = MaterialTheme.typography.titleMedium)
                val d = masmorra
                if (d == null) {
                    Text("Monte uma equipe de até quatro jogadores. O líder inicia uma expedição de cinco salas.")
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Button(enabled = !carregando, onClick = { executar("criarMasmorra", mapOf("dificuldade" to "NORMAL")) { r -> aoMensagem("Masmorra criada. Código: ${r["codigo"]}"); atualizarMasmorra() } }) { Text("Normal") }
                        Button(enabled = !carregando, onClick = { executar("criarMasmorra", mapOf("dificuldade" to "DIFICIL")) { r -> aoMensagem("Masmorra criada. Código: ${r["codigo"]}"); atualizarMasmorra() } }) { Text("Difícil") }
                        Button(enabled = !carregando, onClick = { executar("criarMasmorra", mapOf("dificuldade" to "ABISMO")) { r -> aoMensagem("Masmorra criada. Código: ${r["codigo"]}"); atualizarMasmorra() } }) { Text("Abismo") }
                    }
                    OutlinedTextField(codigoMasmorra, { codigoMasmorra = it.uppercase().filter(Char::isLetterOrDigit).take(6) }, label = { Text("Código da expedição") }, modifier = Modifier.fillMaxWidth())
                    Button(enabled = !carregando && codigoMasmorra.length == 6, onClick = { executar("entrarMasmorra", mapOf("codigo" to codigoMasmorra)) { aoMensagem("Você entrou na expedição."); atualizarMasmorra() } }, modifier = Modifier.fillMaxWidth()) { Text("ENTRAR NA EXPEDIÇÃO") }
                } else {
                    val id = d["id"]?.toString().orEmpty()
                    val membros = d["members"] as? List<*> ?: emptyList<Any>()
                    Text("Sala ${d["room"] ?: 1}/5 · ${d["difficulty"] ?: "NORMAL"} · Equipe ${membros.size}/4 · Formação ${d["formation"] ?: formacaoMasmorra}")
                    Text("Código: ${d["inviteCode"] ?: "—"} · Compartilhe com seus aliados")
                    Text("${d["enemyName"] ?: "Guardião"} · Vida ${d["enemyHp"] ?: 0}")
                    Text("Estado: ${d["status"] ?: "—"}")
                    (d["memberNames"] as? Map<*, *>)?.forEach { (member, name) ->
                        val stats = (d["memberStats"] as? Map<*, *>)?.get(member) as? Map<*, *>
                        Text("$name · Vida ${stats?.get("hp") ?: "?"}/${stats?.get("maxHp") ?: "?"} · ${stats?.get("role") ?: "Aventureiro"}")
                    }
                    if (d["status"] == "FORMANDO") {
                        Text("Formação da equipe")
                        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                            listOf("BALANCEADA", "AGRESSIVA", "DEFENSIVA").forEach { f ->
                                TextButton(onClick = { formacaoMasmorra = f }) { Text(if (formacaoMasmorra == f) "• $f" else f) }
                            }
                        }
                        Button(enabled = !carregando && d["leaderUid"] == uid, onClick = { executar("iniciarMasmorra", mapOf("dungeonId" to id, "formacao" to formacaoMasmorra)) { atualizarMasmorra() } }, modifier = Modifier.fillMaxWidth()) { Text("INICIAR EXPEDIÇÃO") }
                    }
                    if (d["status"] == "ACTIVE") {
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Button(enabled = !carregando, onClick = { executar("acaoMasmorra", mapOf("dungeonId" to id, "tipo" to "ATACAR")) { atualizarMasmorra() } }) { Text("Atacar") }
                            Button(enabled = !carregando, onClick = { executar("acaoMasmorra", mapOf("dungeonId" to id, "tipo" to "MAGIA")) { atualizarMasmorra() } }) { Text("Magia") }
                            Button(enabled = !carregando, onClick = { executar("acaoMasmorra", mapOf("dungeonId" to id, "tipo" to "DEFENDER")) { atualizarMasmorra() } }) { Text("Defender") }
                        }
                        Button(enabled = !carregando, onClick = { executar("acaoMasmorra", mapOf("dungeonId" to id, "tipo" to "COMBO")) { atualizarMasmorra() } }, modifier = Modifier.fillMaxWidth()) { Text("COMBO EM EQUIPE") }
                        membros.filter { member ->
                            val stats = (d["memberStats"] as? Map<*, *>)?.get(member) as? Map<*, *>
                            (stats?.get("hp") as? Number)?.toInt()?.let { it <= 0 } == true && member != uid
                        }.forEach { alvo ->
                            val nome = (d["memberNames"] as? Map<*, *>)?.get(alvo) ?: "Aliado"
                            TextButton(enabled = !carregando, onClick = { executar("acaoMasmorra", mapOf("dungeonId" to id, "tipo" to "REVIVER", "alvoUid" to alvo.toString())) { atualizarMasmorra() } }) { Text("Reanimar $nome") }
                        }
                    }
                    if (d["status"] == "COMPLETED") Button(enabled = !carregando, onClick = { executar("reivindicarMasmorra", mapOf("dungeonId" to id)) { atualizarMasmorra() } }, modifier = Modifier.fillMaxWidth()) { Text("RECEBER RECOMPENSA") }
                    if (d["status"] == "FAILED" || d["status"] == "FORMANDO") TextButton(enabled = !carregando, onClick = { executar("sairMasmorra") { atualizarMasmorra() } }) { Text("Sair da expedição") }
                    Button(enabled = !carregando, onClick = { atualizarMasmorra() }, modifier = Modifier.fillMaxWidth()) { Text("ATUALIZAR EXPEDIÇÃO") }
                }
            }
        }

        Card(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("CHEFES MUNDIAIS", style = MaterialTheme.typography.titleMedium)
                Text("Encontros regionais usam criaturas-chefe já geradas e cadastradas no bestiário global.")
                Text("Escolha a região do encontro:")
                Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    regioesDisponiveis.forEach { (id, nome) ->
                        TextButton(onClick = { regiao = id; chefe = null }) {
                            Text(if (regiao == id) "• $nome" else nome)
                        }
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Button(enabled = !carregando, onClick = { executar("entrarChefe", mapOf("ecosystemId" to regiao)) { aoMensagem("Você entrou no encontro regional."); atualizarChefe() } }) { Text("PARTICIPAR") }
                    Button(enabled = !carregando, onClick = { atualizarChefe() }) { Text("ATUALIZAR") }
                }
                chefe?.let { b ->
                    Text("${b["name"] ?: "Chefe regional"} · Rank ${b["rank"] ?: "?"}")
                    Text("Vida: ${b["hp"] ?: 0}/${b["maxHp"] ?: 0} · ${b["status"] ?: "—"}")
                    val jaReivindicou = (b["claimedUids"] as? List<*>)?.contains(uid) == true
                    val participa = (b["participants"] as? List<*>)?.contains(uid) == true
                    if (b["status"] == "ACTIVE" && participa) Button(enabled = !carregando, onClick = { executar("atacarChefe", mapOf("ecosystemId" to regiao)) { atualizarChefe() } }, modifier = Modifier.fillMaxWidth()) { Text("ATACAR CHEFE") }
                    if (b["status"] == "DEFEATED" && participa && !jaReivindicou) Button(enabled = !carregando, onClick = { executar("reivindicarChefe", mapOf("ecosystemId" to regiao)) { atualizarChefe() } }, modifier = Modifier.fillMaxWidth()) { Text("RECEBER RECOMPENSA") }
                }
            }
        }

        Card(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("ARENA PvP", style = MaterialTheme.typography.titleMedium)
                Text("Combates opcionais por faixa de classificação. O servidor controla turnos, dano e resultado.")
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(enabled = !carregando, onClick = { executar("filaArena") { aoMensagem("Você entrou na fila da arena."); atualizarArena() } }) { Text("BUSCAR PARTIDA") }
                    TextButton(enabled = !carregando, onClick = { executar("cancelarFila") { filaArena = null; partidaArena = null } }) { Text("Cancelar fila") }
                    TextButton(enabled = !carregando, onClick = { atualizarArena() }) { Text("Atualizar") }
                }
                Text("Fila: ${filaArena?.get("status") ?: "Fora da fila"}")
                partidaArena?.let { p ->
                    Text("Partida ${p["status"] ?: "—"} · Turno: ${p["activeUid"] ?: "—"}")
                    val stats = p["stats"] as? Map<*, *>
                    (p["participants"] as? List<*>)?.forEach { member ->
                        val hp = (stats?.get(member) as? Map<*, *>)?.get("hp")
                        val nome = (p["names"] as? Map<*, *>)?.get(member) ?: "Aventureiro"
                        Text("$nome · Vida $hp")
                    }
                    if (p["status"] == "ACTIVE" && p["activeUid"] == uid) {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Button(enabled = !carregando, onClick = { executar("acaoArena", mapOf("matchId" to p["id"].toString(), "tipo" to "ATACAR")) { atualizarArena() } }) { Text("Atacar") }
                            Button(enabled = !carregando, onClick = { executar("acaoArena", mapOf("matchId" to p["id"].toString(), "tipo" to "DEFENDER")) { atualizarArena() } }) { Text("Defender") }
                        }
                    }
                    if (p["status"] == "ACTIVE" && (p["participants"] as? List<*>)?.contains(uid) == true) {
                        TextButton(enabled = !carregando, onClick = { executar("desistirArena", mapOf("matchId" to p["id"].toString())) { atualizarArena() } }) { Text("Desistir da partida") }
                    }
                    if (p["status"] == "FINISHED") Text("Vencedor: ${(p["names"] as? Map<*, *>)?.get(p["winnerUid"])}")
                }
            }
        }

        Card(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("RANKINGS GLOBAIS", style = MaterialTheme.typography.titleMedium)
                Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    categoriasRanking.forEach { (id, nome) ->
                        TextButton(onClick = { rankingCategoria = id }) {
                            Text(if (rankingCategoria == id) "• $nome" else nome)
                        }
                    }
                }
                Button(enabled = !carregando, onClick = { executar("consultarRanking", mapOf("categoria" to rankingCategoria)) { ranking = (it["entradas"] as? List<*>)?.filterIsInstance<Map<*, *>>() ?: emptyList() } }) { Text("CONSULTAR CLASSIFICAÇÃO") }
                ranking.forEach { e -> Text("${e["posicao"]}. ${e["nome"]} · ${e["score"]}") }
                if (ranking.isEmpty()) Text("Ainda não há pontuações registradas nesta categoria.")
            }
        }

        Card(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("EVENTO SAZONAL", style = MaterialTheme.typography.titleMedium)
                Text((evento?.get("title") ?: "Temporada Multiplayer").toString())
                Text((evento?.get("description") ?: "Participe de atividades multiplayer para ganhar pontos.").toString())
                val pontosGlobais = (evento?.get("globalPoints") as? Number)?.toInt() ?: 0
                val metaGlobal = (evento?.get("goal") as? Number)?.toInt() ?: 5000
                Text("Seu progresso: $pontosEvento/3 pontos")
                Text("Progresso de todos os jogadores: $pontosGlobais/$metaGlobal")
                Text("Recompensa: experiência e Insígnia da Convergência")
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(enabled = !carregando, onClick = { executar("participarEvento") { aoMensagem("Inscrição sazonal confirmada."); atualizarEvento() } }) { Text("PARTICIPAR") }
                    Button(enabled = !carregando && (pontosEvento >= 3 || pontosGlobais >= metaGlobal) && !eventoReivindicado, onClick = { executar("reivindicarEvento") { atualizarEvento() } }) { Text("RESGATAR") }
                    TextButton(enabled = !carregando, onClick = { atualizarEvento() }) { Text("Atualizar") }
                }
                if (eventoReivindicado) Text("Recompensa desta temporada já recebida.")
                else if (pontosEvento >= 3 || pontosGlobais >= metaGlobal) Text("Meta alcançada! Você já pode resgatar sua recompensa, se estiver inscrito.")
                else Text("Participe de masmorras e chefes regionais para acumular pontos.")
            }
        }
    }
}
