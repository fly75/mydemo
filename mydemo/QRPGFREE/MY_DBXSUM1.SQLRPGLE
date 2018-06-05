**FREE

 ctl-opt
 DFTACTGRP(*NO) actgrp(*NEW) BNDDIR('IFIAPI')  EXTBININT(*YES)  option(*NOXREF:*NOEXPDDS:*NODEBUGIO:*NOSHOWCPY);

//========================================================================
// Program: MY_DBXSum1
//           print Direct Bill Transaction Summary for select bond renewals
//  requires
//           IFIAPI
//           SQLERRCHK
//========================================================================

dcl-f fbpm0000 disk(*EXT) usage(*INPUT) KEYED;

// get prototypes from copy source
//
/INCLUDE SQLERRCHKH
//
dcl-s mySQLStatus   char(3);

//
/INCLUDE IFIPRTH
//
dcl-s  testdate     char(10);
dcl-s  pgmlib       char(20);
dcl-s  reportTitle  char(60);
dcl-s  columnHeadings char(132);
dcl-s  detail         char(132);

//
dcl-ds SpoolID QUALIFIED;
  jobname    char(10);
  username   char(10);
  jobnbr     zoned(6:0);
  filename   char(10);
  spoolnbr   uns(5);
end-ds;

//
dcl-ds PgmSts PSDS QUALIFIED;
  Proc             *PROC;
  StatusCode       *STATUS;
  Library          char(10) pos(81);
  jobname          char(10) pos(244);
  jobuser          char(10) pos(254);
  jobnumber        zoned(6:0) pos(264);
end-ds;

dcl-ds DBXSummary qualified;
  cdbranch  char(2);
  cdcarrier char(2);
  cdprogram char(2);
  nubond    zoned(7:0);
  nubondre  zoned(2:0);
end-ds;

dcl-ds Bond extname('FBPM0000':*ALL) Qualified prefix('':4);
END-DS;

dcl-ds  StatementItem qualified;
  Source     char(3);
  XType      char(4);
  XAcctDt    date;
  XDate      date;
  cdbranch   char(2);
  cdcarrier  char(2);
  cdprogram  char(2);
  nubond     zoned(7:0);
  nubondre   zoned(2:0);
  nubonden   zoned(4:0);
  cdagent    char(6);
  XAmt       zoned(13:2);
  idlink     char(32);
  flbill     char(1);
  flbillw    char(2);
  ampremnet  zoned(13:2);
  APFlag     char(1);
  cdprinc    char(6);
  tpcash     char(1);
  florigin   char(2);
  nucheck    char(16);
  dsline1    char(38);
  cdfinanc   char(2);
end-ds;

dcl-ds DBItem qualified;
  cdbranch   char(2);
  cdcarrier  char(2);
  cdprogram  char(2);
  nubond     zoned(7:0);
  nubondre   zoned(2:0);
  nubonden   zoned(4:0);
  Source     char(3);
  amnetdue   zoned(13:2);
  nucheck    char(16);
  invkid     char(10);
  edate      zoned(8:0);
  region     char(2);
  prtid      char(1);
end-ds;

dcl-ds Check QUALIFIED;
  CompanyID      zoned(3:0);
  BankAccountID  zoned(3:0);
  Number         zoned(7:0);
  Amount         zoned(11:2);
  Vendor         zoned(6:0);
  Payee          char(30);
  Type           char(1);
  Date           date;
end-ds;

dcl-ds DBAgtChecks DIM(10) QUALIFIED;
  Date           date;
  Vendor         zoned(6:0);
  Payee          char(30);
  Number         zoned(7:0);
  Amount         zoned(11:2);
  XAmount        zoned(11:2);
END-DS;

dcl-s DBAgtPayCount  uns(5) inz(0);

