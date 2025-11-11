function redraw_digit_frame(win, P, S, digit)
% -------------------------------------------------------------------------
% redraw_digit_frame  |  Alavie - Sternberg WM Task Helper
%
% Draws a single digit on a blank background, centered on screen.
% Used during the encoding phase of the Sternberg WM task.
%
% USAGE
%   redraw_digit_frame(win, P, S, digit)
%
% INPUTS
%   win   : PTB window handle
%   P     : parameter struct (expects P.screen.bgColor and textColor)
%   S     : screen struct (expects S.cx, S.cy for screen center)
%   digit : numeric value or char to display
%
% BEHAVIOR
%   1) Clears the window to background color (no flip)
%   2) Draws the digit centered using draw_digit()
%
% NOTES
%   - Does NOT flip the screen — caller must call Screen('Flip', win)
%     after this to display the frame.
%   - Uses helper functions: clear_to_bg() and draw_digit().
% -------------------------------------------------------------------------

% Clear to background
clear_to_bg(win, P.screen.bgColor);

% Draw digit in center
draw_digit(win, S.cx, S.cy, digit, P.screen.textColor);
end
