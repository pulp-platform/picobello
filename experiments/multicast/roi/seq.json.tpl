<%
num_batches = experiment['size'] // experiment['batch']
%>

[
% for row in range(0, experiment['n_rows']):
    % for col in range(0, 4):
    {
        // DMA cores
        "thread": "${f'hart_{(col * 4 + row) * 9 + 8 + 1}'}",
        "roi": [
            // First iteration
            {"idx": 1, "label": "init"},
        % for batch in range(num_batches):
            {"idx": ${1 + batch * 2 + 1}, "label": "${f'batch {batch}'}"},
            // {"idx": ${1 + batch * 2 + 2}, "label": "${f'sync {batch}'}"},
        % endfor
            {"idx": ${1 + num_batches * 2 + 1}, "label": "barrier"},
            // Second iteration
            {"idx": ${3 + num_batches * 2}, "label": "init"},
        % for batch in range(num_batches):
            {"idx": ${3 + num_batches * 2 + batch * 2 + 1}, "label": "${f'batch {batch}'}"},
            // {"idx": ${3 + num_batches * 2 + batch * 2 + 2}, "label": "${f'sync {batch}'}"},
        % endfor
        ]
    },
    % endfor
% endfor
]
