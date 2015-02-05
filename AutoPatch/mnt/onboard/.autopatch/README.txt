AutoPatch - beta 2
------------------

This mod allows the Kobo to patch itself, using patch files stored 
in a hidden .autopatch directory. The patches will be applied when 
the device boots.

Currently, it patches only three files:

    libadobe.so, libnickel.so.1.0.0, librmsdk.so.1.0.0

For each file you may use multiple patch files (patch32lsb format):

    libadobe.so*.patch, libnickel.so.1.0.0*.patch, librmsdk.so.1.0.0*.patch

If a patch fails to apply, it will be moved to the failed/ subdir along
with a logfile that shows the output of the patch32lsb program.

If you want to disable a patch, you can either edit it and set it to `no`,
or you can move the patch file itself to the disabled/ subdir.

In order to uninstall this mod, create an empty file 'uninstall'
(no extension) in the hidden .autopatch directory and reboot.
