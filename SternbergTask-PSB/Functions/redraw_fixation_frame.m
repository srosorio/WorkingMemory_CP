function redraw_fixation_frame(win, P, S)
% -------------------------------------------------------------------------
% redraw_fixation_frame  |  Alavie - WM task visual helper
%
% Draws a fixation cross centered on the screen.
% Used for baseline, post-digit, and post-distractor fixation frames.
%
% INPUTS
%   win : Psychtoolbox window handle
%   P   : parameter struct (expects P.screen.bgColor, P.screen.textColor)
%   S   : screen struct with center coordinates (S.cx, S.cy)
%
% BEHAVIOR
%   1) Clears the screen to background color
%   2) Draws a fixation cross centered at (S.cx, S.cy)
%
% DEPENDS ON
%   clear_to_bg.m:   fills the screen with background color
%   draw_fixation.m: draws the actual cross lines
% -------------------------------------------------------------------------

% Clear to background
clear_to_bg(win, P.screen.bgColor);

% Draw fixation cross (centered)
draw_fixation(win, S.cx, S.cy, P.screen.textColor);
end
