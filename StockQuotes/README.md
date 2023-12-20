```
PURPOSE: Retrieve a price quote for one or more specified stock symbols.

USAGE:   StockQuotes.pl <switches>

             -d[ebug]   Enabled debug mode.

             -h[elp]    Displays help & usage text.

             -l[ist]    Report on stock symbols listed one per line in a file.
                        The default file name is StockSymbolList.txt
                        See the -f[ile] switch to specify a list file name.

             -f[ile]    Name of the file to load a list of stock symbols from.
                        Automatically implies use of the -list switch.

             -r[aw]     Dispaly the raw data from the query response.  This is
                        only valid when directly specifying a single stock
                        symbol on the command line and has no effect when used
                        in combination with the -list and/or -file options.

             AAAA       A single stock symbol to report on.  A symbol is 1 to 4
                        A-Z characters (case insensitive). Multiple individual
                        symbols may be specified on a single command line.
```
