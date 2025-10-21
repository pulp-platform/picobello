<%
import math
n_rows = experiment['n_rows']
n_batches = int(experiment['size'] // experiment['batch'])
n_levels_in_row = int(math.log2(4))
def n_levels_in_col(row_idx):
    if row_idx == 0:
        return int(math.log2(n_rows))
    elif row_idx == 2:
        return 1
    else:
        return 0

def pb_cluster_idx(row, col):
    return row + col * 4
%>

[
% for r in range(n_rows):
    {
        "thread": "${f'hart_{1 + pb_cluster_idx(r, 0) * 9 + 0}'}",
        "roi": [
    ## Reductions in row
    % for level_in_row in range(n_levels_in_row):
        % for batch in range(n_batches):
            {
                "idx": ${4 + n_batches * (n_levels_in_col(r) + n_levels_in_row) * 2 + (level_in_row * n_batches + batch) * 2},
                "label": "${f'comp l{level_in_row}'}"
            },
        % endfor
    % endfor
    ## Reductions in column 0
    % for level_in_col in range(n_levels_in_col(r)):
        % for batch in range(n_batches):
            {
                "idx": ${4 + n_batches * (n_levels_in_col(r) + n_levels_in_row) * 2 + ((n_levels_in_row + level_in_col) * n_batches + batch) * 2},
                "label": "${f'comp l{n_levels_in_row + level_in_col}'}"
            },
        % endfor
    % endfor
        ]
    },

    % if r > 0:
    {
        "thread": "${f'hart_{1 + pb_cluster_idx(r, 0) * 9 + 8}'}",
        "roi": [
        % for batch in range(n_batches):
            ## Transfer from cluster 2 to cluster 0
            {
                "idx": ${4 + n_batches * 2 + batch * 2},
                "label": "${f'{r} > {0 if r in [1, 2] else 2}'}"
            },
        % endfor
        ]
    },
    %endif

    {
        "thread": "${f'hart_{1 + pb_cluster_idx(r, 1) * 9 + 8}'}",
        "roi": [
        % for batch in range(n_batches):
            ## Transfer from cluster 4 to cluster 0
            {
                "idx": ${4 + n_batches * 2 + batch * 2},
                "label": "4 > 0"
            },
        % endfor
        ]
    },

    {
        "thread": "${f'hart_{1 + pb_cluster_idx(r, 1) * 9 + 8}'}",
        "roi": [
        % for batch in range(n_batches):
            ## Transfer from cluster 4 to cluster 0
            {
                "idx": ${4 + n_batches * 2 + batch * 2},
                "label": "4 > 0"
            },
        % endfor
        ]
    },

    {
        "thread": "${f'hart_{1 + pb_cluster_idx(r, 2) * 9 + 0}'}",
        "roi": [
        % for batch in range(n_batches):
            ## Stage 0 reduction
            {
                "idx": ${4 + n_batches * 2 + batch * 2},
                "label": "comp l0"
            },
        % endfor
        ]
    },
    {
        "thread": "${f'hart_{1 + pb_cluster_idx(r, 2) * 9 + 8}'}",
        "roi": [
        % for batch in range(n_batches):
            ## Transfer from cluster 8 to cluster 0
            {
                "idx": ${4 + n_batches * 2 + batch * 2},
                "label": "8 > 0"
            },
        % endfor
        ]
    },

    {
        "thread": "${f'hart_{1 + pb_cluster_idx(r, 3) * 9 + 8}'}",
        "roi": [
        % for batch in range(n_batches):
            ## Transfer from cluster 12 to cluster 8
            {
                "idx": ${4 + n_batches * 2 + batch * 2},
                "label": "12 > 8"
            },
        % endfor
        ]
    },
% endfor
]
