Before you can start making changes to any of the xib files in Interface 
Builder you will need to install the BWToolkit plugin.

To install the plugin you will need to do a Release build of the project so 
that the BWTookit plugin and frameworks are compiled.

Once you have done this double click on the BWToolkit.ibplugin located at:

	./trunk/Frameworks/BWToolkitFramework.framework/build/Release/


If Interface Builder complains that it's already installed then you might want 
to replace the current one with the one you just built.

To do this go to the Interface Builder preferences and click on 'Plugins' and
remove the BWToolkit plugin using the [ - ] button below the list.

You will need to relaunch Interface Builder before you can re-add the plugin 
from the location mentioned above.


As a last resort jump onto IRC and join #sequel-pro on irc.freenode.net and 
I'll be happy to help you out.

- Ben (aka avenjamin)