
# Connecting to MAMP or XAMPP

This page describes how to connect to the MySQL Server of [MAMP](http://www.mamp.info) or [XAMPP](http://www.apachefriends.org/en/xampp-macosx.html) running on the same computer as Sequel Ace. If you want to connect to MAMP/XAMPP running on a different computer, please see [Connecting to a MySQL Server on a Remote Host](https://sequelpro.com/docs/get-started/get-connected/docs/Connecting_to_a_MySQL_Server_on_a_Remote_Host "Connecting to a MySQL Server on a Remote Host").

## MAMP

### CONNECT TO MAMP VIA A UNIX SOCKET

This is the recommended way of connecting to [MAMP](http://www.mamp.info/ "http://www.mamp.info").

In the Sequel Ace connection dialog, choose a socket connection.

(0.9.7 and earlier versions: Enter /Applications/MAMP/tmp/mysql/mysql.sock in the socket field. In 0.9.8 and later versions, this socket path will be checked automatically if the field is left empty.)

Type root into the username field. The default password is also root. Optionally enter a name for the connection.

Make sure that MAMP is running and click connect.

## Connect to MAMP via a standard TCP/IP connection

You can also connect via a TCP/IP connection.

Enter 127.0.0.1 for the Host. Enter root for the username and for the password. The default MySQL port used by MAMP is 8889.

# XAMPP

Just like with MAMP, you can also connect to [XAMPP](http://www.apachefriends.org/en/xampp-macosx.html "http://www.apachefriends.org/en/xampp-macosx.html") via a socket connection or a standard connection. Only the default settings are a little bit different:

## Connect to XAMPP via a unix socket

(0.9.7 and earlier versions: The unix socket for XAMPP is /Applications/XAMPP/xamppfiles/var/mysql/mysql.sock. In 0.9.8 and later versions, this socket path will be checked automatically if the field is left empty.)

Use root as username, and leave the password field blank.

## Connect to XAMPP via a standard TCP/IP connection

Type 127.0.0.1 into the host field. Since XAMPP uses the standard MySQL port 3306, you can leave the port field blank. The user name is root, the default password is blank.