dcl-s rowin   int(10) inz(0);
dcl-s prvglppgm  char(10);
dcl-s printPGM   char(10);
dcl-s Today date;
dcl-s RunDate  date;
dcl-s acode  char(6);
dcl-s pcode  char(6);
dcl-s name           char(30);
dcl-s workDate       date;
dcl-s PremAmt        zoned(13:2);
dcl-s CommAmt        zoned(13:2);
dcl-s wcheck         packed(17:0);
dcl-s tcheck         packed(7:0);
dcl-s NetCashBal    zoned(13:2);
dcl-s NetSuspBal    zoned(13:2);
dcl-s NetBalance    zoned(13:2);
dcl-s AgentCashPaid  zoned(13:2);
dcl-s PrincipalCashPaid zoned(13:2);
dcl-s AgentCashRcvd  zoned(13:2);
dcl-s PrincipalCashRcvd zoned(13:2);
dcl-s PrincipalUnprocessed zoned(13:2);
dcl-s AgentUnprocessed zoned(13:2);

  EXEC SQL
    SET OPTION COMMIT=*NONE, datfmt=*ISO;
  pgmlib = pgmSts.Proc+PGmSts.Library;
  today = %date();
  Testdate = %char(today);
  reportTitle = 'Direct Bill Activity Summary';
  IFIPRT_initialize(pgmlib:Testdate:reportTitle);
  columnHeadings = *BLANKS;
  %subst(columnHeadings:8:8) = 'Bond ID';
  IFIPRT_setColumnHeadings(columnHeadings);
  printPGM = '1';

  //
  openDBXSummary();
  fetchNextDBXSummary();
  mySQLStatus = SQLErrChk( 'fetch first DBXSummary' );

  DOW ( mySQLStatus ='OK' ) or ( mySQLStatus ='WRN');
    rowin += 1;

    IFIPRT_SetNewPage();
    processDBXSummary();

    // get next bond
    fetchNextDBXSummary();
    mySQLStatus = SQLErrChk( 'fetch next DBXSummary' );
    if ( mySQLStatus ='EOD' ) or ( mySQLStatus ='ERR');
      leave;
    ENDIF;
  ENDDO;

  //close program
  closeDBXSummary();
  IFIPRT_SetNewPage();
  detail='End of Report.';
  IFIPRT_printDetail(detail:'3');

  //
  IFIPRT_SetNewPage();
  detail='Bond Summary End of Report.';
  IFIPRT_printDetail(detail:'3');

  IFIPRT_close();
  *inlr=*on;
  return;

//--------------------------------------------------------------------------
//
dcl-proc OpenDBXSummary;

 EXEC SQL
   DECLARE C1 CURSOR FOR
     SELECT DISTINCT cdbranch,cdcarrier,cdprogram,nubond,nubondre
     FROM jjcwork.DBXProblems
     ORDER BY cdbranch,cdcarrier,cdprogram,nubond,nubondre
     FOR READ ONLY;
 //
  EXEC SQL
    OPEN C1;
  mySQLStatus = SQLErrChk( 'open DBX Summary' );
  if ( mySQLStatus ='OK' ) or ( mySQLStatus ='WRN');
  endif;

end-proc;
//--------------------------------------------------------------------------
//
dcl-proc closeDBXSummary;


 EXEC SQL
   CLOSE C1;
  mySQLStatus = SQLErrChk( 'Close DBXSummary' );

end-proc;
//--------------------------------------------------------------------------
//
dcl-proc fetchNextDBXSummary;

 exec SQL
     FETCH NEXT FROM c1 into :DBXSummary;

end-proc;

