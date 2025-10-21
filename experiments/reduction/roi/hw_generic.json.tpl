<%
    def pb_cluster_idx(c, r):
        return c * 4 + r

    n_rows = experiment['n_rows']
%>
[
% for r in range(n_rows):
    % for c in range(4):
    {
        "thread": "${f'hart_{1 + pb_cluster_idx(c, r) * 9 + 8}'}",
        "roi": [
            // First iteration
            {"idx": 1, "label": "reduction"},
            // Second iteration
            {"idx": 3, "label": "reduction"},
        ]
    },
    % endfor
% endfor
]
