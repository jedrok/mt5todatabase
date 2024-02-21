//+------------------------------------------------------------------+
//|                                  MT5-TO-MYSQL-DATABASE-EA-V3.mq5 |
//|                                  Copyright 2023, Ariho Jedididah |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Ariho Jedididah"
#property link      "https://www.mql5.com"
#property version   "3.00"

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include <MQLMySQL.mqh>
#include <CHistoryPositionInfo.mqh>
CHistoryPositionInfo hist_position;            // instantiating CHistoryPositionsInfo class
#include <Trade\DealInfo.mqh>
CDealInfo           m_deal;                    // instantiating CDealInfo class
#include <math_utils.mqh>                      // unused lib, havent found a use case yet since i refactored the code

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+
int  Db_connection;                            // database identifier

//+------------------------------------------------------------------+
//| input variables                                                  |
//+------------------------------------------------------------------+
input string experts_file_path = "C:\\Users\\jedi\\AppData\\Roaming\\MetaQuotes\\Terminal\\D0E8209F77C8CF37AD8BF550E51FF075\\MQL5\\Experts"; //seperate using double backaslash (\\)
//input string Experts_file_path = "";

input datetime start_date = 0;                 // Start date
input datetime end_date   = D'2038.01.01';     // End date
input bool notify         = true;              // Push notification if query execution fails

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
 {
  ResetLastError();                   // resetting last error
//---Checking if input parameters are valid  
  if(AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
     {
      Alert("Erro: This EA is only for retail hedging accounts");
      return INIT_PARAMETERS_INCORRECT;
     }
//---
   if(start_date>end_date)
     {
      Alert("Error: The start date must be earlier than the end date");
      return INIT_PARAMETERS_INCORRECT;
     }
//---     
   int str_length = StringLen(experts_file_path); 
   if(str_length == 0)
     { 
      Alert("Error: Please input the \"Experts\" file path");

      return INIT_PARAMETERS_INCORRECT;
     }
     

//---opening connection with the database
 string Host, User, Password, Database,Table, Socket;     //variables to hold database  credentials
 
 int Port,Client_flag;
 
 Print (MySqlVersion());

//---reading database credentials from INI file
 Host = ReadIni(experts_file_path+"\\MyConnection.ini","MYSQL","Server");
 User = ReadIni(experts_file_path+"\\MyConnection.ini","MYSQL","User");
 Password = ReadIni(experts_file_path+"\\MyConnection.ini","MYSQL","Password");
 Database = ReadIni(experts_file_path+"\\MyConnection.ini","MYSQL","Database");
 Table = ReadIni(experts_file_path+"\\MyConnection.ini","MYSQL","Table"); 
 Port     = (int)StringToInteger(ReadIni(experts_file_path+"\\MyConnection.ini","MYSQL", "Port"));
 Socket   = ReadIni(experts_file_path+"\\MyConnection.ini","MYSQL","Socket");
 Client_flag = CLIENT_MULTI_STATEMENTS; //(int)StringToInteger(ReadIni(INI, "MYSQL", "ClientFlag"));  

 Print ("Host: ", Host, ", User: ", User, ", Database: ",Database);
 
//---open database connection
 Print ("Connecting...");
 
 Db_connection = MySqlConnect(Host, User, Password, Database, Port, Socket, Client_flag);   //connecting to the database
 
 if(Db_connection== -1){
   Print("Connection failed! Error: "+IntegerToString(MySqlErrorNumber) +": " +MySqlErrorDescription); 
   return INIT_FAILED;
 }
  else{ 
    Print("Connected! Db_co_connectionID#",Db_connection);
  }
  
//---checking if the table exists in the database(if it does not, we create the table then insert data)
 if(IsTableThere(Database,Table)){
   Print("Great...table ",Table, " already exists in the database.");
   }
 else{
   Print("Table ",Table," does not exist in the database!!!");
   Print("Creating table ",Table,"...");
   CreateTable(Table);
   Print("Confirming creation of table...");
   if(IsTableThere(Database,Table))
   {
    Print("Table creation confirmed..."); 
   }

 }

//--- Retrieve the history of closed positions for the specified period
  if(!hist_position.HistorySelect(start_date,end_date)){
   Alert("CHistoryPositionInfo::HistorySelect() failed!");
   return(false);
  }    
  
//--- now process the list of all closed positions
  int total = hist_position.PositionsTotal();
  for(int i = 0; i < total; i++){
//--- Select a closed position by its index in the list
  if(!hist_position.SelectByIndex(i)){
  Print("Error: OnInit() failed to select position by index, ", GetLastError());
  }
  else{
   datetime time_open         = hist_position.TimeOpen();
   datetime time_close        = hist_position.TimeClose();
   long     type              = hist_position.PositionType();
   string   type_desc         = hist_position.TypeDescription();
   long     magic             = hist_position.Magic();
   long     pos_id            = hist_position.Identifier();
   double   volume            = hist_position.Volume();
   double   price_open        = hist_position.PriceOpen();
   double   price_sl          = hist_position.StopLoss();
   double   price_tp          = hist_position.TakeProfit();
   double   price_close       = hist_position.PriceClose();
   double   commission        = hist_position.Commission();
   double   swap              = hist_position.Swap();
   double   profit            = hist_position.Profit();
   string   symbol            = hist_position.Symbol();
   string   open_comment      = hist_position.OpenComment();
   string   close_comment     = hist_position.CloseComment();
   string   open_reason_desc  = hist_position.OpenReasonDescription();
   string   close_reason_desc = hist_position.CloseReasonDescription();
   string   deal_tickets      = hist_position.DealTickets(",");
   int      deals_count       = HistoryDealsTotal();   // of the selected position
//---roundinf off the opening and closing prices 




//---converting the negative commision to positive innoder for the negative not to affect computation of overal profit
   double commission_as_positive_digits = MathAbs(commission);
   double overallprofit       = profit-((commission_as_positive_digits)+(swap));
   
   datetime trade_duration    = (time_close - time_open);          
//---convert trade duration DateTime to seconds by simply type casting to long
   long trade_duration_coverted_to_seconds = (long)trade_duration;
   
//---calculate the hours, minutes and seconds of the trade duration using the time in seconds
   long duration_hours   = (trade_duration_coverted_to_seconds/3600);         //calculating hours
   long duration_minutes = (trade_duration_coverted_to_seconds%3600)/60;      //calculating minutes
   long duration_seconds = (trade_duration_coverted_to_seconds%60);           //calculating the secs
   string duration_string = StringFormat("%02d h : %02d m : %02d s",duration_hours,duration_minutes,duration_seconds);
   
//---checking if a record already exists in the table(if it does, we ignore and continue, if it doesn't we insert the record in table)
   if(IsTherePrimaryKey(pos_id,Table)){
    Print("Data for Position ID: ",pos_id," already exists in the table ",Table,".");  
   }
   
  else{
//---inserting data into table

  string Query;  
  Query = "INSERT INTO " + Database + "." + Table + "(PositionID,DealTicketsInOut,Instrument,Type,Volume,OpeningPrice,OpeningTime,ClosingPrice," +
        "ClosingTime,TradeDuration,Sl,Tp,OpenComment,CloseComment,OpenReasonDescription,CloseReasonDescription,ExpertMagicNo,Commision,Swap," +
        "Profit,OverallProfit) VALUES('" + string(pos_id) + "','" + deal_tickets + "','" + symbol + "','" + type_desc + "'," + DoubleToString(volume) + "," + DoubleToString(price_open) + "," + 
        "'" + TimeToString(time_open) + "'," + DoubleToString(price_close) + ",'" + TimeToString(time_close) + "','" + duration_string + "'," + DoubleToString(price_sl) + "," + 
        DoubleToString(price_tp) + ",'" + open_comment + "','" + close_comment + "','" + open_reason_desc + "','" + close_reason_desc + "'," + 
        IntegerToString(magic) + "," + DoubleToString(commission) + "," + DoubleToString(swap) + "," + DoubleToString(profit) + "," + DoubleToString(overallprofit) + ");";
   
//---error handling if the query fails
  bool notification_sent_flag = false;      //notification sent checker flag

  if (!MySqlExecute(Db_connection, Query)) {
    Print("Error #", MySqlErrorNumber, "\n", MySqlErrorDescription, "\nProblem with OnInit() insert query!!!", Query);    
    Comment("Error #", MySqlErrorNumber, "\n", MySqlErrorDescription, "\nProblem with OnInit() insert query!!!", Query);    
     if(notify && !notification_sent_flag){    
       SendNotification("Problem with OnInit() insert query!!!");
        notification_sent_flag = true;    
        }
        
         return INIT_FAILED;  //incase of query failure, stop and exit execution(initialization of expert advisor stops)
      }   
   else {
        Print("Data for Position ID: " + string(pos_id) + " successfully inserted into the database.");    //to track number of trade records inserted into table in database
        notification_sent_flag = false;  //resetting the notifications sent flag to false
          
        }  
   }
   
   
    }                       //end of if statment 
    
    
 }                          //end of for loop
     
//---print message to let us know all previous trades have been inserted on initialization 
   Print("Great...all previous trade records have been successfully inserted into the database.");
   
   return(INIT_SUCCEEDED); 
 }
  
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){
  ResetLastError();                   //resetting last error
  MySqlDisconnect(Db_connection);     //disconecting database on deninitalization
  Print("Database Disconnected!!!");    
  ExpertRemove();                     //removing expert advisor from chart
  Comment(" ");                       //removing comments from the chart
 }
  

