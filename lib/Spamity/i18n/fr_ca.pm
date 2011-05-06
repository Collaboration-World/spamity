package Spamity::i18n::fr_ca;

use Spamity::i18n;
use vars qw(@ISA %Lexicon);
@ISA = qw(Spamity::i18n);

%Lexicon = (
	    # header.html
	    'Rejected messages for' => 'Messages rejetés pour',

	    # help.html
	    'about' => 'à propos',
	    'help' => 'aide',
	    'appendix: filter types' => 'annexe: types de filtres',

	    # login.cgi
	    'Specify your username and password to login.' => 'Entrez votre nom d\'usager et votre mot de passe.',
	    'Authentication failed.' => 'Erreur d\'authentification.',
	    'Your session has expired.' => 'Votre session est expirée.',

	    # login.html
	    'login' => 'authentification',
	    'username' => 'nom d\'usager',
	    'password' => 'mot de passe',
	    'language' => 'langue',
	    'Login' => 'Entrer',
	    
	    # stats.html
	    'statistics' => 'statistiques',
	    'summary' => 'sommaire',
	    'last 24 hours' => 'les dernières 24 heures',
	    'last week' => 'la dernière semaine',
	    'last month' => 'le dernier mois',
	    'most spammed addresses' => 'les adresses les plus pollupostés',
	    'latest rejected messages' => 'messages récemment rejetés',

            # search.html
	    'search' => 'recherche',
	    'domain' => 'domaine',
	    'All' => 'Tous',
	    'from' => 'date de début',
	    'to' => 'date de fin',
	    'today' => 'aujourd\'hui',
	    'same day' => 'même jour',
	    'email/domain' => 'courriel/domaine',
	    'filter type' => 'type de filtre',
	    'display' => 'affichage',
	    'by email' => 'par courriel',
	    'by date' => 'par date',
	    'per page' => 'par page',
	    'all accounts' => 'tous les comptes',
	    'click to show details' => 'cliquez pour voir les détails',
	    
	    'Search' => 'Recherche',
	    'Logout' => 'Quitter',

	    'January' => 'Janvier',
	    'February' => 'Février',
	    'March' => 'Mars',
	    'April' => 'Avril',
	    'May' => 'Mai',
	    'June' => 'Juin',
	    'July' => 'Juillet',
	    'August' => 'Août',
	    'September' => 'Septembre',
	    'October' => 'Octobre',
	    'November' => 'Novembre',
	    'December' => 'Décembre',

	    'Your search returned no results. Please refined your query.' => 'Aucun résultat. Veuillez revoir vos critères de recherche.',
	    'messages found' => 'messages trouvés',
	    
	    'messages' => 'messages',
	    'time' => 'heure',
	    'recipient' => 'destinataire',
	    'sender' => 'expéditeur',
	    'filter method' => 'méthode',
	    'address' => 'adresse',

	    # prefs.cgi
	    'Preferences saved for address' => 'Préférences enregistrées pour l\'adresse',
	    'Your preferences were saved' => 'Vos préférences ont été enregistrées',

	    # prefs.html
	    'preferences' => 'préférences',
	    'Other email' => 'Autre adresse',
	    'Edit' => 'Modifier',
	    'policy for' => 'politique pour',
	    'default' => 'défaut',
	    'customized' => 'personnalisée',
	    'tolerence' => 'tolérance',
	    'accept' => 'accepter',
	    'reject' => 'rejeter',
	    'virus' => 'les virus',
	    'spam' => 'les pourriels',
	    'banned files' => 'les fichiers bannis',
	    'bad header' => 'les en-têtes mal formatées',
	    'address extension' => 'extension courriel',
	    '(optional)' => '(optionnel)',
	    'spam levels' => 'niveaux associés aux pourriels',
	    'tag level' => 'niveau d\'étiquetage',
	    'Controls adding the \'X-Spam-Status\' and \'X-Spam-Level\' headers.' => 'Contrôle l\'ajout des entêtes \'X-Spam-Status\' et \'X-Spam-Level\'.',
	    '2nd tag level' => '2è niveau d\'étiquetage',
	    'Controls adding \'X-Spam-Flag: YES\', and editing Subject.' => 'Contrôle l\'ajout de l\'entête \'X-Spam-Flag: YES\' et de l\'édition du sujet.',
	    'kill level' => 'niveau de destruction',
      	    'Controls \'evasive actions\' (reject, quarantine, extensions). Subject to amavis settings.' => 'Contrôle le déclanchement des actions de destruction (rejet, quarantaine, extensions).',
	    'subject prefix' => 'préfixe au sujet',
	    'lists' => 'listes',
	    'whitelist' => 'liste blanche',
	    'blacklist' => 'liste noire',
	    'Cancel' => 'Annuler',
	    'Save' => 'Enregistrer',
	    
	    # prefs_spamity.html
	    'reports' => 'rapports',
	    'Receive reports on blocked messages for your account' => 'Recevoir des rapports sur les messages bloqués pour votre compte',
	    'frequency' => 'fréquence',
	    'email' => 'courriel',
	    'Daily' => 'Une fois par jour',
	    'Weekly' => 'Une fois par semaine',
	    'Monthly' => 'Une fois par mois',

	    # rawsource.cgi
	    'You are about to reinject a virus to your account. Do you want to continue?' => 'Vous vous apprêtez à injecter un virus dans votre compte. Voulez-vous continuer?',
	    'Reinjecting currently not possible.' => 'La réinjection n\'est présentement pas possible.',

	    # rawsource.html
	    'More info about virus' => 'Plus d\'information concernant le virus',
	    'Reinject' => 'Réinjecter',

            # Web.pm
	    'day-format' => '%e %B %Y',
	    'time-format' => '%T',
	    'number of rejected messages' => 'nombre de messages rejetés',
	    'since' => 'depuis le',
	    'day of week' => 'jour de la semaine',
	    'average number of messages' => 'nombre moyen de messages',
	    'average number of rejected messages' => 'nombre moyen de messages rejetés',
	    'number of messages' => 'nombre de messages',
	    'for the 24 hours' => 'pour les dernières 24 heures',
	    'for the last week' => 'pour la dernière semaine',
	    'by day of week' => 'par jour de la semaine',
	    'for the last month' => 'pour le dernier mois',
	    'Session directory %s doesn\'t exist.' => 'Le répertoire de sessions %s n\'existe pas.',
	    'Session directory %s is not writable.' => 'Aucun droit d\'écriture sur le répertoire de sessions %s.',
	    'Database connection error.' => 'Erreur lors de la connexion à la base de données.',
	    
            # footer.html
	    'by' => 'par',

	    # report_headers.mail

	    # report.mail
	    'No message blocked' => 'Aucun message rejeté',
	    'view' => 'voir',
	    'receive' => 'recevoir',
	    'Login to' => 'Accéder à',
            'Stop receiving spam reports' => 'Ne plus recevoir les rapports de pourriels',

	    # external.cgi
	    'view a rejected message' => 'voir un message rejeté',
	    'receive a rejected message' => 'recevoir un message rejeté',
	    'report a rejected message as a false positive' => 'rapporter un message rejeté comme un faux positif',
	    'The recipient address %s is not associated to your account.' => 'L&#39;adresse du destinataire %s n&#39;est pas associée à votre compte.',
	    'The domain %s is already whitelisted.' => 'Le domaine %s apparaît déjà dans votre liste blanche.',
	    'The address %s is already whitelisted.' => 'L\'addresse %s apparaît déjà dans votre liste blanche.',
	    'The domain %s is already blacklisted.' => 'Le domaine %s apparaît déjà dans votre liste noire.',
	    'The address %s is already blacklisted.' => 'L\'addresse %s apparaît déjà dans votre liste noire.',

	    # external.html
	    'The message from' => 'Le message de',
	    'was successfully sent to' => 'a été envoyé é',
            'Reports on blocked messages for your account have been disabled.' => 'Les rapports sur les messages bloqués pour votre compte ne vous seront plus livrés par courriel.',
	    'The entry' => 'L&#39;entrée',
	    'has been added to the' => 'a été ajoutée à la',
	    'of' => 'de',
	    'Add' => 'Ajouter',
	    'Add to' => 'Ajouter à la',
	    'Choose which part of the email address you want to' => 'Choisissez la partie de l&#39;adresse que vous désirez ajouter à la',
	    'only applicable to local domains' =>  'applicable seulement aux domaines locaux',

	    '_AUTO' => 1,
	    );

1;