//--------------------------------------------------------------------------
//
 dcl-proc processDBXSummary;

 // Bond Details
 printBondDetails(DBXSummary.cdbranch
                 :DBXSummary.cdcarrier
                 :DBXSummary.cdprogram
                 :DBXSummary.nubond
                 :DBXSummary.nubondre
                  );

 // clear Cash Flow totals
 netCashBal = 0;
 netSuspBal = 0;
 netBalance = 0;
 AgentCashPaid = 0;
 AgentCashRcvd = 0;
 PrincipalCashPaid = 0;
 PrincipalCashRcvd = 0;
 PrincipalUnprocessed = 0;
 AgentUnprocessed = 0;
 clear DBagtChecks;
 DBAgtPayCount = 0;
 // Statement Items
 printStatementItems(DBXSummary.nubond:DBXSummary.nubondre);

 detail = *blanks;
 %subst(detail:30:11) = 'Cash';
 %subst(detail:42:20) = %editc(NetCashBal:'A');
 IFIPRT_printDetail(detail:'1');
 detail = *blanks;
 %subst(detail:30:11) = 'Suspense';
 %subst(detail:42:20) = %editc(NetSuspBal:'A');
 IFIPRT_printDetail(detail);
 detail = *blanks;
 %subst(detail:30:11) = 'Net Balance';
 %subst(detail:42:20) = %editc(NetBalance:'A');
 IFIPRT_printDetail(detail);

 // Direct Bill Items
 printDBItems(DBXSummary.nubond:DBXSummary.nubondre);

 // print Cash Flow totals
 detail = *ALL'-';
 %subst(detail:1:20) = 'Cash Flow Analysis';
 IFIPRT_printDetail(detail:'2':'1');

 detail = *blanks;
 %subst(detail:2:5) = 'Party';
 %subst(detail:17:9) = 'Cash Paid';
 %subst(detail:33:13) = 'Cash Received';
 %subst(detail:58:8) = 'Cash Net';
 %subst(detail:74:12) = 'Unprocessed';
 %subst(detail:102:4) = 'Bond';
  %subst(detail:126:3) = 'Due';
 IFIPRT_printDetail(detail);

 detail = *blanks;
 %subst(detail:1:10) = 'Principal';
 %subst(detail:11:20) = %editc(PrincipalCashPaid:'A');
 %subst(detail:31:20) = %editc(PrincipalCashRcvd:'A');
 %subst(detail:51:20) = %editc(PrincipalCashPaid+PrincipalCashRcvd:'A');
 %subst(detail:71:20) = %editc(PrincipalUnprocessed:'A');
 %subst(detail:91:20) = %editc(PremAmt:'A');
 %subst(detail:111:20) = %editc(%dec(PremAmt-(PrincipalCashPaid+PrincipalCashRcvd):13:2):'A');
 IFIPRT_printDetail(detail:'1':'1');

 detail = *blanks;
 %subst(detail:1:10) = 'Agent';


 %subst(detail:11:20) = %editc(AgentCashPaid:'A');
 %subst(detail:31:20) = %editc(AgentCashRcvd:'A');
 %subst(detail:51:20) = %editc(AgentCashPaid+AgentCashRcvd:'A');
 %subst(detail:71:20) = %editc(AgentUnprocessed:'A');
 %subst(detail:91:20) = %editc(-CommAmt:'A');
 %subst(detail:111:20) = %editc(%dec(-CommAmt-(AgentCashPaid+AgentCashRcvd+AgentUnprocessed):13:2):'A');
 IFIPRT_printDetail(detail:'1':'1');

 end-proc;
//--------------------------------------------------------------------------
//

dcl-proc printBondDetails;

dcl-pi *N;
  pbranch   char(2);
  pcarrier  char(2);
  pprogram  char(2);
  pbond     zoned(7:0);
  pbondren  zoned(2:0);
end-pi;

//

 chain  (pbranch:pcarrier:pprogram:pbond:pbondren) fbpm0000re bond;

 pcode = bond.prnclt+%editc(bond.prncno:'X');
 acode = bond.prdclt+%editc(bond.prdcno:'X');

 fetchPremStats( DBXSummary.nubond
                  : DBXSummary.nubondre
                  : premAmt
                  : CommAmt);

 detail = *blanks;
 %subst(detail:1:2) = bond.bbran;
 %subst(detail:3:2) = bond.bcarr;
 %subst(detail:5:2) = bond.bprog;
 %subst(detail:8:7) = %editc(bond.bndno:'X');
 %subst(detail:16:2) = %editc(bond.bndren:'X');
 %subst(detail:20:15) = %editc(bond.bndamn:'1');
 %subst(detail:51:33) = bond.oblgnm;
 IFIPRT_printDetail(detail);

 detail = *blanks;
 %subst(detail:20:10) = 'Effective:';
 workDate = convertDate(bond.effcc:bond.effyy:bond.effmm:bond.effdd);
 %subst(detail:31:10) = %CHAR(workDate:*USA);
 %subst(detail:44:6) = bond.prnclt+%editc(bond.prncno:'X');
 %subst(detail:51:30) = getName(bond.prnclt:bond.prncno);
 %subst(detail:85:30) = 'Premium:    ' + %editc(PremAmt:'N');
 IFIPRT_printDetail(detail);
 detail = *blanks;
 %subst(detail:20:10) = 'Expiring :';
 workDate = convertDate(bond.expcc:bond.expyy:bond.expmm:bond.expdd);
 %subst(detail:31:10) = %CHAR(workDate:*USA);
 %subst(detail:44:6) = bond.prdclt+%editc(bond.prdcno:'X');
 %subst(detail:51:30) = getName(bond.prdclt:bond.prdcno);
 %subst(detail:85:30) = 'Commission: ' + %editc(CommAmt:'N');
 IFIPRT_printDetail(detail);
 return;