//+------------------------------------------------------------------+
//| Expert TradeTransaction function                                 |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
//--- get transaction type as enumeration value
   ENUM_TRADE_TRANSACTION_TYPE transaction_type=trans.type;
//--- if transaction is result of addition of the transaction in history
   if(transaction_type==TRADE_TRANSACTION_DEAL_ADD)
     {
      ResetLastError();          //resetting the last error
      
//---accessing deal history
  if(HistoryDealSelect(trans.deal))
     m_deal.Ticket(trans.deal);
  else
    {
     Print(__FILE__," ",__FUNCTION__,", ERROR: ","HistoryDealSelect(",trans.deal,") error: ",GetLastError());
     return;
    }
  if(m_deal.DealType()==DEAL_TYPE_BUY || m_deal.DealType()==DEAL_TYPE_SELL)
    {
     if(m_deal.Entry()==DEAL_ENTRY_OUT)         //checking if a trade has just closed by checking if an out deal has just been added to deal history
       {
//--- Retrieve the history of closed positions for the specified period
  if(!hist_position.HistorySelect(start_date,end_date))
    {
     Alert("CHistoryPositionInfo::HistorySelect() failed OnTick!");
     return;
    } 
//--- now process the lastest(most recent) closed position
  int total = hist_position.PositionsTotal();
//--- Select the latest closed position by its index in the list
  if(!hist_position.SelectByIndex(total-1)){
  Print("Error: OnTradeTransaction() failed to select position by index, ", GetLastError());
  }
  else{
   datetime time_open         = hist_position.TimeOpen();
   datetime time_close        = hist_position.TimeClose();
   long     type              = hist_position.PositionType();
   string   type_desc         = hist_position.TypeDescription();
   long     magic             = hist_position.Magic();
   long     pos_id            = hist_position.Identifier();
   double   volume            = hist_position.Volume();
   double   price_open        = hist_position.PriceOpen();
   double   price_sl          = hist_position.StopLoss();
   double   price_tp          = hist_position.TakeProfit();
   double   price_close       = hist_position.PriceClose();
   double   commission        = hist_position.Commission();
   double   swap              = hist_position.Swap();
   double   profit            = hist_position.Profit();
   string   symbol            = hist_position.Symbol();
   string   open_comment      = hist_position.OpenComment();
   string   close_comment     = hist_position.CloseComment();
   string   open_reason_desc  = hist_position.OpenReasonDescription();
   string   close_reason_desc = hist_position.CloseReasonDescription();
   string   deal_tickets      = hist_position.DealTickets(",");
   int      deals_count       = HistoryDealsTotal();   // of the selected position
    //------converting the negative commision to positive innoder for the negative not to affect computation of overal profit
   double commission_as_positive_digits = MathAbs(commission);
   double overallprofit       = profit-((commission_as_positive_digits)+(swap)); 
   datetime trade_duration    = (time_close - time_open); 
    //--convert trade duration DateTime to seconds by simply type casting to long
   long trade_duration_coverted_to_seconds = (long)trade_duration;
   //--calculate the hours, minutes and seconds of the trade duration using the time in seconds
   long duration_hours   = (trade_duration_coverted_to_seconds/3600);         //calculating hours
   long duration_minutes = (trade_duration_coverted_to_seconds%3600)/60;      //calculating minutes
   long duration_seconds = (trade_duration_coverted_to_seconds%60);           //calculating the secs
   string duration_string = StringFormat("%02d h : %02d m : %02d s",duration_hours,duration_minutes,duration_seconds);
   
//---inserting data into table
   string Query,Database,Table; 
  
//---reading credentials from ini file
  Database = ReadIni(experts_file_path+"\\MyConnection.ini","MYSQL","Database");
  Table = ReadIni(experts_file_path+"\\MyConnection.ini","MYSQL","Table"); 
  
 
  Query = "INSERT INTO " + Database + "." + Table + "(PositionID,DealTicketsInOut,Instrument,Type,Volume,OpeningPrice,OpeningTime,ClosingPrice," +
        "ClosingTime,TradeDuration,Sl,Tp,OpenComment,CloseComment,OpenReasonDescription,CloseReasonDescription,ExpertMagicNo,Commision,Swap," +
        "Profit,OverallProfit) VALUES('" + string(pos_id) + "','" + deal_tickets + "','" + symbol + "','" + type_desc + "'," + DoubleToString(volume) + "," + DoubleToString(price_open) + "," + 
        "'" + TimeToString(time_open) + "'," + DoubleToString(price_close) + ",'" + TimeToString(time_close) + "','" + duration_string + "'," + DoubleToString(price_sl) + "," + 
        DoubleToString(price_tp) + ",'" + open_comment + "','" + close_comment + "','" + open_reason_desc + "','" + close_reason_desc + "'," + 
        IntegerToString(magic) + "," + DoubleToString(commission) + "," + DoubleToString(swap) + "," + DoubleToString(profit) + "," + DoubleToString(overallprofit) + ");";
   
//---error handling if the query fails
  bool notification_sent_flag = false;      //notification sent checker flag

  if (!MySqlExecute(Db_connection, Query)) {
    Print("Error #", MySqlErrorNumber, "\n", MySqlErrorDescription, "\nProblem with OnTradeTransaction() insert query!!!", Query);    
    Comment("Error #", MySqlErrorNumber, "\n", MySqlErrorDescription, "\nProblem with OnTradeTransaction() insert query!!!", Query);    
    
     if(notify && !notification_sent_flag){    
       SendNotification("Problem with OnTradeTransaction() insert query!!!");
        notification_sent_flag = true;  
        }
      }   
   else {
   Print("A trade with Position ID: " + string(pos_id) +" just closed and successfully inserted into the database."); 
   notification_sent_flag = false;  //resetting the notifications sent flag to false
       }  
          
      }
            
            
            
          }
       }
    }
 }

