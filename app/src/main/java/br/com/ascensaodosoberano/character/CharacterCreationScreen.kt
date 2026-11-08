
package br.com.ascensaodosoberano.character

import androidx.compose.foundation.clickable
import androidx.compose.foundation.background
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.rememberCoroutineScope
import kotlinx.coroutines.launch
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp


@Composable
fun CharacterCreationScreen(
    onCharacterCreated: suspend (CharacterProfile) -> Unit
) {
    var customMode by remember { mutableStateOf(false) }
    var characterName by remember { mutableStateOf("") }
    var selectedClassId by remember { mutableStateOf("warrior") }
    var customConcept by remember { mutableStateOf("") }
    var customName by remember { mutableStateOf("") }
    var errorMessage by remember { mutableStateOf("") }
    var isCreating by remember { mutableStateOf(false) }
    val creationScope = rememberCoroutineScope()
    var appearance by remember {
    mutableStateOf(CharacterAppearance())
}

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF101722))
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Text(
            "FORJE SEU AVENTUREIRO",
            style = MaterialTheme.typography.headlineSmall,
            color = Color(0xFFFFD995),
            fontWeight = FontWeight.Bold
        )
        Text(
            "Escolha sua especialidade e construa sua própria história.",
            color = Color(0xFFBEC9D8),
            style = MaterialTheme.typography.bodyMedium
        )

        OutlinedTextField(
            value = characterName,
            onValueChange = { characterName = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text("Nome do personagem") }
        )

        Text(
            "Sua classe define sua especialidade, não seus limites."
        )

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(
                onClick = { customMode = false }
            ) {
                Text("Classes prontas")
            }

            OutlinedButton(
                onClick = { customMode = true }
            ) {
                Text("Criar minha classe")
            }
        }

        if (!customMode) {
            CharacterSystem.predefinedClasses.forEach { characterClass ->
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable {
                            selectedClassId = characterClass.id
                        },
                    shape = RoundedCornerShape(14.dp),
                    border = androidx.compose.foundation.BorderStroke(
                        1.dp,
                        if (selectedClassId == characterClass.id) Color(0xFFE8BD72) else Color(0xFF465267)
                    ),
                    colors = CardDefaults.cardColors(
                        containerColor =
                            if (selectedClassId == characterClass.id)
                                Color(0xFF3A3025)
                            else
                                Color(0xFF202B3B)
                    )
                ) {
                    Column(Modifier.padding(16.dp)) {
                        Text(
                            characterClass.name,
                            style = MaterialTheme.typography.titleMedium,
                            color = Color(0xFFFFE3AE),
                            fontWeight = FontWeight.Bold
                        )
                        Text(characterClass.description, color = Color(0xFFD0D8E4))

                        if (selectedClassId == characterClass.id) {
                            Text("Selecionada")
                        }
                    }
                }
            }
        } else {
            OutlinedTextField(
                value = customConcept,
                onValueChange = { customConcept = it },
                modifier = Modifier.fillMaxWidth(),
                label = { Text("Descreva sua classe") },
                placeholder = {
                    Text("Ex.: Guerreiro que manipula gravidade...")
                },
                minLines = 4
            )

            OutlinedTextField(
                value = customName,
                onValueChange = { customName = it },
                modifier = Modifier.fillMaxWidth(),
                label = { Text("Nome da classe") }
            )
        }
Text(
    "PERSONALIZE SEU PERSONAGEM",
    style = MaterialTheme.typography.titleLarge,
    color = Color(0xFFFFD995),
    fontWeight = FontWeight.Bold
)

CharacterAppearancePreview(
    appearance = appearance
)

CharacterAppearanceScreen(
    appearance = appearance,
    onAppearanceChange = {
        appearance = it
    }
)
        if (errorMessage.isNotBlank()) {
            Text(
                errorMessage,
                color = MaterialTheme.colorScheme.error
            )
        }

        Button(
            onClick = {
                if (characterName.isBlank()) {
                    errorMessage = "Digite o nome do personagem."
                } else {
                    val profile = if (customMode) {
                        val proposal = CharacterCreation.createCustomProposal(customConcept)
                        if (proposal == null || customName.isBlank()) {
                            errorMessage = "Descreva sua classe e escolha um nome."
                            null
                        } else {
                            val result = CharacterCreation.approveProposal(proposal, customName.trim())
                            CharacterProfile(
                                name = characterName.trim(),
                                level = 1,
                                xp = 0,
                                characterClass = result,
                                appearance = appearance
                            )
                        }
                    } else {
                        val result = CharacterSystem.getClassById(selectedClassId)
                        if (result == null) {
                            errorMessage = "Selecione uma classe válida."
                            null
                        } else {
                            CharacterProfile(
                                name = characterName.trim(),
                                level = 1,
                                xp = 0,
                                characterClass = result,
                                appearance = appearance
                            )
                        }
                    }

                    if (profile != null && !isCreating) {
                        creationScope.launch {
                            isCreating = true
                            errorMessage = ""
                            try {
                                onCharacterCreated(profile)
                            } catch (error: Exception) {
                                errorMessage = error.localizedMessage
                                    ?: "Não foi possível concluir a criação do personagem."
                            } finally {
                                isCreating = false
                            }
                        }
                    }
                }
            },
            enabled = !isCreating,
            modifier = Modifier.fillMaxWidth()
        ) {
            if (isCreating) {
                CircularProgressIndicator(
                    modifier = Modifier.size(18.dp),
                    strokeWidth = 2.dp
                )
                Spacer(Modifier.width(8.dp))
                Text("Gerando habilidades e criando personagem...")
            } else {
                Text("Criar personagem")
            }
        }
    }
}
