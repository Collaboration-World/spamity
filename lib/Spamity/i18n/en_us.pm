package Spamity::i18n::en_us;

use Spamity::i18n;
use vars qw(@ISA %Lexicon);
@ISA = qw(Spamity::i18n);

%Lexicon = (
	    # header.html
	    'Rejected messages for' => 'Rejected messages for',
	    
	    # help.html
	    'about' => 'about',
	    'help' => 'help',
	    'appendix: filter types' => 'appendix: filter types',

	    # login.cgi
	    'Specify your username and password to login.' => 'Specify your username and password to login.',
	    'Authentication failed.' => 'Authentication failed.',
	    'Your session has expired.' => 'Your session has expired.',
	    
            # login.html
	    'login' => 'login',
	    'username' => 'username',
	    'password' => 'password',
	    'language' => 'language',
	    'Login' => 'Login',
	    
	    # stats.html
	    'statistics' => 'statistics',
	    'summary' => 'summary',
	    'last 24 hours' => 'last 24 hours',
	    'last week' => 'last week',
	    'last month' => 'last month',
	    'most spammed addresses' => 'most spammed addresses',
	    'latest rejected messages' => 'latest rejected messages',

	    # search.html
	    'search' => 'search',
	    'domain' => 'domain',
	    'All' => 'All',
	    'from' => 'from',
	    'to' => 'to',
	    'today' => 'today',
	    'same day' => 'same day',
	    'email/domain' => 'email/domain',
	    'filter type' => 'filter type',
	    'display' => 'display',
	    'by email' => 'by email',
	    'by date' => 'by date',
	    'per page' => 'per page',
	    'all accounts' => 'all accounts',
	    'click to show details' => 'click to show details',

	    'Search' => 'Search',
	    'Logout' => 'Logout',

	    'January' => 'January',
	    'February' => 'February',
	    'March' => 'March',
	    'April' => 'April',
	    'May' => 'May',
	    'June' => 'June',
	    'July' => 'July',
	    'August' => 'August',
	    'September' => 'September',
	    'October' => 'October',
	    'November' => 'November',
	    'December' => 'December',

	    'Your search returned no results. Please refined your query.' => 'Your search returned no results. Please refined your query.',
	    'messages found' => 'messages found',

	    'messages' => 'messages',
	    'time' => 'time',
	    'recipient' => 'recipient',
	    'sender' => 'sender',
	    'filter method' => 'filter method',
	    'address' => 'address',

	    # prefs.cgi
	    'Preferences saved for address' => 'Preferences saved for address',
	    
	    # prefs.html
	    'preferences' => 'preferences',
	    'Other email' => 'Other email',
	    'Edit' => 'Edit',
	    'policy for' => 'policy for',
	    'default' => 'default',
	    'customized' => 'customized',
	    'tolerence' => 'tolerence',
	    'accept' => 'accept',
	    'reject' => 'reject',
	    'virus' => 'virus',
	    'spam' => 'spam',
	    'banned files' => 'banned files',
	    'bad header' => 'bad header',
	    'address extension' => 'address extension',
	    '(optional)' => '(optional)',
	    'spam levels' => 'spam levels',
	    'tag level' => 'tag level',
	    'Controls adding the \'X-Spam-Status\' and \'X-Spam-Level\' headers.' => 'Controls adding the \'X-Spam-Status\' and \'X-Spam-Level\' headers.',
	    '2nd tag level' => '2nd tag level',
	    'Controls adding \'X-Spam-Flag: YES\', and editing Subject.' => 'Controls adding \'X-Spam-Flag: YES\', and editing Subject.',
	    'kill level' => 'kill level',
	    'Controls \'evasive actions\' (reject, quarantine, extensions). Subject to amavis settings.' => 'Controls \'evasive actions\' (reject, quarantine, extensions). Subject to amavis settings.',
	    'subject prefix' => 'subject prefix',
	    'lists' => 'lists',
	    'whitelist' => 'whitelist',
	    'blacklist' => 'blacklist',
	    'Cancel' => 'Cancel',
	    'Save' => 'Save',
	    
	    # rawsource.cgi
	    'You are about to reinject a virus to your account. Do you want to continue?' => 'You are about to reinject a virus to your account. Do you want to continue?',
	    'Reinjecting currently not possible.' => 'Reinjecting currently not possible.',

	    # rawsource.html
	    'More info about virus' => 'More info about virus',
	    'Reinject' => 'Reinject',

	    # Web.pm
	    'day-format' => '%B %e %Y',
	    'time-format' => '%T',
	    'number of rejected messages' => 'number of rejected messages',
	    'since' => 'since',
	    'day of week' => 'day of week',
	    'average number of messages' => 'average number of messages',
	    'average number of rejected messages' => 'average number of rejected msgs',
	    'number of messages' => 'number of messages',
	    'for the 24 hours' => 'for the 24 hours',
	    'for the last week' => 'for the last week',
	    'by day of week' => 'by day of week',
	    'for the last month' => 'for the last month',
	    'Session directory %s doesn\'t exist.' => 'Session directory %s doesn\'t exist.',
	    'Session directory %s is not writable.' => 'Session directory %s is not writable.',
	    'Database connection error.' => 'Database connection error.',
	    
            # footer.html
	    'by' => 'by',
	    
	    '_AUTO' => 1,
	    );

1;
