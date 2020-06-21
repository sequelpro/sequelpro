# What type of connection do I have?

When you open Sequel Ace, the first screen that you will see is the database connection window. If you don't have access to a MySQL server, perhaps you could try installing [MySQL](https://dev.mysql.com/doc/mysql-osx-excerpt/en/osx-installation.html "MySQL:Installing on MacOS") or [MariaDB](https://mariadb.com/kb/en/installing-mariadb-on-macos-using-homebrew "MariaDB:Installing on MacOS") on your Mac.

## Local Connections

A MySQL Server running on the same computer as Sequel Ace is called _local_. You can connect to a local MySQL server in two ways:

-   using a **Standard** connection
-   using a **Socket** connection

Which type you prefer is up to you. See below for a description of the two methods.

For more details, see [Connecting to a local MySQL Server](local-connection.md "Connecting to a local MySQL Server").

If you installed MySQL with MAMP or XAMPP, see [Connecting to MAMP or XAMPP](mamp-xampp.md "Connecting to MAMP or XAMPP").

## Remote Connections

If the MySQL server is on a different computer as Sequel Ace, it's called a _remote_ server. You can connect to remote servers:

-   using a **Standard** connection
-   using a **SSH** connection

You can use a standard connection if the MySQL server is directly reachable -- eg. if it is on your local network. If you cannot directly reach your server (eg. it is behind a firewall), you will have to use a SSH connection. For more details see [Connecting to a MySQL Server on a Remote Host](remote-connection.md "Connecting to a MySQL Server on a Remote Host").

At the moment, **Sequel Ace does not support SSL** encryption. If possible, use a SSH connection instead.

# Standard Connection

A standard connection is an **unencrypted** connection using TCP/IP. Such a connection is usually made over the network or over the internet to a remote server. To specify which server to connect to, you must provide its IP address or DNS resolvable name:

**# IP Address**
192.168.0.11
66.78.91.2

**# DNS resolvable name**
Crema.X-Serve.local
intranet.mycompany.com
mysql.webhosting.com

If you use the special address 127.0.0.1, you can connect to a server on your own computer.

> **Note:** Some web hosting companies may give you access to MySQL running on the server that is hosting your website (often by adding your IP address to a whitelist). In this case your web host will provide you with an IP address or a domain name on a server located on the internet that has a port open for you to connect to. If this is unavailable to you, you may need to connect to MySQL via an SSH Tunnel.

Required Fields

Host

Enter the host name or IP address of the host.

Username

The default username for a mysql install is **root**

Optional Fields

Name

The name you want to give the favourite.

Password

The default password for a mysql install is an empty string.
If that's the case, you should change the root password right away.

Database

If you enter a database, it will be selected when the connection to
the server is established.
Otherwise you can select one of the databases on the server afterwards.

Port

Defaults to port 3306.


# Socket Connection

A **Socket connection** is a connection to a copy of MySQL running on your local machine. If you are connecting to MySQL that you have installed from a package installer or source, then you won't normally need to enter anything into the socket field.

Required Fields

Username

The default username for a mysql install is **root**

Password

The default password for a mysql install is an empty string.
If that's the case, you should change the root password right away.

Optional Fields

Name

The name you want to give the favourite.

Database

If you enter a database, it will be selected when the connection to
the server is established.
Otherwise you can select one of the databases on the server afterwards.

Socket

For non-standard mysql installs (e.g - MAMP) manually set the path. Read more about connecting via sockets to [MAMP, XAMPP and other MySQL server setups](mamp-xampp.md).
