from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import tempfile
import os
import re

ARCHIVE = Path("Ascensao_atualizado.zip")
if not ARCHIVE.exists():
    raise SystemExit("Ascensao_atualizado.zip não encontrado")

def replace_once(text, old, new, label, count=1):
    current = text.count(old)
    if current == count:
        return text.replace(old, new), True
    if text.count(new) == count:
        return text, False
    raise SystemExit(f"{label}: esperado trecho original ou corrigido; ocorrência original={current}, corrigida={text.count(new)}")

with ZipFile(ARCHIVE, "r") as source:
    entries = [(info, source.read(info.filename)) for info in source.infolist()]

found = set()
changed = set()
output = []

for info, raw in entries:
    basename = info.filename.rsplit("/", 1)[-1]

    if basename in {"MainActivity.kt", "ExplorationSystem.kt", "CreatureApi.kt", "WorldDirector.kt", "TelaMundo.kt", "CharacterAIGenerationMapper.kt"}:
        text = raw.decode("utf-8").replace("\r\n", "\n")
        found.add(basename)

        if basename == "MainActivity.kt":
            text, did = replace_once(
                text,
                '                TopAppBarCompat("Ascensão do Soberano")',
                '''                Surface(tonalElevation = 3.dp) {
                    Text(
                        text = "Ascensão do Soberano",
                        style = MaterialTheme.typography.titleLarge,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 14.dp)
                    )
                }''',
                "MainActivity: barra superior"
            )
            if did: changed.add(basename)

            # A chamada TelaMundo recebe uma lambda como argumento; o fechamento era ")" ausente.
            old_close = re.compile(r'(?m)^([ \t]*\})\n([ \t]*\})\n([ \t]*\})\n([ \t]*\})\n[ \t]*\n([ \t]*// MULTIPLAYER)')
            new_close = re.compile(r'(?m)^([ \t]*\})\n([ \t]*\})\n([ \t]*)\)\n([ \t]*\})\n[ \t]*\n([ \t]*// MULTIPLAYER)')
            if len(list(old_close.finditer(text))) == 1:
                def close_tela(match):
                    return match.group(1) + "\n" + match.group(2) + "\n" + match.group(3) + ")" + "\n" + match.group(4) + "\n\n" + match.group(5)
                text = old_close.sub(close_tela, text, count=1)
                changed.add(basename)
            elif len(list(new_close.finditer(text))) != 1:
                pos = text.find("// MULTIPLAYER")
                raise SystemExit("MainActivity: fechamento do bloco de combate inesperado: " + repr(text[max(0, pos-130):pos+25]))

            old_enemy = '''                                    if (result.enemyId != null &&
                                        result.criatura == null
                                    ) {

                                        Button(
                                            onClick = {

                                                combateFinalizado = false

                                                combat =
                                                    CombatFactory.createCombat(
                                                        hero,
                                                        result.enemyId
                                                    )

                                                if (combat != null) {

                                                    estadoMundo =
                                                        TransicaoMundo.iniciarCombate(
                                                            estadoMundo
                                                        )

                                                    message = "Combate iniciado!"

                                                } else {
                                                    message =
                                                        "Não foi possível criar o combate."
                                                }
                                            },
                                            modifier = Modifier.fillMaxWidth()
                                        ) {
                                            Text("ENFRENTAR CRIATURA")
                                        }
                                    }'''
            new_enemy = '''                                    result.enemyId
                                        ?.takeIf { result.criatura == null }
                                        ?.let { enemyId ->
                                            Button(
                                                onClick = {
                                                    scope.launch {
                                                        try {
                                                            val criatura =
                                                                RepositorioCriaturas.buscarCriatura(enemyId)

                                                            if (criatura == null) {
                                                                message = "A criatura não está mais disponível no bestiário global."
                                                            } else {
                                                                combateFinalizado = false
                                                                combat = CombatFactory.createCombat(hero, criatura)
                                                                estadoMundo = TransicaoMundo.iniciarCombate(estadoMundo)
                                                                message = "Combate iniciado!"
                                                            }
                                                        } catch (e: Exception) {
                                                            message = "Não foi possível carregar a criatura: ${e.localizedMessage}"
                                                        }
                                                    }
                                                },
                                                modifier = Modifier.fillMaxWidth()
                                            ) {
                                                Text("ENFRENTAR CRIATURA")
                                            }
                                        }'''
            text, did = replace_once(text, old_enemy, new_enemy, "MainActivity: carregamento da criatura")
            if did: changed.add(basename)

        elif basename == "TelaMundo.kt":
            old_pattern = re.compile(r'x = \(posicaoCompanheiro\.x -\s*estado\.posicaoNoMapa\.x\) \* 64\.dp \* 13f,\s*y = \(posicaoCompanheiro\.y -\s*estado\.posicaoNoMapa\.y\) \* 64\.dp \* 21f')
            new_marker = "x = 64.dp * (posicaoCompanheiro.x - estado.posicaoNoMapa.x) * 13f,"
            if len(old_pattern.findall(text)) == 1:
                text = old_pattern.sub("x = 64.dp * (posicaoCompanheiro.x - estado.posicaoNoMapa.x) * 13f,\n                        y = 64.dp * (posicaoCompanheiro.y - estado.posicaoNoMapa.y) * 21f", text, count=1)
                changed.add(basename)
            elif text.count(new_marker) != 1:
                raise SystemExit("TelaMundo: expressão de deslocamento do companheiro inesperada")

        elif basename == "CharacterAIGenerationMapper.kt":
            if "fun fromMap(" not in text:
                if not text.endswith("\n}"):
                    raise SystemExit("CharacterAIGenerationMapper: final do arquivo inesperado")
                method = '''
          
    fun fromMap(data: Map<String, Any?>): CharacterAIGeneration {
        val status = runCatching {
            GenerationStatus.valueOf(data["status"] as? String ?: "NOT_STARTED")
        }.getOrDefault(GenerationStatus.NOT_STARTED)

        return CharacterAIGeneration(
            characterId = data["characterId"] as? String ?: "",
            generationId = data["generationId"] as? String ?: "",
            prompt = data["prompt"] as? String ?: "",
            status = status,
            imagePath = data["imagePath"] as? String ?: "",
            imageUrl = data["imageUrl"] as? String ?: "",
            visualVersion = (data["visualVersion"] as? Number)?.toInt() ?: 1,
            errorMessage = data["errorMessage"] as? String ?: ""
        )
    }
'''
                text = text[:-2] + method + "\n}"
                changed.add(basename)

        elif basename == "ExplorationSystem.kt":
            text, did = replace_once(text, "val bossChance: Int,", "val bossChance: Double,", "ExplorationSystem: tipo da chance")
            if did: changed.add(basename)
            for old, new in [
                ("            RegionRank.E,\n            45,\n            5,", "            RegionRank.E,\n            45,\n            5.0,"),
                ("            RegionRank.C,\n            60,\n            10,", "            RegionRank.C,\n            60,\n            10.0,"),
                ("            RegionRank.S,\n            75,\n            20,", "            RegionRank.S,\n            75,\n            20.0,"),
                ("            RegionRank.SSS,\n            90,\n            30,", "            RegionRank.SSS,\n            90,\n            30.0,")
            ]:
                text, did = replace_once(text, old, new, "ExplorationSystem: valor decimal")
                if did: changed.add(basename)

        elif basename == "CreatureApi.kt":
            old_count = text.count("bossChance: Int")
            if old_count == 2:
                text = text.replace("bossChance: Int", "bossChance: Double")
                changed.add(basename)
            elif old_count != 0 or text.count("bossChance: Double") != 2:
                raise SystemExit("CreatureApi: assinaturas bossChance inesperadas")

        elif basename == "WorldDirector.kt":
            text, did = replace_once(text, "import kotlin.random.Random", "import kotlin.math.roundToInt\nimport kotlin.random.Random", "WorldDirector: import")
            if did: changed.add(basename)
            text, did = replace_once(text, "val bossChance: Int = dangerLevel / 5,", "val bossChance: Double = dangerLevel / 5.0,", "WorldDirector: tipo")
            if did: changed.add(basename)
            text, did = replace_once(text, "val bossChance = context.bossChance.coerceIn(0, danger)", "val bossChance = context.bossChance.coerceIn(0.0, danger.toDouble())", "WorldDirector: limite")
            if did: changed.add(basename)
            text, did = replace_once(text, "        val bossLimit = bossChance * 100\nval encounterLimit = danger * 100", "        val encounterLimit = danger * 100\n        val bossLimit = (bossChance * 100.0).roundToInt().coerceIn(0, encounterLimit)", "WorldDirector: sorteio decimal")
            if did: changed.add(basename)

        raw = text.encode("utf-8")

    output.append((info, raw))

