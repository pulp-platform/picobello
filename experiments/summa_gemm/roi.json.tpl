<% n_tiles = experiment['n_tiles'] %>
[
    % for cluster in range(0,16):
        // Compute cores
        % for j in range(0, 8):
        {
            "thread": "${f'hart_{cluster * 9 + j + 1}'}",
            "roi": [
            % for i in range(0, n_tiles):
                {"idx": ${2 * i + 1}, "label": "${f'tile_{i}'}"},
            % endfor
            ]
        },
        % endfor

        // DMA core
        {
            "thread": "${f'hart_{cluster * 9 + 8 + 1}'}",
            "roi": [
                {"idx": 1, "label": "${f'tile_in_0'}"},
                % for i in range(0, n_tiles - 1):
                    {"idx": ${4*i + 3}, "label": "${f'tile_in_{i+1}'}"},
                    {"idx": ${4*i + 5}, "label": "${f'tile_out_{i}'}"},
                % endfor
                {"idx": ${n_tiles * 4 - 1}, "label": "${f'tile_out_{n_tiles-1}'}"},
            ]
        },
    % endfor
]
