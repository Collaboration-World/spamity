package Spamity::i18n::fr_ca;

use Spamity::i18n;
use vars qw(@ISA %Lexicon);
@ISA = qw(Spamity::i18n);

%Lexicon = (
	    # header.html
	    'Rejected messages for' => 'Messages rejet�s pour',

	    # help.html
	    'about' => '� propos',
	    'help' => 'aide',
	    'appendix: filter types' => 'annexe: types de filtres',

	    # login.cgi
	    'Specify your username and password to login.' => 'Entrez votre nom d\'usager et votre mot de passe.',
	    'Authentication failed.' => 'Erreur d\'authentification.',
	    'Your session has expired.' => 'Votre session est expir�e.',

	    # login.html
	    'login' => 'authentification',
	    'username' => 'nom d\'usager',
	    'password' => 'mot de passe',
	    'language' => 'langue',
	    'Login' => 'Entrer',
	    
	    # stats.html
	    'statistics' => 'statistiques',
	    'summary' => 'sommaire',
	    'last 24 hours' => 'les derni�res 24 heures',
	    'last week' => 'la derni�re semaine',
	    'last month' => 'le dernier mois',
	    'most spammed addresses' => 'les adresses les plus pollupost�s',
	    'latest rejected messages' => 'messages r�cemment rejet�s',

            # search.html
	    'search' => 'recherche',
	    'domain' => 'domaine',
	    'All' => 'Tous',
	    'from' => 'date de d�but',
	    'to' => 'date de fin',
	    'today' => 'aujourd\'hui',
	    'same day' => 'm�me jour',
	    'email/domain' => 'courriel/domaine',
	    'filter type' => 'type de filtre',
	    'display' => 'affichage',
	    'by email' => 'par courriel',
	    'by date' => 'par date',
	    'per page' => 'par page',
	    'all accounts' => 'tous les comptes',
	    'click to show details' => 'cliquez pour voir les d�tails',
	    
	    'Search' => 'Recherche',
	    'Logout' => 'Quitter',

	    'January' => 'Janvier',
	    'February' => 'F�vrier',
	    'March' => 'Mars',
	    'April' => 'Avril',
	    'May' => 'Mai',
	    'June' => 'Juin',
	    'July' => 'Juillet',
	    'August' => 'Ao�t',
	    'September' => 'Septembre',
	    'October' => 'Octobre',
	    'November' => 'Novembre',
	    'December' => 'D�cembre',

	    'Your search returned no results. Please refined your query.' => 'Aucun r�sultat. Veuillez revoir vos crit�res de recherche.',
	    'messages found' => 'messages trouv�s',
	    
	    'messages' => 'messages',
	    'time' => 'heure',
	    'recipient' => 'destinataire',
	    'sender' => 'exp�diteur',
	    'filter method' => 'm�thode',
	    'address' => 'adresse',

	    # prefs.cgi
	    'Preferences saved for address' => 'Pr�f�rences enregistr�es pour l\'adresse',

	    # prefs.html
	    'preferences' => 'pr�f�rences',
	    'Other email' => 'Autre adresse',
	    'Edit' => 'Modifier',
	    'policy for' => 'politique pour',
	    'default' => 'd�faut',
	    'customized' => 'personnalis�e',
	    'tolerence' => 'tol�rance',
	    'accept' => 'accepter',
	    'reject' => 'rejeter',
	    'virus' => 'les virus',
	    'spam' => 'les pourriels',
	    'banned files' => 'les fichiers bannis',
	    'bad header' => 'les en-t�tes mal format�es',
	    'address extension' => 'extension courriel',
	    '(optional)' => '(optionnel)',
	    'spam levels' => 'niveaux associ�s aux pourriels',
	    'tag level' => 'niveau d\'�tiquetage',
	    'Controls adding the \'X-Spam-Status\' and \'X-Spam-Level\' headers.' => 'Contr�le l\'ajout des ent�tes \'X-Spam-Status\' et \'X-Spam-Level\'.',
	    '2nd tag level' => '2� niveau d\'�tiquetage',
	    'Controls adding \'X-Spam-Flag: YES\', and editing Subject.' => 'Contr�le l\'ajout de l\'ent�te \'X-Spam-Flag: YES\' et de l\'�dition du sujet.',
	    'kill level' => 'niveau de destruction',
      	    'Controls \'evasive actions\' (reject, quarantine, extensions). Subject to amavis settings.' => 'Contr�le le d�clanchement des actions de destruction (rejet, quarantaine, extensions).',
	    'subject prefix' => 'pr�fixe au sujet',
	    'lists' => 'listes',
	    'whitelist' => 'liste blanche',
	    'blacklist' => 'liste noire',
	    'Cancel' => 'Annuler',
	    'Save' => 'Enregistrer',
	    
	    # rawsource.cgi
	    'You are about to reinject a virus to your account. Do you want to continue?' => 'Vous vous appr�tez � injecter un virus dans votre compte. Voulez-vous continuer?',
	    'Reinjecting currently not possible.' => 'La r�injection n\'est pr�sentement pas possible.',

	    # rawsource.html
	    'More info about virus' => 'Plus d\'information concernant le virus',
	    'Reinject' => 'R�injecter',

            # Web.pm
	    'day-format' => '%e %B %Y',
	    'time-format' => '%T',
	    'number of rejected messages' => 'nombre de messages rejet�s',
	    'since' => 'depuis le',
	    'day of week' => 'jour de la semaine',
	    'average number of messages' => 'nombre moyen de messages',
	    'average number of rejected messages' => 'nombre moyen de messages rejet�s',
	    'number of messages' => 'nombre de messages',
	    'for the 24 hours' => 'pour les derni�res 24 heures',
	    'for the last week' => 'pour la derni�re semaine',
	    'by day of week' => 'par jour de la semaine',
	    'for the last month' => 'pour le dernier mois',
	    'Session directory %s doesn\'t exist.' => 'Le r�pertoire de sessions %s n\'existe pas.',
	    'Session directory %s is not writable.' => 'Aucun droit d\'�criture sur le r�pertoire de sessions %s.',
	    'Database connection error.' => 'Erreur lors de la connexion � la base de donn�es.',
	    
            # footer.html
	    'by' => 'par',

	    '_AUTO' => 1,
	    );

1;
