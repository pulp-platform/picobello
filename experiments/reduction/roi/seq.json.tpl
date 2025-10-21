<%
n_rows = experiment['n_rows']
n_cols = 4
n_batches = int(experiment['size'] // experiment['batch'])
n_repetitions = 2

def pb_cluster_idx(r, c):
    return c * n_cols + r
%>
[
    <% n_repetitions = 2 %>

    % for row in range(0, n_rows):
        ## for easternmost column, only DMA core
        {
            "thread": "${f'hart_{1 + pb_cluster_idx(row, n_cols-1)*9 + 8}'}",
            "roi": [
                % for iter in range(0, n_repetitions):
                    % for i in range(0, n_batches):
                        {"idx": ${(2 * n_batches + 2) * iter + 2 * i + 2}, "label": "${f'd_{i}'}"},
                    % endfor
                % endfor
            ]
        },

        ## for middle columns
        % for col in range(n_cols-2, 0, -1):
            ## Compute cores
            % for core in range(0, 8):
            {
                "thread": "${f'hart_{1 + pb_cluster_idx(row, col)*9 + core}'}",
                "roi": [
                    % for iter in range(0, n_repetitions):
                        % for i in range(0, n_batches):
                            {"idx": ${(2 * n_batches + 2) * iter + 2 * i + 2}, "label": "${f'c_{i}'}"},
                        % endfor
                    % endfor
                ]
            },
            % endfor
            ## DMA core
            {
                "thread": "${f'hart_{1 + pb_cluster_idx(row, col)*9 + 8}'}",
                "roi": [
                    % for iter in range(0, n_repetitions):
                        % for i in range(0, n_batches):
                            {"idx": ${(2 * n_batches + 2) * iter + 2 * i + 2}, "label": "${f'd_{i}'}"},
                        % endfor
                    % endfor
                ]
            },
        % endfor
    
        ## for westernmost column
        % if row != 0 and n_rows > 1:
            ## DMA core
            {
                "thread": "${f'hart_{1 + pb_cluster_idx(row, 0)*9 + 8}'}",
                "roi": [
                    % for iter in range(0, n_repetitions):
                        % for i in range(0, n_batches):
                            {"idx": ${(2 * n_batches + 2) * iter + 2 * i + 2}, "label": "${f'd2_{i}'}"},
                        % endfor
                    % endfor
                ]
            },
        % endif
        ## Compute cores
        % for core in range(0, 8):
        {
            "thread": "${f'hart_{1 + pb_cluster_idx(row, 0)*9 + core}'}",
            "roi": [
                % for iter in range(0, n_repetitions):
                    % for i in range(0, n_batches):
                        % if row == (n_rows - 1):
                            {"idx": ${(2 * n_batches + 2) * iter + 2 * i + 2}, "label": "${f'c_{i}'}"},
                        % else:
                            {"idx": ${(4 * n_batches + 2) * iter + 2 * i + 2}, "label": "${f'c_{i}'}"},
                            {"idx": ${(4 * n_batches + 2) * iter + 2 * n_batches + 2 * i + 2}, "label": "${f'c2_{i}'}"},
                        % endif
                    % endfor
                % endfor
            ]
        },
        % endfor
    % endfor
]