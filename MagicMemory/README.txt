 Magic Memory Upgrade Mod
 ========================

I attempted a magic trick: Upgrade or Replace the Kobo's internal SD 
card using only the Kobo itself, no card readers, no partitioning or 
disk cloning on the PC.

The Magic Memory Upgrade Mod enables the Kobo to clone its internal SD 
card all by itself. I've only tested it with the H2O, but it should work 
with all readers that have at least 512MB RAM, which should include all 
models since Kobo Aura HD, I believe? It's not always mentioned in the 
specs...

Once the mod is installed, it copies the Kobo's operating system into 
RAM. At that point the internal card can be removed and replaced with 
another card of your choice. The mod detects the new card, formats it, 
and puts the Kobo's operating system back on it. Everything without help 
from the PC (no cardreader and no partitioning or disk imaging software 
required). Apart from installing the mod in the first place, of course.

Once the mod has done its work, the reader reboots and shows you the 
language selection screen. It's essentially a factory reset that also 
replaces your internal MicroSD card, making the full card's capacity 
available to you.

How to use:

    * Backup your books and settings.
    * Make sure your reader is fully charged.
    * Install this mod. (KoboRoot-MagicMemory.tgz » .kobo/KoboRoot.tgz)
    * The reader shows the Updating/Restarting screen.
    * The reader reboots and the screen goes blank.
    ~~~ OS is being loaded into RAM. This might take a while. ~~~
    * You get the normal bootup progress bar and the main screen appears.
      (If you don't use nickel by default, start nickel.)
    * A progress bar appears.
    ~~~ Data is being loaded into RAM. This might take a while. ~~~
    * The screen goes fully black.
---> Without turning the reader off, take out the old internal SD card. <---
    * Wait for the screen to go from fully black to fully white.
---> Without turning the reader off, put in the new internal SD card. <---
    * A progress bar appears.
    ~~~ The SD card is formatted and populated with data from RAM.
        This might take a while. ~~~
    * The reader reboots and gives you the Language Selection screen 
      that normally appears after a factory reset.

The duration of this process heavily depends on the speed of the SD 
card. Actually the 4GB card that came with my H2O was the fastest card. 
I have several 4GB/8GB Sandisk card but they were all considerably 
slower than Kobo's card. (apparently I always bought the cheapest SD 
cards.)

If anything goes wrong in this process, the progress bar will stop 
moving. If that happens, take out the card, hit the reset button, put 
the (old) card in, hit the reset button again and it should boot up 
normally. 
