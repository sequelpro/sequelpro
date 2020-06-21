# Getting Connected

When you open Sequel Ace, the first screen that you will see is the database connection window. If you don't have access to a MySQL server, perhaps you could try installing [MySQL](https://dev.mysql.com/doc/mysql-osx-excerpt/en/osx-installation.html "MySQL:Installing on MacOS") or [MariaDB](https://mariadb.com/kb/en/installing-mariadb-on-macos-using-homebrew "MariaDB:Installing on MacOS") on your Mac.

## Frequently Asked Questions

**I am having trouble connecting to a database. It says: Can't connect to local MySQL server through socket '/tmp/mysql.sock' (2)**

Try manually setting the socket. The socket depends on how you installed MySQL on your computer.

**I'm having trouble connecting to a MySQL 4 or MySQL 5 database on localhost with a MAMP install.**

See [Connecting to MAMP or XAMPP](mamp-xampp.md "Connecting to MAMP or XAMPP").

**My SSH connection gives the error: SSH port forwarding failed and MySQL said: Lost connection to MySQL server at 'reading initial communication packet', system error: 0**

On the server, configure MySQL by editing /etc/my.cnf and comment or remove `skip-networking` from the `[mysqld]` section. Then, restart MySQL Server.

**Sequel Ace doesn't read my `~/.ssh/config` parameters.**

Sequel Ace runs in a sandboxed mode and need you to select private key manually.

## GENERAL NOTES

-   If you enter a database, it will be selected when the connection to the server is established. Otherwise you can select one of the databases on the server afterwards.
-   If you enter no port on a standard/SSH connection, Sequel Ace uses the default port for MySQL, port 3306.
-   If you enter no **SSH port** on a SSH connection, Sequel Ace uses the default port for SSH, port 22.
-   In case you already have a SSH key saved on the remote machine, you can leave the SSH password field empty. Sequel Ace will create the SSH tunnel using that key.
-   Click "'Add to Favorites"' to save the connection for use next time you open Sequel Ace. Passwords are stored in the Keychain. To re-order favourites click the pencil in the bottom left of the connection window, (or choose Preferences > Favorites from the Sequel Ace menu) then drag the favourites in the list.
-   You can connect to multiple databases simultaneously by opening a new window (File > New) or ⌘ + N

## Articles

-   [What type of connection do I have?](connection-types.md)
-   [Connect to a Local MySQL Server](local-connection.md)
-   [Connect to a Remote MySQL Server](remote-connection.md)
-   [Connecting to MAMP or XAMPP](mamp-xampp.md)
