package br.com.ascensaodosoberano.exploration

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage

@Composable
fun TelaAventuraSolo(
    nomeJogador: String,
    nivelJogador: Int,
    local: String,
    titulo: String,
    narrativa: String,
    escolhas: List<String>,
    acaoLivre: String,
    carregando: Boolean,
    erro: String,
    imagemCriaturaUrl: String = "",
    aoAlterarAcao: (String) -> Unit,
    aoEscolher: (String) -> Unit,
    aoEnviarAcaoLivre: () -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier
) {
    val dourado = Color(0xFFFFD58E)
    val texto = Color(0xFFE8EAF0)

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(Color(0xFF182536), Color(0xFF0B111B), Color(0xFF090E17))))
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text("AVENTURA SOLO", color = dourado, fontWeight = FontWeight.Black, letterSpacing = 1.4.sp)
                Text("$nomeJogador · Nível $nivelJogador", color = Color.White, fontWeight = FontWeight.Bold)
                Text(local, color = Color(0xFFB9C9DD), fontSize = 12.sp)
            }
            TextButton(onClick = aoVoltar) { Text("VOLTAR") }
        }

        Card(colors = CardDefaults.cardColors(containerColor = Color(0xE91B2534)), shape = RoundedCornerShape(18.dp)) {
            Column(Modifier.fillMaxWidth().padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(titulo.ifBlank { "O começo da jornada" }, color = dourado, fontSize = 22.sp, fontWeight = FontWeight.Black)
                if (imagemCriaturaUrl.startsWith("https://") || imagemCriaturaUrl.startsWith("http://")) {
                    AsyncImage(
                        model = imagemCriaturaUrl,
                        contentDescription = "Criatura encontrada na aventura",
                        modifier = Modifier.fillMaxWidth().height(220.dp),
                        contentScale = ContentScale.Fit
                    )
                }
                Text(
                    narrativa.ifBlank { "A aventura espera por você. Escolha como deseja começar." },
                    color = texto,
                    style = MaterialTheme.typography.bodyLarge,
                    lineHeight = 26.sp
                )
            }
        }

        if (erro.isNotBlank()) {
            Text(erro, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodyMedium)
        }

        Text("ESCOLHA SUA AÇÃO", color = dourado, fontWeight = FontWeight.Black, letterSpacing = 1.2.sp)
        escolhas.take(4).forEachIndexed { index, escolha ->
            OutlinedButton(
                onClick = { aoEscolher(escolha) },
                enabled = !carregando && escolha.isNotBlank(),
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp)
            ) {
                Text("${index + 1}. $escolha", color = Color.White, modifier = Modifier.fillMaxWidth())
            }
        }

        HorizontalDivider(color = dourado.copy(alpha = .28f))
        Text("5. FAZER QUALQUER OUTRA AÇÃO", color = dourado, fontWeight = FontWeight.Black)
        OutlinedTextField(
            value = acaoLivre,
            onValueChange = aoAlterarAcao,
            modifier = Modifier.fillMaxWidth(),
            enabled = !carregando,
            minLines = 2,
            maxLines = 4,
            placeholder = { Text("Escreva o que deseja fazer...") },
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = dourado,
                unfocusedBorderColor = Color(0xFF53647A),
                focusedTextColor = Color.White,
                unfocusedTextColor = Color.White
            )
        )
        Button(
            onClick = aoEnviarAcaoLivre,
            enabled = !carregando && acaoLivre.isNotBlank(),
            modifier = Modifier.fillMaxWidth().height(52.dp),
            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF76552E))
        ) {
            Text("REALIZAR AÇÃO", fontWeight = FontWeight.Black)
        }

        if (carregando) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
                CircularProgressIndicator(Modifier.size(22.dp), strokeWidth = 2.dp, color = dourado)
                Spacer(Modifier.width(10.dp))
                Text("O narrador está preparando o próximo capítulo...", color = texto)
            }
        }
    }
}
