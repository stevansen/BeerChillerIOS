#!/usr/bin/env python3
"""Writes the App Store Connect metadata files and checks Apple's length limits.

Layout follows fastlane deliver, so the directory can be uploaded as-is:
    AppStore/metadata/<locale>/<field>.txt

Locales are App Store Connect's codes, not the app's language codes: Italian is
"it", not "it-IT".
"""
from pathlib import Path

# Derived from this file's location, so the script works in any clone.
ROOT = Path(__file__).resolve().parent.parent / "AppStore/metadata"

# field -> Apple's maximum length (None = no documented limit worth enforcing)
LIMITS = {
    "name": 30,
    "subtitle": 30,
    "promotional_text": 170,
    "keywords": 100,
    "description": 4000,
    "release_notes": 4000,
}

# App language code -> App Store Connect locale
LOCALES = {
    "en": "en-US",
    "de": "de-DE",
    "es": "es-ES",
    "fr": "fr-FR",
    "it": "it",
    "nl": "nl-NL",
    "pt": "pt-PT",
}

NAME = "BeerCHILLER"

SUBTITLE = {
    "en": "Cold beer, timed precisely",
    "de": "Bier kühlen, exakt getimt",
    "es": "Enfría tu cerveza a tiempo",
    "fr": "Bière fraîche, minutée",
    "it": "Birra fredda, al minuto",
    "nl": "Bier koelen, precies getimed",
    "pt": "Cerveja fresca, no tempo",
}

PROMO = {
    "en": "How long does your beer need in the freezer? BeerCHILLER works it out "
          "from a calibrated cooling model, times it, and tells you the moment "
          "it is cold.",
    "de": "Wie lange braucht das Bier im Gefrierschrank? BeerCHILLER berechnet "
          "es mit einem kalibrierten Kühlmodell, stellt den Timer und meldet "
          "sich, sobald es kalt ist.",
    "es": "¿Cuánto necesita tu cerveza en el congelador? BeerCHILLER lo calcula "
          "con un modelo de enfriamiento calibrado, pone el temporizador y te "
          "avisa en cuanto está fría.",
    "fr": "Combien de temps votre bière doit-elle rester au congélateur ? "
          "BeerCHILLER le calcule avec un modèle calibré, lance le minuteur "
          "et vous prévient dès qu’elle est fraîche.",
    "it": "Quanto tempo serve alla birra nel congelatore? BeerCHILLER lo calcola "
          "con un modello di raffreddamento calibrato, avvia il timer e ti "
          "avvisa appena è fredda.",
    "nl": "Hoe lang moet je bier in de vriezer? BeerCHILLER berekent het met een "
          "gekalibreerd koelmodel, zet de timer en laat het weten zodra het "
          "koud is.",
    "pt": "Quanto tempo precisa a tua cerveja no congelador? O BeerCHILLER "
          "calcula-o com um modelo de arrefecimento calibrado, inicia o "
          "temporizador e avisa quando estiver fresca.",
}

# Keywords: comma-separated, no space after the comma — the space counts against
# the 100-character budget. The app name is already indexed, so it is not
# repeated here.
KEYWORDS = {
    "en": "beer,chill,cooling,fridge,freezer,timer,temperature,cold,drinks,brew",
    "de": "bier,kühlen,kühlschrank,gefrierschrank,timer,temperatur,kalt,getränke",
    "es": "cerveza,enfriar,nevera,congelador,temporizador,temperatura,frío,bebida",
    "fr": "bière,refroidir,frigo,congélateur,minuteur,température,froid,boisson",
    "it": "birra,raffreddare,frigo,congelatore,timer,temperatura,freddo,bevande",
    "nl": "bier,koelen,koelkast,vriezer,timer,temperatuur,koud,drank,brouwsel",
    "pt": "cerveja,arrefecer,frigorífico,congelador,temporizador,temperatura,frio",
}

