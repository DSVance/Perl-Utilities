#! perl.exe

# ------------------------------------------------------------------------------
# ---< Stocks.pl >--------------------------------------------------------------
# ------------------------------------------------------------------------------
#
# PURPOSE:  Retrieve prices from the internet for a list of stock symbols.
#
# LANGUAGE: Perl
#
# NOTES:    -  Stock quote information is retrieved from an online quote service
#              through a REST API.  Accessing the API requires registering for
#              an account and acquiring a access key that must be provided as
#              part of the URL that retrieves the quote data.  The key value is
#              stored in and retrieved from a separate file while building the
#              retrieval URL.  See BuildURL() and LoadServiceKey()
#
# EXAMPLES:
#
#   https://api.iex.cloud/v1/data/CORE/QUOTE/AVGO,INTC?token=pk_8*****bc4
#
#   $ StockQuotes.pl avgo intc
#    
#    ID  Symbol   Open       High       Low        Close      Price     Name
#    --  ------   -------    -------    -------    -------    -------   --------------
#     1   AVGO:   $927.84    $950.73    $910.36    $944.30    $944.30   Broadcom Inc
#     2   INTC:   $ 41.85    $ 42.95    $ 41.81    $ 42.70    $ 42.70   Intel Corp.
#              
# HISTORY:
# 08/02/2023 DSV - Initial development.
# 12/10/2023 DSV - Add ability to provide an alternate input symbol file.
#                - Add support for individual symbol entry on command line.
#                - Display company name in the quote output table.
#
# ------------------------------------------------------------------------------

use strict;
use warnings;
use File::Basename;
use REST::Client;
use JSON;
use Data::Dumper;

# Program Name and execution directory.
my ( $Directory, $ProgramName ) = $0 =~ m/(.*\\|.*\/)(.*)$/;

use constant TRUE  => 1;
use constant FALSE => 0;

# Flag to enable debug mode
my $Debug = "";
my $DebugSpacer =  ( ' ' x ( length ( $ProgramName ) + length ( "DEBUG: " ) ) );

# Call the main entry point
Main();



# ------------------------------------------------------------------------------
# ---< Main >-------------------------------------------------------------------
# ------------------------------------------------------------------------------
#
# PURPOSE:     Main entry point of the program.
#
# ARGUMENTS:   None.
#
# RETURNS:     None.
#
# NOTES:       The list of properties returned from a query for each symbol
#              along with a representative data value:
#
#              avgTotalVolume          => 6064579
#              calculationPrice        => close
#              change                  => 0.84
#              changePercent           => 0.00566
#              close                   => 149.38
#              closeSource             => official
#              closeTime               => 1691006592776
#              companyName             => Abbvie Inc
#              currency                => USD
#              delayedPrice            => 149.375
#              delayedPriceTime        => 1691006399589
#              extendedChange          => -0.18
#              extendedChangePercent   => -0.0012
#              extendedPrice           => 149.2
#              extendedPriceTime       => 1691062160522
#              high                    => 150.57
#              highSource              => 15 minute delayed price
#              highTime                => 1691006399589
#              iexAskPrice             => 0
#              iexAskSize              => 0
#              iexBidPrice             => 0
#              iexBidSize              => 0
#              iexClose                => 149.37
#              iexCloseTime            => 1691006396218
#              iexLastUpdated          => 0
#              iexMarketPercent        => undef
#              iexOpen                 => undef
#              iexOpenTime             => undef
#              iexRealtimePrice        => 0
#              iexRealtimeSize         => 0
#              iexVolume               => 0
#              isUSMarketOpen          => bless( do{\(my $o = 0)} JSON::PP::Boolean )
#              lastTradeTime           => 1691006399589
#              latestPrice             => 149.38
#              latestSource            => Close
#              latestTime              => August 2 2023
#              latestUpdate            => 1691006592776
#              latestVolume            => 3924975
#              low                     => 148.11
#              lowSource               => 15 minute delayed price
#              lowTime                 => 1690983000427
#              marketCap               => 263549592398
#              oddLotDelayedPrice      => 149.38
#              oddLotDelayedPriceTime  => 1691006398467
#              open                    => 148.65
#              openSource              => official
#              openTime                => 1690983198159
#              peRatio                 => 35.23
#              previousClose           => 148.54
#              previousVolume          => 4409838
#              primaryExchange         => NEW YORK STOCK EXCHANGE INC.
#              symbol                  => ABBV
#              volume                  => 0
#              week52High              => 164.38
#              week52Low               => 128.86
#              ytdChange               => -0.0422055054254713
#
#------------------------------------------------------------------------------

