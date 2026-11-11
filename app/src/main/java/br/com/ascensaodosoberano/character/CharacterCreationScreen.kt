package br.com.ascensaodosoberano.character

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

@Composable
fun CharacterCreationScreen(
    onCharacterCreated: (CharacterProfile) -> Unit
) {
    var customMode by remember { mutableStateOf(false) }
    var characterName by remember { mutableStateOf("") }
    var selectedClassId by remember { mutableStateOf("") }
    var selectedCustomClass by remember { mutableStateOf<CharacterClass?>(null) }
    var customConcept by remember { mutableStateOf("") }
    var customName by remember { mutableStateOf("") }
    var errorMessage by remember { mutableStateOf("") }
    var appearance by remember { mutableStateOf(CharacterAppearance()) }

    val selectedClass = if (customMode) selectedCustomClass
        else CharacterSystem.getClassById(selectedClassId)
    val classDefined = selectedClass != null

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
            "Primeiro escolha ou crie uma classe. Só depois seu aventureiro será revelado.",
            color = Color(0xFFBEC9D8)
        )

        OutlinedTextField(
            value = characterName,
            onValueChange = { characterName = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text("Nome do personagem") },
            singleLine = true
        )

        Text("Sua classe define sua especialidade, não seus limites.")

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = {
                customMode = false
                selectedCustomClass = null
                errorMessage = ""
            }) { Text("Classes prontas") }

            OutlinedButton(onClick = {
                customMode = true
                selectedClassId = ""
                selectedCustomClass = null
                errorMessage = ""
            }) { Text("Criar minha classe") }
        }

        if (!customMode) {
            CharacterSystem.predefinedClasses.forEach { characterClass ->
                val selected = selectedClassId == characterClass.id
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable {
                            selectedClassId = characterClass.id
                            selectedCustomClass = null
                            errorMessage = ""
                        },
                    shape = RoundedCornerShape(14.dp),
                    border = BorderStroke(
                        if (selected) 2.dp else 1.dp,
                        if (selected) Color(0xFFE8BD72) else Color(0xFF465267)
                    ),
                    colors = CardDefaults.cardColors(
                        containerColor = if (selected) Color(0xFF3A3025) else Color(0xFF202B3B)
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
                        if (selected) Text("Classe definida", color = Color(0xFFFFD995))
                    }
                }
            }
        } else {
            OutlinedTextField(
                value = customConcept,
                onValueChange = {
                    customConcept = it
                    selectedCustomClass = null
                },
                modifier = Modifier.fillMaxWidth(),
                label = { Text("Descreva sua classe e seus poderes") },
                placeholder = { Text("Ex.: Mago do tempo que distorce o futuro...") },
                minLines = 4
            )
            OutlinedTextField(
                value = customName,
                onValueChange = {
                    customName = it
                    selectedCustomClass = null
                },
                modifier = Modifier.fillMaxWidth(),
                label = { Text("Nome da classe") },
                singleLine = true
            )
            Button(
                onClick = {
                    val proposal = CharacterCreation.createCustomProposal(customConcept)
                    if (proposal == null || customName.isBlank()) {
                        errorMessage = "Descreva sua classe e informe o nome dela."
                    } else {
                        selectedCustomClass = CharacterCreation.approveProposal(
                            proposal,
                            customName.trim()
                        )
                        errorMessage = ""
                    }
                },
                modifier = Modifier.fillMaxWidth()
            ) { Text("Definir classe e revelar personagem") }
        }

        if (classDefined) {
            Divider(color = Color(0xFF465267))
            Text(
                "SUA CLASSE: ${selectedClass!!.name}",
                style = MaterialTheme.typography.titleLarge,
                color = Color(0xFFFFD995),
                fontWeight = FontWeight.Bold
            )
            Text(
                "Veja uma demonstração animada do estilo de combate desta classe. A arte definitiva será exibida assim que estiver disponível.",
                color = Color(0xFFBEC9D8),
                style = MaterialTheme.typography.bodySmall
            )
            ClassSkillShowcase(
                className = selectedClass!!.name,
                classDescription = selectedClass!!.description
            )
            if (appearance.generatedImageUrl.isNotBlank()) {
                CharacterAppearancePreview(
                    appearance = appearance,
                    className = selectedClass!!.name,
                    showLockedPlaceholder = false
                )
            }
            Text(
                "PERSONALIZE SEU PERSONAGEM",
                style = MaterialTheme.typography.titleLarge,
                color = Color(0xFFFFD995),
                fontWeight = FontWeight.Bold
            )
            CharacterAppearanceScreen(
                appearance = appearance,
                onAppearanceChange = { appearance = it }
            )
        } else {
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = Color(0xFF202B3B))
            ) {
                Column(
                    modifier = Modifier.fillMaxWidth().padding(22.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text(
                        "AVENTUREIRO OCULTO",
                        color = Color(0xFFFFD995),
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        "Escolha uma classe ou defina sua classe personalizada para revelar e personalizar seu personagem.",
                        color = Color(0xFFBEC9D8)
                    )
                }
            }
        }

        if (errorMessage.isNotBlank()) {
            Text(errorMessage, color = MaterialTheme.colorScheme.error)
        }

        Button(
            onClick = {
                when {
                    characterName.isBlank() -> errorMessage = "Digite o nome do personagem."
                    selectedClass == null -> errorMessage = "Escolha e defina uma classe antes de criar o personagem."
                    else -> onCharacterCreated(
                        CharacterProfile(
                            name = characterName.trim(),
                            level = 1,
                            xp = 0,
                            characterClass = selectedClass,
                            appearance = appearance
                        )
                    )
                }
            },
            enabled = classDefined && characterName.isNotBlank(),
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Criar personagem")
        }
    }
}
