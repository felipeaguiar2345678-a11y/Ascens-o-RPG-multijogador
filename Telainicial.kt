package br.com.ascensaodosoberano

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

@Composable
fun TelaInicial(
    onEntrar: () -> Unit,
    onCriarConta: () -> Unit,
    onVisitante: () -> Unit
) {
    Box(
        modifier = Modifier.fillMaxSize()
    ) {

        // Vídeos ocupam o fundo inteiro
        VideoFundo(
            modifier = Modifier.fillMaxSize()
        )

        // Camada escura para melhorar a leitura
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black.copy(alpha = 0.48f))
        )

        // Título e botões
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.SpaceBetween
        ) {

            Spacer(modifier = Modifier.height(30.dp))

            Text(
                text = "ASCENSÃO DO SOBERANO",
                style = MaterialTheme.typography.headlineMedium,
                color = Color(0xFFFFD77A)
            )

            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {

                Button(
                    onClick = onEntrar,
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color(0xFF49316D)
                    )
                ) {
                    Text("ENTRAR")
                }

                Button(
                    onClick = onCriarConta,
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color(0xFF765329)
                    )
                ) {
                    Text("CRIAR CONTA")
                }

                OutlinedButton(
                    onClick = onVisitante,
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Text(
                        "JOGAR COMO VISITANTE",
                        color = Color.White
                    )
                }
            }
        }
    }
}