sub Main
{
   my @SymbolList = ();
   my $SymbolCount = 0;

   # Individual option enable flags
   my $OptionsRef =
   {
      'Debug'        => FALSE,
      'LoadList'     => FALSE,
      'RawData'      => FALSE,
      'ListFileName' => "StockSymbolList.txt",
      'KeyFileName'  => "IEXApiKey.txt"
   };

   # Process all command line arguments as needed
   ProcessCmdLine ( $OptionsRef, \@SymbolList );

   # Sort and remove duplicates from symbol list
   if ( $SymbolCount > 1 )
   {
      @SymbolList = sort ( @SymbolList );
      @SymbolList = Unique ( @SymbolList );
      $SymbolCount = scalar ( @SymbolList );
   }

   # Load more symbols from a list in a file if desired
   if ( $OptionsRef->{'LoadList'} == TRUE )
   {
      LoadSymbols ( "$Directory$OptionsRef->{'ListFileName'}", \@SymbolList );
   }
   $SymbolCount = scalar ( @SymbolList );

   unless ( $SymbolCount > 0 )
   {
      print ( "$ProgramName ERROR: No stock symbols found or provided" );
   }

   else
   {
      my $QuoteURL = BuildURL ( "$Directory$OptionsRef->{'KeyFileName'}", @SymbolList ); 

      my $Client = REST::Client->new();
      $Client->setTimeout ( 10 );
      $Client->GET ( $QuoteURL );
      my $Status = $Client->responseCode();
      print ( "$ProgramName DEBUG: GET request status = $Status \n" ) if ( $Debug );
      if ( $Status != 200 )
      {
         print ( "$ProgramName ERROR: The quote service request returned unsuccessful status code $Status \n" );
         print ( "$ProgramName: Service response - " . $Client->responseContent() . "\n" );
         if ( $Status >= 400 && $Status < 500 )
         {
            # Client side error
            print ( "$ProgramName: See key file $Directory$OptionsRef->{'KeyFileName'} to ensure your service access key is valid \n" );
         }
      }

      else
      {
         my $DecodedRef = decode_json ( $Client->responseContent() );

         if ( $Debug )
         {
            my $QuoteCount = scalar ( @$DecodedRef );
            print ( "$ProgramName DEBUG: Quote Count = $QuoteCount \n" );
         }

         printf "\n%s  %s   %s       %s       %s        %s      %s     %s \n", 
               'ID',
               'Symbol',
               'Open',
               'High',
               'Low',
               'Close',
               'Price',
               'Name'
               ;

         printf "%s  %s   %s    %s    %s    %s    %s   %s \n",
               '--',
               '------',
               '-------',
               '-------',
               '-------',
               '-------',
               '-------',
               '---------------------------------------'
               ;

         my $ID = 0;
         foreach my $HashRef ( @$DecodedRef )
         {
            $ID++;
            printf "%2d  % 5s:   \$%6.2f    \$%6.2f    \$%6.2f    \$%6.2f    \$%6.2f   %s \n", 
                  $ID,
                  ${$HashRef}{'symbol'}, 
                  defined ( ${$HashRef}{'open'} )        ? ${$HashRef}{'open'}        : 0,
                  defined ( ${$HashRef}{'high'} )        ? ${$HashRef}{'high'}        : 0,
                  defined ( ${$HashRef}{'low'} )         ? ${$HashRef}{'low'}         : 0,
                  defined ( ${$HashRef}{'close'} )       ? ${$HashRef}{'close'}       : 0,
                  defined ( ${$HashRef}{'latestPrice'} ) ? ${$HashRef}{'latestPrice'} : 0,
                  defined ( ${$HashRef}{'companyName'} ) ? ${$HashRef}{'companyName'} : " "
                  ;

            if ( $OptionsRef->{'RawData'} == TRUE )
            {
               print ( "Raw data for ${$HashRef}{'symbol'}: \n" );
               print ( Dumper ( $HashRef ) . "\n" );
            }
         }
      }
   }
}

