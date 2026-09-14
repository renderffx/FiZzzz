ooo-desk is just me trying to see suspense on the wire without all the react stuff around it.

i kept getting lost in the real codebase so i wrote the smallest thing i could that still does the same shape. a request with some segments and boundaries. thats it.

pending just means waiting. completed means done. failed means leave it for client. flushed means sent. nothing fancy.

the rule i kept coming back to is simple. if parent already went out, the late child has to come in with a $RC. if parent hasnt gone out yet, the child just gets absorbed in. no $RC needed.

fail is $RX. and never $RC after $RX. abort just stops. dead stays dead. i messed that one up once and sent a clean end after abort. that was wrong. fixed now.

wakes are simple too. ok means save the html and finish. err means save the error and fail the boundary. table owns all of it so nothing dangles.

writer just writes chunks with length in front. mem splits them up. net sends once. flight stuff rides in a script tag so i had to escape quotes or the whole thing breaks. learned that the hard way.

escape is the boring part but it matters. &, <, >, quotes. row 3 has a script in it on purpose so i can see if i broke it.

the tape order never changes. legs 14 first so it absorbs. then row 14 reveals. 7 and 19 fail. 28 reveals then its legs reveals. rest just reveal in order. if that order moves i know i broke something.

why zig. honestly i wanted something where bytes are bytes. no gc pausing in the middle, no hidden alloc. if i dupe wrong or free wrong it blows up right there. i like that. js can keep the dom walk, zig keeps the bytes. separate programs, same shape. if mine matches, i trust it.

i didnt port react. i just rewrote the idea. porting would bring all the baggage. this way each side owns its bugs.

i keep a gen and mutants around so i cant lie to myself. gen tries orders. mutants flip rules. if gen finds nothing and all 7 get caught, i feel okay about it. dump just prints the wire so i can look with my own eyes.

thats really it. not a product. just notes that run.
