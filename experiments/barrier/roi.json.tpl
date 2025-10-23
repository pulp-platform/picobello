<%
if experiment['n_clusters'] == 2:
    clusters = [0, 4]
elif experiment['n_clusters'] == 4:
    clusters = [0, 4, 8, 12]
elif experiment['n_clusters'] == 8:
    clusters = [0, 4, 8, 12, 1, 5, 9, 13]
elif experiment['n_clusters'] == 16:
    clusters = list(range(16))
%>

[
% for cluster in clusters:
    {
        "thread": "${f'hart_{cluster * 9 + 8 + 1}'}",
        "roi": [
    % if experiment['impl'] == 'sw':
            {"idx": 1, "label": "barrier"},
            {"idx": 3, "label": "barrier"},
    % elif experiment['impl'] == 'hw':
            {"idx": 3, "label": "barrier"},
            {"idx": 5, "label": "barrier"},
    % endif
        ]
    },
% endfor
]
