# JEP VIM Plugin

This is a VIM plugin implementing the JEP protocol. 

Please check the JEP project page http://joint-editors.org for more details on JEP.


## Prerequisites

You will need a version of VIM compiled with Ruby support.

You can check if Ruby support is up and running by issuing the following VIM command:

    :ruby puts "hello from Ruby"

If you have trouble making this work check

    :help ruby

In particular, check chapter 6, "dynamic loading".


## Install

Add the plugin to your VIM setup just like any other VIM plugin.

Get the JEP Ruby support library by cloning it directly from github:

    > git clone https://github.com/jep-project/jep-ruby.git

Add the following lines to your vimrc to make vim find it:

    ruby << RUBYEOF
    $:.unshift("/path/to/jep-ruby/lib")
    RUBYEOF

On Windows you will also need the win32-process gem. 
Make sure to install it into the Ruby which is used by VIM:

    gem install win32-process

If you don't know which version of Ruby VIM is running with, issue the following command in VIM:

    :ruby require 'rbconfig'; puts RbConfig::CONFIG["bindir"]

This will print the directory containing the Ruby binaries used.
Then make sure that this is the Ruby in you PATH and issue the "gem install" command as show above.


## Configure

### Auto Completion

Auto completion works via the VIM omni completion function. 
You need to set the JEP completion function as the omni completion function:

    set omnifunc=g:jepCompleteFunc

You might want to do this for certain file types only.

### Jump Reference

For the "jump reference" feature you need to invoke the "jepJumpReference" function.
This function falls back to the built-in behavior of <C-]> (jump to definition of the keyword under the cursor) if there is no JEP configuration for a particular file.
So it should be safe to change the mapping of <C-]> in the following way:

    map <silent> <C-]> :call g:jepJumpReference()<CR>

### Update Event

Typically a JEP backend runs in parallel to the VIM JEP frontend.
For example a backend might send problem updates to the frontend after it spent some time parsing the last user input changes.

In order to display backend events like an update of the problems list to the user, VIM must get some kind of update event.

By default, update events are the CursorMoved/CursorMovedI and the CursorHold/CursorHoldI VIM events. 
The plugin does not make any attempt to retrigger the CursorHold event in order to achieve some time based cyclic activation.

This means for example, that the backend output shown in the JEP "console" buffer will only update while you type and once after you stopped typing (HoldEvent).
There might be more output by the backend, but you won't be able to see it until you start interacting with VIM again.

If you see that you are missing updates because the CursorHold event fires too early, you may want to adapt the "updatetime" option:

    set updatetime=2000


If you don't like this behavior at all, you need to set up some cyclic retriggering by yourself and call the jepUpdateEvent function.
Unfortunately, setting up a cyclic event in the classic VIM is very painful.
The only chance you have is to react on the CursorHold event and "virtually" type some keys to retrigger the event.
The tricky part is to do the retriggering in a way that is invisible for the user and at best doesn't interact with any other plugin.

One way to do this is this:

    function! s:holdEventHandler()
      call g:jepUpdateEvent()
      call feedkeys("f\e")
    endfunction

    au CursorHold * call s:holdEventHandler()

This defines a new handler for the Hold event. When the event fires, jepUpdateEvent is called and the Hold event is retriggered by "pressing" the "f" key followed by Escape.
However, this only retriggeres in normal mode and pressing "f" is not free of side effects in all cases.
There are more elaborate ways to do the retriggering but this is outside of the focus of this README.