//+--------------------------------------------------------------------------------------------------------------------------------------------+
//|                                                          Custom Functions                                                                  |
//+--------------------------------------------------------------------------------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| IsTableThere function                                            |
//+------------------------------------------------------------------+
bool IsTableThere(string &Database, string &Table){

  int Cursor, Rows, mysql_return_value;
  string Query;

  Query = "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = '" + Database + "' AND TABLE_NAME = '" + Table + "';";

  Cursor = MySqlCursorOpen(Db_connection, Query);
    if (Cursor >= 0) {              // cursor opened
        Rows = MySqlCursorRows(Cursor);
        if (Rows > 0) {             // record exists
            if (MySqlCursorFetchRow(Cursor)) {
                // retrieve digit in the row field 
                mysql_return_value = MySqlGetFieldAsInt(Cursor, 0);
                //if return value is = 1, table exists, if it is = 0, the table doesn't exist
                if (mysql_return_value == 1) {
                    MySqlCursorClose(Cursor);
                    
                    return true;
                }
            }
        }
       
       MySqlCursorClose(Cursor);
    }
    
  return false;
 }


//+------------------------------------------------------------------+
//| IsTherePrimaryKey  function                                      |
//+------------------------------------------------------------------+
bool IsTherePrimaryKey(long &pos_id, string &Table){
  int Cursor, Rows, mysql_return_value;
  string  Query;

  Query = "SELECT EXISTS(SELECT 1 FROM "+Table+" WHERE PositionID IN ('"+ string(pos_id) +"')) AS id_exists;";

  Cursor = MySqlCursorOpen(Db_connection, Query);
    if (Cursor >= 0) {              // cursor opened
        Rows = MySqlCursorRows(Cursor);
        if (Rows > 0) {             // record exists
            if (MySqlCursorFetchRow(Cursor)) {
                // retrieve digit in the row field 
                mysql_return_value = MySqlGetFieldAsInt(Cursor, 0);
                //if return value is = 1, the primary Key exists, if it is = 0, then the primary key doesn't exist
                if (mysql_return_value == 1) {
                
                   MySqlCursorClose(Cursor);
                    return true;
                   
                       }   
                     }
                  }    
      
           MySqlCursorClose(Cursor);
       
          }
          
    return false;
 }  
  
  
