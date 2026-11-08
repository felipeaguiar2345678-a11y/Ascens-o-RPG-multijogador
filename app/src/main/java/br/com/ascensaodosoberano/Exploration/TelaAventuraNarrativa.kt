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
    modifier: Modifier = Modifier
) {
    val dourado = Color(0xFFFFD58E)
    val texto = Color(0xFFE8EAF0)
    val fundo = Color(0xFF0B111B)
    val painel = Color(0xE91B2534)

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

        Card(colors = CardDefaults.cardColors(containerColor = painel), shape = RoundedCornerShape(18.dp)) {
            Column(Modifier.fillMaxWidth().padding(18.dp), verticalArrangement = Arrangement.spacedBy(11.dp)) {
                Text("CAPÍTULO ATUAL", color = dourado, fontWeight = FontWeight.Black, letterSpacing = 1.5.sp, fontSize = 11.sp)
                Text(if (criaturaEncontrada == null) "O caminho à frente" else "Algo se move nas proximidades", color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold)
                Text(
                    when {
                        criaturaEncontrada?.chefe == true -> "O ambiente muda de repente. O vento perde a força, os sons ao redor desaparecem e uma presença esmagadora se revela. Não é um encontro comum: algo poderoso decidiu mostrar sua presença."
                        criaturaEncontrada != null -> "Um ruído interrompe seus pensamentos. Entre as sombras, uma criatura se aproxima com cautela, observando cada movimento. Você tem alguns instantes para decidir como reagir."
                        mensagem.isNotBlank() -> "A aventura continua. O que aconteceu até aqui deixou marcas no caminho, e a próxima decisão pode abrir uma oportunidade ou revelar um novo perigo."
                        else -> "A jornada segue adiante. O ambiente parece vivo: sons distantes atravessam o cenário, sinais antigos aparecem pelo caminho e cada decisão pode conduzir a um acontecimento diferente."
                    },
                    color = texto, style = MaterialTheme.typography.bodyLarge, lineHeight = 25.sp
                )
                if (mensagem.isNotBlank()) {
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
            Button(onClick = aoExplorar, enabled = !buscandoCriaturas, modifier = Modifier.fillMaxWidth().height(56.dp), colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF76552E))) {
                if (buscandoCriaturas) {
                    CircularProgressIndicator(Modifier.size(21.dp), strokeWidth = 2.dp, color = Color.White)
                    Spacer(Modifier.width(10.dp))
                    Text("OBSERVANDO O AMBIENTE…")
                } else {
                    Text("CONTINUAR A HISTÓRIA", fontWeight = FontWeight.Black, letterSpacing = 1.sp)
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
