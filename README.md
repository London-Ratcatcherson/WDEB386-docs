# WDEB386-docs
This is my first full fat documentation for the Windows 95 kernel debugger.

Although Windows 3.0 was a 16 bit OS, its kernel actually ran in full 32 bit
mode. The user mode executables were all limited to 16, 12 and 8 bit apps 
(or, Win 3.0, Win 2.0 and MSDOS). For the user mode apps, you could use
a standalone debugger like CodeView. But for the full kernel mode, you needed
something heavier duty. WDEB386, short for Windows DEbugger running in 80386 
protected mode (or the full 32 bit flat memory model). 

When I started at Microsoft as a Developer for Windows 3.1, the kernel debugger was 
a fairly minimal framework with not a lot of documentation. Basically, you'd 
ask your office mate, "How do you set this thing up?".

You'd get a dumb terminal (with an orange or green screen) and connect your serial
port to the PC to be debugged. Then you checked that the serial ports on both
systems were set the same (I wrote a small assembly language app to ensure this).
Once verified, you'd set your MSDOS AUTOEXEC.BAT to fire up WDEB386 and then
load Windows. 

The WDEB386 debugger had one core set of commands - show/edit the registers,
display memory, dump the stacks, and so on. As programmers ran into problems, 
they would often write new debugger commands, which were sometimes back ported 
into the debugger.

Individual device drivers had their own internal special commands, which you 
could trigger using WDEB386. These internal commands would vary between the
standard Windows build and the debug builds (which had more internal checks, 
but ran lots slower). Some developers would share their commands freely, while 
others kept theirs pretty close to the vest. 

By the time Windows 3.1 shipped and work got underway on Windows 95, the 
WDEB386 was a classic squirrel's nest of instructions, which changed from 
build to build and had no documentation. I was fortunately in being both an 
engineer AND a journalist, so I combined these skills to create the first
usable Windows 95 kernel debugger documention.

And here we are - "Your pal, WDEB386"!

( Named for the old "Your pal, Jimmy Olsen" comics ).