# ---< /Main >------------------------------------------------------------------


# ------------------------------------------------------------------------------
# ---< ProcessCmdLine >---------------------------------------------------------
# ------------------------------------------------------------------------------
#
# PURPOSE:     Retreives and processes each command line argument as needed.
#
# ARGUMENTS:   OptionsRef - Multi-field structure for argument & option values.
#
#              SymbolListRef - Reference to the list/array to add symbols to.
#
# RETURNS:     None.
#
# NOTES:
#
#------------------------------------------------------------------------------

sub ProcessCmdLine
{
   my ( $OptionsRef, $SymbolListRef ) = @_;
   my ( $Arg, $ArgCount, $Usage );

   $Usage ="PURPOSE: Retrieve a price quote for one or more specified stock symbols.        \n" .
           "\n" .
           "USAGE:   $0 <switches>                                                          \n" .
           "\n" .
           "             -d[ebug]   Enabled debug mode.                                     \n" .
           "\n" .
           "             -h[elp]    Displays help & usage text.                             \n" .
           "\n" .
           "             -l[ist]    Report on stock symbols listed one per line in a file.  \n" .
           "                        The default file name is $OptionsRef->{'ListFileName'}  \n" .
           "                        See the -f[ile] switch to specify a list file name.     \n" .
           "\n" .
           "             -f[ile]    Name of the file to load a list of stock symbols from.  \n" .
           "                        Automatically implies use of the -list switch.          \n" .
           "\n" .
           "             -r[aw]     Dispaly the raw data from the query response.  This is  \n" .
           "                        only valid when directly specifying a single stock      \n" .
           "                        symbol on the command line and has no effect when used  \n" .
           "                        in combination with the -list and/or -file options.     \n" .
           "\n" .
           "             AAAA       A single stock symbol to report on.  A symbol is 1 to 4 \n" .
           "                        A-Z characters (case insensitive). Multiple individual  \n" .
           "                        symbols may be specified on a single command line.      \n" .
           "\n" .  
           "SUPPORT: Scott Vance - scottvance4596\@gmail.com                                \n" .
           "\n" ;

   # First check exclusively for the HELP switch.
   for ( $ArgCount = 0; $ArgCount <= $#ARGV; $ArgCount++ )
   {
      # Check for the HELP switch.  Display usage if found.
      if ( $ARGV[$ArgCount] =~ m/^(-|\/)(\?|h|help)$/i )
      {
         print ( "\n$Usage" );
         exit;
      }
   }

   # Next check exclusively for the DEBUG switch.
   for ( $ArgCount = 0; $ArgCount <= $#ARGV; $ArgCount++ )
   {
      if ( $ARGV[$ArgCount] =~ m/^(-|\/)(d|debug)$/i )
      {
         $Debug = $ARGV[$ArgCount];
         $OptionsRef->{ 'Debug' } = TRUE;

         # Warn user that Debug is enabled
         print ( "$ProgramName: Debug mode is enabled \n" );

         # Remove the debug flag from argument array and reset
         # the argument count to reflect the deletion
         splice ( @ARGV, $ArgCount, 1 );
         $ArgCount = scalar ( @ARGV );
         $ArgCount--;
      }
   }

   # Ensure that there are more arguments
   unless ( $ArgCount > 0 )
   {
         print ( "\n$Usage" );
         exit;
   }

   # Now process all other arguments.
   for ( $ArgCount = 0; $ArgCount <= $#ARGV; $ArgCount++ )
   {
      $Arg = $ARGV[$ArgCount];

      # --- Check for the LIST switch ---
      if ( $Arg =~ m/^(-|\/)(l|list)$/i )
      {
         $OptionsRef->{'LoadList'} = TRUE;
      }

      # --- Check for the FILE switch ---
      elsif ( $Arg =~ m/^(-|\/)(f|file)$/i )
      {
         unless ( defined ( $ARGV[$ArgCount + 1] ) )
         {
             print ( "$ProgramName ERROR: No value found after $ARGV[$ArgCount] switch \n" );
             $OptionsRef->{'ListFileName'} = "";
         }

         else
         {
            $ArgCount++;
            $Arg = $ARGV[$ArgCount];
            $OptionsRef->{'ListFileName'} = $Arg;
            $OptionsRef->{'LoadList'} = TRUE;
         }
      }

      # --- Check for the RAW switch ---
      elsif ( $Arg =~ m/^(-|\/)(r|raw)$/i )
      {
         $OptionsRef->{'RawData'} = TRUE;
         print ( "$ProgramName: Raw data mode is enabled \n" );
      }

      # --- Check for unrecognized switches ---
      elsif ( $Arg =~ m/^\-/i )
      {
         print ( "$ProgramName ERROR: Unrecognized switch \"$Arg\" \n" );
      }

      # --- Check for stock symbols ---
      elsif ( $Arg =~ m/^\s*([a-zA-Z]{1,4})/ )
      {
         $Arg = uc ( $Arg ); 
         push ( @$SymbolListRef, $Arg );
         print ( "$ProgramName: Added '$Arg' to stock symbol list \n" ) if ( $Debug );
      }

      # --- Anything remaining is not recognized as a valid input ---
      else
      {
         print ( "$ProgramName ERROR: Unrecognized argument \"$Arg\". \n" );
      }
   }

   if (  $OptionsRef->{'LoadList'} == TRUE )
   {
      $OptionsRef->{'RawData'} = FALSE;
      print ( "$ProgramName WARNING: Raw data mode was overridden by other options \n" );

   }
}

# ---< /ProcessCmdLine >--------------------------------------------------------


# ------------------------------------------------------------------------------
# ---< LoadSymbols >------------------------------------------------------------
# ------------------------------------------------------------------------------
#
# PURPOSE:     Load a list of stock symbols from a file.
#
# ARGUMENTS:   InputFileName - The name of the file to load symbols from.
#
#              SymbolListRef - Reference to the list/array to add symbols to.
#
# RETURNS:     None
#
# NOTES:       - The input file is expected to contain a list of stock sybols
#                with each being between 1 and 4 characters long, and appearing
#                on a single line by itself.  Blank lines (or lines with only
#                whitspace) are ignored, as are lines that begin with '#'.
#
#------------------------------------------------------------------------------

sub LoadSymbols
{
   my ( $InputFileName, $SymbolListRef ) = @_;

   unless ( open ( INFILE, "<$InputFileName" ) )
   {
      print ( "$ProgramName ERROR: Unable to open symbol list file $InputFileName \n");
   }

   else
   {
      my $Line = "";
      my $LineCount = 0;
      my @FileSymbolList = ();
      my $FileSymbolCount = 0;


      while ( $Line = <INFILE> )
      {
         $LineCount++;
         if ( $Line =~ m/^\s*$/ || $Line =~ m/^\s*#.*$/ )
         {
            print ( "$ProgramName DEBUG: Skipped line $LineCount: $Line" ) if ( $Debug );
         }

         elsif ( $Line =~ m/^\s*([a-zA-Z]{1,4})(?:\s|#)/ ) 
         {
            push ( @FileSymbolList, uc ( $1 ) )
         }

         else
         {
            print ( "$ProgramName WARNING: Ignoring invalid entry on line $LineCount: $Line" );
         }
      }
      close ( INFILE );

      $FileSymbolCount = scalar ( @FileSymbolList );
      @FileSymbolList = sort ( @FileSymbolList );

      if ( $Debug )
      {
         printf ( "$ProgramName DEBUG: Loaded $FileSymbolCount symbols from $InputFileName \n" );
         foreach my $Symbol ( @FileSymbolList )
         {
            print ( "$DebugSpacer >>> $Symbol \n" );
         }
      }

      # Add symbols from file to the master list of symbols.
      push ( @$SymbolListRef, @FileSymbolList );
      @$SymbolListRef = sort ( @$SymbolListRef );
      @$SymbolListRef = Unique ( @$SymbolListRef );
   }
}

# ---< /LoadSymbols >-----------------------------------------------------------


# ------------------------------------------------------------------------------
# ---< BuildURL >---------------------------------------------------------------
# ------------------------------------------------------------------------------
#
# PURPOSE:     Retreives and processes each command line argument as needed.
#
# ARGUMENTS:   Symbol - the stock symbol to build a quote-URL for.
#
# RETURNS:     The URL to use for retrieving a quote for the specified symbol.
#
# NOTES:       An example of a valid URL for the latest price for symbol RIO:
#              https://api.iex.cloud/v1/data/CORE/QUOTE/AVGO,?token=pk_8*****bc4
#
#-------------------------------------------------------------------------------

sub BuildURL
{
   my ( $KeyFileName, @SymbolArray ) = @_;
   my $URL = "";

   my $SymbolCount = scalar @SymbolArray;
   if ( ! ( $SymbolCount > 0 ) )
   {
      print ( "$ProgramName ERROR: A symbol is required" );
   }

   else
   {
      my $SymbolList = "";
      foreach my $Symbol ( @SymbolArray )
      {
         $SymbolList = $SymbolList . $Symbol . ",";
      }

      print ( "$ProgramName DEBUG: Symbol List = $SymbolList \n" ) if ( $Debug );

      my $IEXApis = "https://api.iex.cloud/v1/data/CORE/QUOTE";
      my $IEXApiKey = LoadServiceKey ( $KeyFileName );

      $URL = "$IEXApis/$SymbolList?token=$IEXApiKey";
      print ( "$ProgramName: URL = $URL \n" ) if ( $Debug );
   }

   return $URL;
}

# ---< /BuildURL >--------------------------------------------------------------


# ------------------------------------------------------------------------------
# ---< LoadServiceKey >---------------------------------------------------------
# ------------------------------------------------------------------------------
#
# PURPOSE:     Load a list of stock symbols from a file.
#
# ARGUMENTS:   InputFileName - The name of the file to load the key from.
#
# RETURNS:     The access key string for the stock quote service.
#
# NOTES:       - Blank lines (or lines with only whitspace) are ignored, as are
#                lines that begin with '#'.  Other than those, the input file is
#                expected to contain a SINGLE line of text that is the stock
#                quote service's access key value.
#
#------------------------------------------------------------------------------

sub LoadServiceKey
{
   my ( $InputFileName ) = @_;
   my $KeyValue;

   unless ( open ( INFILE, "<$InputFileName" ) )
   {
      print ( "$ProgramName ERROR: Unable to open service key file $InputFileName \n");
   }

   else
   {
      while ( my $Line = <INFILE> )
      {
         unless ( $Line =~ m/^\s*$/ || $Line =~ m/^\s*#.*$/ )
         {
            $KeyValue = $Line;
         }
      }
      close ( INFILE );

      print ( "$ProgramName DEBUG: Quote service key = $KeyValue \n" ) if ( $Debug );
   }

   return $KeyValue;
}

# ---< /LoadServiceKey >--------------------------------------------------------



# ------------------------------------------------------------------------------
# ---< Unique >-----------------------------------------------------------------
# ------------------------------------------------------------------------------
#
# PURPOSE:     Filter an array down to the set of unique values
#
# ARGUMENTS:   An array of values.
#
# RETURNS:     An array with unique values.
#
# NOTES:
#
# ------------------------------------------------------------------------------

sub Unique
{
    my %seen;
    grep !$seen{$_}++, @_;
}

# ---< /Unique >----------------------------------------------------------------
