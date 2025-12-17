% if experiment['n_rows'] == 1:
[
    {
        "thread": "${f'hart_{0 * 9 + 8 + 1}'}",
        "roi": [
            // Transfer from memory tile to cluster 0
            {"idx": 10, "label": "level 0"},

            // Transfer from cluster 0 to cluster 8
            {"idx": 12, "label": "level 1"},

            // Transfer from cluster 0 to cluster 4
            {"idx": 14, "label": "level 2"},

        ]
    },

    {
        "thread": "${f'hart_{8 * 9 + 8 + 1}'}",
        "roi": [
            // Transfer from cluster 8 to cluster 12
            {"idx": 6, "label": "level 2"}
        ]
    },
]
% elif experiment['n_rows'] == 2:
[
    {
        "thread": "${f'hart_{0 * 9 + 8 + 1}'}",
        "roi": [
            // Transfer from memory tile to cluster 0
            {"idx": 12, "label": "level 0"},

            // Transfer from cluster 0 to cluster 8
            {"idx": 14, "label": "level 1"},

            // Transfer from cluster 0 to cluster 4
            {"idx": 16, "label": "level 2"},

            // Transfer from cluster 0 to cluster 1
            {"idx": 18, "label": "level 3"},
        ]
    },

    {
        "thread": "${f'hart_{8 * 9 + 8 + 1}'}",
        "roi": [
            // Transfer from cluster 8 to cluster 12
            {"idx": 8, "label": "level 2"},

            // Transfer from cluster 8 to cluster 9
            {"idx": 10, "label": "level 3"}
        ]
    },

    {
        "thread": "${f'hart_{4 * 9 + 8 + 1}'}",
        "roi": [
            // Transfer from cluster 4 to cluster 5
            {"idx": 6, "label": "level 3"}
        ]
    },

    {
        "thread": "${f'hart_{12 * 9 + 8 + 1}'}",
        "roi": [
            // Transfer from cluster 12 to cluster 13
            {"idx": 6, "label": "level 3"}
        ]
    },
]
% elif experiment['n_rows'] == 4:
[
    {
        "thread": "${f'hart_{0 * 9 + 8 + 1}'}",
        "roi": [
            // Transfer from memory tile to cluster 0
            {"idx": 14, "label": "level 0"},

            // Transfer from cluster 0 to cluster 8
            {"idx": 16, "label": "level 1"},

            // Transfer from cluster 0 to cluster 4
            {"idx": 18, "label": "level 2"},

            // Transfer from cluster 0 to cluster 2
            {"idx": 20, "label": "level 3"},

            // Transfer from cluster 0 to cluster 1
            {"idx": 22, "label": "level 4"},
        ]
    },

    {
        "thread": "${f'hart_{8 * 9 + 8 + 1}'}",
        "roi": [
            // Transfer from cluster 8 to cluster 12
            {"idx": 10, "label": "level 2"},

            // Transfer from cluster 8 to cluster 10
            {"idx": 12, "label": "level 3"},

            // Transfer from cluster 8 to cluster 9
            {"idx": 14, "label": "level 4"}
        ]
    },

    {
        "thread": "${f'hart_{4 * 9 + 8 + 1}'}",
        "roi": [
            // Transfer from cluster 4 to cluster 6
            {"idx": 8, "label": "level 3"},

            // Transfer from cluster 4 to cluster 5
            {"idx": 10, "label": "level 4"},
        ]
    },

    {
        "thread": "${f'hart_{12 * 9 + 8 + 1}'}",
        "roi": [
            // Transfer from cluster 12 to cluster 14
            {"idx": 8, "label": "level 3"},

            // Transfer from cluster 12 to cluster 13
            {"idx": 10, "label": "level 4"},
        ]
    },

    {
        "thread": "${f'hart_{2 * 9 + 8 + 1}'}",
        "roi": [
            // Transfer from cluster 2 to cluster 3
            {"idx": 6, "label": "level 4"},
        ]
    },

    {
        "thread": "${f'hart_{6 * 9 + 8 + 1}'}",
        "roi": [
            // Transfer from cluster 6 to cluster 7
            {"idx": 6, "label": "level 4"}
        ]
    },

    {
        "thread": "${f'hart_{10 * 9 + 8 + 1}'}",
        "roi": [
            // Transfer from cluster 10 to cluster 11
            {"idx": 6, "label": "level 4"},
        ]
    },

    {
        "thread": "${f'hart_{14 * 9 + 8 + 1}'}",
        "roi": [
            // Transfer from cluster 14 to cluster 15
            {"idx": 6, "label": "level 4"},
        ]
    },
]
% endif