end-proc;
//--------------------------------------------------------------------------
//
dcl-proc printStatementItems;
dcl-pi *N;
  pnubond  zoned(7:0);
  pnubondre zoned(2:0);
end-pi;
dcl-s this_Acode char(6);

 //TODO:
 openStatementItems(pnubond:pnubondre);
 //

 detail = *ALL'-';
 %subst(detail:1:18) = 'Statement Entries ';
 IFIPRT_printDetail(detail:'2':'1');
 fetchNextStatementItem();
 mySQLStatus = SQLErrChk( 'fetch first Statement Item' );

 DOW ( mySQLStatus ='OK' ) or ( mySQLStatus ='WRN');
   // accumulate net cash balance
   netBalance += StatementItem.Xamt;
   //
   detail = *blanks;
   %subst(detail:1:4) = %editc(StatementItem.nubonden:'X');
   %subst(detail:6:10) = %char(StatementItem.XDAte:*USA);
   %subst(detail:18:4) = StatementItem.Xtype;

   %subst(detail:42:20) = %editc(StatementItem.xamt:'A');
   %subst(detail:62:16) = %subst(StatementItem.idlink:1:16);

   select;

     WHEN StatementItem.Source='A/R';
       %subst(detail:22:20) = %editc(StatementItem.ampremnet:'A');
       %subst(detail:79:1) = StatementItem.flbill;
       %subst(detail:80:1) = StatementItem.flbillw;
       // Agent and principal are swapped on direct bill A/R item
       if (StatementItem.apflag='P');
         %subst(detail:82:6) = StatementItem.cdagent;
       else;
         %subst(detail:82:6) = StatementItem.cdprinc;
       endif;
       // %subst(detail:89:1) = StatementItem.apflag;

     WHEN StatementItem.Source='CSH';
       select;
         when (%subst(StatementItem.xtype:3:2)='AC');
           PrincipalCashRcvd += StatementItem.xamt;
       ENDSL;
       // accumulate net cash balance
       netcashBal += StatementItem.Xamt;

       // closer look at disbursement details
       if (%subst(StatementItem.Xtype:3:2)='DI');
         wcheck =  %dec(%trim(StatementItem.nucheck):17:0);
         tcheck =  wcheck;
         getCheckDetails(tcheck:Check);
         %subst(detail:79:7) = %editc(check.Number:'X');
         %subst(detail:87:10) = %char(Check.Date:*USA);
         %subst(detail:98:10) = %editc(check.CompanyID:'X')
                              +'-'+%editc(check.vendor:'X');
         %subst(detail:109:20) = %subst(check.payee:1:20);
         This_Acode = getACode_BondEndorsement(DBXSummary.cdbranch
                 :DBXSummary.cdcarrier
                 :DBXSummary.cdprogram
                 :DBXSummary.nubond
                 :DBXSummary.nubondre
                 :StatementItem.nubonden );

         if (getAgentVendorID(This_Acode)=check.vendor);
           AgentCashPaid += StatementItem.xamt;
           addAgentPayment(check:StatementItem.xamt);
         else;
           PrincipalCashPaid += StatementItem.xamt;
         endif;
       else;
         %subst(detail:79:16) = StatementItem.nucheck;
         %subst(detail:95:38) = StatementItem.dsline1;
       endif;

     WHEN StatementItem.Source='SUS';
       //
       netSuspBal += StatementItem.xamt;
       // %subst(detail:74:1) = StatementItem.tpcash;
       // %subst(detail:76:2) = StatementItem.florigin;
       if (%subst(StatementItem.xtype:3:2)='DI') and (%trim(StatementItem.idlink)<>'** PAS **');
         wcheck =  %dec(%trim(StatementItem.nucheck):17:0);
         tcheck =  wcheck;
         getCheckDetails(tcheck:Check);
         %subst(detail:79:7) = %editc(check.Number:'X');
         %subst(detail:87:10) = %char(Check.Date:*USA);
         %subst(detail:98:10) = %editc(check.CompanyID:'X')
                              +'-'+%editc(check.vendor:'X');
         %subst(detail:109:20) = %subst(check.payee:1:20);

       else;
         %subst(detail:79:16) = StatementItem.nucheck;
         %subst(detail:95:38) = StatementItem.dsline1;
       endif;

   endsl;

   IFIPRT_printDetail(detail);
   //
   fetchNextStatementItem();
   mySQLStatus = SQLErrChk( 'fetch next Statement Item' );
   if ( mySQLStatus ='EOD' ) or ( mySQLStatus ='ERR');
     leave;
   ENDIF;
 ENDDO;
 closeStatementItems();
 return;

