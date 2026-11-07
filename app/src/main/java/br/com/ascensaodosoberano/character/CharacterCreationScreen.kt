
package br.com.ascensaodosoberano.character

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp


@Composable
fun CharacterCreationScreen(
    onCharacterCreated: (CharacterProfile) -> Unit
) {
    var customMode by remember { mutableStateOf(false) }
    var characterName by remember { mutableStateOf("") }
    var selectedClassId by remember { mutableStateOf("warrior") }
    var customConcept by remember { mutableStateOf("") }
    var customName by remember { mutableStateOf("") }
    var errorMessage by remember { mutableStateOf("") }
    var appearance by remember {
    mutableStateOf(CharacterAppearance())
}

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Text(
            "CRIAÇÃO DE PERSONAGEM",
            style = MaterialTheme.typography.headlineSmall
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
                    colors = CardDefaults.cardColors(
                        containerColor =
                            if (selectedClassId == characterClass.id)
                                MaterialTheme.colorScheme.primaryContainer
                            else
                                MaterialTheme.colorScheme.surfaceVariant
                    )
                ) {
                    Column(Modifier.padding(16.dp)) {
                        Text(
                            characterClass.name,
                            style = MaterialTheme.typography.titleMedium
                        )
                        Text(characterClass.description)

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
    style = MaterialTheme.typography.titleLarge
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
    } else if (customMode) {
        val proposal = CharacterCreation
            .createCustomProposal(customConcept)

        if (proposal == null || customName.isBlank()) {
            errorMessage = "Descreva sua classe e escolha um nome."
        } else {
            val result = CharacterCreation.approveProposal(
                proposal,
                customName.trim()
            )

            onCharacterCreated(
                CharacterProfile(
                    name = characterName.trim(),
                    level = 1,
                    xp = 0,
                    characterClass = result,
                    appearance = appearance
                )
            )
        }
    } else {
        val result = CharacterSystem.getClassById(selectedClassId)

        if (result != null) {
            onCharacterCreated(
                CharacterProfile(
                    name = characterName.trim(),
                    level = 1,
                    xp = 0,
                    characterClass = result,
                    appearance = appearance
                )
            )
        }
    }
},
modifier = Modifier.fillMaxWidth()
        ) {
            Text("Criar personagem")
        }
    }
}
