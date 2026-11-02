# AI USB: uitsluitend op de USB werken

- Deze USB-hoofdmap is de enige actieve projectlocatie. Leid de hoofdmap af van
  het script/executablepad; vertrouw niet op een vaste stationsletter.
- Maak geen nieuwe projectinstallatie onder C:\ai-usb, AppData of Program Files.
- UI-broncode: apps/web-ui. Rust-broncode: apps/manager. Distributie: dist.
- Gesprekken: data. Modellen: models. Configuratie: config. Back-ups: backups.
  Logs: logs. Houd ook het WebView-profiel onder data/webview-profile.
- Gebruik scripts/usb-environment.ps1 bij builds en dependency-installaties;
  tijdelijke bestanden en nieuwe toolcaches horen op de USB.
- Schrijf tijdelijke tests onder tests of tools/temp, niet in de Windows-tempmap.
- Bestaande systeemsoftware/compilers mogen vanaf de computer worden aangeroepen.
  Verplaats geen gedeelde Windows- of ontwikkeltools van andere projecten.
- Historische bestanden onder archive zijn geen actieve startpunten.
- Bewaar gesprekken en modellen. Verwijder geen modelbestanden op basis van een
  verzoek om UI-elementen of een modelselector te verwijderen.
- Gebruik de bestaande React/CSS-interface in het Rust-WebView-hoofdvenster.
  Wijzig geen gegenereerde React/Next-bestanden onder node_modules.
