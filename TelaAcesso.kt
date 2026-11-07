package br.com.ascensaodosoberano

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp

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

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = if (cadastro) "CRIAR CONTA" else "ENTRAR",
            style = MaterialTheme.typography.headlineMedium
        )

        Spacer(Modifier.height(20.dp))

        OutlinedTextField(
            value = email,
            onValueChange = { email = it },
            label = { Text("E-mail") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true
        )

        Spacer(Modifier.height(12.dp))

        OutlinedTextField(
            value = senha,
            onValueChange = { senha = it },
            label = { Text("Senha") },
            visualTransformation = PasswordVisualTransformation(),
            modifier = Modifier.fillMaxWidth(),
            singleLine = true
        )

        Spacer(Modifier.height(16.dp))

        Button(
            onClick = { onConfirmar(email, senha) },
            enabled = !carregando &&
                email.isNotBlank() &&
                senha.length >= 6,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(if (cadastro) "CRIAR CONTA" else "ENTRAR")
        }

        if (!cadastro) {
            TextButton(
                onClick = { onRecuperarSenha(email) },
                enabled = !carregando && email.isNotBlank()
            ) {
                Text("Esqueci minha senha")
            }
        }

        if (carregando) {
            CircularProgressIndicator()
        }

        if (mensagem.isNotBlank()) {
            Text(mensagem)
        }

        Spacer(Modifier.height(12.dp))

        TextButton(
            onClick = onVoltar,
            enabled = !carregando
        ) {
            Text("VOLTAR")
        }
    }
}