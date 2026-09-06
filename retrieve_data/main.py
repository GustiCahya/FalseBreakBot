import json
from datetime import datetime, timedelta
import dukascopy_python
from dukascopy_python.instruments import INSTRUMENT_FX_MAJORS_AUD_USD

def download_data():
    print("Downloading AUD/USD data from Dukascopy for the last 20 years...")
    
    # Calculate date range (last 20 years to today)
    end_date = datetime.now()
    start_date = end_date - timedelta(days=365*20)
    
    print(f"Date range: {start_date.strftime('%Y-%m-%d')} to {end_date.strftime('%Y-%m-%d')}")

    try:
        # Fetch Daily OHLCV data (1 Day interval chosen to prevent gigabytes of download)
        # You can change to dukascopy_python.INTERVAL_HOUR_1 for hourly data
        df = dukascopy_python.fetch(
            instrument=INSTRUMENT_FX_MAJORS_AUD_USD,
            start=start_date,
            end=end_date,
            interval=dukascopy_python.INTERVAL_DAY_1,
            offer_side=dukascopy_python.OFFER_SIDE_BID
        )

        print("Data downloaded successfully!")
        
        # Reset index to make timestamp a regular column
        df.reset_index(inplace=True)
            
        # Rename the datetime column to 'time'
        if 'timestamp' in df.columns:
            df.rename(columns={'timestamp': 'time'}, inplace=True)
        elif 'index' in df.columns:
            df.rename(columns={'index': 'time'}, inplace=True)
        
        # Convert datetime to string format compatible with MT5
        if 'time' in df.columns:
            df['time'] = df['time'].dt.strftime('%Y-%m-%d %H:%M:%S')

        # Drop any columns that are not typical OHLCV if needed, 
        # but typical Dukascopy return is [timestamp, open, high, low, close, volume]
        expected_cols = ['time', 'open', 'high', 'low', 'close', 'volume']
        cols_to_keep = [c for c in expected_cols if c in df.columns]
        if len(cols_to_keep) > 0:
            df = df[cols_to_keep]

        # Save to JSON array format
        output_file = "AUDUSD_20years_Daily.json"
        
        # Orient 'records' creates a JSON array of dictionaries, ideal for MT5
        json_data = df.to_dict(orient='records')
        
        with open(output_file, 'w') as f:
            json.dump(json_data, f, indent=4)
            
        print(f"Data saved to {output_file}")
        print(f"Total rows: {len(df)}")
        
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    download_data()
