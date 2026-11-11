package br.com.ascensaodosoberano

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun TelaAcesso(
    cadastro: Boolean,
    mensagem: String = "",
    carregando: Boolean = false,
    onConfirmar: (String, String) -> Unit,
    onVoltar: () -> Unit,
    onRecuperarSenha: (String) -> Unit
) {
    var email by remember { mutableStateOf("") }
    var senha by remember { mutableStateOf("") }
    val dourado = br.com.ascensaodosoberano.ui.AscensaoPalette.Ouro

    Box(
        modifier = Modifier.fillMaxSize().background(
            Brush.verticalGradient(listOf(br.com.ascensaodosoberano.ui.AscensaoPalette.Fundo, br.com.ascensaodosoberano.ui.AscensaoPalette.SuperficieElevada, Color(0xFF0B1019)))
        ),
        contentAlignment = Alignment.Center
    ) {
        Card(
            modifier = Modifier.fillMaxWidth().padding(22.dp),
            shape = RoundedCornerShape(22.dp),
            colors = CardDefaults.cardColors(containerColor = br.com.ascensaodosoberano.ui.AscensaoPalette.Superficie),
            border = androidx.compose.foundation.BorderStroke(1.dp, dourado.copy(alpha = 0.4f))
        ) {
            Column(
                modifier = Modifier.fillMaxWidth().padding(22.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                Text("✦", color = dourado, fontSize = 30.sp)
                Text(
                    if (cadastro) "FORJE SUA JORNADA" else "BEM-VINDO DE VOLTA",
                    color = Color(0xFFFFE4AC),
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    if (cadastro) "Crie sua conta para guardar sua aventura." else "Entre para continuar sua aventura.",
                    color = Color(0xFFCBD3DF)
                )

                OutlinedTextField(
                    value = email,
                    onValueChange = { email = it },
                    label = { Text("E-mail") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    shape = RoundedCornerShape(12.dp)
                )
                OutlinedTextField(
                    value = senha,
                    onValueChange = { senha = it },
                    label = { Text("Senha") },
                    visualTransformation = PasswordVisualTransformation(),
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    shape = RoundedCornerShape(12.dp)
                )

                Button(
                    onClick = { onConfirmar(email.trim(), senha) },
                    enabled = !carregando && email.isNotBlank() && senha.length >= 6,
                    modifier = Modifier.fillMaxWidth().height(52.dp),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF76532D))
                ) {
                    Text(if (cadastro) "CRIAR MINHA CONTA" else "ENTRAR NO JOGO", fontWeight = FontWeight.Bold)
                }

                if (!cadastro) {
                    TextButton(
                        onClick = { onRecuperarSenha(email.trim()) },
                        enabled = !carregando && email.isNotBlank(),
                        modifier = Modifier.align(Alignment.CenterHorizontally)
                    ) { Text("Esqueci minha senha", color = dourado) }
                }

                if (carregando) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.Center,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        CircularProgressIndicator(color = dourado, modifier = Modifier.size(24.dp))
                        Text("  Preparando sua jornada...", color = Color.White)
                    }
                }
                if (mensagem.isNotBlank()) {
                    Text(mensagem, color = MaterialTheme.colorScheme.error)
                }
                HorizontalDivider(color = Color.White.copy(alpha = 0.12f))
                TextButton(
                    onClick = onVoltar,
                    enabled = !carregando,
                    modifier = Modifier.align(Alignment.CenterHorizontally)
                ) {
                    Text("← VOLTAR AO INÍCIO", color = Color(0xFFE4D6BE), fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}