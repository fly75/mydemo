000100180514**FREE
000101180514
000102180514 ctl-opt
000103180514 DFTACTGRP(*NO) actgrp(*NEW) BNDDIR('IFIAPI')  EXTBININT(*YES)  option(*NOXREF:*NOEXPDDS:*NODEBUGIO:*NOSHOWCPY);
000104180514
000105180514//========================================================================
000106180514// Program: MY_DBXSum1
000107180514//           print Direct Bill Transaction Summary for select bond renewals
000108180514//  requires
000109180514//           IFIAPI
000110180514//           SQLERRCHK
000111180514//========================================================================
000112180514
000113180514dcl-f fbpm0000 disk(*EXT) usage(*INPUT) KEYED;
000114180514
000115180514// get prototypes from copy source
000116180514//
000117180514/INCLUDE SQLERRCHKH
000118180514//
000119180514dcl-s mySQLStatus   char(3);
000120180514
000121180514//
000122180514/INCLUDE IFIPRTH
000123180514//
000124180514dcl-s  testdate     char(10);
000125180514dcl-s  pgmlib       char(20);
000126180514dcl-s  reportTitle  char(60);
000127180514dcl-s  columnHeadings char(132);
000128180514dcl-s  detail         char(132);
000129180514
000130180514//
000131180514dcl-ds SpoolID QUALIFIED;
000132180514  jobname    char(10);
000133180514  username   char(10);
000134180514  jobnbr     zoned(6:0);
000135180514  filename   char(10);
000136180514  spoolnbr   uns(5);
000137180514end-ds;
000138180514
000139180514//
000140180514dcl-ds PgmSts PSDS QUALIFIED;
000141180514  Proc             *PROC;
000142180514  StatusCode       *STATUS;
000143180514  Library          char(10) pos(81);
000144180514  jobname          char(10) pos(244);
000145180514  jobuser          char(10) pos(254);
000146180514  jobnumber        zoned(6:0) pos(264);
000147180514end-ds;
000148180514
000149180514dcl-ds DBXSummary qualified;
000150180514  cdbranch  char(2);
000151180514  cdcarrier char(2);
000152180514  cdprogram char(2);
000153180514  nubond    zoned(7:0);
000154180514  nubondre  zoned(2:0);
000155180514end-ds;
000156180514
000157180514dcl-ds Bond extname('FBPM0000':*ALL) Qualified prefix('':4);
000158180514END-DS;
000159180514
000160180514dcl-ds  StatementItem qualified;
000161180514  Source     char(3);
000162180514  XType      char(4);
000163180515  XAcctDt    date;
000164180514  XDate      date;
000165180514  cdbranch   char(2);
000166180514  cdcarrier  char(2);
000167180514  cdprogram  char(2);
000168180514  nubond     zoned(7:0);
000169180514  nubondre   zoned(2:0);
000170180514  nubonden   zoned(4:0);
000171180514  cdagent    char(6);
000172180514  XAmt       zoned(13:2);
000173180514  idlink     char(32);
000174180514  flbill     char(1);
000175180514  flbillw    char(2);
000176180514  ampremnet  zoned(13:2);
000177180514  APFlag     char(1);
000178180514  cdprinc    char(6);
000181180514  tpcash     char(1);
000182180514  florigin   char(2);
000183180514  nucheck    char(16);
000184180514  dsline1    char(38);
000185180514  cdfinanc   char(2);
000186180514end-ds;
000224180514
000225180514dcl-ds DBItem qualified;
000226180514  cdbranch   char(2);
000227180514  cdcarrier  char(2);
000228180514  cdprogram  char(2);
000229180514  nubond     zoned(7:0);
000230180514  nubondre   zoned(2:0);
000231180514  nubonden   zoned(4:0);
000232180514  Source     char(3);
000233180514  amnetdue   zoned(13:2);
000234180514  nucheck    char(16);
000235180514  invkid     char(10);
000236180514  edate      zoned(8:0);
000237180514  region     char(2);
000238180514  prtid      char(1);
000239180514end-ds;
000240180514
000241180514dcl-ds Check QUALIFIED;
000242180514  CompanyID      zoned(3:0);
000243180514  BankAccountID  zoned(3:0);
000244180516  Number         zoned(7:0);
000245180514  Amount         zoned(11:2);
000246180514  Vendor         zoned(6:0);
000247180514  Payee          char(30);
000248180514  Type           char(1);
000249180516  Date           date;
000250180514end-ds;
000251180514
000252180515dcl-ds DBAgtChecks DIM(10) QUALIFIED;
000253180516  Date           date;
000254180516  Vendor         zoned(6:0);
000255180516  Payee          char(30);
000256180516  Number         zoned(7:0);
000257180516  Amount         zoned(11:2);
000258180516  XAmount        zoned(11:2);
000259180515END-DS;
000260180515
000261180515dcl-s DBAgtPayCount  uns(5) inz(0);
000262180515
000263180514dcl-s rowin   int(10) inz(0);
000264180514dcl-s prvglppgm  char(10);
000265180514dcl-s printPGM   char(10);
000266180514dcl-s Today date;
000267180514dcl-s RunDate  date;
000268180514dcl-s acode  char(6);
000269180514dcl-s pcode  char(6);
000270180514dcl-s name           char(30);
000271180514dcl-s workDate       date;
000272180514dcl-s PremAmt        zoned(13:2);
000273180514dcl-s CommAmt        zoned(13:2);
000274180514dcl-s wcheck         packed(17:0);
000275180514dcl-s tcheck         packed(7:0);
000276180514dcl-s NetCashBal    zoned(13:2);
000277180515dcl-s NetSuspBal    zoned(13:2);
000278180515dcl-s NetBalance    zoned(13:2);
000279180514dcl-s AgentCashPaid  zoned(13:2);
000280180514dcl-s PrincipalCashPaid zoned(13:2);
000281180514dcl-s AgentCashRcvd  zoned(13:2);
000282180514dcl-s PrincipalCashRcvd zoned(13:2);
000283180515dcl-s PrincipalUnprocessed zoned(13:2);
000284180515dcl-s AgentUnprocessed zoned(13:2);
000285180514
000286180514  EXEC SQL
000287180514    SET OPTION COMMIT=*NONE, datfmt=*ISO;
000288180514  pgmlib = pgmSts.Proc+PGmSts.Library;
000289180514  today = %date();
000290180514  Testdate = %char(today);
000291180514  reportTitle = 'Direct Bill Activity Summary';
000292180514  IFIPRT_initialize(pgmlib:Testdate:reportTitle);
000293180514  columnHeadings = *BLANKS;
000294180514  %subst(columnHeadings:8:8) = 'Bond ID';
000295180514  IFIPRT_setColumnHeadings(columnHeadings);
000296180514  printPGM = '1';
000297180514
000298180514  //
000299180514  openDBXSummary();
000300180514  fetchNextDBXSummary();
000301180514  mySQLStatus = SQLErrChk( 'fetch first DBXSummary' );
000302180514
000303180514  DOW ( mySQLStatus ='OK' ) or ( mySQLStatus ='WRN');
000304180514    rowin += 1;
000305180514
000306180514    IFIPRT_SetNewPage();
000307180514    processDBXSummary();
000308180514
000309180514    // get next bond
000310180514    fetchNextDBXSummary();
000311180514    mySQLStatus = SQLErrChk( 'fetch next DBXSummary' );
000312180514    if ( mySQLStatus ='EOD' ) or ( mySQLStatus ='ERR');
000313180514      leave;
000314180514    ENDIF;
000315180514  ENDDO;
000316180514
000317180514  //close program
000318180514  closeDBXSummary();
000319180514  IFIPRT_SetNewPage();
000320180514  detail='End of Report.';
000321180514  IFIPRT_printDetail(detail:'3');
000322180514
000323180514  //
000324180514  IFIPRT_SetNewPage();
000325180514  detail='Bond Summary End of Report.';
000326180514  IFIPRT_printDetail(detail:'3');
000327180514
000328180514  IFIPRT_close();
000329180514  *inlr=*on;
000330180514  return;
000331180514
000332180514//--------------------------------------------------------------------------
000333180514//
000334180515dcl-proc OpenDBXSummary;
000335180514
000336180514 EXEC SQL
000337180514   DECLARE C1 CURSOR FOR
000338180514     SELECT DISTINCT cdbranch,cdcarrier,cdprogram,nubond,nubondre
000339180514     FROM jjcwork.DBXProblems
000340180514     ORDER BY cdbranch,cdcarrier,cdprogram,nubond,nubondre
000341180514     FOR READ ONLY;
000342180514 //
000343180514  EXEC SQL
000344180514    OPEN C1;
000345180514  mySQLStatus = SQLErrChk( 'open DBX Summary' );
000346180514  if ( mySQLStatus ='OK' ) or ( mySQLStatus ='WRN');
000347180514  endif;
000348180514
000349180514end-proc;
000350180514//--------------------------------------------------------------------------
000351180514//
000352180514dcl-proc closeDBXSummary;
000353180514
000354180514
000355180514 EXEC SQL
000356180514   CLOSE C1;
000357180514  mySQLStatus = SQLErrChk( 'Close DBXSummary' );
000358180514
000359180514end-proc;
000360180514//--------------------------------------------------------------------------
000361180514//
000362180514dcl-proc fetchNextDBXSummary;
000363180514
000364180514 exec SQL
000365180514     FETCH NEXT FROM c1 into :DBXSummary;
000366180514
000367180514end-proc;
000368180514
000369180514//--------------------------------------------------------------------------
000370180514//
000371180514 dcl-proc processDBXSummary;
000372180514
000373180514 // Bond Details
000374180514 printBondDetails(DBXSummary.cdbranch
000375180514                 :DBXSummary.cdcarrier
000376180514                 :DBXSummary.cdprogram
000377180514                 :DBXSummary.nubond
000378180514                 :DBXSummary.nubondre
000379180514                  );
000380180514
000381180514 // clear Cash Flow totals
000382180514 netCashBal = 0;
000383180515 netSuspBal = 0;
000384180515 netBalance = 0;
000385180514 AgentCashPaid = 0;
000386180514 AgentCashRcvd = 0;
000387180514 PrincipalCashPaid = 0;
000388180514 PrincipalCashRcvd = 0;
000389180515 PrincipalUnprocessed = 0;
000390180515 AgentUnprocessed = 0;
000391180515 clear DBagtChecks;
000392180515 DBAgtPayCount = 0;
000393180514 // Statement Items
000394180514 printStatementItems(DBXSummary.nubond:DBXSummary.nubondre);
000395180515
000396180515 detail = *blanks;
000397180515 %subst(detail:30:11) = 'Cash';
000398180515 %subst(detail:42:20) = %editc(NetCashBal:'A');
000399180515 IFIPRT_printDetail(detail:'1');
000400180515 detail = *blanks;
000401180515 %subst(detail:30:11) = 'Suspense';
000402180515 %subst(detail:42:20) = %editc(NetSuspBal:'A');
000403180515 IFIPRT_printDetail(detail);
000404180515 detail = *blanks;
000405180515 %subst(detail:30:11) = 'Net Balance';
000406180515 %subst(detail:42:20) = %editc(NetBalance:'A');
000407180515 IFIPRT_printDetail(detail);
000408180515
000409180514 // Direct Bill Items
000410180514 printDBItems(DBXSummary.nubond:DBXSummary.nubondre);
000411180514
000412180514 // print Cash Flow totals
000413180514 detail = *ALL'-';
000414180514 %subst(detail:1:20) = 'Cash Flow Analysis';
000415180515 IFIPRT_printDetail(detail:'2':'1');
000416180514
000417180514 detail = *blanks;
000418180515 %subst(detail:2:5) = 'Party';
000419180515 %subst(detail:17:9) = 'Cash Paid';
000420180515 %subst(detail:33:13) = 'Cash Received';
000421180515 %subst(detail:58:8) = 'Cash Net';
000422180515 %subst(detail:74:12) = 'Unprocessed';
000423180515 %subst(detail:102:4) = 'Bond';
000424180515  %subst(detail:126:3) = 'Due';
000425180514 IFIPRT_printDetail(detail);
000426180514
000427180514 detail = *blanks;
000428180515 %subst(detail:1:10) = 'Principal';
000429180515 %subst(detail:11:20) = %editc(PrincipalCashPaid:'A');
000430180515 %subst(detail:31:20) = %editc(PrincipalCashRcvd:'A');
000431180515 %subst(detail:51:20) = %editc(PrincipalCashPaid+PrincipalCashRcvd:'A');
000432180515 %subst(detail:71:20) = %editc(PrincipalUnprocessed:'A');
000433180515 %subst(detail:91:20) = %editc(PremAmt:'A');
000434180517 %subst(detail:111:20) = %editc(%dec(PremAmt-(PrincipalCashPaid+PrincipalCashRcvd):13:2):'A');
000435180515 IFIPRT_printDetail(detail:'1':'1');
000436180514
000437180514 detail = *blanks;
000438180514 %subst(detail:1:10) = 'Agent';
000439180515
000440180515
000441180515 %subst(detail:11:20) = %editc(AgentCashPaid:'A');
000442180515 %subst(detail:31:20) = %editc(AgentCashRcvd:'A');
000443180515 %subst(detail:51:20) = %editc(AgentCashPaid+AgentCashRcvd:'A');
000444180515 %subst(detail:71:20) = %editc(AgentUnprocessed:'A');
000445180515 %subst(detail:91:20) = %editc(-CommAmt:'A');
000446180517 %subst(detail:111:20) = %editc(%dec(-CommAmt-(AgentCashPaid+AgentCashRcvd+AgentUnprocessed):13:2):'A');
000447180515 IFIPRT_printDetail(detail:'1':'1');
000448180515
000449180514 end-proc;
000450180514//--------------------------------------------------------------------------
000451180514//
000452180514
000453180514dcl-proc printBondDetails;
000454180514
000455180514dcl-pi *N;
000456180514  pbranch   char(2);
000457180514  pcarrier  char(2);
000458180514  pprogram  char(2);
000459180514  pbond     zoned(7:0);
000460180514  pbondren  zoned(2:0);
000461180514end-pi;
000462180514
000463180514//
000464180514
000465180514 chain  (pbranch:pcarrier:pprogram:pbond:pbondren) fbpm0000re bond;
000466180514
000467180514 pcode = bond.prnclt+%editc(bond.prncno:'X');
000468180514 acode = bond.prdclt+%editc(bond.prdcno:'X');
000469180514
000470180514 fetchPremStats( DBXSummary.nubond
000471180514                  : DBXSummary.nubondre
000472180514                  : premAmt
000473180514                  : CommAmt);
000474180514
000475180514 detail = *blanks;
000476180514 %subst(detail:1:2) = bond.bbran;
000477180514 %subst(detail:3:2) = bond.bcarr;
000478180514 %subst(detail:5:2) = bond.bprog;
000479180514 %subst(detail:8:7) = %editc(bond.bndno:'X');
000480180514 %subst(detail:16:2) = %editc(bond.bndren:'X');
000481180514 %subst(detail:20:15) = %editc(bond.bndamn:'1');
000482180514 %subst(detail:51:33) = bond.oblgnm;
000483180514 IFIPRT_printDetail(detail);
000484180514
000485180514 detail = *blanks;
000486180514 %subst(detail:20:10) = 'Effective:';
000487180514 workDate = convertDate(bond.effcc:bond.effyy:bond.effmm:bond.effdd);
000488180514 %subst(detail:31:10) = %CHAR(workDate:*USA);
000489180514 %subst(detail:44:6) = bond.prnclt+%editc(bond.prncno:'X');
000490180514 %subst(detail:51:30) = getName(bond.prnclt:bond.prncno);
000491180514 %subst(detail:85:30) = 'Premium:    ' + %editc(PremAmt:'N');
000492180514 IFIPRT_printDetail(detail);
000493180514 detail = *blanks;
000494180514 %subst(detail:20:10) = 'Expiring :';
000495180514 workDate = convertDate(bond.expcc:bond.expyy:bond.expmm:bond.expdd);
000496180514 %subst(detail:31:10) = %CHAR(workDate:*USA);
000497180514 %subst(detail:44:6) = bond.prdclt+%editc(bond.prdcno:'X');
000498180514 %subst(detail:51:30) = getName(bond.prdclt:bond.prdcno);
000499180514 %subst(detail:85:30) = 'Commission: ' + %editc(CommAmt:'N');
000500180514 IFIPRT_printDetail(detail);
000501180514 return;
000502180514
000503180514end-proc;
000504180514//--------------------------------------------------------------------------
000505180514//
000506180514dcl-proc printStatementItems;
000507180514dcl-pi *N;
000508180514  pnubond  zoned(7:0);
000509180514  pnubondre zoned(2:0);
000510180514end-pi;
000511180517dcl-s this_Acode char(6);
000512180514
000513180514 //TODO:
000514180514 openStatementItems(pnubond:pnubondre);
000515180514 //
000516180514
000517180514 detail = *ALL'-';
000518180514 %subst(detail:1:18) = 'Statement Entries ';
000519180514 IFIPRT_printDetail(detail:'2':'1');
000520180514 fetchNextStatementItem();
000521180514 mySQLStatus = SQLErrChk( 'fetch first Statement Item' );
000522180514
000523180514 DOW ( mySQLStatus ='OK' ) or ( mySQLStatus ='WRN');
000524180514   // accumulate net cash balance
000525180515   netBalance += StatementItem.Xamt;
000526180514   //
000527180514   detail = *blanks;
000528180514   %subst(detail:1:4) = %editc(StatementItem.nubonden:'X');
000529180514   %subst(detail:6:10) = %char(StatementItem.XDAte:*USA);
000530180514   %subst(detail:18:4) = StatementItem.Xtype;
000531180515
000532180515   %subst(detail:42:20) = %editc(StatementItem.xamt:'A');
000533180515   %subst(detail:62:16) = %subst(StatementItem.idlink:1:16);
000534180514
000535180514   select;
000536180514
000537180516     WHEN StatementItem.Source='A/R';
000538180515       %subst(detail:22:20) = %editc(StatementItem.ampremnet:'A');
000539180515       %subst(detail:79:1) = StatementItem.flbill;
000540180515       %subst(detail:80:1) = StatementItem.flbillw;
000541180515       // Agent and principal are swapped on direct bill A/R item
000542180514       if (StatementItem.apflag='P');
000543180515         %subst(detail:82:6) = StatementItem.cdagent;
000544180514       else;
000545180515         %subst(detail:82:6) = StatementItem.cdprinc;
000546180514       endif;
000547180515       // %subst(detail:89:1) = StatementItem.apflag;
000548180515
000549180516     WHEN StatementItem.Source='CSH';
000550180515       select;
000551180514         when (%subst(StatementItem.xtype:3:2)='AC');
000552180514           PrincipalCashRcvd += StatementItem.xamt;
000553180514       ENDSL;
000554180515       // accumulate net cash balance
000555180515       netcashBal += StatementItem.Xamt;
000556180517
000558180517       // closer look at disbursement details
000559180514       if (%subst(StatementItem.Xtype:3:2)='DI');
000560180514         wcheck =  %dec(%trim(StatementItem.nucheck):17:0);
000561180514         tcheck =  wcheck;
000562180514         getCheckDetails(tcheck:Check);
000563180516         %subst(detail:79:7) = %editc(check.Number:'X');
000564180516         %subst(detail:87:10) = %char(Check.Date:*USA);
000565180514         %subst(detail:98:10) = %editc(check.CompanyID:'X')
000566180514                              +'-'+%editc(check.vendor:'X');
000567180514         %subst(detail:109:20) = %subst(check.payee:1:20);
000568180517         This_Acode = getACode_BondEndorsement(DBXSummary.cdbranch
000569180517                 :DBXSummary.cdcarrier
000570180517                 :DBXSummary.cdprogram
000571180517                 :DBXSummary.nubond
000572180517                 :DBXSummary.nubondre
000573180517                 :StatementItem.nubonden );
000574180517
000575180517         if (getAgentVendorID(This_Acode)=check.vendor);
000576180514           AgentCashPaid += StatementItem.xamt;
000577180516           addAgentPayment(check:StatementItem.xamt);
000578180514         else;
000579180514           PrincipalCashPaid += StatementItem.xamt;
000580180514         endif;
000581180514       else;
000582180514         %subst(detail:79:16) = StatementItem.nucheck;
000583180514         %subst(detail:95:38) = StatementItem.dsline1;
000584180514       endif;
000585180514
000586180516     WHEN StatementItem.Source='SUS';
000587180515       //
000588180515       netSuspBal += StatementItem.xamt;
000589180515       // %subst(detail:74:1) = StatementItem.tpcash;
000590180515       // %subst(detail:76:2) = StatementItem.florigin;
000591180514       if (%subst(StatementItem.xtype:3:2)='DI') and (%trim(StatementItem.idlink)<>'** PAS **');
000592180514         wcheck =  %dec(%trim(StatementItem.nucheck):17:0);
000593180514         tcheck =  wcheck;
000594180514         getCheckDetails(tcheck:Check);
000595180516         %subst(detail:79:7) = %editc(check.Number:'X');
000596180516         %subst(detail:87:10) = %char(Check.Date:*USA);
000597180514         %subst(detail:98:10) = %editc(check.CompanyID:'X')
000598180514                              +'-'+%editc(check.vendor:'X');
000599180514         %subst(detail:109:20) = %subst(check.payee:1:20);
000600180514
000601180514       else;
000602180514         %subst(detail:79:16) = StatementItem.nucheck;
000603180514         %subst(detail:95:38) = StatementItem.dsline1;
000604180514       endif;
000605180514
000606180514   endsl;
000607180514
000608180514   IFIPRT_printDetail(detail);
000609180514   //
000610180514   fetchNextStatementItem();
000611180514   mySQLStatus = SQLErrChk( 'fetch next Statement Item' );
000612180514   if ( mySQLStatus ='EOD' ) or ( mySQLStatus ='ERR');
000613180514     leave;
000614180514   ENDIF;
000615180514 ENDDO;
000616180514 closeStatementItems();
000617180514 return;
000618180514
000619180514end-proc;
000620180514//--------------------------------------------------------------------------
000719180514//
000720180514dcl-proc printDBItems;
000721180514
000722180514dcl-pi *N;
000723180514  pnubond  zoned(7:0);
000724180514  pnubondre zoned(2:0);
000725180514end-pi;
000726180516dcl-s i int(5);
000727180516
000735180516
000736180514 openDBItem(DBXSummary.nubond:DBXSummary.nubondre);
000737180514 detail = *ALL'-';
000738180514 %subst(detail:1:30) = 'Direct Bill Agent Commission ';
000739180514 IFIPRT_printDetail(detail:'2':'1');
000740180516
000741180516 if DBAgtPayCount=0;
000742180516   IFIPRT_printDetail('** No Payments Found **':'1':'1');
000743180516 else;
000744180516   IFIPRT_printDetail('** Payments Found **':'1':'1');
000745180516   for i = 1 to DBAgtPayCount;
000746180516     detail = *blanks;
000747180517     %subst(detail:13:10) = %char(DBAgtChecks(i).date:*USA);
000748180517     %subst(detail:24:6) = %editc(DBAgtChecks(i).vendor:'X');
000749180517     %subst(detail:31:30) = DBAgtChecks(i).payee;
000750180517     %subst(detail:62:7) = %editc(DBAgtChecks(i).number:'X');
000751180517     %subst(detail:82:16) =  %editc(DBAgtChecks(i).XAmount:'A');
000752180517     %subst(detail:100:20) =  %editc(DBAgtChecks(i).Amount:'A');
000753180516     IFIPRT_printDetail(detail:'1':'1');
000754180516   endfor;
000755180516 endif;
000756180516 IFIPRT_printDetail('** Payments Expected **':'1':'1');
000757180514 fetchNextDBItem();
000758180514 mySQLStatus = SQLErrChk( 'fetch first DB Item' );
000759180514
000760180514 DOW ( mySQLStatus ='OK' ) or ( mySQLStatus ='WRN');
000761180514   //
000762180514   detail = *blanks;
000763180514   %subst(detail:1:3) = DBItem.Source;
000764180517   %subst(detail:5:1) = DBitem.prtid;
000765180517   %subst(detail:15:10) = %editc(DBitem.edate:'X');
000766180517   %subst(detail:34:12) = DBitem.invkid;
000767180517   %subst(detail:62:16) = DBitem.nucheck;
000768180517   %subst(detail:79:20) = %editc(DBitem.amnetdue:'A');
000769180515   // determine if payment was posted to farp000/100/110
000770180515   monitor;
000771180515   wcheck = %dec(%trim(DBitem.nucheck):17:0);
000772180515   on-error;
000773180515     wcheck = 0;
000774180515   endmon;
000775180515   tcheck = wcheck;
000776180515   if (tcheck>0) and (isProcessedAgentPayment(tcheck));
000777180517     if (DBitem.amnetdue=0);
000778180517       %subst(detail:101:30) = '* OK *';
000779180517     else;
000780180517       %subst(detail:101:30) = '* Amounts differ *';
000781180517     ENDIF;
000782180515   else;
000783180517     %subst(detail:101:30) = '* Check NOT processed *';
000784180515     AgentUnprocessed += DBitem.amnetdue;
000785180515   endif;
000786180515   IFIPRT_printDetail(detail);
000787180514   //
000788180514   fetchNextDBItem();
000789180514   mySQLStatus = SQLErrChk( 'fetch next DB Item' );
000790180514   if ( mySQLStatus ='EOD' ) or ( mySQLStatus ='ERR');
000791180514     leave;
000792180514   ENDIF;
000793180514 ENDDO;
000794180514 closeDBItem();
000795180514 return;
000796180514
000797180514end-proc;
000798180514//--------------------------------------------------------------------------
000799180514//
000800180514dcl-proc openStatementItems;
000801180514
000802180514dcl-pi *N;
000803180514  pnubond  zoned(7:0);
000804180514  pnubondre zoned(2:0);
000805180514end-pi;
000806180514
000807180514 //TODO:
000808180514 EXEC SQL
000809180514   DECLARE C2 CURSOR FOR
000810180514     WITH StatementITem AS
000811180514     (
000812180514     SELECT char('A/R',3) AS Source, 'A' Concat tptrans Concat cdtrans AS Xtype,
000813180515               dtaccount XDate, dtaccount AS xacctdt, cdbranch,cdcarrier,cdprogram,nubond,nubondre,nubonden,
000814180514               cdagent, amnetdue XAmt, idlink,
000815180514              flbill, flbillw ,ampremnet,  case when ampremgrs=0 THEN 'A' ELSE 'P' END APFLAG, cdprinc,
000816180514               ' ' as TPCASh, ' ' AS florigin, ' 'as nucheck,   ' 'as dsline1,   ' 'as cdfinanc
000817180514     FROM iftovr.farp000   WHERE (NUbond,nubondre)=(:pnubond,:pnubondre)
000818180514     UNION All
000819180514
000820180514     SELECT char('CSH',3) AS Source, 'C' Concat tptrans Concat cdtrans AS Xtype,
000821180515            dtpost Xdate,  dtaccount AS xacctdt,cdbranch,cdcarrier,cdprogram, nubond,nubondre,nubonden,
000822180514             cdagent, ampay Xamt,idlink ,
000823180514             ' ' as flbill, ' ' AS flbillw ,0 as ampremnet, ' 'AS APFLAG, ' '  AS cdprinc,
000824180514               tpcash,florigin, nucheck, dsline1,cdfinanc
000825180514     FROM iftovr.farp100   WHERE (NUbond,nubondre)=(:pnubond,:pnubondre)
000826180514     UNION ALL
000827180514     SELECT char('SUS',3) AS Source, 'S' Concat tptrans Concat cdtrans AS Xtype,
000828180515            dtpost xdate, dtaccount AS xacctdt,cdbranch,cdcarrier,cdprogram, nubond,nubondre,nubonden,
000829180514              cdagent,ampay XAmt,idlink ,
000830180514              ' ' as flbill, ' ' AS flbillw ,0 as ampremnet, ' 'AS APFLAG, ' '  AS cdprinc,
000831180514               tpcash,florigin, nucheck,  dsline1, ' ' AS cdfinanc
000832180514     FROM iftovr.farp110   WHERE (NUbond,nubondre)=(:pnubond,:pnubondre)
000833180514     )
000834180514     Select * from StatementItem
000835180514
000836180515   ORDER BY cdbranch,cdcarrier,cdprogram,nubond,nubondre,nubonden,xacctdt,xdate,source
000837180514     FOR READ ONLY;
000838180514 //
000839180514  EXEC SQL
000840180514    OPEN C2;
000841180514  mySQLStatus = SQLErrChk( 'open Statement Item' );
000842180514  if ( mySQLStatus ='OK' ) or ( mySQLStatus ='WRN');
000843180514  endif;
000844180514
000845180514end-proc;
000846180514//--------------------------------------------------------------------------
000847180514//
000848180514dcl-proc closeStatementItems;
000849180514
000850180514
000851180514 // close file cursor
000852180514 EXEC SQL
000853180514   CLOSE C2;
000854180514  mySQLStatus = SQLErrChk( 'Close Statment Item' );
000855180514
000856180514
000857180514end-proc;
000858180514//--------------------------------------------------------------------------
000859180514//
000860180514dcl-proc fetchNextStatementItem;
000861180514
000862180514
000863180514 exec SQL
000864180514     FETCH NEXT FROM c2 into :StatementItem ;
000865180514
000866180514end-proc;
000867180515//--------------------------------------------------------------------------
000870180514//
000871180514dcl-proc openDBItem;
000872180514dcl-pi *N;
000873180514  pnubond  zoned(7:0);
000874180514  pnubondre zoned(2:0);
000875180514end-pi;
000876180514
000877180514 //TODO:
000878180514 EXEC SQL
000879180514   DECLARE C5 CURSOR FOR
000880180514     SELECT cdbranch,cdcarrier,cdprogram, nubond,nubondre,nubonden,
000881180514            char('DBI',3),amnetdue,nucheck,invkid,edate,region,prtid
000882180514     FROM fdtxvrpt
000883180514     WHERE (NUbond,nubondre)=(:pnubond,:pnubondre)
000884180514     ORDER BY cdbranch,cdcarrier,cdprogram, nubond,nubondre,nubonden,11
000885180514     FOR READ ONLY;
000886180514 //
000887180514  EXEC SQL
000888180514    OPEN C5  ;
000889180514  mySQLStatus = SQLErrChk( 'open DB Item' );
000890180514  if ( mySQLStatus ='OK' ) or ( mySQLStatus ='WRN');
000891180514  endif;
000892180514
000893180514
000894180514end-proc;
000895180514//--------------------------------------------------------------------------
000896180514//
000897180514dcl-proc closeDBItem;
000898180514
000899180514      // close file cursor
000900180514 EXEC SQL
000901180514   CLOSE C5;
000902180514  mySQLStatus = SQLErrChk( 'Close DB Item' );
000903180514
000904180514
000905180514end-proc;
000906180514//--------------------------------------------------------------------------
000907180514//
000908180514dcl-proc fetchNextDBItem;
000909180514
000910180514 exec SQL
000911180514     FETCH NEXT FROM c5 into :DBItem;
000912180514
000913180514end-proc;
000914180514//--------------------------------------------------------------------------
000915180514//
000916180514dcl-proc getName;
000917180514
000918180514dcl-pi *N char(30);
000919180514  c1 char(1) const;
000920180514  c2 zoned(5:0) const;
000921180514end-pi;
000922180514
000923180514//                 PI            30a
000924180514// c1                             1a
000925180514// c2                             5s 0
000926180514
000927180514dcl-s  name   char(30);
000928180514
000929180514 name = '*** Name Not Found ***';
000930180514 Exec sql
000931180514 select na00cn into :Name from fbna0000
000932180514  where (na00c1,na00c2)=(:c1,:c2);
000933180514  return name;
000934180514
000935180514end-proc;
000936180514//--------------------------------------------------------------------------
000937180514//
000938180514dcl-proc convertDate;
000939180514
000940180514dcl-pi *N date;
000941180514 cc zoned(2:0);
000942180514 yy zoned(2:0);
000943180514 mm zoned(2:0);
000944180514 dd zoned(2:0);
000945180514END-PI;
000946180514
000947180514dcl-s workdate char(10);
000948180514
000949180514workdate = %editc(cc:'X')+%editc(yy:'X')+'-'
000950180514          +%editc(mm:'X')+'-'+%editc(dd:'X');
000951180514 return %date(workdate:*ISO);
000952180514
000953180514end-proc;
000954180514//--------------------------------------------------------------------------
000955180514//
000956180514dcl-proc fetchPremStats;
000957180514
000958180514dcl-pi *N;
000959180514  xnubond  zoned(7:0) CONST;
000960180514  xnubondre zoned(2:0) CONST;
000961180514  Premium  zoned(13:2);
000962180514  Commission zoned(13:2);
000963180514end-pi;
000964180514
000965180514
000966180514 Premium = 0;
000967180514 Commission = 0;
000968180514 Exec sql
000969180514 select sum(ampremtrn),sum(amagentcom) INTO :Premium,:Commission
000970180514  from fmrm000
000971180514  where (NUbond,nubondre)=(:xnubond,:xnubondre)
000972180514  GROUP BY NUbond,nubondre;
000973180514
000974180514
000975180515  return ;
000976180515
000977180515end-proc;
000978180515//--------------------------------------------------------------------------
000979180515//
000980180515dcl-proc addAgentPayment;
000981180515
000982180515dcl-pi *N;
000983180516  thischeck    likeds(check);
000984180516  XAmount       zoned(13:2);
000985180516end-pi;
000986180515  DBAgtPayCount += 1;
000987180516  DBAgtChecks(DBAgtPayCount).date = thischeck.date;
000988180516  DBAgtChecks(DBAgtPayCount).number = thischeck.number;
000989180516  DBAgtChecks(DBAgtPayCount).vendor = thischeck.vendor;
000990180516  DBAgtChecks(DBAgtPayCount).payee = thischeck.payee;
000991180516  DBAgtChecks(DBAgtPayCount).Amount = thischeck.amount;
000992180516  DBAgtChecks(DBAgtPayCount).XAmount = Xamount;
000993180515return ;
000994180514
000995180514end-proc;
000996180515//--------------------------------------------------------------------------
000997180515//
000998180515dcl-proc isProcessedAgentPayment;
000999180515
001000180515dcl-pi *N ind;
001001180515  Pcheck    zoned(7:0) CONST;
001002180515end-pi;
001003180515
001004180515dcl-s TRUE  ind inz('1');
001005180515dcl-s FALSE ind inz('0');
001006180515
001007180516  if (DBAgtPayCount=0) or (%lookup(pcheck:DBagtChecks(*).number:1:DBagtPayCount)=0);
001008180515    return FALSE;
001010180515  else;
001011180515    return TRUE;
001013180515  endif;
001014180515
001015180515end-proc;
001016180514//--------------------------------------------------------------------------
001017180514//
001018180514dcl-proc getCheckDetails;
001019180514
001020180514dcl-pi *N;
001021180515  Pcheck    zoned(7:0) CONST;
001022180514  thisCheck  likeds(CHECK);
001023180514end-pi;
001024180514
001025180514clear thisCheck;
001026180514 // get check details
001027180514 EXEC SQL
001028180514   SELECT
001029180514     ZONED(c.corp#,3,0) CompanyID,
001030180514     ZONED(c.bank#,3,0) BankAccountID,
001031180514     ZONED(c.rchkr#,7,0) ChkNumber,
001032180514     ZONED(c.rramt$,11,2) Chkamount,
001033180514     ZONED(C.rrvnd#,6,0) VendorID,
001034180514     c.rrvndn Payee,
001035180514     CHAR( case when c.rchkr#>9000000 THEN 'W' ELSE 'C' END,1) PayType,
001036180514     IFNULL( iftovr.ific_date(rrckhh,rrckyy,rrckmm,rrckdd), '0001-01-01')
001037180514   INTO :thisCheck
001038180514   FROM xappfile.chkrlp C
001039180514   where c.rchkr#=:pcheck;
001040180514  mySQLStatus = SQLErrChk('getCheckDetails');
001041180514  if ( mySQLStatus ='OK' ) or ( mySQLStatus ='WRN');
001042180514
001043180514  else;
001044180516    thisCheck.number = pcheck;
001045180514    thisCheck.payee =  '*** Check Not Found ***';
001046180514  endif;
001047180514
001048180514return;
001049180514
001050180514end-proc;
001051180514//--------------------------------------------------------------------------
001052180514//
001053180514dcl-proc getAgentVendorID ;
001054180514
001055180514dcl-pi *N zoned(6:0);
001056180514  acode char(6);
001057180514end-pi;
001058180514
001059180514dcl-s vnd# zoned(6:0);
001060180514
001061180514
001062180514// get check details
001063180514select;
001064180514  when (acode='A00418');
001065180514    vnd# = 5569;
001066180514  when (acode='A00580');
001067180514    vnd# = 5773;
001068180514  when (acode='A01340');
001069180514    vnd# = 6328;
001070180514  when (acode='A00816');
001071180514    vnd# = 5774;
001072180514  other;
001073180514    vnd# = 999999;
001074180514endsl;
001075180514
001076180514return vnd#;
001077180514
001078180514end-proc;
001079180517//--------------------------------------------------------------------------
001080180517//
001081180517dcl-proc getACode_BondEndorsement;
001082180517
001083180517dcl-pi *N char(6);
001084180517  branch char(2) CONST;
001085180517  carrier char(2) CONST;
001086180517  program char(2) CONST;
001087180517  bond    zoned(7:0) CONST;
001088180517  bondren zoned(2:0) CONST;
001089180517  bondend zoned(4:0) CONST;
001090180517end-pi;
001091180517
001092180517dcl-s ACode char(6);
001093180517
001094180517clear acode;
001095180517exec sql
001096180517
001097180517 SELECT s000prdclt concat DIGITS(s000prdcno) INTO :ACode
001098180517   FROM fbsp0000
001099180517 WHERE (s000bbran,s000bcarr,s000bprog,s000bndno,s000bndren,s000bendrs)
001100180517    =  (:branch,:carrier,:program,:bond,:bondren,:bondend);
001108180517
001109180517return acode;
001110180517
001111180517end-proc;
