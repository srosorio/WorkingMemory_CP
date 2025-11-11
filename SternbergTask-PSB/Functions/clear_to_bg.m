function clear_to_bg(win, bg)
% -------------------------------------------------------------------------
% clear_to_bg  |  Alavie - Sternberg WM Task Helper
%
% Fill the entire Psychtoolbox window with the given background color.
% This function does NOT perform a Screen('Flip'); it only draws the color
% to the back buffer. Use Screen('Flip', win) after calling this function
% when you want the background to appear on screen.
%
% USAGE
%   clear_to_bg(win, bg)
%
% INPUTS
%   win : PTB window handle (from Screen or PsychImaging)
%   bg  : scalar or [R G B] background color (default = 127 gray)
%
% NOTES
%   - Safe for headless or mock mode: if win is 0 or empty, does nothing.
%   - Used throughout task phases (fixation, blank, probe, etc.)
% -------------------------------------------------------------------------

if nargin < 2, bg = 127; end
if isempty(win) || win == 0
    return;  % headless / no PTB window
end

Screen('FillRect', win, bg);
end