end-proc;
//--------------------------------------------------------------------------
//
dcl-proc printDBItems;

dcl-pi *N;
  pnubond  zoned(7:0);
  pnubondre zoned(2:0);
end-pi;
dcl-s i int(5);


 openDBItem(DBXSummary.nubond:DBXSummary.nubondre);
 detail = *ALL'-';
 %subst(detail:1:30) = 'Direct Bill Agent Commission ';
 IFIPRT_printDetail(detail:'2':'1');

 if DBAgtPayCount=0;
   IFIPRT_printDetail('** No Payments Found **':'1':'1');
 else;
   IFIPRT_printDetail('** Payments Found **':'1':'1');
   for i = 1 to DBAgtPayCount;
     detail = *blanks;
     %subst(detail:13:10) = %char(DBAgtChecks(i).date:*USA);
     %subst(detail:24:6) = %editc(DBAgtChecks(i).vendor:'X');
     %subst(detail:31:30) = DBAgtChecks(i).payee;
     %subst(detail:62:7) = %editc(DBAgtChecks(i).number:'X');
     %subst(detail:82:16) =  %editc(DBAgtChecks(i).XAmount:'A');
     %subst(detail:100:20) =  %editc(DBAgtChecks(i).Amount:'A');
     IFIPRT_printDetail(detail:'1':'1');
   endfor;
 endif;
 IFIPRT_printDetail('** Payments Expected **':'1':'1');
 fetchNextDBItem();
 mySQLStatus = SQLErrChk( 'fetch first DB Item' );

 DOW ( mySQLStatus ='OK' ) or ( mySQLStatus ='WRN');
   //
   detail = *blanks;
   %subst(detail:1:3) = DBItem.Source;
   %subst(detail:5:1) = DBitem.prtid;
   %subst(detail:15:10) = %editc(DBitem.edate:'X');
   %subst(detail:34:12) = DBitem.invkid;
   %subst(detail:62:16) = DBitem.nucheck;
   %subst(detail:79:20) = %editc(DBitem.amnetdue:'A');
   // determine if payment was posted to farp000/100/110
   monitor;
   wcheck = %dec(%trim(DBitem.nucheck):17:0);
   on-error;
     wcheck = 0;
   endmon;
   tcheck = wcheck;
   if (tcheck>0) and (isProcessedAgentPayment(tcheck));
     if (DBitem.amnetdue=0);
       %subst(detail:101:30) = '* OK *';
     else;
       %subst(detail:101:30) = '* Amounts differ *';
     ENDIF;
   else;
     %subst(detail:101:30) = '* Check NOT processed *';
     AgentUnprocessed += DBitem.amnetdue;
   endif;
   IFIPRT_printDetail(detail);
   //
   fetchNextDBItem();
   mySQLStatus = SQLErrChk( 'fetch next DB Item' );
   if ( mySQLStatus ='EOD' ) or ( mySQLStatus ='ERR');
     leave;
   ENDIF;
 ENDDO;
 closeDBItem();
 return;

end-proc;
//--------------------------------------------------------------------------
//
dcl-proc openStatementItems;

dcl-pi *N;
  pnubond  zoned(7:0);
  pnubondre zoned(2:0);
