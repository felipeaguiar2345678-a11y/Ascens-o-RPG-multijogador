package br.com.ascensaodosoberano.powers

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun PoderesDoPersonagemPanel(
    profile: CharacterPowerProfile,
    characterLevel: Int,
    generatingIds: Set<String>
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Text("PODERES E DESPERTARES", style = MaterialTheme.typography.titleMedium)

        profile.desires
            .filter { desire -> profile.powers.none { it.id == desire.id } }
            .forEach { desire ->
                Card(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text(desire.name, style = MaterialTheme.typography.titleSmall)
                            if (desire.id in generatingIds) CircularProgressIndicator()
                        }
                        Text(desire.description, style = MaterialTheme.typography.bodySmall)
                        Text(
                            when {
                                desire.id in generatingIds -> "A IA está moldando sua habilidade..."
                                desire.id == "despertar_inicial_classe" -> "Habilidade inicial da classe · criação automática pela IA"
                                else -> "Despertar conquistado · ${desire.progress}% de afinidade"
                            },
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.secondary
                        )
                    }
                }
            }

        if (profile.powers.isEmpty() && profile.desires.isEmpty()) {
            Text(
                "Suas experiências ainda estão moldando algo dentro de você. Treine, lute, explore e sobreviva para descobrir seu primeiro poder.",
                style = MaterialTheme.typography.bodySmall
            )
        }

        profile.powers.forEach { power ->
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
            ) {
                Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    val statusLabel = when (power.status) {
                        PowerStatus.DESIRED -> "Em formação"
                        PowerStatus.IN_DEVELOPMENT -> "Em desenvolvimento"
                        PowerStatus.AWAKENED -> "Despertado"
                        PowerStatus.EVOLVING -> "Em evolução"
                        PowerStatus.MASTERED -> "Dominado"
                    }
                    Text(power.name, style = MaterialTheme.typography.titleMedium)
                    Text("Nível do poder ${power.level} · $statusLabel", style = MaterialTheme.typography.labelSmall)
                    if (power.concept.isNotBlank()) {
                        Text("CONCEITO ORIGINAL", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.secondary)
                        Text(power.concept, style = MaterialTheme.typography.bodySmall)
                    }
                    Text(power.description, style = MaterialTheme.typography.bodyMedium)
                    if (power.manifestation.isNotBlank()) {
                        Text("MANIFESTAÇÃO ATUAL", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.secondary)
                        Text(power.manifestation, style = MaterialTheme.typography.bodySmall)
                    }
                    if (power.potential.isNotBlank()) {
                        Text("POTENCIAL", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.secondary)
                        Text(power.potential, style = MaterialTheme.typography.bodySmall)
                    }
                    Text("Custo de mana: ${power.manaCost} · Dano: ${power.baseDamage} · Duração: ${power.durationTurns} turno(s) · Recarga: ${power.cooldown} turno(s)", style = MaterialTheme.typography.bodySmall)
                    if (power.effects.isNotEmpty()) Text("Efeitos: ${power.effects.joinToString(" · ")}", style = MaterialTheme.typography.bodySmall)
                    if (power.limitations.isNotEmpty()) Text("Limitações: ${power.limitations.joinToString(" · ")}", style = MaterialTheme.typography.bodySmall)
                    if (power.awakeningNarrative.isNotBlank()) Text(power.awakeningNarrative, style = MaterialTheme.typography.bodySmall)

                    if (power.evolutionStages.isNotEmpty()) {
                        Text("CAMINHO DE EVOLUÇÃO", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.secondary)
                        power.evolutionStages.forEach { stage ->
                            val unlocked = characterLevel >= stage.requiredLevel
                            Text(
                                "${if (unlocked) "◆" else "◇"} ${stage.name} · nível ${stage.requiredLevel}",
                                style = MaterialTheme.typography.bodySmall,
                                color = if (unlocked) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Text(stage.description, style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
            }
        }
    }
}
