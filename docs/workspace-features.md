# Uitgebreide AI-USB-werkplek

Na de update: sluit de app en open `START.bat`. Modellen stoppen na **30 minuten
inactiviteit**. Een modelwissel, annuleren of afsluiten kan ze eerder stoppen.

## Modellen

- **Slimme modelkeuze** kiest met lokale trefwoordregels een geïnstalleerd model
  voor code, redeneren, gewone chat of beeld. Het RAM-advies weegt mee; de gekozen
  modelnaam staat bij het antwoord. Handmatig kiezen blijft mogelijk.
- **Hardwareadvies** toont de echte CPU, logische threads en beschikbaar RAM.
  De benodigde modelruimte is een schatting inclusief context-overhead, geen garantie.
- **Vergelijk met** laat twee geïnstalleerde modellen dezelfde vraag beantwoorden.
  Ze draaien na elkaar; antwoorden staan naast elkaar. Annuleren stopt de aanvraag.
- **Sterren** zijn redactionele indicaties, geen gemeten benchmarks. Nederlands,
  code, redeneren en snelheid hebben afzonderlijke schattingen. Snelheid gebruikt
  downloadgrootte als grove indicatie en is afhankelijk van de computer.
- **Favorieten** staan bovenaan en hebben een eigen bibliotheektab.
- De catalogus bevat extra **Qwen3 4B**, **Gemma 3 4B beeld** en **MiMo VL 7B BF16**,
  naast de eerder toegevoegde MiMo RL-varianten. MiMo VL BF16 is groot: circa
  16,6 GB download en ruim 20 GB model-RAM. Downloaden gebeurt alleen na je keuze.
  Beeldprojectors worden samen met het model gedownload en afzonderlijk gecontroleerd.
- Downloads kunnen in een **wachtrij**. Bij pauzeren/fouten stopt de wachtrij;
  hervat via de bibliotheek. De wachtrij geldt voor de huidige appsessie;
  gedeeltelijke downloads blijven op USB staan na afsluiten.

## Documenten, afbeeldingen en bronnen

Open **Gereedschap & voorkeuren** boven het invoervak.

- Voeg PDF, TXT, Markdown, CSV, JSON, logs of ondersteunde codebestanden toe.
  PDF-tekstextractie werkt lokaal. Gescande PDF’s zonder tekstlaag vereisen OCR;
  er verschijnt een melding wanneer geen tekst beschikbaar is.
- Uitgelezen tekst staat in `data/documents/`. Zoeken werkt op de toegevoegde
  documenten, met lokale trefwoordmatching en bronfragmenten. Je kunt één document
  selecteren. Alleen relevante fragmenten gaan naar het model, niet een hele grote PDF.
- Antwoorden tonen **Bronnen** met de bestandsnaam, het fragmentnummer en de gebruikte
  tekst. PDF-paginamarkeringen blijven in de opgeslagen tekst staan.
- PNG-, JPEG- en WebP-bijlagen kunnen worden besproken met een geïnstalleerd beeldmodel.
  GLM-OCR is voor tekstherkenning; Gemma/MiMo VL zijn voor bredere beeldvragen.
- **Zoek online (Wikipedia)** verstuurt de vraag naar de Nederlandstalige Wikipedia.
  De gevonden fragmenten gaan mee in de vraag; bronknoppen openen de pagina in de browser.
  Dit is een encyclopediezoekfunctie, geen algemene nieuwszoekmachine.

## Spraak en voorkeuren

- **Inspreken** gebruikt offline Windows-spraakherkenning, maximaal 15 seconden.
  De gekozen taal moet als Windows-spraakherkenner op de pc beschikbaar zijn.
  Als die ontbreekt, toont de app dat expliciet.
- **Voorlezen** gebruikt een geïnstalleerde Nederlandse Windows-stem indien beschikbaar,
  anders de standaardstem. Er is geen internetdienst voor audio nodig.
- Kies kort, uitgebreid, eenvoudig, technisch of normaal, en kies de antwoordtaal.
  Voorkeuren en favorieten worden met de gesprekken in `data/chats.json` bewaard.
  **Voorkeuren wissen** zet ze terug naar de standaardwaarden.

## Gesprekken en prestaties

- Zoek in gesprekstitels én berichttekst in de zijbalk.
- Geef een gesprek een mapnaam; School, Werk en Code zijn suggesties en eigen namen kunnen ook.
- **Opnieuw proberen** maakt een nieuw gesprek vanaf de oorspronkelijke vraag, met de
  huidige modelkeuze. Het oorspronkelijke gesprek blijft bewaard.
- **Opslag berekenen** toont de ruimte voor modellen, gesprekken, documenten, back-ups
  en het WebView-profiel. Geen bestanden worden daardoor verwijderd.
- Tijdens genereren zie je verstreken tijd, modelgeheugen en vrij RAM. Na het antwoord
  zie je tokens en gemiddelde tokens/s inclusief model laden en bronzoeken.

## Controles

- `scripts/test-desktop.ps1`: Rust-tests, waaronder 30-minutenbeleid, documentbronnen,
  hardwaregegevens en verificatie van beeldprojectors.
- `tests/workspace-ui.mjs`: browserintegratie met gecontroleerde API-antwoorden;
  gebruikt geïnstalleerde Edge. Start Node na `scripts/usb-environment.ps1`.
- `scripts/build-ui.ps1`, `scripts/build-desktop.ps1` en `scripts/deploy-desktop.ps1`:
  bouwen en publiceren op de USB, met back-up van de vorige executables.

De losse portable installer is niet opnieuw ingepakt; de actieve USB-app en webbundel
worden door deze update bijgewerkt.