end-pi;

 //TODO:
 EXEC SQL
   DECLARE C2 CURSOR FOR
     WITH StatementITem AS
     (
     SELECT char('A/R',3) AS Source, 'A' Concat tptrans Concat cdtrans AS Xtype,
               dtaccount XDate, dtaccount AS xacctdt, cdbranch,cdcarrier,cdprogram,nubond,nubondre,nubonden,
               cdagent, amnetdue XAmt, idlink,
              flbill, flbillw ,ampremnet,  case when ampremgrs=0 THEN 'A' ELSE 'P' END APFLAG, cdprinc,
               ' ' as TPCASh, ' ' AS florigin, ' 'as nucheck,   ' 'as dsline1,   ' 'as cdfinanc
     FROM iftovr.farp000   WHERE (NUbond,nubondre)=(:pnubond,:pnubondre)
     UNION All

     SELECT char('CSH',3) AS Source, 'C' Concat tptrans Concat cdtrans AS Xtype,
            dtpost Xdate,  dtaccount AS xacctdt,cdbranch,cdcarrier,cdprogram, nubond,nubondre,nubonden,
             cdagent, ampay Xamt,idlink ,
             ' ' as flbill, ' ' AS flbillw ,0 as ampremnet, ' 'AS APFLAG, ' '  AS cdprinc,
               tpcash,florigin, nucheck, dsline1,cdfinanc
     FROM iftovr.farp100   WHERE (NUbond,nubondre)=(:pnubond,:pnubondre)
     UNION ALL
     SELECT char('SUS',3) AS Source, 'S' Concat tptrans Concat cdtrans AS Xtype,
            dtpost xdate, dtaccount AS xacctdt,cdbranch,cdcarrier,cdprogram, nubond,nubondre,nubonden,
              cdagent,ampay XAmt,idlink ,
              ' ' as flbill, ' ' AS flbillw ,0 as ampremnet, ' 'AS APFLAG, ' '  AS cdprinc,
               tpcash,florigin, nucheck,  dsline1, ' ' AS cdfinanc
     FROM iftovr.farp110   WHERE (NUbond,nubondre)=(:pnubond,:pnubondre)
     )
     Select * from StatementItem

   ORDER BY cdbranch,cdcarrier,cdprogram,nubond,nubondre,nubonden,xacctdt,xdate,source
     FOR READ ONLY;
 //
  EXEC SQL
    OPEN C2;
  mySQLStatus = SQLErrChk( 'open Statement Item' );
  if ( mySQLStatus ='OK' ) or ( mySQLStatus ='WRN');
  endif;

end-proc;
//--------------------------------------------------------------------------
//
dcl-proc closeStatementItems;


 // close file cursor
 EXEC SQL
   CLOSE C2;
  mySQLStatus = SQLErrChk( 'Close Statment Item' );


end-proc;
//--------------------------------------------------------------------------
//
dcl-proc fetchNextStatementItem;


 exec SQL
     FETCH NEXT FROM c2 into :StatementItem ;

end-proc;
//--------------------------------------------------------------------------
//
dcl-proc openDBItem;
dcl-pi *N;
  pnubond  zoned(7:0);
  pnubondre zoned(2:0);
end-pi;

 //TODO:
 EXEC SQL
   DECLARE C5 CURSOR FOR
     SELECT cdbranch,cdcarrier,cdprogram, nubond,nubondre,nubonden,
            char('DBI',3),amnetdue,nucheck,invkid,edate,region,prtid
     FROM fdtxvrpt
     WHERE (NUbond,nubondre)=(:pnubond,:pnubondre)
     ORDER BY cdbranch,cdcarrier,cdprogram, nubond,nubondre,nubonden,11
     FOR READ ONLY;
 //
  EXEC SQL
    OPEN C5  ;
  mySQLStatus = SQLErrChk( 'open DB Item' );
  if ( mySQLStatus ='OK' ) or ( mySQLStatus ='WRN');
  endif;


end-proc;
//--------------------------------------------------------------------------
//
dcl-proc closeDBItem;

      // close file cursor
 EXEC SQL
   CLOSE C5;
  mySQLStatus = SQLErrChk( 'Close DB Item' );


end-proc;
//--------------------------------------------------------------------------
//
dcl-proc fetchNextDBItem;

 exec SQL
     FETCH NEXT FROM c5 into :DBItem;

end-proc;
//--------------------------------------------------------------------------
//
dcl-proc getName;

dcl-pi *N char(30);
  c1 char(1) const;
  c2 zoned(5:0) const;
end-pi;

//                 PI            30a
// c1                             1a
// c2                             5s 0

dcl-s  name   char(30);

 name = '*** Name Not Found ***';
 Exec sql
 select na00cn into :Name from fbna0000
  where (na00c1,na00c2)=(:c1,:c2);
  return name;

end-proc;
//--------------------------------------------------------------------------
//
dcl-proc convertDate;

dcl-pi *N date;
 cc zoned(2:0);
 yy zoned(2:0);
 mm zoned(2:0);
 dd zoned(2:0);
END-PI;

dcl-s workdate char(10);

workdate = %editc(cc:'X')+%editc(yy:'X')+'-'
          +%editc(mm:'X')+'-'+%editc(dd:'X');
 return %date(workdate:*ISO);

