package br.com.ascensaodosoberano.character

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import br.com.ascensaodosoberano.combat.Combatant
import br.com.ascensaodosoberano.combat.SkillDamageCalculator
import br.com.ascensaodosoberano.world.AtaqueCriatura

private val StatusOuro = Color(0xFFE8BD72)
private val StatusPainel = Color(0xFF202A3B)

@Composable
fun PainelStatusPersonagem(
    profile: CharacterProfile,
    hero: Combatant,
    gold: Long,
    xpProgress: Float,
    nextLevelXp: Int,
    onAllocateAttribute: (String) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(20.dp),
            colors = CardDefaults.cardColors(containerColor = StatusPainel),
            border = BorderStroke(1.dp, StatusOuro.copy(alpha = 0.42f))
        ) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(profile.name, color = Color(0xFFFFE5B0), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                        Text(profile.characterClass.name + " • Nível " + profile.level, color = Color(0xFFC7D0DF))
                    }
                    Column(horizontalAlignment = Alignment.End) {
                        Text("✦ $gold", color = StatusOuro, fontWeight = FontWeight.Bold)
                        Text("Rank ${hero.rank}", color = Color(0xFFC7D0DF), style = MaterialTheme.typography.labelSmall)
                    }
                }

                StatusBarra("VIDA", hero.hp, hero.maxHp, Color(0xFFE35F68))
                StatusBarra("MANA", hero.mana, hero.maxMana, Color(0xFF5B9DEB))

                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("EXPERIÊNCIA", color = StatusOuro, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.weight(1f))
                    Text("${profile.xp} / $nextLevelXp XP", color = Color.White, style = MaterialTheme.typography.labelMedium)
                }
                LinearProgressIndicator(
                    progress = { xpProgress.coerceIn(0f, 1f) },
                    modifier = Modifier.fillMaxWidth().height(8.dp),
                    color = StatusOuro,
                    trackColor = Color(0xFF414B5C)
                )
                Text(
                    "${(xpProgress * 100).toInt()}% • ${(nextLevelXp - profile.xp).coerceAtLeast(0)} XP para o próximo nível",
                    color = Color(0xFFBFC9D8),
                    style = MaterialTheme.typography.bodySmall
                )
            }
        }

        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(18.dp),
            colors = CardDefaults.cardColors(containerColor = Color(0xFF182131)),
            border = BorderStroke(1.dp, Color.White.copy(alpha = 0.09f))
        ) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("COMBATE", color = StatusOuro, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    StatusAtributo("ATAQUE", hero.attack.toString(), Modifier.weight(1f))
                    StatusAtributo("MAGIA", hero.magicPower.toString(), Modifier.weight(1f))
                    StatusAtributo("DEFESA", hero.defense.toString(), Modifier.weight(1f))
                    StatusAtributo("AGILIDADE", hero.agility.toString(), Modifier.weight(1f))
                }
            }
        }

        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(18.dp),
            colors = CardDefaults.cardColors(containerColor = Color(0xFF182131)),
            border = BorderStroke(1.dp, Color(0xFF8C78B8).copy(alpha = 0.35f))
        ) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("HABILIDADES", color = StatusOuro, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                Text(
                    "Técnicas que seu personagem já domina. O dano é uma estimativa antes da defesa do inimigo e da rolagem de combate.",
                    color = Color(0xFFBFC9D8),
                    style = MaterialTheme.typography.bodySmall
                )
                if (hero.attacks.isEmpty()) {
                    Text("Nenhuma habilidade aprendida ainda.", color = Color(0xFFD8DFEA))
                } else {
                    hero.attacks.forEachIndexed { index, habilidade ->
                        HabilidadeStatusCard(
                            habilidade,
                            hero,
                            profile.powerProfile.powers.firstOrNull { it.id == habilidade.id }?.limitations.orEmpty()
                        )
                        if (index < hero.attacks.lastIndex) {
                            HorizontalDivider(color = Color.White.copy(alpha = 0.08f))
                        }
                    }
                }
            }
        }

        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(18.dp),
            colors = CardDefaults.cardColors(containerColor = Color(0xFF182131)),
            border = BorderStroke(1.dp, Color.White.copy(alpha = 0.09f))
        ) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("ATRIBUTOS", color = StatusOuro, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.weight(1f))
                    Surface(color = Color(0xFF59452B), shape = RoundedCornerShape(20.dp)) {
                        Text(
                            "${profile.attributePoints} pontos",
                            color = Color(0xFFFFE5B0),
                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 5.dp),
                            style = MaterialTheme.typography.labelMedium
                        )
                    }
                }
                AtributoDistribuivel("Força", profile.attributes.strength, "forca", profile.attributePoints > 0, onAllocateAttribute)
                AtributoDistribuivel("Inteligência", profile.attributes.intelligence, "inteligencia", profile.attributePoints > 0, onAllocateAttribute)
                AtributoDistribuivel("Agilidade", profile.attributes.agility, "agilidade", profile.attributePoints > 0, onAllocateAttribute)
                AtributoDistribuivel("Vitalidade", profile.attributes.vitality, "vitalidade", profile.attributePoints > 0, onAllocateAttribute)
                AtributoDistribuivel("Espírito", profile.attributes.spirit, "espirito", profile.attributePoints > 0, onAllocateAttribute)
            }
        }
    }
}

