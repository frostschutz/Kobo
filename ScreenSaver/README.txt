This mod displays a random "screensaver" PNG image on sleep/poweroff.

=== Installation steps: ===

1. Disable "Show current read" in Kobo's privacy/power settings.
   (mod requires blank Sleeping / Poweroff screens)
2. copy KoboRoot-ScreenSaver.tgz -> .kobo/KoboRoot.tgz
3. eject/umount device, disconnect the USB cable
   (mod does not work while charging)
--- KoboRoot.tgz will automatically install & reboot ---
4. let the device go to sleep (by either setting timeout, or pressing power button)
   (mod should display an automatically detected scanline for standby)
5. let the device power off (by either setting timeout, or holding power button)
   (mod should display an automatically detected scanline for poweroff)
--- ScreenSaver should now be fully operational ---
6. Put your images in .addons/screensaver/{standby,poweroff} folders.

=== Configuration: ===

There is a configuration file in .addons/screensaver/screensaver.cfg
Don't edit it with MS Notepad - use Notepad++ or any proper editor instead.

It contains automatically detected scanline offset/pattern which is used 
to verify that the device is showing the Sleeping / Poweroff screen to be 
replaced with screensaver images.

These values might be misdetected or stop working after firmware update 
or when changing to a different language. You have to remove previously 
detected values in order to re-detect new ones.

To uninstall this mod, set uninstall=1 in this configuration file.

=== Images: ===

You can put your images in the .addons/screensaver/{standby,poweroff} folders.
The images must be in PNG format.

Supports up to about 1000 files, depending on filename length. (shorter is better)
Image dimensions and offsets depends on your device, please adapt accordingly.
Small filesizes are better - reduce color to grayscale (16 colors) or black/white.

