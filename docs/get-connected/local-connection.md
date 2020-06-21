# Connect to a Local MySQL Server

This document describes how to connect to a server running on the same computer as Sequel Ace.

## Making sure your MySQL server is running

If you are not sure if the MySQL server is running, open _Activity Viewer_ (from _Applications_ » _Utilities_). Choose _All Processes_ in the popup menu. Type mysqld into the search field. If you see a mysqld process, MySQL is running.

## Connecting via a socket connection

Open Sequel Ace. Choose a _Socket_ Connection. You must only specify the username and password (if any). Most MySQL installations use the default username root and a blank password.

If you leave the socket field empty, Sequel Ace will try several common socket file locations. If Sequel Ace can't find your socket file, or if you have multiple MySQL servers running on your computer, you must enter the location of the socket file.

**Note**: the popular MAMP package uses root as default password. See [Connecting to MAMP or XAMPP.](get-connected/mamp-xampp.md "Connecting to MAMP or XAMPP")

## Connecting via a standard connection

Open Sequel Ace. Choose a _Standard_ Connection. Enter 127.0.0.1 for the host. The default username for a new MySQL installation is root, with a blank password. You can leave the port field blank unless your server uses a different port than 3306.

**Note**: MAMP uses port 8889 per default, and root as the password. See [Connecting to MAMP or XAMPP](get-connected/mamp-xampp.md "Connecting to MAMP or XAMPP")

**Note**: Don't try using localhost instead of 127.0.0.1. MySQL treats the hostname localhost specially. For details, see [MySQL manual.](https://dev.mysql.com/doc/refman/en/connecting.html)