required = {"MainActivity.kt", "TelaMundo.kt", "CharacterAIGenerationMapper.kt", "ExplorationSystem.kt", "CreatureApi.kt", "WorldDirector.kt"}
if found != required:
    raise SystemExit(f"Arquivos esperados ausentes: {sorted(required - found)}")

worker_path = Path("cloudflare/worker.js")
worker = worker_path.read_text(encoding="utf-8")
old_worker = """        !Number.isFinite(bossChance) ||
        bossChance < 0 ||
        bossChance > 100 ||
        Math.round(bossChance * 100) !== bossChance * 100"""
new_worker = """        !Number.isFinite(bossChance) ||
        bossChance < 0 ||
        bossChance > danger ||
        Math.abs(bossChance * 100 - Math.round(bossChance * 100)) > 1e-7"""
worker, worker_changed = replace_once(worker, old_worker, new_worker, "Worker: validação decimal")

fd, temp_name = tempfile.mkstemp(suffix=".zip")
os.close(fd)
try:
    with ZipFile(temp_name, "w", ZIP_DEFLATED) as target:
        for info, raw in output:
            target.writestr(info, raw)
    Path(temp_name).replace(ARCHIVE)
finally:
    if os.path.exists(temp_name):
        os.unlink(temp_name)

if worker_changed:
    worker_path.write_text(worker, encoding="utf-8")

print("Correções verificadas e aplicadas. Arquivos Kotlin alterados:", ", ".join(sorted(changed)))