@Composable
private fun StatusBarra(label: String, current: Int, maximum: Int, color: Color) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(label, color = Color(0xFFD8DFEA), style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold)
            Spacer(Modifier.weight(1f))
            Text("$current / $maximum", color = Color.White, style = MaterialTheme.typography.labelMedium)
        }
        LinearProgressIndicator(
            progress = { if (maximum > 0) (current.toFloat() / maximum).coerceIn(0f, 1f) else 0f },
            modifier = Modifier.fillMaxWidth().height(9.dp),
            color = color,
            trackColor = Color(0xFF414B5C)
        )
    }
}

@Composable
private fun StatusAtributo(label: String, value: String, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.background(Color(0xFF293548), RoundedCornerShape(10.dp)).padding(vertical = 9.dp, horizontal = 5.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(value, color = Color.White, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
        Text(label, color = Color(0xFFBAC5D5), style = MaterialTheme.typography.labelSmall)
    }
}

@Composable
private fun AtributoDistribuivel(
    label: String,
    value: Int,
    key: String,
    enabled: Boolean,
    onAllocate: (String) -> Unit
) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(label, color = Color(0xFFE1E7F0), modifier = Modifier.weight(1f))
        Text(value.toString(), color = Color.White, fontWeight = FontWeight.Bold, modifier = Modifier.padding(horizontal = 12.dp))
        FilledTonalButton(
            onClick = { onAllocate(key) },
            enabled = enabled,
            contentPadding = PaddingValues(horizontal = 12.dp, vertical = 4.dp)
        ) { Text("+1") }
    }
}

@Composable
private fun HabilidadeStatusCard(
    habilidade: AtaqueCriatura,
    hero: Combatant,
    limitations: List<String>
) {
    val tipo = when (habilidade.tipoDano.uppercase()) {
        "FISICO", "FÍSICO" -> "Física"
        "MAGICO", "MÁGICO" -> "Mágica"
        else -> "Especial"
    }
    val danoEstimado = SkillDamageCalculator.estimatedDamage(hero, habilidade)
    Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                habilidade.nome,
                color = Color(0xFFFFE5B0),
                fontWeight = FontWeight.Bold,
                modifier = Modifier.weight(1f)
            )
            Surface(
                color = if (tipo == "Mágica") Color(0xFF3B3158) else Color(0xFF49352B),
                shape = RoundedCornerShape(20.dp)
            ) {
                Text(
                    tipo,
                    color = Color(0xFFF1E8FF),
                    modifier = Modifier.padding(horizontal = 9.dp, vertical = 4.dp),
                    style = MaterialTheme.typography.labelSmall
                )
            }
        }
        Text(
            habilidade.descricao.ifBlank { "Habilidade de combate sem descrição cadastrada." },
            color = Color(0xFFC7D0DF),
            style = MaterialTheme.typography.bodySmall
        )
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            DetalheHabilidade("DANO", danoEstimado.toString())
            DetalheHabilidade("CUSTO", if (habilidade.custoMana > 0) "${habilidade.custoMana} Mana" else "Grátis")
            DetalheHabilidade("RECARGA", if (habilidade.turnosRecarga > 0) "${habilidade.turnosRecarga} turno(s)" else "Sem recarga")
        }
        if (habilidade.efeitos.isNotEmpty()) {
            Text(
                "Efeitos: ${habilidade.efeitos.joinToString(", ")}",
                color = Color(0xFFB7A5DC),
                style = MaterialTheme.typography.labelSmall
            )
        }
        if (limitations.isNotEmpty()) {
            Text(
                "Limitações: " + limitations.joinToString("; "),
                color = Color(0xFFFFC78D),
                style = MaterialTheme.typography.bodySmall
            )
        }

        if (habilidade.turnosCarregamento > 0) {
            Text(
                "Carregamento: ${habilidade.turnosCarregamento} turno(s)",
                color = Color(0xFFE8BD72),
                style = MaterialTheme.typography.labelSmall
            )
        }
    }
}

@Composable
private fun RowScope.DetalheHabilidade(label: String, value: String) {
    Column(
        modifier = Modifier.weight(1f)
            .background(Color(0xFF293548), RoundedCornerShape(9.dp))
            .padding(horizontal = 7.dp, vertical = 7.dp)
    ) {
        Text(label, color = Color(0xFF9EABC0), style = MaterialTheme.typography.labelSmall)
        Text(value, color = Color.White, fontWeight = FontWeight.SemiBold, style = MaterialTheme.typography.bodySmall)
    }
}
