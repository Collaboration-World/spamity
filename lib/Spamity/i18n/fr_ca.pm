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

	    '_AUTO' => 1,
	    );

1;
