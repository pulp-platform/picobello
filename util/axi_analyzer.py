from pathlib import Path
import pandas as pd
import json
import re

pd.options.display.float_format = '{:.1f}'.format

INT_FIELDS = {'addr', 'atop', 'burst', 'cache', 'id', 'len', 'size'}

######################
#    NICE PRINT      #
######################
def styled_print(message: str):
    # Define your markers and styles
    styles = {
        r"\\gb\{(.*?)\}": "\033[1;32m\\1\033[0m",  # bold green
        r"\\rb\{(.*?)\}": "\033[1;31m\\1\033[0m",  # bold red
        r"\\yb\{(.*?)\}": "\033[1;33m\\1\033[0m",  # bold yellow
        r"\\cb\{(.*?)\}": "\033[1;36m\\1\033[0m",  # bold cyan
    }

    styled = message
    for pattern, replacement in styles.items():
        styled = re.sub(pattern, replacement, styled)

    print(styled)

def gprint(msg): styled_print(f"\\gb{{{msg}}}")
def rprint(msg): styled_print(f"\\rb{{{msg}}}")
def yprint(msg): styled_print(f"\\yb{{{msg}}}")
def cprint(msg): styled_print(f"\\cb{{{msg}}}")

def raise_exception(extype: type[Exception], msg: str):
    rprint(msg)
    raise extype(msg)

######################
#    PARSING LOG     #
######################

# Function to convert the log line into a valid JSON struct for correct parsing
def clean_and_parse(line):
    line = re.sub(r',\s*}', '}', line.strip())
    line = re.sub(r"(0x[\da-fA-FxX]+)", r'"\1"', line)  # quote hex & X values
    line = line.replace("'", '"')  # JSON compatible
    return json.loads(line)

# Function to parse the log file from AXI DUMPER
def parse_axi_dump(file_path):
    """
    Parses the AXI transaction log file into a pandas DataFrame.
    All values (even hex) are converted and stored as integers to simplify processing.

    Parameters:
        file_path (str): Path to the AXI dump text file.

    Returns:
        pd.DataFrame: A DataFrame where each row is a transaction dictionary entry.
    """
    parsed_entries = []

    cprint(f"Parsing {file_path.name}")  # Optional
    with open(file_path, 'r') as file:
        for line_num, line in enumerate(file, start=1):
            line = line.strip().rstrip(',')

            # Convert all values to integers if possible
            try:
                parsed = clean_and_parse(line)
                format_entry = {}
                # Copnvert entries with the correct type
                for k, v in parsed.items():
                    if k in INT_FIELDS:
                        try:
                            format_entry[k] = int(v, 16) if isinstance(v, str) and v.startswith('0x') else int(v)
                        except Exception:
                            format_entry[k] = v  # fallback to string
                    else:
                        format_entry[k] = str(v)
                parsed_entries.append(format_entry)
            except Exception as e:
                rprint(f"Parsing line: {line.strip()}\n -> {e}")

        gprint(f"Parsed file {file_path}")

    df = pd.DataFrame(parsed_entries)
    # Set the time as first column in the dataframe
    # if 'time' in df.columns:
    #     cols = ['time'] + [col for col in df.columns if col != 'time']
    #     df = df[cols]

    return df

# Function to gather all the AXI transactions from different logs
def collect_df(directory, pattern="axi_trace_mem_tile_*.log"):
    """
    Collects and aggregates AXI transactions from multiple log files.

    Parameters:
        directory (str or Path): Directory containing the AXI log files.
        pattern (str): Glob pattern to match log files.

    Returns:
        pd.DataFrame: Combined and time-ordered DataFrame of all transactions.
    """
    directory = Path(directory)
    all_dfs = []

    for file_path in sorted(directory.glob(pattern)):
        df = parse_axi_dump(file_path)
        df['source_file'] = file_path.name  # Optional: track source
        all_dfs.append(df)

    if not all_dfs:
        raise_exception(FileNotFoundError, f"No AXI log files found in '{directory}' matching '{pattern}'")

    df_combined = pd.concat(all_dfs, ignore_index=True)

    # Set surce file and time to be the first twop columsn
    if 'source_file' in df_combined.columns and 'time' in df_combined.columns:
        cols = ['source_file', 'time'] + [col for col in df_combined.columns if col not in ('source_file', 'time')]
        df_combined = df_combined[cols]

    # Ensure sort order: first by 'time', then by 'source_file'
    df_combined.sort_values(by=['source_file', 'time'], inplace=True)

    return df_combined


######################
#   ELABORATE INFO   #
######################

