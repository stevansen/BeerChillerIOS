#!/usr/bin/env python3
"""Store copy staged for the next version. Nothing here is published.

The live copy is in make_appstore_metadata.py. This file holds the revision that
goes out with the next release, for one reason above all: the published
descriptions never mention the alarm. It arrived in build 2, it is the most
distinctive thing the app does, and the store text still says the app "notifies"
you. On a released version the description cannot be edited at all — only the
promotional text can — so it waits here until there is a version to attach it to.

Generate with:

    python3 tools/make_appstore_metadata.py --next

which writes AppStore/metadata-next/ and enforces the same length limits.

On the alarm claim: precision, not enthusiasm. The in-app sound really is audible
with the ring/silent switch set to silent, because it uses the .playback audio
session category. The system alarm really does keep ringing through Focus, but
only on iOS 26.1 and later. A background notification on an older release is
silenced like any other. Each language says exactly that and no more — a blanket
"rings even when silenced" would be false for part of the audience.
"""

# No PROMO here on purpose. The promotional text is staying as published —
# it is the one field that can be changed on a live release, so it has
# already been revised and does not travel with this batch. The generator
# falls back to the live copy for anything this module does not define.
SUBTITLE = {
    "en": "Cold beer, timed to the minute",
    "de": "Bier kühlen, exakt getimt",
    "es": "Cerveza fría, al minuto",
    "fr": "Bière fraîche, à la minute",
    "it": "Birra fredda, al minuto",
    "nl": "Bier koelen, tot op de minuut",
    "pt": "Cerveja fresca, ao minuto",
}


# Comma-separated, no space after the comma — the space counts. "alarm" and
# "wecker" are new: the app now competes for that search too.
KEYWORDS = {
    "en": "beer,chill,cooling,fridge,freezer,timer,alarm,temperature,cold,drinks",
    "de": "bier,kühlen,kühlschrank,gefrierschrank,timer,wecker,temperatur,kalt",
    "es": "cerveza,enfriar,nevera,congelador,temporizador,alarma,temperatura,frío",
    "fr": "bière,refroidir,frigo,congélateur,minuteur,alarme,température,froid",
    "it": "birra,raffreddare,frigo,congelatore,timer,sveglia,temperatura,freddo",
    "nl": "bier,koelen,koelkast,vriezer,timer,wekker,temperatuur,koud,drank",
    "pt": "cerveja,arrefecer,frigorífico,congelador,temporizador,alarme,frio",
}

