Kobo WebPortal
--------------

The Kobo Web Portal is a local webserver, running on your Kobo. It has 
a HTML landing page with links to several sites. It can also run CGI 
scripts and thus provide you with browser-based apps.

To install, copy KoboRoot-WebPortal.tgz -> .kobo/KoboRoot.tgz

After installation it can be reached via http://webportal/ and you can 
choose to "Set Page as Home" in Kobo's webbrowser settings.

Unfortunately it won't work if no wifi network is available, since the 
Kobo refuses to start the webbrowser. But it does come with a small hack 
that allows intranet wifi networks (without real internet connectivity).

To enable this hack, see .addons/webportal/vhosts.conf

After the installation you will find the following files:

  .addons/webportal/cgi-bin/notes (sample CGI script, see below)
  .addons/webportal/cgi-bin/servicemenu (sample CGI script, see blow)
  .addons/webportal/httpd.conf (webserver configuration file)
  .addons/webportal/index.html (WebPortal landing page, edit to your liking)
  .addons/webportal/ncsi.txt (part of the intranet wifi hack)
  .addons/webportal/vhosts.conf (vhosts configuration file)

Note: These files will be overwritten any time you install this mod. If 
you customize these files, make backups! Alternatively set a different 
home directory in httpd.conf and make your customizations in that 
directory.

To uninstall, create .addons/webportal/uninstall and reboot the device. It will 
be renamed to .addons/webportal/uninstall-date-time and you can remove the 
.addons/webportal directory yourself.

Notes
~~~~~

Read, write and edit notes as plain text files in your webbrowser. They 
will be stored in /notes/file.txt. May be useful for shopping lists or 
something. (From the way it looks you can tell it was originally made 
for another device. I've yet to learn Kobo browser oddities. Clicking 
the 'save' button only seems to work while the keyboard is open.)

ServiceMenu
~~~~~~~~~~~

Displays system info. Checks internal and external memory for read 
errors. Also has an option to format the external card. (On the iriver 
Story HD, this mod could also format the internal card, and delete the 
book database, but I've disabled it here).

FileManager
~~~~~~~~~~~

Lets you browse the Kobo's files, as well as download individual files 
or entire folders (as TAR). Also lets you upload files, and 
upload&install TAR/TGZ. In order to use this you must allow machines in 
your local network to access the web portal, by editing 
.addons/webportal/httpd.conf. The Kobo's IP can be seen in Settings->Device 
Information (while Wifi is enabled). 
