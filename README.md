# MT5 to MySQL Database EA v3.0

An Expert Advisor for MetaTrader 5 that automatically logs trading history to a MySQL database.

## Features

- **Automatic Trade Logging**: Captures all closed positions and stores them in MySQL
- **Real-time Updates**: Logs trades immediately when they close
- **Historical Data Import**: Imports existing trade history on first run
- **Duplicate Prevention**: Checks for existing records to avoid duplicates
- **Error Handling**: Comprehensive error handling with optional push notifications

## Requirements

- MetaTrader 5 with retail hedging account
- MySQL database server
- MQLMySQL library installed

## Setup

### 1. Database Configuration
Create a configuration file at: `{Experts Folder}\MyConnection.ini`

```ini
[MYSQL]
Server=localhost
User=your_username
Password=your_password
Database=your_database
Table=trading_history
Port=3306
Socket=
```

### 2. EA Parameters
- **experts_file_path**: Path to your MT5 Experts folder
- **start_date**: Historical data start date (0 = from beginning)
- **end_date**: Historical data end date
- **notify**: Enable/disable push notifications on errors

## Database Schema

The EA creates a table with the following structure:

| Column | Type | Description |
|--------|------|-------------|
| PositionID | INT (Primary Key) | Unique position identifier |
| DealTicketsInOut | VARCHAR(100) | Deal ticket numbers |
| Instrument | VARCHAR(45) | Trading symbol |
| Type | VARCHAR(45) | Position type (Buy/Sell) |
| Volume | DOUBLE | Trade volume |
| OpeningPrice | DOUBLE | Entry price |
| OpeningTime | DATETIME | Position open time |
| ClosingPrice | DOUBLE | Exit price |
| ClosingTime | DATETIME | Position close time |
| TradeDuration | VARCHAR(100) | Trade duration (HH:MM:SS) |
| Sl | DOUBLE | Stop loss level |
| Tp | DOUBLE | Take profit level |
| OpenComment | VARCHAR(100) | Opening comment |
| CloseComment | VARCHAR(100) | Closing comment |
| OpenReasonDescription | VARCHAR(100) | Open reason |
| CloseReasonDescription | VARCHAR(100) | Close reason |
| ExpertMagicNo | INT | EA magic number |
| Commission | DOUBLE | Trading commission |
| Swap | DOUBLE | Swap charges |
| Profit | DOUBLE | Gross profit |
| OverallProfit | DOUBLE | Net profit (after commission & swap) |

## Installation

1. Copy the EA file to your MT5 Experts folder
2. Install the MQLMySQL library
3. Create the database configuration file
4. Attach the EA to any chart
5. Configure the input parameters



## Version History

- v3.0 - Current version with enhanced error handling and notifications
