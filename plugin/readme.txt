# Change Area Detection

Simple approach finding first differing line running both from the beginning and the end.

delete:

A                begin     0,3  => 0-0 / -
B    B
C    C
D    D

A    A           middle    1,1  => 1-2 / -
B    
C    
D    D

A    A           end       3,0  => 3-3 / - 
B    B
C    C
D

add:

     A           begin     0,3  => - / 0-0 
B    B
C    C
D    D

A    A           middle    1,1  => - / 1-2
     B
     C
D    D

A    A           end       3:4 / 3:5
B    B
C    C
     D


change:

A    a           begin     0:2 / 0:2
B    B
C    C
D    D

A    A           middel    1:4 / 1:4
B    b
C    c
D    D

A    A           end       3:5 / 3:5
B    B
C    C
D    d         


no differences:

A    A                     4:1 / 4:1
B    B
C    C
D    D

## Efficient Line Differences

Since very large files should be supported, detection of line differences must be fast.
VIM can compare lists as a whole much faster than walking over the lists and comparing the elements.

* use a binary search on arrays to find the first differing line from beginning/end
* only consider the first N lines where N is the number of lines of the shorter file
* split N by 2 and round down: M = floor(N/2)
* check old[0:M-1] == new[0:M-1]
* if different, first different line is in block 0..M-1, otherwise in M..N-1