//+------------------------------------------------------------------+
//| CreateTable function                                             |
//+------------------------------------------------------------------+
void CreateTable(string &Table){
//---creating the table in the database
 string Query; 

 Query = "CREATE TABLE `"+Table+"`" + "("+
  "`PositionID` INT PRIMARY KEY NOT NULL," +  
  "`DealTicketsInOut` varchar(100) NOT NULL,"+
  "`Instrument` varchar(45) DEFAULT NULL,"+
  "`Type` varchar(45) DEFAULT NULL,"+
  "`Volume` double DEFAULT NULL,"+
  "`OpeningPrice` double DEFAULT NULL,"+
  "`OpeningTime` datetime DEFAULT NULL,"+
  "`ClosingPrice` double DEFAULT NULL,"+
  "`ClosingTime` datetime DEFAULT NULL,"+
  "`TradeDuration` varchar(100) DEFAULT NULL,"+
  "`Sl` double DEFAULT NULL,"+
  "`Tp` double DEFAULT NULL,"+
  "`OpenComment` varchar(100) DEFAULT NULL,"+
  "`CloseComment` varchar(100) DEFAULT NULL,"+
  "`OpenReasonDescription` varchar(100) DEFAULT NULL,"+
  "`CloseReasonDescription` varchar(100) DEFAULT NULL,"+
  "`ExpertMagicNo` int DEFAULT NULL,"+
  "`Commision` double DEFAULT NULL,"+
  "`Swap` double DEFAULT NULL,"+
  "`Profit` double DEFAULT NULL,"+
  "`OverallProfit` double DEFAULT NULL"+
  ");";
                   
//---error handling if the query fails
  bool notification_sent_flag = false;      //notification sent checker flag

  if (!MySqlExecute(Db_connection, Query)){
    Print("Error #", MySqlErrorNumber, "\n", MySqlErrorDescription, "\nProblem with create table query: ", Query);    
    Comment("Error #", MySqlErrorNumber, "\n", MySqlErrorDescription, "\nProblem with create table query: ", Query);    
 
     if(notify && !notification_sent_flag){    
       SendNotification("Problem with CreateTable() create table query!!!");
        notification_sent_flag = true;  
        }
      }        
      else
      {
       Print("Table ",Table," created successfully."); 
       notification_sent_flag = false;  //resetting the notifications sent flag to false
      }       
 }
 

//+----------------------------------------------------------------------------------------------------------------------------------+