DESCRIPTION = {
    "en": """BeerCHILLER tells you how long your beer needs in the fridge or the freezer, counts it down, and raises an alarm the moment it is cold.

Pick the container, the volume, how it sits and the temperatures. BeerCHILLER estimates the cooling time from a calibrated thermodynamic model and starts a timer. No sign-up, no account, no network.

AN ALARM, NOT JUST A NOTIFICATION

With the app open, the alarm sounds through the ring/silent switch — the way an alarm should. On iOS 26.1 and later it also schedules a system alarm that rings through Focus and keeps ringing until you stop it. On earlier versions a notification arrives when the app is in the background. Close the app, lock the phone, walk into another room: you still find out.

HOW IT WORKS

The estimate comes from the BeerChiller Calibrated V2.1 model. Beer and container are treated as one body and the appliance air as a reservoir at constant temperature, so cooling slows realistically as the beer approaches it — the last two degrees take far longer than the first two. Bottle and can, 0.33 / 0.5 / 1.0 litre, standing or lying, fridge or freezer: each combination has its own calibration, and a cold-start correction applies to bottles going into the freezer.

The complete model, with every formula and every constant, is documented inside the app. Nothing is hidden behind a black box.

WHILE IT RUNS

• A dial counts down and shows the estimated current beer temperature
• Home Screen and Lock Screen widgets in four sizes
• A Live Activity in the Dynamic Island
• An Apple Watch app that starts and stops a run on its own, plus watch face complications
• The run survives closing the app or restarting your iPhone

MADE FOR iOS

• Light and dark mode, selectable independently of the system setting
• Two looks: a clean Classic style, and a Beer style with original artwork
• Dynamic Type up to the largest accessibility sizes
• VoiceOver labels throughout — including the formulas, read as words rather than spelled out symbol by symbol
• iPhone and iPad, portrait and landscape

PRIVACY

BeerCHILLER collects nothing and contains no network code at all. Your settings and the running timer stay on your device, shared only with the app's own widget and watch app so they can show your countdown.

A NOTE ON ACCURACY

The times are estimates. A real fridge or freezer cools faster or slower depending on airflow, how full it is, contact with the shelf, and how often the door opens. Treat the countdown as a good guide, not a measurement.

BeerCHILLER is built on an original concept and design by C. Auer. Enjoy responsibly.""",

    "de": """BeerCHILLER sagt dir, wie lange dein Bier im Kühlschrank oder Gefrierschrank braucht, zählt die Zeit herunter und schlägt Alarm, sobald es kalt ist.

Gebinde, Volumen, Lage und Temperaturen wählen: BeerCHILLER berechnet die Kühlzeit mit einem kalibrierten thermodynamischen Modell und startet den Timer. Keine Anmeldung, kein Konto, kein Netzwerk.

EIN ALARM, KEINE BLOSSE MITTEILUNG

Bei geöffneter App klingelt der Alarm auch dann, wenn das iPhone stumm geschaltet ist — so wie sich ein Wecker gehört. Ab iOS 26.1 stellt die App zusätzlich einen Systemwecker, der durch Fokus hindurch klingelt und erst aufhört, wenn du ihn wegdrückst. Auf älteren Versionen kommt im Hintergrund eine Mitteilung. App schließen, Bildschirm sperren, ins Nebenzimmer gehen: du erfährst es trotzdem.

WIE ES RECHNET

Die Schätzung stammt vom Modell BeerChiller Calibrated V2.1. Bier und Gebinde werden als ein Körper behandelt, die Geräteluft als Reservoir mit konstanter Temperatur. Dadurch verlangsamt sich die Kühlung realistisch, je näher das Bier der Gerätetemperatur kommt — die letzten zwei Grad dauern deutlich länger als die ersten zwei. Flasche und Dose, 0,33 / 0,5 / 1,0 Liter, stehend oder liegend, Kühl- oder Gefrierschrank: jede Kombination hat ihre eigene Kalibrierung, und für Flaschen im Gefrierschrank kommt eine Kaltstart-Korrektur hinzu.

Das vollständige Modell mit allen Formeln und Konstanten ist in der App dokumentiert. Nichts versteckt sich in einer Blackbox.

WÄHREND DER KÜHLZEIT

• Eine Skala zählt herunter und zeigt die geschätzte aktuelle Biertemperatur
• Widgets für Home- und Sperrbildschirm in vier Größen
• Eine Live-Aktivität in der Dynamic Island
• Eine Apple-Watch-App, die eigenständig starten und stoppen kann, samt Komplikationen für das Zifferblatt
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

    "it": """BeerCHILLER ti dice quanto tempo serve alla tua birra in frigo o in congelatore, fa il conto alla rovescia e suona appena è fredda.

Scegli il contenitore, il volume, la posizione e le temperature: BeerCHILLER stima il tempo di raffreddamento con un modello termodinamico calibrato e avvia il timer. Senza registrazione, senza account, senza rete.

UNA SVEGLIA, NON UNA SEMPLICE NOTIFICA

Con l'app aperta la sveglia suona anche a iPhone silenziato, come deve fare una sveglia. Da iOS 26.1 l'app ne programma anche una di sistema, che suona attraverso Full Immersion e continua finché non la fermi. Sulle versioni precedenti in secondo piano arriva una notifica. Chiudi l'app, blocca il telefono, vai in un'altra stanza: lo scoprirai comunque.

COME FUNZIONA

La stima deriva dal modello BeerChiller Calibrated V2.1. Birra e contenitore sono trattati come un unico corpo e l'aria dell'apparecchio come un serbatoio a temperatura costante: il raffreddamento rallenta quindi in modo realistico man mano che la birra si avvicina — gli ultimi due gradi richiedono molto più tempo dei primi due. Bottiglia e lattina, 0,33 / 0,5 / 1,0 litri, in piedi o coricata, frigo o congelatore: ogni combinazione ha la propria calibrazione, e per le bottiglie messe in congelatore si applica una correzione di avvio a freddo.

Il modello completo, con tutte le formule e le costanti, è documentato dentro l'app. Nulla resta nascosto in una scatola nera.

MENTRE IL TIMER SCORRE

• Un quadrante conta alla rovescia e mostra la temperatura stimata della birra
• Widget per schermata Home e schermata di blocco, in quattro dimensioni
• Un'attività in tempo reale nella Dynamic Island
• Un'app per Apple Watch che avvia e ferma da sola, con complicazioni per il quadrante
• Il timer sopravvive alla chiusura dell'app e al riavvio dell'iPhone

FATTA PER iOS

• Chiaro e scuro, selezionabili indipendentemente dall'impostazione di sistema
• Due aspetti: uno stile Classico essenziale e uno stile Birra con grafica originale
• Testo dinamico fino alle dimensioni di accessibilità più grandi
• Etichette VoiceOver in tutta l'app, anche per le formule, lette come parole invece che simbolo per simbolo
• iPhone e iPad, verticale e orizzontale

PRIVACY

BeerCHILLER non raccoglie nulla e non contiene alcun codice di rete. Le impostazioni e il timer in corso restano sul dispositivo, condivisi solo con il widget e l'app per l'orologio di BeerCHILLER perché possano mostrare il conto alla rovescia.

SULLA PRECISIONE

I tempi sono stime. Un frigorifero o un congelatore reale raffredda più o meno rapidamente in base al flusso d'aria, al carico, al contatto con il ripiano e a quante volte si apre la porta. Considera il conto alla rovescia una buona indicazione, non una misura.

BeerCHILLER si basa su un'idea e un design originali di C. Auer. Bevi responsabilmente.""",

    "es": """BeerCHILLER te dice cuánto tiempo necesita tu cerveza en la nevera o el congelador, hace la cuenta atrás y suena en cuanto está fría.

Elige el envase, el volumen, la posición y las temperaturas: BeerCHILLER calcula el tiempo de enfriamiento con un modelo termodinámico calibrado y pone en marcha el temporizador. Sin registro, sin cuenta, sin red.

UNA ALARMA, NO UN SIMPLE AVISO

Con la app abierta, la alarma suena aunque el iPhone esté en silencio, como debe hacerlo una alarma. A partir de iOS 26.1 la app programa además una alarma del sistema, que suena a través de los modos de concentración y no para hasta que la detienes. En versiones anteriores llega una notificación en segundo plano. Cierra la app, bloquea el teléfono, vete a otra habitación: te enterarás igual.

CÓMO FUNCIONA

La estimación proviene del modelo BeerChiller Calibrated V2.1. La cerveza y el envase se tratan como un solo cuerpo, y el aire del aparato como un depósito a temperatura constante, de modo que el enfriamiento se ralentiza de forma realista al acercarse: los dos últimos grados tardan mucho más que los dos primeros. Botella y lata, 0,33 / 0,5 / 1,0 litros, de pie o tumbada, nevera o congelador: cada combinación tiene su propia calibración, y las botellas que entran en el congelador reciben una corrección de arranque en frío.

El modelo completo, con todas las fórmulas y constantes, está documentado dentro de la app. Nada queda oculto en una caja negra.

MIENTRAS FUNCIONA

• Un dial cuenta atrás y muestra la temperatura estimada de la cerveza
• Widgets para la pantalla de inicio y la pantalla bloqueada, en cuatro tamaños
• Una actividad en directo en la Dynamic Island
• Una app para Apple Watch que inicia y detiene por sí sola, con complicaciones para la esfera
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

    "fr": """BeerCHILLER vous dit combien de temps votre bière doit rester au réfrigérateur ou au congélateur, décompte les minutes et sonne dès qu’elle est fraîche.

Choisissez le récipient, le volume, la position et les températures : BeerCHILLER estime le temps de refroidissement à partir d’un modèle thermodynamique calibré et lance le minuteur. Sans inscription, sans compte, sans réseau.

UNE ALARME, PAS UNE SIMPLE NOTIFICATION

App ouverte, l’alarme sonne même iPhone en mode silencieux, comme doit le faire une alarme. À partir d’iOS 26.1, l’app programme en plus une alarme système, qui traverse les modes de concentration et sonne jusqu’à ce que vous l’arrêtiez. Sur les versions antérieures, une notification arrive en arrière-plan. Fermez l’app, verrouillez le téléphone, passez dans une autre pièce : vous serez prévenu quand même.

COMMENT ÇA MARCHE

L’estimation vient du modèle BeerChiller Calibrated V2.1. La bière et son récipient sont traités comme un seul corps, et l’air de l’appareil comme un réservoir à température constante : le refroidissement ralentit donc de façon réaliste à l’approche de la cible — les deux derniers degrés prennent bien plus longtemps que les deux premiers. Bouteille et canette, 0,33 / 0,5 / 1,0 litre, debout ou couchée, réfrigérateur ou congélateur : chaque combinaison a son propre calibrage, et une correction de démarrage à froid s’applique aux bouteilles mises au congélateur.

Le modèle complet, avec toutes ses formules et constantes, est documenté dans l’app. Rien n’est caché dans une boîte noire.

PENDANT LE REFROIDISSEMENT

• Un cadran décompte et affiche la température estimée de la bière
• Des widgets pour l’écran d’accueil et l’écran verrouillé, en quatre tailles
• Une activité en direct dans la Dynamic Island
• Une app Apple Watch qui démarre et arrête seule, avec des complications pour le cadran
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

    "nl": """BeerCHILLER vertelt je hoe lang je bier in de koelkast of de vriezer moet, telt af en slaat alarm zodra het koud is.

Kies de verpakking, het volume, de positie en de temperaturen: BeerCHILLER berekent de koeltijd met een gekalibreerd thermodynamisch model en start de timer. Geen registratie, geen account, geen netwerk.

EEN WEKKER, GEEN GEWONE MELDING

Met de app open klinkt het alarm ook als je iPhone op stil staat, zoals een wekker hoort te doen. Vanaf iOS 26.1 zet de app bovendien een systeemwekker, die door Focus heen gaat en blijft bellen tot je hem stopt. Op oudere versies komt op de achtergrond een melding. Sluit de app, vergrendel je telefoon, loop naar een andere kamer: je hoort het toch.

HOE HET REKENT

De schatting komt van het model BeerChiller Calibrated V2.1. Bier en verpakking worden als één lichaam behandeld en de lucht in het apparaat als een reservoir met constante temperatuur, waardoor het koelen realistisch vertraagt naarmate het bier dichterbij komt: de laatste twee graden duren veel langer dan de eerste twee. Fles en blikje, 0,33 / 0,5 / 1,0 liter, staand of liggend, koelkast of vriezer: elke combinatie heeft zijn eigen kalibratie, en voor flessen in de vriezer geldt een koudestartcorrectie.

Het volledige model, met alle formules en constanten, staat gedocumenteerd in de app. Niets verdwijnt in een zwarte doos.

TIJDENS HET KOELEN

• Een schijf telt af en toont de geschatte biertemperatuur
• Widgets voor beginscherm en toegangsscherm, in vier maten
• Een live activiteit in de Dynamic Island
• Een Apple Watch-app die zelfstandig start en stopt, met complicaties voor de wijzerplaat
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

    "pt": """O BeerCHILLER diz-te quanto tempo a tua cerveja precisa no frigorífico ou no congelador, faz a contagem decrescente e toca assim que estiver fresca.

Escolhe o recipiente, o volume, a posição e as temperaturas: o BeerCHILLER calcula o tempo de arrefecimento com um modelo termodinâmico calibrado e inicia o temporizador. Sem registo, sem conta, sem rede.

UM ALARME, NÃO UMA SIMPLES NOTIFICAÇÃO

Com a app aberta, o alarme toca mesmo com o iPhone silenciado, como deve ser. A partir do iOS 26.1 a app agenda também um alarme do sistema, que atravessa os modos de concentração e continua a tocar até o parares. Em versões anteriores chega uma notificação em segundo plano. Fecha a app, bloqueia o telefone, vai para outra divisão: ficas a saber na mesma.

COMO FUNCIONA

A estimativa vem do modelo BeerChiller Calibrated V2.1. A cerveja e o recipiente são tratados como um só corpo, e o ar do aparelho como um reservatório a temperatura constante, pelo que o arrefecimento abranda de forma realista à medida que se aproxima: os dois últimos graus demoram muito mais do que os dois primeiros. Garrafa e lata, 0,33 / 0,5 / 1,0 litros, em pé ou deitada, frigorífico ou congelador: cada combinação tem a sua própria calibração, e às garrafas colocadas no congelador aplica-se uma correção de arranque a frio.

O modelo completo, com todas as fórmulas e constantes, está documentado dentro da app. Nada fica escondido numa caixa negra.

ENQUANTO CORRE

• Um mostrador faz a contagem decrescente e indica a temperatura estimada da cerveja
• Widgets para o ecrã principal e o ecrã bloqueado, em quatro tamanhos
• Uma atividade em direto na Dynamic Island
• Uma app para Apple Watch que inicia e para sozinha, com complicações para o mostrador
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
    "en": """A real alarm when the beer is ready.

• With the app open it now makes a sound — before, the ready screen appeared in silence.
• On iOS 26.1 and later BeerCHILLER schedules a system alarm: it rings through Focus and keeps ringing until you stop it.
• The notification for a closed app works as before.""",
    "de": """Ein echter Alarm, wenn das Bier fertig ist.

• Bei geöffneter App klingelt es jetzt — vorher erschien der Fertig-Schirm stumm.
• Ab iOS 26.1 stellt BeerCHILLER einen Systemwecker: Er klingelt durch Fokus hindurch und hört erst auf, wenn du ihn wegdrückst.
• Die Mitteilung bei geschlossener App funktioniert wie bisher.""",
    "es": """Una alarma de verdad cuando la cerveza está lista.

• Con la app abierta ahora suena: antes, la pantalla de aviso aparecía en silencio.
• Desde iOS 26.1, BeerCHILLER programa una alarma del sistema: suena a través de los modos de concentración y no para hasta que la detienes.
• La notificación con la app cerrada funciona como antes.""",
    "fr": """Une vraie alarme quand la bière est prête.

• App ouverte, elle sonne désormais : avant, l’écran de fin s’affichait en silence.
• À partir d’iOS 26.1, BeerCHILLER programme une alarme système : elle traverse les modes de concentration et sonne jusqu’à ce que vous l’arrêtiez.
• La notification app fermée fonctionne comme avant.""",
    "it": """Una sveglia vera quando la birra è pronta.

• Con l’app aperta ora suona: prima la schermata di fine compariva in silenzio.
• Da iOS 26.1 BeerCHILLER programma una sveglia di sistema: suona attraverso Full Immersion e continua finché non la fermi.
• La notifica ad app chiusa funziona come prima.""",
    "nl": """Een echt alarm wanneer het bier klaar is.

• Met de app open klinkt er nu geluid — eerder verscheen het klaar-scherm in stilte.
• Vanaf iOS 26.1 zet BeerCHILLER een systeemwekker: die gaat door Focus heen en blijft bellen tot je hem stopt.
• De melding bij een gesloten app werkt als voorheen.""",
    "pt": """Um alarme a sério quando a cerveja está pronta.

• Com a app aberta passa a tocar — antes, o ecrã de pronto aparecia em silêncio.
• A partir do iOS 26.1 o BeerCHILLER agenda um alarme do sistema: atravessa os modos de concentração e continua até o parares.
• A notificação com a app fechada funciona como antes.""",
}
