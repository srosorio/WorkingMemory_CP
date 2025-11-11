function draw_fixation(win, cx, cy, color)
% -------------------------------------------------------------------------
% draw_fixation  |  Alavie - Sternberg WM Task Helper
%
% Draws a small fixation cross centered at (cx, cy).
% Typically used by redraw_fixation_frame() and other visual phases.
%
% USAGE
%   draw_fixation(win, cx, cy, color)
%
% INPUTS
%   win   : PTB window handle
%   cx,cy : center coordinates (in pixels)
%   color : grayscale or [R G B] color value (default = 255)
%
% NOTES
%   - Does NOT flip the screen — call Screen('Flip', win) separately.
%   - Safe for headless mode: exits cleanly if win is empty or 0.
%   - Cross size and thickness are fixed for now; adjust below if needed.
% -------------------------------------------------------------------------

if nargin < 4, color = 255; end
if isempty(win) || win == 0
    return;  % headless / no PTB window
end

% Parameters
sz = 20;   % cross half-length (pixels)
th = 3;    % line thickness (pixels)

% Draw cross
Screen('DrawLine', win, color, cx - sz, cy, cx + sz, cy, th);  % horizontal
Screen('DrawLine', win, color, cx, cy - sz, cx, cy + sz, th);  % vertical
end
