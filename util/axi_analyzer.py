# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Lorenzo Leone <lleone@iis.ee.ethz.ch>

import pandas as pd
import ast

pd.options.display.float_format = '{:.1f}'.format

INT_FIELDS = {'atop', 'burst', 'cache', 'id', 'len', 'size', 'user'}

######################
#    PARSING LOG     #
######################

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

    with open(file_path, 'r') as file:
        for line_num, line in enumerate(file, start=1):
            line = line.strip().rstrip(',')
            if not line:
                continue

            try:
                # Safely parse the line as a Python dictionary
                entry = ast.literal_eval(line)

                # Convert all values to integers if possible
                intified_entry = {}
                for k, v in entry.items():
                    if isinstance(v, int):
                        intified_entry[k] = v
                    elif isinstance(v, str):
                        intified_entry[k] = v  # keep strings like 'type'
                    else:
                        intified_entry[k] = int(v)  # cast floats or hex-compatible

                parsed_entries.append(intified_entry)

            except Exception as e:
                print(f"[Line {line_num}] Failed to parse line: {line}")
                print(f"  Error: {e}")

    df = pd.DataFrame(parsed_entries)
    # Set the time as first column in the dataframe
    if 'time' in df.columns:
        cols = ['time'] + [col for col in df.columns if col != 'time']
        df = df[cols]

    return df


# Function to annotate write addresses in the DataFrame
def resolve_write_addresses(df):
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
            print(current_aw)

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
                raise RuntimeError(f"[Line {idx}] Found W entry without preceding AW.")

    return df


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

    # Define format rules to apply to each df column
    format_rules = {
        'addr':  format_hex,
        'atop':  format_hex,
        'burst': format_hex,
        'id':    format_int,
        'len':   format_hex,
        'size':  format_hex,
        'data':  format_hex,
        'last':  format_bool,
        'strb':  format_hex,
    }

    for col, formatter in format_rules.items():
        # Apply format rules for the specified columns
        if col in df_formatted.columns:
            df_formatted[col] = df_formatted[col].apply(formatter)

    return df_formatted

# Function to select transactions matching a specific criteria
def filter_transactions(df, tx_type, **kwargs):
    """
    Filters the DataFrame for entries of a given transaction type (AW, W, etc.)
    and optional field-based filters like addr, id, burst, etc.

    Parameters:
        df (pd.DataFrame): The AXI transaction log DataFrame.
        tx_type (str): Required. Transaction type to filter on (e.g., 'AW', 'W').
        kwargs (dict): Additional field filters, e.g. addr='0x70000000', id=7.

    Returns:
        pd.DataFrame: Filtered DataFrame matching the criteria.
    """
    df_filtered = df[df['type'] == tx_type]

    for key, val in kwargs.items():
        if key not in df.columns:
            raise ValueError(f"Column '{key}' not found in DataFrame.")

        # Convert hex strings to int
        if isinstance(val, str) and val.startswith('0x'):
            try:
                val = int(val, 16)
            except ValueError:
                raise ValueError(f"Invalid hex value for {key}: '{val}'")

        df_filtered = df_filtered[df_filtered[key] == val]

    return df_filtered.reset_index(drop=True)


if __name__ == "__main__":
    file_path = "axi_trace_mem_tile_0.log"
    df = parse_axi_dump(file_path)
    df = resolve_write_addresses(df)
    df_formatted = filter_transactions(df, "W", addr="0x700044e8")
    df_formatted = format_axi_df_for_display(df_formatted)
    print(df_formatted)
