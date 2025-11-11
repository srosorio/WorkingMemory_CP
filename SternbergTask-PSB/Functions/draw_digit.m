function draw_digit(win, cx, cy, digit, color)
% -------------------------------------------------------------------------
% draw_digit  |  Alavie - Sternberg WM Task Helper
%
% Draws a single numeric digit centered on the screen.
% Typically used during the encoding (digit presentation) phase.
%
% USAGE
%   draw_digit(win, cx, cy, digit, color)
%
% INPUTS
%   win   : PTB window handle
%   cx,cy : screen center coordinates (currently unused)
%   digit : numeric value or char to draw
%   color : [R G B] or grayscale color (default = 255 white)
%
% NOTES
%   - Draws text to the back buffer only (no flip).
%   - Centering handled by DrawFormattedText().
%   - Safe for headless / mock mode: returns if win is invalid.
%   - Font and text size should be pre-configured in open_ptb_screen().
% -------------------------------------------------------------------------

if nargin < 5, color = 255; end
if isempty(win) || win == 0
    return;  % headless / no PTB window
end

% Draw digit centered on screen
DrawFormattedText(win, num2str(digit), 'center', 'center', color, [], [], [], 1.2);
end
