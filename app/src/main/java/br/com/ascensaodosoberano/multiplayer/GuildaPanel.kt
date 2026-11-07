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
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch

@Composable
fun GuildaPanel(uid: String, nomeJogador: String, aoMensagem: (String) -> Unit) {
    val repository = remember { GuildRepository() }
    val scope = rememberCoroutineScope()
    var guilda by remember { mutableStateOf<GuildaSnapshot?>(null) }
    var nomeNovaGuilda by remember { mutableStateOf("") }
    var codigoGuilda by remember { mutableStateOf("") }
    var carregando by remember { mutableStateOf(false) }

    DisposableEffect(uid) {
        val listener = if (uid.isNotBlank()) repository.observarMinhaGuilda(uid) { guilda = it } else null
        onDispose { listener?.remove() }
    }

    Card(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text("GUILDAS", style = MaterialTheme.typography.titleMedium)
            Text("Crie uma comunidade permanente ou entre em uma usando um código. Guildas são independentes dos grupos Ally.")

            val atual = guilda
            if (atual != null) {
                Text(atual.nome, style = MaterialTheme.typography.titleLarge)
                Text("Membros: ${atual.membros.size}/30")
                Text("ACAMPAMENTO DA GUILDA · Nível ${atual.nivelAcampamento}", style = MaterialTheme.typography.titleSmall)
                Text("Progresso: ${atual.experienciaAcampamento}/${atual.nivelAcampamento * 100} contribuições · bônus de XP: +${((atual.nivelAcampamento - 1).coerceAtMost(10) * 2)}%")
                Text("Cada masmorra concluída e chefe regional derrotado fortalece o acampamento de sua guilda.")
                Text("Código de convite: ${atual.codigoConvite}", style = MaterialTheme.typography.titleSmall)
                Text("Compartilhe esse código com quem deseja convidar.")
                atual.membros.forEach { membro ->
                    val nome = atual.nomesMembros[membro] ?: "Aventureiro"
                    Text((if (membro == atual.liderUid) "Líder: " else "Membro: ") + nome)
                }
                TextButton(
                    enabled = !carregando,
                    onClick = {
                        carregando = true
                        scope.launch {
                            runCatching { repository.sair() }
                                .onSuccess { aoMensagem("Você saiu da guilda. Se era o líder, a liderança passou para outro membro.") }
                                .onFailure { aoMensagem("Não foi possível sair da guilda: ${it.localizedMessage}") }
                            carregando = false
                        }
                    }
                ) { Text("Sair da guilda") }
            } else {
                OutlinedTextField(
                    value = nomeNovaGuilda,
                    onValueChange = { nomeNovaGuilda = it.take(24) },
                    label = { Text("Nome da nova guilda") },
                    supportingText = { Text("De 3 a 24 caracteres") },
                    modifier = Modifier.fillMaxWidth()
                )
                Button(
                    enabled = !carregando && nomeNovaGuilda.trim().length in 3..24,
                    modifier = Modifier.fillMaxWidth(),
                    onClick = {
                        carregando = true
                        scope.launch {
                            runCatching { repository.criar(nomeNovaGuilda, uid, nomeJogador) }
                                .onSuccess { aoMensagem("Guilda criada! O código de convite aparecerá aqui.") ; nomeNovaGuilda = "" }
                                .onFailure { aoMensagem("Não foi possível criar a guilda: ${it.localizedMessage}") }
                            carregando = false
                        }
                    }
                ) { Text(if (carregando) "Aguarde..." else "CRIAR GUILDA") }

                OutlinedTextField(
                    value = codigoGuilda,
                    onValueChange = { codigoGuilda = it.uppercase().filter { c -> c.isLetterOrDigit() }.take(6) },
                    label = { Text("Código de convite") },
                    supportingText = { Text("Código de 6 caracteres") },
                    modifier = Modifier.fillMaxWidth()
                )
                Button(
                    enabled = !carregando && codigoGuilda.length == 6,
                    modifier = Modifier.fillMaxWidth(),
                    onClick = {
                        carregando = true
                        scope.launch {
                            runCatching { repository.entrar(codigoGuilda, nomeJogador) }
                                .onSuccess { aoMensagem("Você entrou na guilda!"); codigoGuilda = "" }
                                .onFailure { aoMensagem("Não foi possível entrar: ${it.localizedMessage}") }
                            carregando = false
                        }
                    }
                ) { Text("ENTRAR EM UMA GUILDA") }
            }
        }
    }
}
