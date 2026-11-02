ORVYN 1 - EXPERIMENTEEL TRAININGSPAKKET

Status: CPU-proef afgerond op 30 oktober 2026; kandidaat niet geschikt voor toepassing.
24 LoRA-stappen met 4 CPU-threads zijn uitgevoerd. Training plus voor/nameting
duurde 188 seconden na het laden van het model. De omgeving voorbereiden en het
model laden duurden daarnaast langer. Het huidige appmodel is niet vervangen.
Kandidaat: models/training/orvyn1-candidate-20261030-190726
Resultaten: evaluation.json, answers.json en review.json in die map.

De aparte evaluatieloss ging van 1.530 naar 1.541 (Nederlands), 3.499 naar 2.820
(code), 2.179 naar 1.907 (web) en 3.313 naar 2.033 (Opex). Lager is hier beter.
De vier gegenereerde toetsantwoorden laten geen betrouwbare verbetering zien:
code beantwoordt een andere vraag, bronverwijzingen ontbreken en de leesactie
van Opex is ongeldig. Deze kandidaat daarom niet samenvoegen of activeren.

Doelen: Nederlandse gesprekken, code, brongebruik en de bestaande Opex-acties.
De proef hierboven gebruikte de oorspronkelijke seedset: 48 training, 16 toetsing.
Actieve nieuwe dataset: data/training/orvyn-1/v2 (112 training, 48 toetsing).
De oorspronkelijke JSONL-bestanden zijn behouden. De nieuwe set voegt gerichte
voorbeelden toe voor opdrachtvolging, bronverwijzingen en het Opex-actieformaat.
24 nieuwe Python-referentiefuncties zijn gecontroleerd op 36 invoer-uitvoergevallen.
Er is nog geen nieuw model getraind op v2.
De voorbeelden zijn eigen synthetische startvoorbeelden. Er zijn geen privechats
gebruikt. Dit kleine pakket is bedoeld voor een technische proef, niet als bewijs
dat het model op alle vier gebieden veel beter wordt. Breid de data uit met
gecontroleerde, gevarieerde voorbeelden en een onafhankelijke praktijkevaluatie.

Hardware gevonden: 32 GB RAM, Intel UHD Graphics 630, geen CUDA GPU.
Een CPU-proef is mogelijk, maar belast de pc. Deze proef gebruikte circa 5.2 GB RAM.
De bestaande systeeminstallatie heeft PyTorch 2.14 CPU en Transformers 5.17.
De nieuwe omgeving en caches blijven op de USB; systeemsoftware wordt niet aangepast.

In de app: Instellingen > Training toont kandidaten, voorbeelden en voor/na-antwoorden.
Instellingen > Opstart toont de gemeten fasen van de huidige appstart.
Voortgang van een nieuwe proef verschijnt via logs/training/progress.json.
Oude voortgangsmeldingen bewijzen niet dat een proces nog draait.

Controle zonder training (gebruikt v2; --dataset seed kiest de eerdere set):
  python tools/training/train_orvyn.py

Datacontrole en referentietests:
  python tools/training/check_data.py --dataset v2
  python tests/test_training.py

Omgeving voorbereiden (installeert ontbrekende pakketten alleen in tools):
  powershell -File scripts/setup-training.ps1

Kleine CPU-proef opnieuw uitvoeren (maakt een nieuwe aparte kandidaat):
  tools/training-venv/Scripts/python.exe tools/training/train_orvyn.py --train --device cpu --steps 24 --threads 4

Het script leest de bestaande GGUF en dequantiseert die naar float32. Dit vraagt
meer RAM dan gewoon chatten. Het traint alleen LoRA-adapters en houdt de originele
gewichten intact. Voor en na training wordt aparte evaluatieloss per domein gemeten.
Alleen loss verbeteren is onvoldoende: beoordeel ook antwoorden en toolvoorstellen.
PC-training geeft geen extra rechten, muisbediening of toegang tot nieuwe tools.

Uitvoer komt onder models/training/orvyn1-candidate-*. Het script registreert die
adapter NIET in de app. Een geslaagde kandidaat moet nog inhoudelijk worden getest,
samengevoegd/geconverteerd naar een passende GGUF en vergeleken met het huidige model.
Er wordt niets naar een cloudtrainingdienst verzonden en er worden geen kosten gemaakt.

Bronnen voor het ontwerp van de proef:
https://huggingface.co/docs/transformers/gguf
https://huggingface.co/docs/trl/peft_integration