# Function to annotate write addresses in the DataFrame
def resolve_write_addresses_per_interface(df):
    """
    Resolves and fills in the missing 'addr' field in each W (write data) entry
    based on the most recent AW (write address) entry before it.

    Modifies the DataFrame in place and returns it.

    Parameters:
        df (pd.DataFrame): Parsed AXI transactions

    Returns:
        pd.DataFrame: Modified DataFrame with filled 'addr' fields for W entries
    """

    current_aw = None
    w_counter = 0      # tracks how many W entries have occurred since last AW

    df = df.copy()  # Optional: avoid mutating original DF

    for idx, row in df.iterrows():
        if row.get('type') == 'AW':
            current_aw = {
                'addr': row.get('addr'),
                'size': row.get('size'),
            }
            w_counter = 0  # reset on new AW

        elif row.get('type') == 'W':
            if current_aw is not None:
                bytes_per_transfer = 1 << int(current_aw['size'])
                resolved_addr = current_aw['addr'] + w_counter * bytes_per_transfer
                df.at[idx, 'addr'] = resolved_addr
                w_counter += 1

                if row.get('last') == 1:
                  current_aw = None
                  w_counter = 0
            else:
                raise_exception(RuntimeError, (f"[{row.get('source_file')}] Found W entry without preceding AW at {row.get('time')} ps"))

    return df


# Function to annotate address of W/R transactions looking at the
# previous AW/AR requests. The check is done by transcations at
# the same interface, i.e. reported in the same file to avoid mixing
# W/R form a file with AW/AR of another dump.
def resolve_write_addresses(df):
    resolved_dfs = []

    for source, group in df.groupby('source_file', sort=False):
        resolved = resolve_write_addresses_per_interface(group)
        resolved_dfs.append(resolved)

    return pd.concat(resolved_dfs, ignore_index=True)


def _apply_field_filters(df_subset, **kwargs):
    for key, val in kwargs.items():
        if key not in df_subset.columns:
            raise_exception(ValueError, f"Column '{key}' not found in DataFrame.")

        if isinstance(val, str) and val.startswith('0x'):
            try:
                val = int(val, 16)
            except ValueError:
                raise_exception(ValueError, f"Invalid hex value for {key}: '{val}'")

        df_subset = df_subset[df_subset[key] == val]

    return df_subset.reset_index(drop=True)



def select_aw(df, **kwargs):
    df_aw = df[df['type'] == 'AW']
    return _apply_field_filters(df_aw, **kwargs)

def select_w(df, **kwargs):
    df_w = df[df['type'] == 'W']
    return _apply_field_filters(df_w, **kwargs)


def filter_transactions(df, tx_type, **kwargs):
    """
    Dispatches to type-specific filter logic for AW, W, etc.

    Parameters:
        df (pd.DataFrame): Full AXI DataFrame.
        tx_type (str): Type of transaction to filter ('AW', 'W', etc).
        kwargs (dict): Filters like addr='0x70000000', id=7, etc.

    Returns:
        pd.DataFrame: Filtered DataFrame based on type logic.
    """
    tx_type = tx_type.upper()
    if tx_type == "AW":
        return select_aw(df[df['type'] == 'AW'], **kwargs)
    elif tx_type == "W":
        return select_w(df, **kwargs)
    else:
        raise_exception(ValueError, f"Unsupported transaction type '{tx_type}'")



def format_axi_df_for_display(df):
    """
    Returns a new DataFrame with selected fields formatted as strings.
    This allows clean display, printing, or export to CSV.

    Only modifies formatting of specific fields; all others are untouched.
    """
    df_formatted = df.copy()

    def format_hex(x):
        return f"0x{int(x):x}" if pd.notnull(x) else "None"

    def format_int(x):
        return str(int(x)) if pd.notnull(x) else "None"

    def format_bool(x):
        return str(bool(x)) if pd.notnull(x) else "None"

    for col in INT_FIELDS:
        if col in df_formatted.columns:
            df_formatted[col] = df_formatted[col].apply(format_hex)

    return df_formatted


def save_df_to_csv(df, file_name):
    df.to_csv(file_name, index=False)


if __name__ == "__main__":
    file_path = "axi_trace_mem_tile_0.log"
    df = collect_df("axi_log/")

    df = resolve_write_addresses(df)
    save_df_to_csv(df, "df_orig.csv")

    df_formatted = filter_transactions(df, "W", addr="0x7000b080")
    df_formatted = format_axi_df_for_display(df_formatted)
    save_df_to_csv(df_formatted, "write_trans.csv")
    save_df_to_csv(df_formatted, "axi_log.csv")
