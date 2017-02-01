CB API

1 - log <level> ....
    level = error, warn, info, debug

2 -
  progress <task> begin [<max>]
  progress <task> ### ... msg ...
  progress <task> end


# SyncStore	WorkStore
#
#     NC	  NC	 [ Do nothing ] N/A
#     	NC	Modified 	[ S<-W ] recv
#     	NC	Deleted  	[ S<-W ] recv

#    New	Missing  [ S->W ] send
#    	New	  New	   	[ S->W* ] sendback

#    Modified     NC	 [ S->W ] send
#    	Modified Deleted  	[ S->W ] send
#    	Modified Modified	[ S->W* ] sendback

#    Deleted	  NC	 [ S->W ] send
#    	Deleted	Modified	[ S->W* ] sendback
#    	Deleted	Deleted		[ Do Nothing ] NoOp

TODO:

- Default .ini is search trough volumes or /proc/mounts
- Improve exclude patterns?