end-proc;
//--------------------------------------------------------------------------
//
dcl-proc fetchPremStats;

dcl-pi *N;
  xnubond  zoned(7:0) CONST;
  xnubondre zoned(2:0) CONST;
  Premium  zoned(13:2);
  Commission zoned(13:2);
end-pi;


 Premium = 0;
 Commission = 0;
 Exec sql
 select sum(ampremtrn),sum(amagentcom) INTO :Premium,:Commission
  from fmrm000
  where (NUbond,nubondre)=(:xnubond,:xnubondre)
  GROUP BY NUbond,nubondre;


  return ;

end-proc;
//--------------------------------------------------------------------------
//
dcl-proc addAgentPayment;

dcl-pi *N;
  thischeck    likeds(check);
  XAmount       zoned(13:2);
end-pi;
  DBAgtPayCount += 1;
  DBAgtChecks(DBAgtPayCount).date = thischeck.date;
  DBAgtChecks(DBAgtPayCount).number = thischeck.number;
  DBAgtChecks(DBAgtPayCount).vendor = thischeck.vendor;
  DBAgtChecks(DBAgtPayCount).payee = thischeck.payee;
  DBAgtChecks(DBAgtPayCount).Amount = thischeck.amount;
  DBAgtChecks(DBAgtPayCount).XAmount = Xamount;
return ;

end-proc;
//--------------------------------------------------------------------------
//
dcl-proc isProcessedAgentPayment;

dcl-pi *N ind;
  Pcheck    zoned(7:0) CONST;
end-pi;

dcl-s TRUE  ind inz('1');
dcl-s FALSE ind inz('0');

  if (DBAgtPayCount=0) or (%lookup(pcheck:DBagtChecks(*).number:1:DBagtPayCount)=0);
    return FALSE;
  else;
    return TRUE;
  endif;

end-proc;
//--------------------------------------------------------------------------
//
dcl-proc getCheckDetails;

dcl-pi *N;
  Pcheck    zoned(7:0) CONST;
  thisCheck  likeds(CHECK);
end-pi;

clear thisCheck;
 // get check details
 EXEC SQL
   SELECT
     ZONED(c.corp#,3,0) CompanyID,
     ZONED(c.bank#,3,0) BankAccountID,
     ZONED(c.rchkr#,7,0) ChkNumber,
     ZONED(c.rramt$,11,2) Chkamount,
     ZONED(C.rrvnd#,6,0) VendorID,
     c.rrvndn Payee,
     CHAR( case when c.rchkr#>9000000 THEN 'W' ELSE 'C' END,1) PayType,
     IFNULL( iftovr.ific_date(rrckhh,rrckyy,rrckmm,rrckdd), '0001-01-01')
   INTO :thisCheck
   FROM xappfile.chkrlp C
   where c.rchkr#=:pcheck;
  mySQLStatus = SQLErrChk('getCheckDetails');
  if ( mySQLStatus ='OK' ) or ( mySQLStatus ='WRN');

  else;
    thisCheck.number = pcheck;
    thisCheck.payee =  '*** Check Not Found ***';
  endif;

return;

end-proc;
//--------------------------------------------------------------------------
//
dcl-proc getAgentVendorID ;

dcl-pi *N zoned(6:0);
  acode char(6);
end-pi;

dcl-s vnd# zoned(6:0);


// get check details
select;
  when (acode='A00418');
    vnd# = 5569;
  when (acode='A00580');
    vnd# = 5773;
  when (acode='A01340');
    vnd# = 6328;
  when (acode='A00816');
    vnd# = 5774;
  other;
    vnd# = 999999;
endsl;

return vnd#;

end-proc;
//--------------------------------------------------------------------------
//
dcl-proc getACode_BondEndorsement;

dcl-pi *N char(6);
  branch char(2) CONST;
  carrier char(2) CONST;
  program char(2) CONST;
  bond    zoned(7:0) CONST;
  bondren zoned(2:0) CONST;
  bondend zoned(4:0) CONST;
end-pi;

dcl-s ACode char(6);

clear acode;
exec sql

 SELECT s000prdclt concat DIGITS(s000prdcno) INTO :ACode
   FROM fbsp0000
 WHERE (s000bbran,s000bcarr,s000bprog,s000bndno,s000bndren,s000bendrs)
    =  (:branch,:carrier,:program,:bond,:bondren,:bondend);

return acode;

end-proc;
