The SPMySQL Framework is intended to provide a stable MySQL connection framework, with the ability to run text-based queries and rapidly retrieve result sets with conversion from MySQL data types to Cocoa objects.

SPMySQL.framework has an interface loosely based around that provided by MCPKit by Serge Cohen and Bertrand Mansion (http://mysql-cocoa.sourceforge.net/), and in particular the heavily modified Sequel Pro version (http://www.sequelpro.com/).  It is a full rewrite of the original framework, although it includes code from patches implementing the following Sequel Pro functionality, largely contributed by Hans-Jörg Bibiko, Stuart Connolly, Jakob Egger, and Rowan Beentje:
	- Connection locking (Jakob et al)
	- Ping & keepalive (Rowan et al)
	- Query cancellation (Rowan et al)
	- Delegate setup (Stuart et al)
	- SSL support (Rowan et al)
	- Connection checking (Rowan et al)
	- Version state (Stuart et al)
	- Maximum packet size control (Hans et al)
	- Result multithreading and streaming (Rowan et al)
	- Improved encoding support & switching (Rowan et al)
	- Database structure; moved to inside the app (Hans et al)
	- Query reattempts and error-handling approach (Rowan et al)
	- Geometry result class (Hans et al)
	- Connection proxy (Stuart et al)


INTEGRATION

SPMySQL.framework can be added to your project as a standard Cocoa framework, or the entire project can be added as a subproject in Xcode.
To add as a subproject in Xcode:
 	1) Add the SPMySQL framework's .xcodeproj to your current project
 	2) Choose an existing target, Get Info, and under direct dependenies add a new dependency.  Choose the SPMySQL.framework target from the sub-project
 	3) Expand the subproject to see its child target - SPMySQL.framework.  Drag this to the "Link Binary With Libraries" build phase of any targets using the framework.
 	4) If you don't have a Copy Frameworks phase, add one; drag the SPMySQL.framework child target to this phase.
 	5) In your build settings, add a User Header Search Path; make it a recursive path to the SPMySQL project folder location (for example ${PROJECT_DIR}/Frameworks/SPMySQLFramework).  This should allow you to #include "SPMySQL.h" and have everything function.

As a last resort jump onto IRC and join #sequel-pro on irc.freenode.net and any of the 
developers will be more than happy to help you out.


LICENSE

Copyright (c) 2012 Rowan Beentje (rowan.beent.je) and the Sequel Pro team.

The SPMySQL framework is offered under the MIT license:

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.