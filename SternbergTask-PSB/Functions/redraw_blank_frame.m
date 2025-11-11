function redraw_blank_frame(win, P)
% -------------------------------------------------------------------------
% redraw_blank_frame  |  Alavie - Sternberg WM Task Helper
%
% Clears the current Psychtoolbox window to the background color.
% Used whenever the task requires a blank frame (e.g., between digits,
% after fixation, or during ITI).
%
% USAGE
%   redraw_blank_frame(win, P)
%
% INPUTS
%   win : PTB window handle
%   P   : parameter struct (expects P.screen.bgColor)
%
% NOTES
%   - This function only draws to the back buffer (no flip).
%   - Use Screen('Flip', win) to present the blank frame.
% -------------------------------------------------------------------------

clear_to_bg(win, P.screen.bgColor);
end

