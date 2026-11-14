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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import br.com.ascensaodosoberano.world.CriaturaGerada
import br.com.ascensaodosoberano.combat.CriaturaPixelArt
import br.com.ascensaodosoberano.multiplayer.AllyStorySnapshot

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
    historiaCompartilhada: AllyStorySnapshot? = null,
    aoEscolherNaHistoria: (String) -> Unit = {},
    tituloAventura: String = "",
    narrativaAventura: String = "",
    erroAventura: String = "",
    resultadoDadoAventura: String = "",
    escolhasAventura: List<String> = emptyList(),
    rankJogador: String = "E",
    chefesPromocaoDerrotados: List<String> = emptyList(),
    aoAceitarMissao: (GuildMission) -> Unit = {},
    acaoLivre: String = "",
    aoAlterarAcaoLivre: (String) -> Unit = {},
    aoEscolherNaAventura: (String) -> Unit = {},
    aoEnviarAcaoLivre: () -> Unit = {},
    modifier: Modifier = Modifier,
    missaoAtiva: GuildMission? = null,
    aoAbandonarMissao: () -> Unit = {},
    aceitandoMissao: Boolean = false,
    erroAceitarMissao: String = ""
) {
    val dourado = Color(0xFFFFD58E)
    val texto = Color(0xFFE8EAF0)
    val fundo = Color(0xFF0B111B)
    val painel = Color(0xE91B2534)
    if (missaoAtiva != null) {
        val missao = missaoAtiva
        Column(
            modifier = modifier.fillMaxSize()
                .background(Brush.verticalGradient(listOf(Color(0xFF211B36), Color(0xFF090D17), Color(0xFF05070D))))
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 22.dp, vertical = 24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
                Text("MISSÃO ATIVA  ·  RANK ${missao.rank}  ·  ${missao.rarity.uppercase()}", modifier = Modifier.fillMaxWidth(), color = dourado, fontWeight = FontWeight.Black, letterSpacing = 1.1.sp, fontSize = 12.sp, textAlign = TextAlign.Start, softWrap = true)
                Text(missao.title, modifier = Modifier.fillMaxWidth(), color = Color.White, fontSize = 25.sp, fontWeight = FontWeight.Black, lineHeight = 32.sp, textAlign = TextAlign.Start, softWrap = true)
                Text("${missao.destinationName} · ${missao.regionName}", modifier = Modifier.fillMaxWidth(), color = Color(0xFFC8B5F5), fontWeight = FontWeight.Bold, fontSize = 16.sp, textAlign = TextAlign.Start, softWrap = true)
                Surface(color = Color(0xD91A2231), shape = RoundedCornerShape(18.dp), modifier = Modifier.fillMaxWidth()) {
                    Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("OBJETIVO", modifier = Modifier.fillMaxWidth(), color = dourado, fontWeight = FontWeight.Black, letterSpacing = 1.1.sp, fontSize = 17.sp)
                        Text(missao.objective, modifier = Modifier.fillMaxWidth(), color = texto, fontSize = 18.sp, lineHeight = 27.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Start, softWrap = true)
                        Text("Recompensa: ${missao.rewardGold} ouro · ${missao.rewardXp} XP", modifier = Modifier.fillMaxWidth(), color = Color(0xFFFFD58E), fontSize = 17.sp, lineHeight = 24.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Start, softWrap = true)
                        Text("Raridade ${missao.rarity} · dificuldade ×${"%.1f".format(missao.difficultyMultiplier)}", modifier = Modifier.fillMaxWidth(), color = Color(0xFFC8B5F5), fontSize = 14.sp, lineHeight = 20.sp, textAlign = TextAlign.Start, softWrap = true)
                        if (narrativaAventura.isNotBlank()) Text(narrativaAventura.take(260), modifier = Modifier.fillMaxWidth(), color = texto, fontSize = 18.sp, lineHeight = 28.sp, textAlign = TextAlign.Start, softWrap = true)
                        if (criaturaEncontrada != null) Text("Encontro: ${criaturaEncontrada.nome}", color = Color(0xFFFFC477), fontWeight = FontWeight.Bold)
                        if (erroAventura.isNotBlank()) Text(erroAventura, color = Color(0xFFFFA29A))
                    }
                }
                if (criaturaEncontrada != null) {
                    Button(onClick = aoEnfrentarCriatura, modifier = Modifier.fillMaxWidth().height(54.dp), colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF8C3038))) {
                        Text("ENFRENTAR ${criaturaEncontrada.nome}", fontWeight = FontWeight.Black)
                    }
                    OutlinedButton(onClick = aoIgnorarCriatura, modifier = Modifier.fillMaxWidth()) { Text("CONTINUAR SEM LUTAR") }
                } else if (escolhasAventura.isNotEmpty()) {
                    Text("ESCOLHA SEU PRÓXIMO PASSO", color = dourado, fontWeight = FontWeight.Black)
                    escolhasAventura.take(4).forEach { escolha ->
                        OutlinedButton(onClick = { aoEscolherNaAventura(escolha) }, enabled = !buscandoCriaturas, modifier = Modifier.fillMaxWidth(), contentPadding = PaddingValues(horizontal = 12.dp, vertical = 14.dp)) {
                            Text(escolha, modifier = Modifier.fillMaxWidth(), color = Color.White, fontSize = 18.sp, lineHeight = 25.sp, textAlign = TextAlign.Center, softWrap = true)
                        }
                    }
                } else {
                    Button(onClick = { if (acaoLivre.isNotBlank()) aoEnviarAcaoLivre() else aoExplorar() }, enabled = !buscandoCriaturas, modifier = Modifier.fillMaxWidth().height(56.dp), colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF76552E))) {
                        Text(if (buscandoCriaturas) "PREPARANDO A PRÓXIMA CENA…" else "CONTINUAR MISSÃO", fontWeight = FontWeight.Black)
                    }
                }
                OutlinedButton(onClick = aoAbandonarMissao, modifier = Modifier.fillMaxWidth()) { Text("ABANDONAR MISSÃO") }
        }
    } else {
    Column(
        modifier = modifier.fillMaxSize()
            .background(Brush.verticalGradient(listOf(Color(0xFF182536), fundo, Color(0xFF090E17))))
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            if (imagemPersonagemUrl.startsWith("https://") || imagemPersonagemUrl.startsWith("http://")) {
                AsyncImage(model = imagemPersonagemUrl, contentDescription = "Retrato de $nomeJogador", modifier = Modifier.size(76.dp), contentScale = ContentScale.Crop)
            } else {
                Surface(modifier = Modifier.size(76.dp), shape = RoundedCornerShape(14.dp), color = Color(0xFF34445A)) {
                    Box(contentAlignment = Alignment.Center) { Text("✦", color = dourado, fontSize = 34.sp) }
                }
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(nomeJogador, color = dourado, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                Text("Nível $nivelJogador", color = texto.copy(alpha = .82f))
                Text(local.uppercase(), color = Color(0xFFB9C9DD), fontSize = 10.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.2.sp)
            }
            Surface(shape = RoundedCornerShape(10.dp), color = Color(0xFF28374A)) {
                Text("AVENTURA", color = dourado, fontSize = 9.sp, fontWeight = FontWeight.Black, modifier = Modifier.padding(horizontal = 9.dp, vertical = 7.dp))
            }
        }

        QuadroMissoesGuilda(
            nivelJogador = nivelJogador,
            rankJogador = rankJogador,
            chefesPromocaoDerrotados = chefesPromocaoDerrotados,
            aoAceitarMissao = aoAceitarMissao,
            aceitandoMissao = aceitandoMissao,
            erroAceitarMissao = erroAceitarMissao
        )

        Card(colors = CardDefaults.cardColors(containerColor = painel), shape = RoundedCornerShape(18.dp)) {
            Column(Modifier.fillMaxWidth().padding(18.dp), verticalArrangement = Arrangement.spacedBy(11.dp)) {
                Text("CAPÍTULO ATUAL", color = dourado, fontWeight = FontWeight.Black, letterSpacing = 1.5.sp, fontSize = 11.sp)
                Text(tituloAventura.ifBlank { if (criaturaEncontrada == null) "O caminho à frente" else "Algo se move nas proximidades" }, color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold)
                Text(
                    narrativaAventura.ifBlank {
                        when {
                            criaturaEncontrada?.chefe == true -> "O ambiente muda de repente. O vento perde a força, os sons ao redor desaparecem e uma presença esmagadora se revela."
                            criaturaEncontrada != null -> "Um ruído interrompe seus pensamentos. Entre as sombras, uma criatura se aproxima com cautela."
                            mensagem.isNotBlank() -> mensagem
                            else -> "A jornada começa. Cada decisão pode abrir uma oportunidade ou revelar um novo perigo."
                        }
                    },
                    color = texto, style = MaterialTheme.typography.bodyLarge, lineHeight = 25.sp
                )
                if (mensagem.isNotBlank() && narrativaAventura.isBlank()) {
                    HorizontalDivider(color = dourado.copy(alpha = .28f))
                    Text(mensagem, color = Color(0xFFE7D6B5), style = MaterialTheme.typography.bodyMedium, lineHeight = 23.sp)
                }
            }
        }

        if (historiaCompartilhada != null) {
            Card(colors = CardDefaults.cardColors(containerColor = Color(0xE9233042)), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text("HISTÓRIA COMPARTILHADA · GRUPO", color = dourado, fontWeight = FontWeight.Black, letterSpacing = 1.sp, fontSize = 10.sp)
                    Text(historiaCompartilhada.chapterTitle, color = Color.White, fontSize = 21.sp, fontWeight = FontWeight.Bold)
                    if (historiaCompartilhada.imageUrl.startsWith("https://") || historiaCompartilhada.imageUrl.startsWith("http://")) {
                        AsyncImage(model = historiaCompartilhada.imageUrl, contentDescription = "Cena compartilhada", modifier = Modifier.fillMaxWidth().height(190.dp), contentScale = ContentScale.Crop)
                    }
                    Text(historiaCompartilhada.narrativeText, color = texto, style = MaterialTheme.typography.bodyLarge, lineHeight = 25.sp)
                    if (historiaCompartilhada.choices.isNotEmpty()) {
                        Text("O QUE VOCÊ ESCOLHE?", color = dourado, fontWeight = FontWeight.Bold, fontSize = 11.sp)
                        historiaCompartilhada.choices.forEach { escolha ->
                            OutlinedButton(onClick = { aoEscolherNaHistoria(escolha) }, modifier = Modifier.fillMaxWidth()) {
                                Text(escolha, color = Color.White)
                            }
                        }
                    }
                }
            }
        }

        if (resultadoDadoAventura.isNotBlank()) {
            Card(colors = CardDefaults.cardColors(containerColor = Color(0xFF26364A)), shape = RoundedCornerShape(14.dp)) {
                Column(Modifier.fillMaxWidth().padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text("ROLAGEM DE DESTINO", color = dourado, fontWeight = FontWeight.Black, fontSize = 11.sp, letterSpacing = 1.sp)
                    Text(resultadoDadoAventura, color = Color.White, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.bodyLarge)
                }
            }
        }

        if (erroAventura.isNotBlank()) {
            Text(erroAventura, color = Color(0xFFFFA29A), style = MaterialTheme.typography.bodyMedium)
        }

        if (buscandoCriaturas) {
            Card(
                colors = CardDefaults.cardColors(containerColor = Color(0xFF26364A)),
                shape = RoundedCornerShape(14.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    CircularProgressIndicator(Modifier.size(22.dp), strokeWidth = 2.dp, color = dourado)
                    Text(
                        if (escolhasAventura.isEmpty()) "O narrador está preparando sua aventura..."
                        else "A história está avançando. Aguarde a próxima cena...",
                        color = texto,
                        style = MaterialTheme.typography.bodyMedium
                    )
                }
            }
        }


        if (criaturaEncontrada != null) {
            val criatura = criaturaEncontrada
            Card(colors = CardDefaults.cardColors(containerColor = Color(0xFF291D28)), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(if (criatura.chefe) "⚠ AMEAÇA DE CHEFE" else "⚔ ENCONTRO HOSTIL", color = if (criatura.chefe) Color(0xFFFF8D78) else Color(0xFFFFC477), fontWeight = FontWeight.Black, letterSpacing = 1.1.sp)
                    if (criatura.imagemDetalhadaCaminho.startsWith("https://") || criatura.imagemDetalhadaCaminho.startsWith("http://")) {
                        AsyncImage(model = criatura.imagemDetalhadaCaminho, contentDescription = "Imagem de ${criatura.nome}", modifier = Modifier.fillMaxWidth().height(220.dp), contentScale = ContentScale.Fit)
                    } else if (criatura.imagemIconeCaminho.startsWith("https://") || criatura.imagemIconeCaminho.startsWith("http://")) {
                        AsyncImage(model = criatura.imagemIconeCaminho, contentDescription = "Imagem de ${criatura.nome}", modifier = Modifier.fillMaxWidth().height(190.dp), contentScale = ContentScale.Fit)
                    } else {
                        CriaturaPixelArt(nome = criatura.nome, rank = criatura.rank, chefe = criatura.chefe, modifier = Modifier.fillMaxWidth().height(190.dp))
                    }
                    Text(criatura.nome, color = Color.White, fontSize = 23.sp, fontWeight = FontWeight.Black)
                    Text("Rank ${criatura.rank}  ·  Nível ${criatura.nivel}  ·  ${criatura.raridade}", color = dourado, fontWeight = FontWeight.Bold)
                    Text(criatura.descricao.ifBlank { "A criatura encara você. Sua postura revela que ela está pronta para atacar." }, color = texto, style = MaterialTheme.typography.bodyLarge, lineHeight = 24.sp)
                    Row(horizontalArrangement = Arrangement.spacedBy(9.dp)) {
                        Button(onClick = aoEnfrentarCriatura, modifier = Modifier.weight(1f).height(50.dp), colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF8C3038))) {
                            Text("INICIAR COMBATE", fontWeight = FontWeight.Black)
                        }
                        OutlinedButton(onClick = aoIgnorarCriatura, modifier = Modifier.weight(1f).height(50.dp)) { Text("RECUAR") }
                    }
                }
            }
        } else {
            if (escolhasAventura.size == 4) {
                Text("O QUE VOCÊ FAZ AGORA?", color = dourado, fontWeight = FontWeight.Black, letterSpacing = 1.sp)
                escolhasAventura.forEachIndexed { index, escolha ->
                    OutlinedButton(
                        onClick = { aoEscolherNaAventura(escolha) },
                        enabled = !buscandoCriaturas,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("${index + 1}. $escolha", color = Color.White, modifier = Modifier.fillMaxWidth())
                    }
                }
                HorizontalDivider(color = dourado.copy(alpha = .28f))
                Text("5. FAZER OUTRA AÇÃO", color = dourado, fontWeight = FontWeight.Black)
                OutlinedTextField(
                    value = acaoLivre,
                    onValueChange = aoAlterarAcaoLivre,
                    modifier = Modifier.fillMaxWidth(),
                    enabled = !buscandoCriaturas,
                    minLines = 2,
                    maxLines = 4,
                    placeholder = { Text("Descreva livremente o que deseja fazer...") }
                )
                Button(
                    onClick = aoEnviarAcaoLivre,
                    enabled = !buscandoCriaturas && acaoLivre.isNotBlank(),
                    modifier = Modifier.fillMaxWidth().height(52.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF76552E))
                ) { Text("REALIZAR AÇÃO", fontWeight = FontWeight.Black) }
            } else {
                Button(onClick = aoExplorar, enabled = !buscandoCriaturas, modifier = Modifier.fillMaxWidth().height(56.dp), colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF76552E))) {
                    if (buscandoCriaturas) {
                        CircularProgressIndicator(Modifier.size(21.dp), strokeWidth = 2.dp, color = Color.White)
                        Spacer(Modifier.width(10.dp))
                        Text("O NARRADOR ESTÁ PREPARANDO A CENA…")
                    } else {
                        Text("COMEÇAR A AVENTURA", fontWeight = FontWeight.Black, letterSpacing = 1.sp)
                    }
                }
            }
        }

        Text("JORNADA E PERSONAGEM", color = dourado, fontWeight = FontWeight.Black, letterSpacing = 1.2.sp, fontSize = 11.sp)
        listOf(
            "STATUS" to "Atributos, nível e evolução",
            "INVENTARIO" to "Itens, equipamentos e ouro",
            "BESTIARIO" to "Criaturas e descobertas",
            "MULTIPLAYER" to "Grupo e aventura compartilhada"
        ).forEach { (id, descricao) ->
            OutlinedButton(onClick = { aoAbrirPainel(id) }, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(12.dp)) {
                Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(id, color = dourado, fontWeight = FontWeight.Bold)
                    Text(descricao, color = texto.copy(alpha = .72f), style = MaterialTheme.typography.labelSmall)
                }
            }
        }
        Spacer(Modifier.height(16.dp))
    }
    }
}