DESCRIPTION = {
    "en": """BeerCHILLER tells you how long your beer needs in the fridge or the freezer — and alerts you the moment it is cold.

Pick the container, the volume, how it sits and the temperatures. BeerCHILLER estimates the cooling time from a calibrated thermodynamic model, starts a timer, and notifies you when your target temperature is reached. No sign-up, no account, no network.

HOW IT WORKS

The estimate comes from the BeerChiller Calibrated V2.1 model. Beer and container are treated as one body and the appliance air as a reservoir at constant temperature, so cooling slows realistically as the beer approaches it — the last two degrees take far longer than the first two. Bottle and can, 0.33 / 0.5 / 1.0 litre, standing or lying, fridge or freezer: each combination has its own calibration, and a cold-start correction applies to bottles going into the freezer.

The complete model, with every formula and every constant, is documented inside the app. Nothing is hidden behind a black box.

WHILE IT RUNS

• A dial counts down and shows the estimated current beer temperature
• Home Screen and Lock Screen widgets in four sizes
• A Live Activity in the Dynamic Island
• An Apple Watch app that can start and stop a run on its own, plus watch face complications
• A notification when the beer is ready, even with the app closed
• The run survives closing the app or restarting your iPhone

MADE FOR iOS

• Light and dark mode, selectable independently of the system setting
• Two looks: a clean Classic style, and a Beer style with original artwork
• Dynamic Type up to the largest accessibility sizes
• VoiceOver labels throughout — including the formulas, which are read as words rather than spelled out symbol by symbol
• iPhone and iPad, portrait and landscape

PRIVACY

BeerCHILLER collects nothing and contains no network code at all. Your settings and the running timer stay on your device, shared only with the app's own widget and watch app so they can show your countdown.

A NOTE ON ACCURACY

The times are estimates. A real fridge or freezer cools faster or slower depending on airflow, how full it is, contact with the shelf, and how often the door opens. Treat the countdown as a good guide, not a measurement.

BeerCHILLER is built on an original concept and design by C. Auer. Enjoy responsibly.""",

    "de": """BeerCHILLER sagt dir, wie lange dein Bier im Kühlschrank oder Gefrierschrank braucht — und meldet sich, sobald es kalt ist.

Gebinde, Volumen, Lage und Temperaturen wählen: BeerCHILLER berechnet die Kühlzeit mit einem kalibrierten thermodynamischen Modell, startet den Timer und benachrichtigt dich, wenn die Zieltemperatur erreicht ist. Keine Anmeldung, kein Konto, kein Netzwerk.

WIE ES RECHNET

Die Schätzung stammt vom Modell BeerChiller Calibrated V2.1. Bier und Gebinde werden als ein Körper behandelt, die Geräteluft als Reservoir mit konstanter Temperatur. Dadurch verlangsamt sich die Kühlung realistisch, je näher das Bier der Gerätetemperatur kommt — die letzten zwei Grad dauern deutlich länger als die ersten zwei. Flasche und Dose, 0,33 / 0,5 / 1,0 Liter, stehend oder liegend, Kühl- oder Gefrierschrank: jede Kombination hat ihre eigene Kalibrierung, und für Flaschen im Gefrierschrank kommt eine Kaltstart-Korrektur hinzu.

Das vollständige Modell mit allen Formeln und Konstanten ist in der App dokumentiert. Nichts versteckt sich in einer Blackbox.

WÄHREND DER KÜHLZEIT

• Eine Skala zählt herunter und zeigt die geschätzte aktuelle Biertemperatur
• Widgets für Home- und Sperrbildschirm in vier Größen
• Eine Live-Aktivität in der Dynamic Island
• Eine Apple-Watch-App, die eigenständig starten und stoppen kann, samt Komplikationen für das Zifferblatt
• Eine Mitteilung, wenn das Bier fertig ist — auch bei geschlossener App
• Der Timer übersteht das Schließen der App und einen Neustart des iPhones

FÜR iOS GEMACHT

• Hell und dunkel, unabhängig von der Systemeinstellung wählbar
• Zwei Optiken: eine klare Klassik-Variante und eine Bier-Variante mit eigener Grafik
• Dynamische Schrift bis zu den größten Bedienungshilfen-Größen
• Durchgehend VoiceOver-Beschriftungen — auch für die Formeln, die als Worte gelesen werden statt Zeichen für Zeichen
• iPhone und iPad, Hoch- und Querformat

DATENSCHUTZ

BeerCHILLER erhebt keine Daten und enthält überhaupt keinen Netzwerkcode. Einstellungen und laufender Timer bleiben auf dem Gerät und werden nur mit dem eigenen Widget und der eigenen Watch-App geteilt, damit diese den Countdown anzeigen können.

ZUR GENAUIGKEIT

Die Zeiten sind Schätzungen. Ein echter Kühl- oder Gefrierschrank kühlt schneller oder langsamer — je nach Luftstrom, Beladung, Kontakt zum Einlegeboden und wie oft die Tür aufgeht. Nimm den Countdown als guten Richtwert, nicht als Messung.

BeerCHILLER beruht auf einem Konzept und Design von C. Auer. Genieße verantwortungsvoll.""",

    "es": """BeerCHILLER te dice cuánto tiempo necesita tu cerveza en la nevera o el congelador, y te avisa en cuanto está fría.

Elige el envase, el volumen, la posición y las temperaturas. BeerCHILLER calcula el tiempo de enfriamiento con un modelo termodinámico calibrado, pone en marcha el temporizador y te notifica al alcanzar la temperatura objetivo. Sin registro, sin cuenta, sin red.

CÓMO FUNCIONA

La estimación proviene del modelo BeerChiller Calibrated V2.1. La cerveza y el envase se tratan como un solo cuerpo, y el aire del aparato como un depósito a temperatura constante, de modo que el enfriamiento se ralentiza de forma realista al acercarse: los dos últimos grados tardan mucho más que los dos primeros. Botella y lata, 0,33 / 0,5 / 1,0 litros, de pie o tumbada, nevera o congelador: cada combinación tiene su propia calibración, y las botellas que entran en el congelador reciben una corrección de arranque en frío.

El modelo completo, con todas las fórmulas y constantes, está documentado dentro de la app. Nada queda oculto en una caja negra.

MIENTRAS FUNCIONA

• Un dial cuenta atrás y muestra la temperatura estimada de la cerveza
• Widgets para la pantalla de inicio y la pantalla bloqueada, en cuatro tamaños
• Una actividad en directo en la Dynamic Island
• Una app para Apple Watch capaz de iniciar y detener por sí sola, con complicaciones para la esfera
• Una notificación cuando la cerveza está lista, incluso con la app cerrada
• El temporizador sobrevive al cierre de la app y al reinicio del iPhone

HECHA PARA iOS

• Modo claro y oscuro, elegible con independencia del ajuste del sistema
• Dos aspectos: un estilo Clásico sobrio y un estilo Cerveza con ilustración propia
• Texto dinámico hasta los tamaños de accesibilidad más grandes
• Etiquetas de VoiceOver en toda la app, también en las fórmulas, que se leen como palabras y no símbolo a símbolo
• iPhone y iPad, vertical y horizontal

PRIVACIDAD

BeerCHILLER no recopila nada y no contiene ningún código de red. Tus ajustes y el temporizador en curso se quedan en tu dispositivo y solo se comparten con el widget y la app de reloj propios, para que puedan mostrar la cuenta atrás.

SOBRE LA PRECISIÓN

Los tiempos son estimaciones. Una nevera o un congelador reales enfrían más rápido o más despacio según la circulación del aire, la carga, el contacto con la bandeja y la frecuencia con que se abre la puerta. Toma la cuenta atrás como una buena guía, no como una medición.

BeerCHILLER se basa en un concepto y un diseño originales de C. Auer. Consume con responsabilidad.""",

    "fr": """BeerCHILLER vous dit combien de temps votre bière doit rester au réfrigérateur ou au congélateur, et vous prévient dès qu’elle est fraîche.

Choisissez le récipient, le volume, la position et les températures. BeerCHILLER estime le temps de refroidissement à partir d’un modèle thermodynamique calibré, lance le minuteur et vous notifie lorsque la température cible est atteinte. Sans inscription, sans compte, sans réseau.

COMMENT ÇA MARCHE

L’estimation vient du modèle BeerChiller Calibrated V2.1. La bière et son récipient sont traités comme un seul corps, et l’air de l’appareil comme un réservoir à température constante : le refroidissement ralentit donc de façon réaliste à l’approche de la cible — les deux derniers degrés prennent bien plus longtemps que les deux premiers. Bouteille et canette, 0,33 / 0,5 / 1,0 litre, debout ou couchée, réfrigérateur ou congélateur : chaque combinaison a son propre calibrage, et une correction de démarrage à froid s’applique aux bouteilles mises au congélateur.

Le modèle complet, avec toutes ses formules et constantes, est documenté dans l’app. Rien n’est caché dans une boîte noire.

PENDANT LE REFROIDISSEMENT

• Un cadran décompte et affiche la température estimée de la bière
• Des widgets pour l’écran d’accueil et l’écran verrouillé, en quatre tailles
• Une activité en direct dans la Dynamic Island
• Une app Apple Watch capable de démarrer et d’arrêter seule, avec des complications pour le cadran
• Une notification quand la bière est prête, même app fermée
• Le minuteur survit à la fermeture de l’app et au redémarrage de l’iPhone

CONÇUE POUR iOS

• Mode clair et sombre, au choix, indépendamment du réglage système
• Deux apparences : un style Classique sobre et un style Bière avec une illustration originale
• Texte dynamique jusqu’aux plus grandes tailles d’accessibilité
• Étiquettes VoiceOver partout, y compris pour les formules, lues comme des mots plutôt qu’épelées symbole par symbole
• iPhone et iPad, portrait et paysage

CONFIDENTIALITÉ

BeerCHILLER ne collecte rien et ne contient aucun code réseau. Vos réglages et le minuteur en cours restent sur votre appareil, partagés uniquement avec le widget et l’app de montre de BeerCHILLER pour qu’ils puissent afficher le décompte.

À PROPOS DE LA PRÉCISION

Les durées sont des estimations. Un réfrigérateur ou un congélateur réel refroidit plus vite ou plus lentement selon la circulation de l’air, le remplissage, le contact avec la clayette et la fréquence d’ouverture de la porte. Prenez le décompte comme un bon repère, pas comme une mesure.

BeerCHILLER repose sur un concept et un design originaux de C. Auer. À consommer avec modération.""",

    "it": """BeerCHILLER ti dice quanto tempo serve alla tua birra in frigo o in congelatore, e ti avvisa appena è fredda.

Scegli il contenitore, il volume, la posizione e le temperature. BeerCHILLER stima il tempo di raffreddamento con un modello termodinamico calibrato, avvia il timer e ti notifica al raggiungimento della temperatura desiderata. Senza registrazione, senza account, senza rete.

COME FUNZIONA

La stima deriva dal modello BeerChiller Calibrated V2.1. Birra e contenitore sono trattati come un unico corpo e l’aria dell’apparecchio come un serbatoio a temperatura costante: il raffreddamento rallenta quindi in modo realistico man mano che la birra si avvicina — gli ultimi due gradi richiedono molto più tempo dei primi due. Bottiglia e lattina, 0,33 / 0,5 / 1,0 litri, in piedi o coricata, frigo o congelatore: ogni combinazione ha la propria calibrazione, e per le bottiglie messe in congelatore si applica una correzione di avvio a freddo.

Il modello completo, con tutte le formule e le costanti, è documentato dentro l’app. Nulla resta nascosto in una scatola nera.

MENTRE IL TIMER SCORRE

• Un quadrante conta alla rovescia e mostra la temperatura stimata della birra
• Widget per schermata Home e schermata di blocco, in quattro dimensioni
• Un’attività in tempo reale nella Dynamic Island
• Un’app per Apple Watch che può avviare e fermare da sola, con complicazioni per il quadrante
• Una notifica quando la birra è pronta, anche con l’app chiusa
• Il timer sopravvive alla chiusura dell’app e al riavvio dell’iPhone

FATTA PER iOS

• Chiaro e scuro, selezionabili indipendentemente dall’impostazione di sistema
• Due aspetti: uno stile Classico essenziale e uno stile Birra con grafica originale
• Testo dinamico fino alle dimensioni di accessibilità più grandi
• Etichette VoiceOver in tutta l’app, anche per le formule, lette come parole invece che simbolo per simbolo
• iPhone e iPad, verticale e orizzontale

PRIVACY

BeerCHILLER non raccoglie nulla e non contiene alcun codice di rete. Le impostazioni e il timer in corso restano sul dispositivo, condivisi solo con il widget e l’app per l’orologio di BeerCHILLER perché possano mostrare il conto alla rovescia.

SULLA PRECISIONE

I tempi sono stime. Un frigorifero o un congelatore reale raffredda più o meno rapidamente in base al flusso d’aria, al carico, al contatto con il ripiano e a quante volte si apre la porta. Considera il conto alla rovescia una buona indicazione, non una misura.

BeerCHILLER si basa su un’idea e un design originali di C. Auer. Bevi responsabilmente.""",

    "nl": """BeerCHILLER vertelt je hoe lang je bier in de koelkast of de vriezer moet, en laat het weten zodra het koud is.

Kies de verpakking, het volume, de positie en de temperaturen. BeerCHILLER berekent de koeltijd met een gekalibreerd thermodynamisch model, start de timer en stuurt een melding wanneer de doeltemperatuur is bereikt. Geen registratie, geen account, geen netwerk.

HOE HET REKENT

De schatting komt van het model BeerChiller Calibrated V2.1. Bier en verpakking worden als één lichaam behandeld en de lucht in het apparaat als een reservoir met constante temperatuur, waardoor het koelen realistisch vertraagt naarmate het bier dichterbij komt: de laatste twee graden duren veel langer dan de eerste twee. Fles en blikje, 0,33 / 0,5 / 1,0 liter, staand of liggend, koelkast of vriezer: elke combinatie heeft zijn eigen kalibratie, en voor flessen in de vriezer geldt een koudestartcorrectie.

Het volledige model, met alle formules en constanten, staat gedocumenteerd in de app. Niets verdwijnt in een zwarte doos.

TIJDENS HET KOELEN

• Een schijf telt af en toont de geschatte biertemperatuur
• Widgets voor beginscherm en toegangsscherm, in vier maten
• Een live activiteit in de Dynamic Island
• Een Apple Watch-app die zelfstandig kan starten en stoppen, met complicaties voor de wijzerplaat
• Een melding wanneer het bier klaar is, ook met de app gesloten
• De timer overleeft het sluiten van de app en het herstarten van je iPhone

GEMAAKT VOOR iOS

• Lichte en donkere modus, los van de systeeminstelling te kiezen
• Twee uiterlijken: een rustige Klassieke stijl en een Bier-stijl met eigen illustratie
• Dynamische tekst tot en met de grootste toegankelijkheidsformaten
• VoiceOver-labels in de hele app, ook bij de formules, die als woorden worden voorgelezen in plaats van teken voor teken

• iPhone en iPad, staand en liggend

PRIVACY

BeerCHILLER verzamelt niets en bevat helemaal geen netwerkcode. Je instellingen en de lopende timer blijven op je toestel en worden alleen gedeeld met de eigen widget en watch-app, zodat die het aftellen kunnen tonen.

OVER DE NAUWKEURIGHEID

De tijden zijn schattingen. Een echte koelkast of vriezer koelt sneller of langzamer, afhankelijk van luchtstroming, belading, contact met de plaat en hoe vaak de deur opengaat. Zie het aftellen als een goede richtlijn, niet als een meting.

BeerCHILLER is gebaseerd op een oorspronkelijk concept en ontwerp van C. Auer. Geniet met mate.""",

    "pt": """O BeerCHILLER diz-te quanto tempo a tua cerveja precisa no frigorífico ou no congelador, e avisa assim que estiver fresca.

Escolhe o recipiente, o volume, a posição e as temperaturas. O BeerCHILLER estima o tempo de arrefecimento com um modelo termodinâmico calibrado, inicia o temporizador e notifica-te quando a temperatura pretendida for atingida. Sem registo, sem conta, sem rede.

COMO FUNCIONA

A estimativa vem do modelo BeerChiller Calibrated V2.1. A cerveja e o recipiente são tratados como um só corpo, e o ar do aparelho como um reservatório a temperatura constante, pelo que o arrefecimento abranda de forma realista à medida que se aproxima: os dois últimos graus demoram muito mais do que os dois primeiros. Garrafa e lata, 0,33 / 0,5 / 1,0 litros, em pé ou deitada, frigorífico ou congelador: cada combinação tem a sua própria calibração, e às garrafas colocadas no congelador aplica-se uma correção de arranque a frio.

O modelo completo, com todas as fórmulas e constantes, está documentado dentro da app. Nada fica escondido numa caixa negra.

ENQUANTO CORRE

• Um mostrador faz a contagem decrescente e indica a temperatura estimada da cerveja
• Widgets para o ecrã principal e o ecrã bloqueado, em quatro tamanhos
• Uma atividade em direto na Dynamic Island
• Uma app para Apple Watch capaz de iniciar e parar por si só, com complicações para o mostrador
• Uma notificação quando a cerveja está pronta, mesmo com a app fechada
• O temporizador sobrevive ao fecho da app e ao reinício do iPhone

FEITA PARA iOS

• Modo claro e escuro, à escolha, independentemente da definição do sistema
• Dois aspetos: um estilo Clássico sóbrio e um estilo Cerveja com ilustração original
• Texto dinâmico até aos maiores tamanhos de acessibilidade
• Etiquetas VoiceOver em toda a app, incluindo nas fórmulas, lidas como palavras em vez de símbolo a símbolo
• iPhone e iPad, vertical e horizontal

PRIVACIDADE

O BeerCHILLER não recolhe nada e não contém qualquer código de rede. As tuas definições e o temporizador em curso ficam no teu dispositivo, partilhados apenas com o widget e a app de relógio do próprio BeerCHILLER, para que possam mostrar a contagem.

SOBRE A PRECISÃO

Os tempos são estimativas. Um frigorífico ou congelador real arrefece mais depressa ou mais devagar, dependendo da circulação de ar, da carga, do contacto com a prateleira e da frequência com que a porta é aberta. Toma a contagem como uma boa referência, não como uma medição.

O BeerCHILLER baseia-se num conceito e design originais de C. Auer. Bebe com responsabilidade.""",
}

