%define perl_vendorlib %(eval "`perl -V:installvendorlib`"; echo $installvendorlib)
%define common_description Spamity parses logs files generated by Postfix and offers a web interface to consult rejected messages. Authentication is possible through an IMAP or LDAP server and desired accounts can receive administrator privileges.

Name: Spamity
Summary: Perl modules for spamityd and its web interface.
Version: 0.96
Release: 1
License: GPL
Group: Applications/Internet
URL: http://www.collaboration-world.com/spamity/

Packager: Francis Lachapelle <francis@Sophos.ca>
Vendor: Collaboration-World, http://www.collaboration-world.com/

Source: Spamity-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

BuildArch: noarch
BuildRequires: perl
Requires: perl

%description
%{common_description}

%package -n perl-Spamity
Summary: Perl modules for spamityd and its web interface.
Group: Applications/Internet
%description -n perl-Spamity
%{common_description}

This package provides the Perl modules.

%package -n spamityd
Summary: Spamity daemon
Group: Applications/Internet
Requires: perl-Spamity = %{version}-%{release}
%description -n spamityd
%{common_description}

This package provides the daemon that parses the mail logs.

%package -n spamity-web
Summary: Spamity web interface
Group: Applications/Internet
Requires: perl-Spamity = %{version}-%{release}
%description -n spamity-web
%{common_description}

This package provides the web interface of Spamity.

%prep
%setup

%install
rm -rf $RPM_BUILD_ROOT
install -D -m0600 -oapache -gapache etc/spamity.conf $RPM_BUILD_ROOT%{_sysconfdir}/spamity.conf
install -d -m0755 $RPM_BUILD_ROOT%{perl_vendorlib}/Spamity
install -m0644 lib/Spamity.pm $RPM_BUILD_ROOT%{perl_vendorlib}/Spamity.pm
find lib/Spamity -type d -exec chmod o+x {} ';'
cp -av lib/Spamity $RPM_BUILD_ROOT%{perl_vendorlib}
install -d -m0755 $RPM_BUILD_ROOT%{_localstatedir}/www/html/spamity
cp -av htdocs/* $RPM_BUILD_ROOT%{_localstatedir}/www/html/spamity
install -d -m0755 $RPM_BUILD_ROOT%{_localstatedir}/www/cgi-bin/spamity
cp -av cgi-bin/* $RPM_BUILD_ROOT%{_localstatedir}/www/cgi-bin/spamity
install -D -m0755 init.d/spamityd.rh $RPM_BUILD_ROOT%{_initrddir}/spamityd
install -D -m0700 sbin/spamityd $RPM_BUILD_ROOT%{_sbindir}/spamityd

%clean
rm -rf $RPM_BUILD_ROOT

%files -n perl-Spamity
%defattr(-, root, root, 0755)
%doc COPYING ChangeLog README RELEASE_NOTES sessions.mysql sessions.psql sessions.oracle scripts
%config(noreplace) %{_sysconfdir}/spamity.conf
%{perl_vendorlib}/Spamity.pm
%{perl_vendorlib}/Spamity/

%files -n spamity-web
%defattr(-, root, root, 0755)
%{_localstatedir}/www/*

%files -n spamityd
%defattr(-, root, root, 0755)
%{_sbindir}/spamityd
%config %{_initrddir}/spamityd

%post -n spamityd
/sbin/chkconfig --add spamityd

%preun -n spamityd
if [ $1 = 0 ]; then
    /sbin/service spamityd stop >/dev/null 2>&1
    /sbin/chkconfig --del spamityd
fi

%changelog
* Sat Nov 26 2005 Francis Lachapelle <francis@Sophos.ca>
- Created initial spec file
