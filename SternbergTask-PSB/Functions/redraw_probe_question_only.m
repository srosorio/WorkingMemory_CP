function redraw_probe_question_only(win, P, S)
% -------------------------------------------------------------------------
% redraw_probe_question_only  |  Alavie - Sternberg WM Task Helper
%
% Draws a plain background with a centered question mark ("?") — used during
% the **recall (probe)** phase when subjects must enter digits one by one.
%
% USAGE
%   redraw_probe_question_only(win, P, S)
%
% INPUTS
%   win : PTB window handle
%   P   : parameter struct
%         - P.screen.bgColor   : background color
%         - P.screen.textColor : text color
%         - Optional: P.probe.qMarkChar (custom symbol)
%   S   : screen struct (kept for compatibility; not used here)
%
% BEHAVIOR
%   1) Clears the window to background color.
%   2) Draws a centered question mark (or custom symbol) in the middle.
%
% NOTE
%   - Does NOT call Screen('Flip', win); caller must flip explicitly.
%   - This function is used for the probe mode that shows a single "?"
%     between each recall entry.
% -------------------------------------------------------------------------

% --- Fill background ---
Screen('FillRect', win, P.screen.bgColor);

% --- Select question mark character ---
if isfield(P,'probe') && isfield(P.probe,'qMarkChar')
    q = P.probe.qMarkChar;
else
    q = '?';
end

% --- Draw centered symbol ---
DrawFormattedText(win, q, 'center', 'center', P.screen.textColor);

end