RELEASE_NOTES = {
    "en": "First release of BeerCHILLER for iPhone, iPad and Apple Watch.",
    "de": "Erste Version von BeerCHILLER für iPhone, iPad und Apple Watch.",
    "es": "Primera versión de BeerCHILLER para iPhone, iPad y Apple Watch.",
    "fr": "Première version de BeerCHILLER pour iPhone, iPad et Apple Watch.",
    "it": "Prima versione di BeerCHILLER per iPhone, iPad e Apple Watch.",
    "nl": "Eerste versie van BeerCHILLER voor iPhone, iPad en Apple Watch.",
    "pt": "Primeira versão do BeerCHILLER para iPhone, iPad e Apple Watch.",
}

SUPPORT_URL = "https://github.com/stevansen/BeerChillerIOS"
MARKETING_URL = "https://github.com/stevansen/BeerChillerIOS"
PRIVACY_URL = "https://github.com/stevansen/BeerChillerIOS/blob/main/PRIVACY.md"


def main():
    failures = []
    written = 0

    for lang, locale in LOCALES.items():
        directory = ROOT / locale
        directory.mkdir(parents=True, exist_ok=True)

        fields = {
            "name": NAME,
            "subtitle": SUBTITLE[lang],
            "promotional_text": PROMO[lang],
            "keywords": KEYWORDS[lang],
            "description": DESCRIPTION[lang],
            "release_notes": RELEASE_NOTES[lang],
            "support_url": SUPPORT_URL,
            "marketing_url": MARKETING_URL,
            "privacy_url": PRIVACY_URL,
        }

        for field, value in fields.items():
            value = value.strip()
            limit = LIMITS.get(field)
            if limit and len(value) > limit:
                failures.append(f"{locale}/{field}: {len(value)} > {limit}")
            (directory / f"{field}.txt").write_text(value + "\n", encoding="utf-8")
            written += 1

        print(f"{locale:6s} subtitle {len(SUBTITLE[lang]):2d}/30  "
              f"promo {len(PROMO[lang]):3d}/170  "
              f"keywords {len(KEYWORDS[lang]):3d}/100  "
              f"description {len(DESCRIPTION[lang]):4d}/4000")

    print(f"\n{written} files written to {ROOT}")
    if failures:
        print("\nLIMIT VIOLATIONS:")
        for f in failures:
            print("  " + f)
        raise SystemExit(1)
    print("all fields within Apple's limits")


if __name__ == "__main__":
    main()
