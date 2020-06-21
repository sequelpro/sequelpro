# Connect to a Remote MySQL Server

This page explains how to connect to a MySQL Server running on a different computer than Sequel Ace.

## CONNECTION TYPES FOR CONNECTING TO A REMOTE HOST

At the moment, Sequel Ace supports two methods for connecting to remote MySQL servers:

-   a **Standard** connection
-   a **SSH** connection

#### Standard Connections

**Standard connections** are the simplest method to connect to a MySQL server. A standard connection in Sequel Ace is a connection over the local network or the internet. It uses the TCP/IP protocol. Standard connections are not encrypted.

#### SSH connections

You can use a **SSH connection** to circumvent some of the restrictions of standard conections. A SSH connection is actually not really a different kind of connection, but rather a standard connection made _through a SSH tunnel_. While a standard connection involves only two hosts (your computer and the host on which the MySQL server is running), a SSH connection involves a third host, the **SSH host**. The SSH host can be the same as the MySQL host, but it doesn't have to be.

_An SSH connection can be used to connect through a firewall (if the firewall allows SSH tunnels). `sshd` is a process that accepts SSH connections, and `mysqld` is the MySQL server process._

If you use a SSH connection, Sequel Ace first creates a SSH tunnel to the SSH host. Then it uses this tunnel to connect via a standard connection _from the SSH host_ to the MySQL host. This complicated procedure allows you to:

-   Connect to a server behind a firewall

_If a firewall prevents direct access to the MySQL server, you might still be able to connect via SSH to a computer behind the firewall (or the MySQL server itself), and from there to the MySQL server._

-   Encrypt the connection

_If you use a SSH connection, the connection between your computer and the SSH host are encrypted. Please note that the connection between the SSH host and the MySQL host is not encrypted._

Of course, SSH connections don't solve every problem. The following requirements are necessary:

-   like above, the MySQL server must accept network connections
-   the MySQL server must allow access from the SSH host
-   you must be able to reach the SSH host

_If the SSH host is behind a firewall, it must be configured to allow SSH connections. Also, if the SSH host is behind a NAT, it must also be configured correctly._

##### CHOOSING A SSH HOST

The SSH host can basically be any computer that can access the MySQL server. You could for example use your desktop computer at work to connect to your company's MySQL server from home. A hosting provider might tell you to connect to their MySQL server via a specific SSH host. You need a username and a password for the computer you want to use as the SSH host, and it must support remote access via SSH. Almost all Unix/Linux systems and Mac OS X have built-in SSH support. On Mac OS, SSH ist called _Remote Login_ and can be enabled in the _Sharing_ preferences. If you want to use a Microsoft Windows computer as a SSH host, you must install a SSH server first (this might be difficult).

##### CREATING AN SSH CONNECTION FROM TERMINAL.APP

Sequel Ace now sets up an SSH Tunnel for you when you choose the SSH connection type. However there still may be scenarios where you might wish to set one up yourself. You can setup an SSH tunnel using the following command from Terminal.app:

$ ssh -L 1234:mysqlhost:3306 sshuser@sshhost

Here `mysqlhost` is what you have to enter in Sequel Ace as the MySQL host, `sshuser`corresponds to the SSH user, and `sshhost` corresponds to the SSH host field, obviously. The first number, `1234`, is the local port of the SSH tunnel. Sequel Ace chooses this port automatically. The second number in the command, `3306`, is the port used by the MySQL server.

## Notes

-   the MySQL server must accept network connections

_Some server administrators forbid connections from other computers, by using the option --skip-networking. Then the MySQL server only accepts connection from processes running on the same server (eg. PHP scripts), but not from remote clients (such as Sequel Ace). See [MySQL Manual](https://dev.mysql.com/doc/refman/en/server-options.html#option_mysqld_skip-networking)._

-   the MySQL server must be configured to accept connections from your adress

Many administrators configure MySQL in a manner that it allows network connections only from specific IP addresses. If this is the case, they will probably ask you for your IP adress. See [MySQL Manual](https://dev.mysql.com/doc/refman/en/connection-access.html) for details on how MySQL decides if you are allowed to connect.

if the server is behind a firewall, the firewall must be configured to accept MySQL connections

The firewall must be configured to allow incoming TCP connections on the port used by MySQL. Per default, MySQL uses port 3306.

You must be able to reach the MySQL server directly

If the MySQL server is behind a NAT gateway, you may not be able to reach the server.

