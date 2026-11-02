# Orvyn 1

Orvyn 1 is een lokaal chatprofiel op de bestaande Llama 3.2 1B Instruct
Q4_K_M-gewichten (807.694.464 bytes). Het is geen nieuw getraind model.
Het deelt het bestaande GGUF-bestand; er is geen extra modelkopie gedownload.

Eigen instructies: kort, direct en standaard Nederlands.
Generatie: maximaal 512 antwoordtokens, temperatuur 0,3, top_p 0,9.
Een lager aangevraagd tokenmaximum blijft behouden.
Langere codebestanden en complexe redeneertaken passen beter bij een groter model.
De werkelijke snelheid hangt af van de pc en het laden vanaf de USB.

Kies na herstart Orvyn 1 in de modelkeuze of de AI-bibliotheek.
Configuratie: config/custom-models.json.
Basismodel, herkomst en controlehash blijven in die configuratie vermeld.

## Websites en snelheid

Plak bij Orvyn 1 een openbare HTTPS-link in je vraag, bijvoorbeeld:
"Vat https://example.com samen". De app leest maximaal twee links, geeft
tekstfragmenten aan het model en toont de bronnen. Het is geen interactieve
browser: inloggen, JavaScript-apps, PDF en IPv6-only sites worden niet ondersteund.
De website ontvangt de URL-aanvraag, niet je volledige chat. Een pagina blijft
vijf minuten in het werkgeheugen gecachet. Privé- en lokale IP-adressen zijn geblokkeerd.

Orvyn 1 gebruikt nu één servergespreksplek in plaats van vier, duidelijke basisinstructies en maximaal 512 antwoordtokens. Een geladen, bereikbaar model
slaat de herhaalde start- en curl-gezondheidscontrole over.
De eerste start blijft afhankelijk van USB- en Windows-bestandscaches.

Live-test 30 oktober 2026: eerste reactie inclusief laden 45,49 s; korte vervolgvraag 0,195 s. Dit zijn metingen op deze pc, geen gegarandeerde tijden. Website lezen, cache en blokkade van een lokaal adres zijn getest.
